#!/bin/bash -e
# Runs inside debian:bookworm-slim. /work = buildscripts, SDK mounted read-only.
echo "deb http://deb.debian.org/debian bookworm-backports main" > /etc/apt/sources.list.d/bp.list
apt-get update -qq
apt-get install -y -qq git gcc-multilib libc-dev make automake autoconf pkg-config libtool nasm python3 python3-jsonschema python3-jinja2 wget zip unzip cmake >/dev/null
apt-get install -y -qq -t bookworm-backports meson ninja-build >/dev/null
git config --global --add safe.directory '*'
cd /work
sed -i -e 's/sudo //g' *.sh
./include/download-deps.sh
git -C deps/libplacebo submodule update --init --recursive
git -C deps/mbedtls submodule update --init --recursive
./patch.sh
cp flavors/default.sh scripts/ffmpeg.sh
./build.sh --arch arm64
ls -la prefix/arm64-v8a/usr/local/lib/*.so
