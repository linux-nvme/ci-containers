#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2026 Daniel Wagner, SUSE LLC
#
# Author: Daniel Wagner <dwagner@suse.de>

for dockerfile in main/Dockerfile.*; do
    docker buildx build --platform linux/amd64 . -f "${dockerfile}"
done
