# Pure Live Android build patch

- Upstream: `guide-inc-org/guide-flutter_inappwebview`
- Ref: `sbi_fx_pc/v6.2.0-beta.3`
- Resolved commit: `3e6c4c4a25340cd363af9d38891d88498b90be26`
- Package: `flutter_inappwebview_android 1.2.0-beta.3`

The Dart and Java implementation is copied unchanged from the resolved package.
The Android Gradle file removes its module-private AGP 8 classpath, targets Java
17 / compileSdk 37, and uses `proguard-android-optimize.txt`, which is required by
AGP 9.3.1. The original license is retained in `LICENSE`.
