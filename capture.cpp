#include <iostream>
#include <vector>
#include <memory>
#include <chrono>
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
};

int main() {
    cout << "[INFO] Starting KVS video streaming application...\n";

    string stream_name = "video-analytics-video-stream";
    std::shared_ptr<KinesisVideoStream> stream;
    cout << "[INFO] Stream name: " << stream_name << endl;

    auto deviceInfoProvider = std::make_unique<DefaultDeviceInfoProvider>();
    cout << "[INFO] Created DefaultDeviceInfoProvider\n";

    Credentials creds(
        getenv("AWS_ACCESS_KEY_ID") ? getenv("AWS_ACCESS_KEY_ID") : "",
        getenv("AWS_SECRET_ACCESS_KEY") ? getenv("AWS_SECRET_ACCESS_KEY") : "",
        getenv("AWS_SESSION_TOKEN") ? getenv("AWS_SESSION_TOKEN") : ""
    );

    auto credentialProvider = std::make_unique<StaticCredentialProvider>(creds);
    cout << "[INFO] Created StaticCredentialProvider\n";

    auto callbackProvider = std::unique_ptr<DefaultCallbackProvider>(
        new DefaultCallbackProvider(
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
        )
    );
    cout << "[INFO] Created DefaultCallbackProvider\n";

    auto producer = KinesisVideoProducer::createSync(std::move(deviceInfoProvider), std::move(callbackProvider));
    cout << "[INFO] KinesisVideoProducer created successfully\n";

    auto stream_definition = std::make_unique<StreamDefinition>(
        stream_name,
        std::chrono::hours(2),
        nullptr,
        "",
        STREAMING_TYPE_REALTIME,
        "video/h264"
    );
    cout << "[INFO] StreamDefinition created\n";

    try {
        stream = producer->createStreamSync(std::move(stream_definition));
        cout << "[INFO] Stream created: " << stream_name << endl;
    } catch (const std::runtime_error &e) {
        cerr << "[WARN] Stream probably already exists: " << e.what() << endl;
    }
    cout << "[INFO] Stream created and active\n";

    VideoCapture cap(0);
    if (!cap.isOpened()) {
        cerr << "[ERROR] Camera open failed\n";
        return -1;
    }
    cout << "[INFO] Webcam opened successfully\n";

    int width = (int)cap.get(CAP_PROP_FRAME_WIDTH);
    int height = (int)cap.get(CAP_PROP_FRAME_HEIGHT);
    cout << "[INFO] Camera resolution: " << width << "x" << height << endl;

    const AVCodec* codec = avcodec_find_encoder(AV_CODEC_ID_H264);
    if (!codec) {
        cerr << "[ERROR] H264 codec not found!\n";
        return -1;
    }
    cout << "[INFO] H264 codec found\n";

    AVCodecContext* ctx = avcodec_alloc_context3(codec);
    ctx->width = width;
    ctx->height = height;
    ctx->time_base = {1, 30};
    ctx->framerate = {30, 1};
    ctx->pix_fmt = AV_PIX_FMT_YUV420P;

    av_opt_set(ctx->priv_data, "preset", "ultrafast", 0);
    if (avcodec_open2(ctx, codec, nullptr) < 0) {
        cerr << "[ERROR] Failed to open codec\n";
        return -1;
    }
    cout << "[INFO] Codec opened successfully\n";

    AVFrame* frame_ff = av_frame_alloc();
    frame_ff->format = ctx->pix_fmt;
    frame_ff->width = width;
    frame_ff->height = height;
    av_frame_get_buffer(frame_ff, 32);

    AVPacket* pkt = av_packet_alloc();

    Mat frame;
    uint64_t frame_index = 0;

    cout << "[INFO] Starting capture and streaming loop...\n";
    while (true) {
        cap >> frame;
        if (frame.empty()) {
            cout << "[WARN] Captured empty frame, skipping...\n";
            continue;
        }

        Mat yuv;
        cvtColor(frame, yuv, COLOR_BGR2YUV_I420);

        memcpy(frame_ff->data[0], yuv.data, width * height);
        memcpy(frame_ff->data[1], yuv.data + width * height, width * height / 4);
        memcpy(frame_ff->data[2], yuv.data + width * height * 5 / 4, width * height / 4);

        frame_ff->pts = frame_index++;

        avcodec_send_frame(ctx, frame_ff);

        while (avcodec_receive_packet(ctx, pkt) == 0) {
            Frame kvs_frame;
            kvs_frame.index = frame_index;
            kvs_frame.flags = FRAME_FLAG_KEY_FRAME;
            kvs_frame.presentationTs =
                chrono::duration_cast<chrono::nanoseconds>(
                    chrono::system_clock::now().time_since_epoch()
                ).count() / 100;
            kvs_frame.decodingTs = kvs_frame.presentationTs;
            kvs_frame.duration = 40 * 10000;
            kvs_frame.size = pkt->size;
            kvs_frame.frameData = pkt->data;

            stream->putFrame(kvs_frame);
            cout << "[INFO] Sent H264 frame #" << frame_index 
                 << " size=" << pkt->size << " bytes\n";

            av_packet_unref(pkt);
        }

        imshow("Preview", frame);
        if (waitKey(1) == 27) {
            cout << "[INFO] ESC pressed, exiting loop\n";
            break;
        }
    }

    cout << "[INFO] Releasing resources...\n";
    cap.release();
    av_frame_free(&frame_ff);
    av_packet_free(&pkt);
    avcodec_free_context(&ctx);
    cout << "[INFO] Application terminated successfully\n";

    return 0;
}