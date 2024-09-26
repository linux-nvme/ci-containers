#!/bin/bash

for dockerfile in Dockerfile.*; do
    docker buildx build --platform linux/amd64 . -f "${dockerfile}"
done
