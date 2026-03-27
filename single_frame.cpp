#include <iostream>
#include <vector>
#include <memory>
#include <opencv2/opencv.hpp>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
}

#include <KinesisVideoProducer.h>

using namespace std;
using namespace cv;
using namespace com::amazonaws::kinesis::video;

class EmptyClientCallbackProvider : public ClientCallbackProvider {
public:
    UINT64 getCallbackCustomData() override { return 0; }
};

class EmptyStreamCallbackProvider : public StreamCallbackProvider {
public:
    UINT64 getCallbackCustomData() override { return 0; }

    // void streamErrorReport(UINT64, STREAM_HANDLE, UPLOAD_HANDLE, UINT64 errored_timecode, STATUS status_code)  {
    //     printf("[SDK ERROR] Stream Error: 0x%08x at timecode %llu\n", status_code, errored_timecode);
    // }

    // void streamDroppedFrameHandler(UINT64, STREAM_HANDLE, UINT64 dropped_frame_timestamp)  {
    //     printf("[SDK WARNING] Frame dropped at timestamp: %llu\n", dropped_frame_timestamp);
    // }
};

// ---------------- Helper ----------------
uint64_t getCurrentKvsTimestamp() {
    // AWS KVS uses 100-ns precision
    return chrono::duration_cast<chrono::nanoseconds>(
               chrono::system_clock::now().time_since_epoch()).count() / 100;
}

// ---------------- Main ----------------
int main() {
    log4cplus::PropertyConfigurator::doConfigure("log4cplus.properties");
    cout << "[INFO] Starting single-frame KVS test...\n";

    string stream_name = "video-analytics-video-stream";
    std::shared_ptr<KinesisVideoStream> stream = nullptr;

    // ---------------- Credentials ----------------
    Credentials creds(
        getenv("AWS_ACCESS_KEY_ID") ? getenv("AWS_ACCESS_KEY_ID") : "",
        getenv("AWS_SECRET_ACCESS_KEY") ? getenv("AWS_SECRET_ACCESS_KEY") : "",
        getenv("AWS_SESSION_TOKEN") ? getenv("AWS_SESSION_TOKEN") : ""
    );

    auto credentialProvider = std::make_unique<StaticCredentialProvider>(creds);
    auto callbackProvider = std::make_unique<DefaultCallbackProvider>(
        std::make_unique<EmptyClientCallbackProvider>(),
        std::make_unique<EmptyStreamCallbackProvider>(),
        std::move(credentialProvider),
        "us-east-1",
        "",
        "",
        "",
        "",
        false,
        (uint64_t)0
    );

    auto producer = KinesisVideoProducer::createSync(std::make_unique<DefaultDeviceInfoProvider>(),
                                                     std::move(callbackProvider));
    cout << "[INFO] KinesisVideoProducer created\n";

    // ---------------- Camera Capture ----------------
    VideoCapture cap(0);
    if (!cap.isOpened()) { cerr << "[ERROR] Camera open failed\n"; return -1; }

    Mat frame;
    cap >> frame;  // Capture single frame
    if (frame.empty()) { cerr << "[ERROR] Failed to capture frame\n"; return -1; }

    int width = frame.cols;
    int height = frame.rows;

    // ---------------- H264 Encoder ----------------
    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    AVCodecContext* ctx = avcodec_alloc_context3(codec);
    ctx->width = width;
    ctx->height = height;
    ctx->time_base = {1, 30};
    ctx->framerate = {30, 1};
    ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    ctx->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    ctx->gop_size = 30;
    ctx->has_b_frames = 0;

    av_opt_set(ctx->priv_data, "preset", "ultrafast", 0);
    av_opt_set(ctx->priv_data, "tune", "zerolatency", 0);

    avcodec_open2(ctx, codec, nullptr);

    AVFrame* frame_ff = av_frame_alloc();
    frame_ff->format = ctx->pix_fmt;
    frame_ff->width = width;
    frame_ff->height = height;
    av_frame_get_buffer(frame_ff, 32);

    // Convert frame to YUV420
    Mat yuv;
    cvtColor(frame, yuv, COLOR_BGR2YUV_I420);
    memcpy(frame_ff->data[0], yuv.data, width * height);
    memcpy(frame_ff->data[1], yuv.data + width * height, width * height / 4);
    memcpy(frame_ff->data[2], yuv.data + width * height * 5 / 4, width * height / 4);
    frame_ff->pts = 0;

    AVPacket* pkt = av_packet_alloc();
    avcodec_send_frame(ctx, frame_ff);
    while (stream->getStreamStatus() != STREAM_STATUS_READY) {
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }
    if (avcodec_receive_packet(ctx, pkt) == 0) {
        // ---------------- Initialize KVS Stream ----------------
        auto stream_definition = std::make_unique<StreamDefinition>(
            stream_name,
            chrono::hours(24),
            nullptr, "", STREAMING_TYPE_REALTIME, "video/h264",
            chrono::milliseconds::zero(), chrono::seconds(2),
            chrono::milliseconds(1), true, true, true,
            "V_MPEG4/ISO/AVC", "Video Track",
            ctx->extradata, ctx->extradata_size,
            NAL_ADAPTATION_ANNEXB_NALS | NAL_ADAPTATION_ANNEXB_CPD_NALS
        );

        stream = producer->createStreamSync(std::move(stream_definition));
        cout << "[INFO] KVS Stream initialized\n";

        // ---------------- Prepare Frame ----------------
        Frame kvs_frame;
        kvs_frame.index = 0;
        kvs_frame.flags = FRAME_FLAG_KEY_FRAME; // Single frame MUST be key
        kvs_frame.presentationTs = getCurrentKvsTimestamp();
        kvs_frame.decodingTs = kvs_frame.presentationTs;
        kvs_frame.duration = 333333; // 33.3ms
        kvs_frame.size = pkt->size;
        kvs_frame.frameData = pkt->data;

        // ---------------- Send to KVS ----------------
        STATUS status = stream->putFrame(kvs_frame);
        if (status == STATUS_SUCCESS) {
            cout << "[SUCCESS] Single frame sent to KVS\n";
        } else {
            cout << "[ERROR] Failed to put frame: 0x" << hex << status << endl;
        }
    }

    // ---------------- Cleanup ----------------
    cap.release();
    av_frame_free(&frame_ff);
    av_packet_free(&pkt);
    avcodec_free_context(&ctx);
    return 0;
}