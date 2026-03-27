#include <iostream>
#include <string>
#include <memory>
#include <KinesisVideoProducer.h>
#include <DefaultCallbackProvider.h>

using namespace std;
using namespace com::amazonaws::kinesis::video;

// Minimal callbacks
class MyClientCallbacks : public ClientCallbackProvider {
public:
    UINT64 getCallbackCustomData() override { return 0; }
};
class MyStreamCallbacks : public StreamCallbackProvider {
public:
    UINT64 getCallbackCustomData() override { return 0; }
};

int main() {
    log4cplus::PropertyConfigurator::doConfigure("log4cplus.properties");

    const char* access_key = getenv("AWS_ACCESS_KEY_ID");
    const char* secret_key = getenv("AWS_SECRET_ACCESS_KEY");
    string region = "us-east-1";
    string stream_name = "video-analytics-video-stream";

    cout << "--- KVS macOS Stream Creation Test ---" << endl;

    // CA bundle check
    string ca_path = "/etc/ssl/cert.pem";
    if (FILE* f = fopen(ca_path.c_str(), "r")) fclose(f);
    else ca_path = "/opt/homebrew/etc/openssl@3/cert.pem";

    auto deviceInfoProvider = make_unique<DefaultDeviceInfoProvider>();
    Credentials creds(access_key ? access_key : "", secret_key ? secret_key : "");
    auto credentialProvider = make_unique<StaticCredentialProvider>(creds);

    auto clientCb = unique_ptr<ClientCallbackProvider>(new MyClientCallbacks());
    auto streamCb = unique_ptr<StreamCallbackProvider>(new MyStreamCallbacks());

    auto callbackProvider = make_unique<DefaultCallbackProvider>(
        std::move(clientCb), std::move(streamCb), std::move(credentialProvider),
        region, "TRACE", "", ca_path, "", true, (uint64_t)0
    );

    auto producer = KinesisVideoProducer::createSync(std::move(deviceInfoProvider), std::move(callbackProvider));
    cout << "[STEP 1] Producer ready." << endl;

    // Dummy codec private data (H264 SPS)
    BYTE dummy_cpd[] = {0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0x00, 0x0a};

    auto stream_def = make_unique<StreamDefinition>(
        stream_name, chrono::hours(24), nullptr, "", 
        STREAMING_TYPE_REALTIME, "video/h264",
        chrono::milliseconds::zero(), chrono::seconds(2),
        chrono::milliseconds(1), true, true, true,
        "V_MPEG4/ISO/AVC", "Video Track",
        dummy_cpd, sizeof(dummy_cpd),
        NAL_ADAPTATION_ANNEXB_NALS | NAL_ADAPTATION_ANNEXB_CPD_NALS
    );

    cout << "[STEP 2] Creating stream..." << endl;
    try {
        auto stream = producer->createStreamSync(std::move(stream_def));
        cout << "[SUCCESS] Stream handle ready. You can now push frames." << endl;
    } catch (const runtime_error& e) {
        cerr << "[FATAL] Failed to create stream: " << e.what() << endl;
    }

    return 0;
}