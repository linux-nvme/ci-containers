#!/bin/bash

BUILDDIR="$(pwd)/.build"
CC=${CC:-"gcc"}

tools_build_samurai() {
    mkdir -p "${BUILDDIR}"/build-tools
    git clone --depth 1 https://github.com/michaelforney/samurai.git \
        "${BUILDDIR}/build-tools/samurai"
    pushd "${BUILDDIR}/build-tools/samurai" || exit 1

    CC="${CC}" make
    SAMU="${BUILDDIR}/build-tools/samurai/samu"

    popd || exit 1

    cp ${SAMU} .
}

tools_build_muon() {
    mkdir -p "${BUILDDIR}"/build-tools
    git clone --depth 1 https://git.sr.ht/~lattis/muon \
        "${BUILDDIR}/build-tools/muon"
    pushd "${BUILDDIR}/build-tools/muon" || exit 1

    CC="${CC}" ninja="${SAMU}" meson setup              \
        -Dprefix="${BUILDDIR}/build-tools"              \
        -Dlibcurl=enabled                               \
        -Dlibarchive=enabled                            \
        -Dlibpkgconf=enabled                            \
        -Ddocs=disabled                                 \
        -Dsamurai=disabled                              \
        "${BUILDDIR}/build-tools/.build-muon"
    meson compile -C "${BUILDDIR}/build-tools/.build-muon"
    meson test -C "${BUILDDIR}/build-tools/.build-muon"

    popd || exit 1

    cp "${BUILDDIR}/build-tools/.build-muon/muon" .
}

export PATH=$PATH:$(pwd)

tools_build_samurai
tools_build_muon

mkdir -p bin
mv samu bin
mv muon bin
