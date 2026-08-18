import 'package:pure_live/common/index.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ReleaseAssetUrls {
  const ReleaseAssetUrls({required this.projectUrl, required this.version, required this.buildNumber});

  final String projectUrl;
  final String version;
  final int buildNumber;

  String get releaseBase => '$projectUrl/releases/download/v$version';
  String get androidArm64 => '$releaseBase/PureLive-$version-$buildNumber-arm64-v8a-release.apk';
  String get androidArmeabiV7a => '$releaseBase/PureLive-$version-$buildNumber-armeabi-v7a-release.apk';
  String get androidX8664 => '$releaseBase/PureLive-$version-$buildNumber-x86_64-release.apk';
  String get windowsSetup => '$releaseBase/PureLive-$version-windows-x64-setup.exe';
  String get windowsPortable => '$releaseBase/PureLive-$version-$buildNumber-windows-x64-portable.zip';
  String get macosUniversal => '$releaseBase/PureLive-$version-$buildNumber-macos-universal.zip';
}

class VersionController extends GetxController {
  final hasNewVersion = false.obs;

  // =========================
  // Android
  // =========================

  final apkUrl = ''.obs;
  final apkUrl2 = ''.obs;
  final apkUrl3 = ''.obs;
  // =========================
  // Windows
  // =========================
  final windowsUrl = ''.obs;
  final windowsUrl2 = ''.obs;
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

    apkUrl.value = assets.androidArmeabiV7a;
    apkUrl2.value = assets.androidArm64;
    apkUrl3.value = assets.androidX8664;

    // =====================================================
    // Windows
    // =====================================================

    windowsUrl.value = assets.windowsSetup;
    windowsUrl2.value = assets.windowsPortable;
    // =====================================================
    // macOS
    // ========================= ===========================

    macosUrl.value = assets.macosUniversal;

    loading.value = false;
  }
}
