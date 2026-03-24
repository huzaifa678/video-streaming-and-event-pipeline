# Video Streaming & Analytics Service 🎥

[![Status](https://img.shields.io/badge/status-in%20development-yellow)](https://github.com/yourusername/video-streaming-service)

## Overview
This project implements a **real-time video streaming and analytics pipeline** using AWS services, C++, and Terraform.  

It captures live video, streams it to AWS Kinesis Video Streams, performs analytics via Rekognition, stores data in S3/Redshift, and supports real-time processing for enriched insights.  

---

## Architecture



---

## Getting Started

### Prerequisites

- C++17 compiler (`clang++`)
- OpenCV & FFmpeg installed
- AWS account with KVS, Rekognition, S3, Redshift, Lambda permissions
- Terraform installed
- AWS CLI configured with your credentials

### AWS Credentials

Set up your credentials via environment variables or `~/.zshrc`:

```bash
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
export AWS_SESSION_TOKEN=YOUR_SESSION_TOKEN
export AWS_DEFAULT_REGION=us-east-1
```

### Build & Run C++ Producer

```bash
./build.sh
./kvs_app
```

### Deploy Terraform Infrastructure 

```bash
terraform init
terraform plan
terraform apply
```