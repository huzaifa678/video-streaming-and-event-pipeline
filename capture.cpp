#define __STDC_CONSTANT_MACROS
#define __STDC_LIMIT_MACROS

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavcodec/bsf.h>
#include <libavutil/opt.h>
#include <libswscale/swscale.h>
}

#include <iostream>
#include <memory>
#include <opencv2/opencv.hpp>
#include <KinesisVideoProducer.h>

using namespace std;
using namespace cv;
using namespace com::amazonaws::kinesis::video;

#define LOG(x) cout << "[INFO] " << x << endl
#define ERR(x) cerr << "[ERROR] " << x << endl


class EmptyClientCallbackProvider : public ClientCallbackProvider {
public:
    UINT64 getCallbackCustomData() { return 0; }
};

class EmptyStreamCallbackProvider : public StreamCallbackProvider {
public:
    UINT64 getCallbackCustomData() { return 0; }
};

class MyDeviceInfoProvider : public DefaultDeviceInfoProvider {
public:
    device_info_t getDeviceInfo() override {
        auto d = DefaultDeviceInfoProvider::getDeviceInfo();
        d.storageInfo.storageSize = 256 * 1024 * 1024;
        return d;
    }
};


int main() {

    log4cplus::PropertyConfigurator::doConfigure("log4cplus.properties");

    Credentials creds(getenv("AWS_ACCESS_KEY_ID") ?: "", getenv("AWS_SECRET_ACCESS_KEY") ?: "");
    if (creds.getAccessKey().empty()) {
        ERR("AWS Credentials not found!");
        return -1;
    }

    auto callbackProvider = make_unique<DefaultCallbackProvider>(
        make_unique<EmptyClientCallbackProvider>(),
        make_unique<EmptyStreamCallbackProvider>(),
        make_unique<StaticCredentialProvider>(creds),
        "us-east-1", "", "", "", "", API_CALL_CACHE_TYPE_ALL, 0
    );

    auto producer = KinesisVideoProducer::createSync(make_unique<MyDeviceInfoProvider>(), std::move(callbackProvider));

    VideoCapture cap(0);
    cap.set(CAP_PROP_FRAME_WIDTH, 1280);
    cap.set(CAP_PROP_FRAME_HEIGHT, 720);
    int width = cap.get(CAP_PROP_FRAME_WIDTH), height = cap.get(CAP_PROP_FRAME_HEIGHT), fps = 30;

    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    AVCodecContext* ctx = avcodec_alloc_context3(codec);
    ctx->width = width; 
    ctx->height = height; 
    ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    ctx->time_base = {1, fps}; 
    ctx->gop_size = fps; 
    ctx->max_b_frames = 0;
    ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

    AVDictionary* opts = nullptr;
    av_dict_set(&opts, "preset", "ultrafast", 0);
    av_dict_set(&opts, "tune", "zerolatency", 0);
    av_dict_set(&opts, "x264-params", "keyint=30:min-keyint=30:scenecut=0:repeat-headers=1:annexb=1:bitrate=2000:vbv-maxrate=2000:vbv-bufsize=4000:nal-hrd=cbr", 0);

    if (avcodec_open2(ctx, codec, &opts) < 0) {
        ERR("Could not open codec");
        return -1;
    }
    LOG("Encoder opened. Extradata size: " << ctx->extradata_size);

    SwsContext* sws_ctx = sws_getContext(width, height, AV_PIX_FMT_BGR24, width, height, AV_PIX_FMT_YUV420P, SWS_BILINEAR, nullptr, nullptr, nullptr);
    AVFrame* frame = av_frame_alloc();
    frame->width = width; frame->height = height; frame->format = ctx->pix_fmt;
    av_frame_get_buffer(frame, 32);

    AVPacket* pkt = av_packet_alloc();
    shared_ptr<KinesisVideoStream> stream = nullptr;
    bool streamInit = false;

    uint64_t frameCounter = 0;
    uint64_t startTime = chrono::duration_cast<chrono::nanoseconds>(chrono::system_clock::now().time_since_epoch()).count() / 100;

    while (true) {
        auto frameStart = chrono::steady_clock::now();
        Mat img; cap >> img;
        if (img.empty()) continue;

        const uint8_t* src[] = { img.data };
        int stride[] = { (int)img.step[0] };
        sws_scale(sws_ctx, src, stride, 0, height, frame->data, frame->linesize);

        frame->pts = frameCounter;

        if (avcodec_send_frame(ctx, frame) >= 0) {
            while (avcodec_receive_packet(ctx, pkt) >= 0) {
                if (!streamInit) {
                    if (!(pkt->flags & AV_PKT_FLAG_KEY)) {
                        av_packet_unref(pkt);
                        continue;
                    }
                    
                    auto def = make_unique<StreamDefinition>(
                        "video-analytics-video-stream", chrono::hours(24), nullptr, "", 
                        STREAMING_TYPE_REALTIME, "video/h264",
                        chrono::milliseconds::zero(), chrono::milliseconds(2000), chrono::milliseconds(1),
                        true, true, true, true, true, true, true,
                        (NAL_ADAPTATION_ANNEXB_NALS | NAL_ADAPTATION_ANNEXB_CPD_NALS),
                        fps, 4*1024*1024, chrono::seconds(120), chrono::seconds(40), chrono::seconds(30),
                        "V_MPEG4/ISO/AVC", "Video Track", ctx->extradata, (uint32_t)ctx->extradata_size
                    );
                    stream = producer->createStreamSync(std::move(def));
                    streamInit = true;
                    LOG("KVS Stream Initialized.");
                }

                Frame kvsFrame{};
                kvsFrame.index = frameCounter; 
                uint64_t ts = startTime + (frameCounter * (10000000 / fps));

                kvsFrame.flags = (pkt->flags & AV_PKT_FLAG_KEY) ? FRAME_FLAG_KEY_FRAME : FRAME_FLAG_NONE;
                kvsFrame.presentationTs = ts;
                kvsFrame.decodingTs = ts;
                kvsFrame.duration = 10000000 / fps;
                kvsFrame.size = pkt->size;
                kvsFrame.frameData = pkt->data;
                kvsFrame.trackId = 1;

                stream->putFrame(kvsFrame);
                frameCounter++; 
                av_packet_unref(pkt); 
            }
        }
        if (waitKey(1) == 27) break;
        this_thread::sleep_until(frameStart + chrono::milliseconds(1000 / fps));
    }

    av_frame_free(&frame); av_packet_free(&pkt);
    avcodec_free_context(&ctx); sws_freeContext(sws_ctx);
    return 0;
}