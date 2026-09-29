#!/bin/bash -e
# Runs inside debian:bookworm-slim after build-arm64.sh has downloaded and patched
# the dependencies in /work. Usage: build-abis.sh armv7l x86_64
sed -i "s|http://deb.debian.org|http://mirrors.tuna.tsinghua.edu.cn|g" /etc/apt/sources.list.d/debian.sources
echo "deb http://mirrors.tuna.tsinghua.edu.cn/debian bookworm-backports main" > /etc/apt/sources.list.d/bp.list
echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80retries
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY apt-get update -qq
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY apt-get install -y -qq git gcc-multilib libc-dev make automake autoconf pkg-config libtool nasm python3 python3-jsonschema python3-jinja2 wget zip unzip cmake >/dev/null
env -u http_proxy -u https_proxy -u HTTP_PROXY -u HTTPS_PROXY apt-get install -y -qq -t bookworm-backports meson ninja-build >/dev/null
git config --global --add safe.directory '*'
command -v nasm meson ninja >/dev/null || { echo 'missing build tools'; exit 1; }
cd /work
for arch in "$@"; do
  echo "=== build $arch $(date +%T)"
  ./build.sh --arch $arch
  [ -f prefix/$( [ $arch = armv7l ] && echo armeabi-v7a || echo $arch )/usr/local/lib/libmpv.so ] || { echo "no libmpv for $arch"; exit 1; }
done
ls -la prefix/*/usr/local/lib/libmpv.so
