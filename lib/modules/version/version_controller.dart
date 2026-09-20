import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:package_info_plus/package_info_plus.dart';

typedef VersionUpdateChecker = Future<bool> Function();
typedef VersionPackageInfoLoader = Future<PackageInfo> Function();

class ReleaseAssetUrls {
  const ReleaseAssetUrls({required this.projectUrl, required this.version, required this.buildNumber});

  final String projectUrl;
  final String version;
  final int buildNumber;

  String get normalizedVersion {
    final value = version.trim();
    return value.startsWith('v') || value.startsWith('V') ? value.substring(1) : value;
  }

  bool get isValid {
    final uri = Uri.tryParse(projectUrl.trim());
    final safeVersion =
        RegExp(r'^[0-9A-Za-z][0-9A-Za-z._-]*$').hasMatch(normalizedVersion) && !normalizedVersion.contains('..');
    return uri != null &&
        uri.scheme == 'https' &&
        uri.hasAuthority &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.userInfo.isEmpty &&
        safeVersion &&
        buildNumber > 0;
  }

  String get releaseBase {
    if (!isValid) return '';
    final normalizedProject = projectUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return '$normalizedProject/releases/download/v$normalizedVersion';
  }

  String _asset(String suffix) {
    if (!isValid) return '';
    return '$releaseBase/PureLive-$normalizedVersion-$buildNumber-$suffix';
  }

  String get androidArm64 => _asset('android-arm64-v8a-release.apk');
  String get androidArmeabiV7a => _asset('android-armeabi-v7a-release.apk');
  String get androidX8664 => _asset('android-x86_64-release.apk');
  String get windowsSetup => _asset('windows-x64-setup.exe');
  String get windowsMsix => _asset('windows-x64.msix');
  String get windowsPortable => _asset('windows-x64-portable.zip');
  String get macosUniversal => _asset('macos-universal.zip');
}

class VersionController extends GetxController {
  VersionController({this.updateChecker, this.packageInfoLoader});

  final VersionUpdateChecker? updateChecker;
  final VersionPackageInfoLoader? packageInfoLoader;
  bool _checking = false;

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
  final error = false.obs;
  final updateLog = ''.obs;
  final downloadPending = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(checkNewVersion());
  }

  Future<void> getPackageInfo() async {
    packageInfo = await (packageInfoLoader?.call() ?? PackageInfo.fromPlatform());
  }

  Future<void> checkNewVersion() async {
    if (_checking) return;
    _checking = true;
    loading.value = true;
    error.value = false;
    _clearReleaseState();
    try {
      final updateSucceeded = await (updateChecker?.call() ?? VersionUtil().checkUpdate());
      if (!updateSucceeded) throw StateError('Update feed request failed');
      await getPackageInfo();

      final latestVersion = VersionUtil.latestVersion.trim();
      final newVersion = VersionUtil.isNewerVersion(latestVersion, packageInfo.version);
      final assets = ReleaseAssetUrls(
        projectUrl: VersionUtil.projectUrl,
        version: latestVersion,
        buildNumber: VersionUtil.latestBuildNumber ?? 0,
      );
      if (!assets.isValid) throw const FormatException('Incomplete release identity');

      hasNewVersion.value = newVersion;
      updateLog.value = VersionUtil.latestUpdateLog;
      final androidAbis = VersionUtil.latestAndroidAbis;
      androidArmeabiV7aUrl.value = androidAbis.contains('armeabi-v7a') ? assets.androidArmeabiV7a : '';
      androidArm64Url.value = androidAbis.contains('arm64-v8a') ? assets.androidArm64 : '';
      androidX8664Url.value = androidAbis.contains('x86_64') ? assets.androidX8664 : '';
      windowsSetupUrl.value = assets.windowsSetup;
      windowsMsixUrl.value = VersionUtil.latestWindowsMsixAvailable ? assets.windowsMsix : '';
      windowsPortableUrl.value = assets.windowsPortable;
      macosUrl.value = assets.macosUniversal;
    } catch (_) {
      error.value = true;
      _clearReleaseState();
    } finally {
      loading.value = false;
      _checking = false;
    }
  }

  void _clearReleaseState() {
    hasNewVersion.value = false;
    updateLog.value = '';
    androidArmeabiV7aUrl.value = '';
    androidArm64Url.value = '';
    androidX8664Url.value = '';
    windowsSetupUrl.value = '';
    windowsMsixUrl.value = '';
    windowsPortableUrl.value = '';
    macosUrl.value = '';
  }
}
