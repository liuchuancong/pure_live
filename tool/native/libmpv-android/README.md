# Android libmpv (mpv 0.41.0 + FFmpeg 9.0.2)

media_kit's Android `libmpv.so` came from Predidit/libmpv-android-video-build v1.2.7 (mpv 32a164cc + FFmpeg 7.1.3). FFmpeg 7.1 cannot read codec-id-12 HEVC FLV (Shopee Live, some 17LIVE rooms), so Pure Live builds its own arm64-v8a, armeabi-v7a and x86_64 bundles from the same build scripts with newer dependencies.

- Base: Predidit/libmpv-android-video-build `main` (2026-08-11), plus `predidit-buildscripts.patch`:
  - FFmpeg n9.0.2 (`946fcce0`), mpv v0.41.0 (`41f6a645`), libplacebo v7.360.1, dav1d 1.5.4, mbedtls 3.6.7 (needs its `framework` submodule), NDK 27.3.13750724.
  - Dropped the Kazumi HLS ad-filter FFmpeg patch (VOD only; its `hls_ad_filter` demuxer option is removed from the vendored media_kit). The mpv JavaVM / fence-leak patches and both libplacebo patches apply unchanged.
  - FFmpeg 8 removed libpostproc, so `--disable-postproc` (and the no-op `--enable-avutil`) are gone from `flavors/default.sh`.
- Build: `build-arm64.sh` inside `docker.io/debian:bookworm-slim` with the buildscripts at `/work` and an Android SDK (NDK 27.3) at `/work/sdk/android-sdk-linux`. It downloads and patches the dependencies; `build-abis.sh armv7l x86_64` then builds the other ABIs from the same tree (each ABI has its own `_build-<arch>` directories and `prefix/<abi>`). `build-abis.sh` uses the Tsinghua Debian mirror without the proxy (a proxied apt 502 once left nasm uninstalled, which `build.sh` does not report) and fails if an ABI produced no `libmpv.so`.
- Package: `lib/<abi>/libmpv.so` (built) + `lib/<abi>/libmediakitandroidhelper.so` (unchanged from the v1.2.7 jar of the same ABI, same helper commit), zipped with fixed timestamps (2025-01-01) as `libmpv-android-0.41.0-ffmpeg-9.0.2-<abi>.jar`.
- Checks (all three ABIs): `Lavc63.1` / `Lavf63.1`, `mpv v0.41.0`, `h264/hevc/vp9/av1_mediacodec` present, ELF LOAD alignment 16 KiB, identical `NEEDED` libraries. arm64-v8a is device-verified on REDMI K90 (Douyu H.264 with Qualcomm c2 hardware decoding).
- Published as internal dependency assets (prerelease `native-libmpv-android-0.41.0-ff9.0.2-b1`, with `SHA256SUMS.txt`) and referenced from `third_party/media_kit/hook/native_bundles.json` (`android_arm64`, `android_arm`, `android_x64`). x86 (32-bit) stays on v1.2.7; the app does not ship it.
