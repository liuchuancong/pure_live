import 'package:pure_live/common/index.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ReleaseAssetUrls {
  const ReleaseAssetUrls({
    required this.projectUrl,
    required this.version,
    required this.buildNumber,
  });

  final String projectUrl;
  final String version;
  final int buildNumber;

  String get releaseBase => '$projectUrl/releases/download/v$version';
  String get androidArm64 =>
      '$releaseBase/PureLive-$version-$buildNumber-android-arm64-v8a-release.apk';
  String get androidArmeabiV7a =>
      '$releaseBase/PureLive-$version-$buildNumber-android-armeabi-v7a-release.apk';
  String get androidX8664 =>
      '$releaseBase/PureLive-$version-$buildNumber-android-x86_64-release.apk';
  String get windowsSetup => '$releaseBase/PureLive-$version-$buildNumber-windows-x64-setup.exe';
  String get windowsMsix => '$releaseBase/PureLive-$version-$buildNumber-windows-x64.msix';
  String get windowsPortable =>
      '$releaseBase/PureLive-$version-$buildNumber-windows-x64-portable.zip';
  String get macosUniversal => '$releaseBase/PureLive-$version-$buildNumber-macos-universal.zip';
}

class VersionController extends GetxController {
  final hasNewVersion = false.obs;

  // =========================
  // Android
  // =========================

  final androidArmeabiV7aUrl = ''.obs;
  final androidArm64Url = ''.obs;
  final androidX8664Url = ''.obs;

  // =========================
  // Windows
  // =========================
  final windowsSetupUrl = ''.obs;
  final windowsMsixUrl = ''.obs;
  final windowsPortableUrl = ''.obs;

  // =========================
  // macOS
  // =========================
  final macosUrl = ''.obs;

  late PackageInfo packageInfo;

  final loading = true.obs;

  @override
  void onInit() {
    super.onInit();
    checkNewVersion();
  }

  Future<void> getPackageInfo() async {
    packageInfo = await PackageInfo.fromPlatform();
  }

  Future<void> checkNewVersion() async {
    await VersionUtil().checkUpdate();

    await getPackageInfo();

    hasNewVersion.value = VersionUtil.hasNewVersion();

    final latestVersion = VersionUtil.latestVersion;

    final localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final int buildNumber;
    if (hasNewVersion.value) {
      buildNumber = VersionUtil.latestBuildNumber ?? (localBuild + 1);
    } else {
      buildNumber = VersionUtil.latestBuildNumber ?? localBuild;
    }
    final assets = ReleaseAssetUrls(
      projectUrl: VersionUtil.projectUrl,
      version: latestVersion,
      buildNumber: buildNumber,
    );

    // =====================================================
    // Android
    // =====================================================

    final androidAbis = VersionUtil.latestAndroidAbis;
    androidArmeabiV7aUrl.value = androidAbis.contains('armeabi-v7a')
        ? assets.androidArmeabiV7a
        : '';
    androidArm64Url.value = androidAbis.contains('arm64-v8a') ? assets.androidArm64 : '';
    androidX8664Url.value = androidAbis.contains('x86_64') ? assets.androidX8664 : '';

    // =====================================================
    // Windows
    // =====================================================

    windowsSetupUrl.value = assets.windowsSetup;
    // MSIX requires a matching publisher certificate. Only advertise it when
    // the release feed explicitly confirms that the signed asset was uploaded.
    windowsMsixUrl.value = VersionUtil.latestWindowsMsixAvailable ? assets.windowsMsix : '';
    windowsPortableUrl.value = assets.windowsPortable;

    // =====================================================
    // macOS
    // =====================================================

    macosUrl.value = assets.macosUniversal;

    loading.value = false;
  }
}
