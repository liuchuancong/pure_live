# Android libmpv (mpv 0.41.0 + FFmpeg 9.0.2)

media_kit's Android `libmpv.so` came from Predidit/libmpv-android-video-build v1.2.7 (mpv 32a164cc + FFmpeg 7.1.3). FFmpeg 7.1 cannot read codec-id-12 HEVC FLV (Shopee Live, some 17LIVE rooms), so Pure Live builds its own arm64-v8a bundle from the same build scripts with newer dependencies.

- Base: Predidit/libmpv-android-video-build `main` (2026-08-11), plus `predidit-buildscripts.patch`:
  - FFmpeg n9.0.2 (`946fcce0`), mpv v0.41.0 (`41f6a645`), libplacebo v7.360.1, dav1d 1.5.4, mbedtls 3.6.7 (needs its `framework` submodule), NDK 27.3.13750724.
  - Dropped the Kazumi HLS ad-filter FFmpeg patch (VOD only; its `hls_ad_filter` demuxer option is removed from the vendored media_kit). The mpv JavaVM / fence-leak patches and both libplacebo patches apply unchanged.
  - FFmpeg 8 removed libpostproc, so `--disable-postproc` (and the no-op `--enable-avutil`) are gone from `flavors/default.sh`.
- Build: `build-arm64.sh` inside `docker.io/debian:bookworm-slim` with the buildscripts at `/work` and an Android SDK (NDK 27.3) at `/work/sdk/android-sdk-linux`.
- Package: `lib/arm64-v8a/libmpv.so` (built) + `lib/arm64-v8a/libmediakitandroidhelper.so` (unchanged from v1.2.7, same helper commit), zipped with fixed timestamps as `default-arm64-v8a.jar`.
- Checks: `Lavc63.1` / `Lavf63.1`, `mpv v0.41.0`, `h264/hevc/vp9/av1_mediacodec` present, ELF LOAD alignment 16 KiB. Device-verified on REDMI K90 (Douyu H.264 with Qualcomm c2 hardware decoding).
- Published as an internal dependency asset (prerelease `native-libmpv-android-0.41.0-ff9.0.2-b1`) and referenced from `third_party/media_kit/hook/native_bundles.json` (`android_arm64`). Other ABIs stay on v1.2.7; the app ships arm64-v8a only.
