import 'package:pure_live/common/index.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pure_live/common/base/base_controller.dart';

class VersionController extends BaseController {
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
  final macosFvpUrl = ''.obs;

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

    final releaseUrl = '${VersionUtil.projectUrl}/releases/download/v$latestVersion';

    final localBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final int buildNumber;
    if (hasNewVersion.value) {
      buildNumber = VersionUtil.latestBuildNumber ?? (localBuild + 1);
    } else {
      buildNumber = VersionUtil.latestBuildNumber ?? localBuild;
    }

    // =====================================================
    // Android
    // =====================================================

    apkUrl.value = '$releaseUrl/app-armeabi-v7a-release.apk';
    apkUrl2.value = '$releaseUrl/app-arm64-v8a-release.apk';
    apkUrl3.value = '$releaseUrl/app-x86_64-release.apk';

    // =====================================================
    // Windows
    // =====================================================

    windowsUrl.value = '$releaseUrl/PureLive-$latestVersion+$buildNumber-windows-x64-setup.exe';
    windowsUrl2.value = '$releaseUrl/PureLive-$latestVersion+$buildNumber-windows-x64.msix';
    // =====================================================
    // macOS
    // ========================= ===========================

    macosUrl.value = '$releaseUrl/PureLive-$latestVersion-macOS.dmg';
    macosFvpUrl.value = '$releaseUrl/PureLive-$latestVersion-fvp-macOS.dmg';

    loading.value = false;
  }
}
