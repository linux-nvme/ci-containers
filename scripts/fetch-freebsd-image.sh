#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (c) 2026 Western Digital Corporation or its affiliates.
#
# Author: Dennis Maisenbacher <dennis.maisenbacher@wdc.com>
#

set -euo pipefail

variant="${1:?usage: fetch-freebsd-image.sh <variant>}"

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

version="$(./generate --distro freebsd --print-freebsd version)"
arch="$(./generate --distro freebsd --print-freebsd arch)"
vmfs="$(./generate --distro freebsd --print-freebsd vmfs)"
mirror="$(./generate --distro freebsd --print-freebsd mirror)"
sha512="$(./generate --distro freebsd --print-freebsd sha512)"

image="FreeBSD-${version}-${arch}-BASIC-CLOUDINIT-${vmfs}.qcow2"
url="${mirror}/${version}/${arch}/Latest/${image}.xz"

builddir="${variant}/build"
qcow="${builddir}/freebsd-${variant}.qcow2"
workdir="${builddir}/.fetch-freebsd"

rm -rf "$workdir"
mkdir -p "$workdir" "$builddir"
trap 'rm -rf "$workdir"' EXIT

echo "Fetching ${url} ..."
curl -fL --retry 5 --retry-delay 10 -o "${workdir}/${image}.xz" "$url"

echo "Verifying sha512 ..."
echo "${sha512}  ${workdir}/${image}.xz" | sha512sum -c -

echo "Decompressing ..."
xz -dc "${workdir}/${image}.xz" > "$qcow"

echo "Created ${qcow}"
