#!/bin/bash -e
# Runs inside ubuntu:24.04 (glibc 2.39 ceiling for the app bundle). /src = Predidit/libmpv-linux-build.
set -e
export DEBIAN_FRONTEND=noninteractive
sed -i -E "s#http://(archive|security).ubuntu.com#http://mirrors.tuna.tsinghua.edu.cn#g" /etc/apt/sources.list.d/ubuntu.sources
echo 'Acquire::http::Proxy "false";' > /etc/apt/apt.conf.d/99noproxy
apt-get update -qq
apt-get install -y -qq git sudo zip hwdata wget gcc g++ autoconf automake debhelper glslang-dev ladspa-sdk xutils-dev libasound2-dev \
  libarchive-dev libbluray-dev libbs2b-dev libcaca-dev libcdio-paranoia-dev libdrm-dev libdvdnav-dev libegl1-mesa-dev \
  libepoxy-dev libfontconfig-dev libfreetype6-dev libfribidi-dev libgl1-mesa-dev libgbm-dev libgme-dev libgsm1-dev \
  libharfbuzz-dev libjpeg-dev libbrotli-dev liblcms2-dev libmodplug-dev libmp3lame-dev libopenal-dev libopus-dev \
  libopencore-amrnb-dev libopencore-amrwb-dev libpulse-dev librtmp-dev libsdl2-dev libsixel-dev libssh-dev libsoxr-dev \
  libspeex-dev libtool libv4l-dev libva-dev libvdpau-dev libvorbis-dev libvo-amrwbenc-dev libunwind-dev libvpx-dev \
  libwayland-dev libx11-dev libxext-dev libxkbcommon-dev libxrandr-dev libxss-dev libxv-dev libxvidcore-dev \
  linux-libc-dev nasm ninja-build pkg-config python3 python3-docutils python3-pip meson wayland-protocols \
  x11proto-core-dev zlib1g-dev libfdk-aac-dev libtheora-dev libwebp-dev unixodbc-dev libpq-dev libxxhash-dev libaom-dev \
  cmake python3-jinja2 >/dev/null
git config --global --add safe.directory '*'
git config --global http.version HTTP/1.1
# /tmp/mpv_build is a host volume so finished clones survive a retry.
B=/tmp/mpv_build; mkdir -p $B; cp -r /src/external/* $B; chmod -R 777 $B; cd $B
> ffmpeg_options
for o in --enable-small --enable-libass --enable-libdav1d --disable-bzlib --disable-sndio --disable-outdevs --disable-filters \
  --disable-muxers --disable-encoders --disable-decoders --disable-demuxers --disable-protocols; do echo $o >> ffmpeg_options; done
cat >> ffmpeg_options <<'OPTS'
--enable-decoder=*sub*,movtext,*web*,aac*,ac3*,eac3*,alac*,ape,ass,av1*,ccaption,cfhd,cook,dca,dnxhd,exr,truehd,*yuv*,flv,flac,gif,h26[3-4]*,hevc*,hap,libdav1d,mp[1-3]*,prores,*[mj]peg*,mlp,mpl2,nellymoser,opus,pcm*,qtrle,*png*,tiff,rawvideo,rv*,sami,srt,ssa,v210*,vc1*,vorbis,vp[6-9]*,wm*,wrapped_avframe
--enable-demuxer=*sub*,*ac3,*ac,*avs*,*[mj]peg*,*vc*,*web*,au,ape,ass,av[1i],concat,dnxhd,dts*,*dash*,*flv,gif,hls,h264,kux,matroska,mov,mp3,mxf,obu,ogg,pcm*,rawvideo,rt*p,spdif,srt,v210*,wav,*pipe,image2
--enable-encoder=*_at,aac,gif,h26[3-4]*,av1*,hevc*,mjpeg*,*png,opus,pcm*,prores*,rawvideo,spdif,speedhq,*jpeg,*png,vp[8-9]*,wrapped_avframe
--enable-muxer=*jpeg,fifo,flv,gif,hls,h264,hevc,image2,mov,mp4,mpegts,matroska,null,pcm*,rawvideo,rt*,spdif,*pipe,*segment,webm,wav
--enable-protocol=cache,concat*,crypto*,data,fd,*file,ftp,h*,i*,pipe,rt*,s*,t*,u*
--enable-filter=*null*,afade,*fifo,*format,*resample,aeval,atempo,pan,crop,eq*,framerate,hw*,loudnorm,scale,volume,yadif*
OPTS
> mpv_options
for o in -Dlibmpv=true -Duchardet=enabled -Dsndio=disabled -Dcaca=disabled -Djpeg=disabled -Dlibbluray=disabled \
  -Ddvdnav=disabled -Dsixel=disabled -Dcdda=disabled -Dvulkan=disabled -Dvaapi=enabled -Dvaapi-wayland=enabled \
  -Degl-wayland=enabled -Ddmabuf-wayland=enabled; do echo $o >> mpv_options; done
./use-bzip2-master
./use-libxpresent-master
./use-uchardet-master
./use-rubberband-master
./use-libdisplay-info-master
./use-dav1d-custom 1.5.4
./use-ffmpeg-custom n9.0.2
./use-libass-master
./use-libplacebo-custom 4c426e466814536def653cb23f1d1c287ea7a7f5
./use-mpv-custom f011d73d5fcf3f1907bbd6ddde3e860e3d611cf9
for i in 1 2 3; do ./update && break; [ $i = 3 ] && exit 1; sleep 10; done
# The Kazumi HLS ad-filter FFmpeg patch is VOD-only and not carried (see tool/native/libmpv-android).
cd mpv; for p in /src/patch/mpv/*.patch; do echo "Applying $p"; git apply "$p"; done; cd ..
./clean
./build -j$(nproc)
ls -la mpv/build/libmpv.so*
mkdir -p /out && cp -L mpv/build/libmpv.so.2 /out/
