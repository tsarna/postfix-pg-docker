#!/bin/bash

image_name=ghcr.io/tsarna/postfix-pg
time_tag=$(date -u -I)

docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --push \
    -t "$image_name:latest" \
    -t "$image_name:$time_tag" \
    .
