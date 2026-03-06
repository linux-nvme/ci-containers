#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

for dockerfile in main/Dockerfile.*; do
    docker buildx build --platform linux/amd64 . -f "${dockerfile}"
done
