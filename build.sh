#!/bin/bash

SDK_PATH=~/Downloads/amazon-kinesis-video-streams-producer-sdk-cpp

export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:$PKG_CONFIG_PATH"

clang++ ../video-streaming-service/capture.cpp -std=c++17 \
  -I/usr/local/src \
  -I$SDK_PATH/open-source/local/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/src/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/client/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/common/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/utils/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/mkvgen/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/view/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/heap/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/state/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/trace/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/signaling/include \
  -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/streaming/include \
  \
  $(pkg-config --cflags libavcodec libavutil libavformat opencv4) \
  \
  -L$SDK_PATH/build/dependency/libkvscproducer/kvscproducer-src \
  -L$SDK_PATH/open-source/local/lib \
  \
  -Wl,-rpath,$SDK_PATH/build/dependency/libkvscproducer/kvscproducer-src \
  -Wl,-rpath,$SDK_PATH/open-source/local/lib \
  -Wl,-rpath,/opt/homebrew/lib \
  -Wl,-rpath,@loader_path/build \
  \
  -lKinesisVideoProducer -lcproducer -lkvsCommonCurl \
  -lcurl \
  \
  $(pkg-config --libs libavcodec libavutil libavformat opencv4) \
  \
  -o kvs_app

# clang++ ../video-streaming-service/camera_2.cpp -std=c++17 \
#   -I/usr/local/src \
#   -I$SDK_PATH/open-source/local/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/src/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/client/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/common/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/utils/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/mkvgen/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/view/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/heap/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/state/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/trace/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/signaling/include \
#   -I$SDK_PATH/dependency/libkvscproducer/kvscproducer-src/dependency/libkvspic/kvspic-src/src/streaming/include \
#   -I/opt/homebrew/opt/opencv/include/opencv4 \
#   -L/usr/local/lib \
#   -L/opt/homebrew/opt/opencv/lib \
#   -L$SDK_PATH/build/dependency/libkvscproducer/kvscproducer-src \
#   -Wl,-rpath,/usr/local/lib \
#   -Wl,-rpath,$SDK_PATH/build/dependency/libkvscproducer/kvscproducer-src \
#   -Wl,-headerpad_max_install_names \
#   -lKinesisVideoProducer -lcproducer -lkvsCommonCurl -lopencv_core -lopencv_imgcodecs -lopencv_highgui -lopencv_videoio \
#   -L$SDK_PATH/open-source/local/lib \
#   -Wl,-rpath,$SDK_PATH/open-source/local/lib \
#   -lcurl \
#   -o kvs_app