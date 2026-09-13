import 'dart:async';
import 'package:pure_live/gen/env.g.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/common/global/platform_utils.dart';


class VersionUtil {
  static PackageInfo? _packageInfo;

  /// Release/update repository for this maintained distribution.
  ///
  /// Keeping the owner configurable lets downstream builders select their own
  /// release feed without editing runtime code. This repository defaults to
  /// the liuchuancong maintenance release channel so its bundled version.json and generated asset
  /// URLs always describe the same published artifacts.
  static final String updateOwner = AppConfig.pureliveUpdateOwner;
  static final String updateRepository = AppConfig.pureliveUpdateRepository;
  static final String projectUrl = 'https://github.com/$updateOwner/$updateRepository';
  static final String issuesUrl = '$projectUrl/issues';
  static const String githubUrl = 'https://github.com/liuchuancong';

  static const String email = '17792321552@163.com';
  static const String emailUrl = 'mailto:17792321552@163.com?subject=PureLive Feedback';

  static const String telegramGroup = 't.me/pure_live_channel';
  static const String telegramGroupUrl = 'https://t.me/pure_live_channel';

  static final String releaseUrl = 'https://api.github.com/repos/$updateOwner/$updateRepository/releases?per_page=30';

  static final GitHubMirror mirror = GitHubMirror(owner: updateOwner, repo: updateRepository, branch: 'master');

  static List<String> get _versionUrls => SettingsService.to.app.useGitHubOriginForUpdates.v
      ? [mirror.rawUrl('assets/version.json')]
      : mirror.mirrors('assets/version.json');

  final isHasNewVersion = false.obs;

  static String latestVersion = '';
  static int? latestBuildNumber;
  static int latestVersionNum = 0;
  static String latestUpdateLog = '';
  static bool prerelease = false;
  static String downloadUrl = '';
  static Set<String> latestAndroidAbis = AppConsts.supportAndroidAbis;
  static bool latestWindowsMsixAvailable = false;
  var allReleased = [].obs;

  static Map<String, dynamic>? _cachedVersionJson;

  static final RxBool historyLoading = false.obs;
  static final RxBool historyError = false.obs;

  static Future<void> initPackageInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  static String get version {
    if (_packageInfo == null) return '0.0.0';
    return _packageInfo!.version;
  }

  static int get buildNumber {
    if (_packageInfo == null) return 0;
    return int.tryParse(_packageInfo!.buildNumber) ?? 0;
  }

  Future<bool> checkUpdate() async {
    if (_cachedVersionJson != null) {
      try {
        _applyVersionData(_cachedVersionJson!);
        isHasNewVersion.value = hasNewVersion();
        return true;
      } catch (_) {
        _cachedVersionJson = null;
        _resetAfterFailedCheck();
        return false;
      }
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urls = _versionUrls.map((e) => '$e?ts=$timestamp').toList();

      final data = await RaceHttp.fetchJson(
        urls,
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (data == null) {
        _resetAfterFailedCheck();
        return false;
      }

      _applyVersionData(data);
      _cachedVersionJson = data;
      isHasNewVersion.value = hasNewVersion();
      debugPrint("🏁 更新线路成功");
      return true;
    } catch (e) {
      debugPrint("⚠️ 更新检查失败: $e");
      _resetAfterFailedCheck();
      return false;
    }
  }

  static void _applyVersionData(Map<String, dynamic> data) {
    final selected = selectPlatformVersionData(data, platform: _currentPlatformKey);
    final parsedVersion = selected['version']?.toString().trim() ?? '';
    final parsedBuildNumber = _versionInt(selected['build_number']);
    if (parsedVersion.isEmpty || parsedBuildNumber == null || parsedBuildNumber <= 0) {
      throw const FormatException('Incomplete release identity');
    }
    latestVersion = parsedVersion;
    latestVersionNum = _versionInt(selected['version_num']) ?? 0;
    latestBuildNumber = parsedBuildNumber;
    latestUpdateLog = selected['version_desc']?.toString() ?? '';
    prerelease = selected['prerelease'] == true;
    downloadUrl = selected['download_url']?.toString() ?? '';
    latestAndroidAbis = selectAndroidAbis(selected);
    latestWindowsMsixAvailable = selected['windows_msix_available'] == true;
  }

  /// Only advertises APK variants that the release feed says were published.
  /// Older feeds default to arm64, matching this maintenance branch's local
  /// release target, rather than generating links to missing assets.
  static Set<String> selectAndroidAbis(Map<String, dynamic> data) {
    final raw = data['android_abis'];
    if (raw is! List) return const {'arm64-v8a'};
    return raw.map((item) => item.toString()).where(AppConsts.supportAndroidAbis.contains).toSet();
  }

  /// Keeps update announcements aligned with the artifacts that were really
  /// published for each platform. The top-level object remains the fallback
  /// for older feeds and older clients.
  static Map<String, dynamic> selectPlatformVersionData(Map<String, dynamic> data, {required String platform}) {
    final platforms = data['platforms'];
    final platformData = platforms is Map ? platforms[platform] : null;
    if (platformData is! Map) return data;
    return {...data, ...Map<String, dynamic>.from(platformData)};
  }

  static String get _currentPlatformKey {
    if (PlatformUtils.isWindows) return 'windows';
    if (PlatformUtils.isAndroid) return 'android';
    if (PlatformUtils.isMacOS) return 'macos';
    if (PlatformUtils.isIOS) return 'ios';
    if (PlatformUtils.isLinux) return 'linux';
    return 'default';
  }

  static bool hasNewVersion() {
    return isNewerVersion(latestVersion, version);
  }

  static bool isNewerVersion(String latest, String current) {
    try {
      final latestClean = latest.split(RegExp(r'[-+]'))[0].replaceFirst(RegExp('^[vV]'), '').trim();
      final currentClean = current.split(RegExp(r'[-+]'))[0].replaceFirst(RegExp('^[vV]'), '').trim();

      final latestParts = latestClean.split('.').map(int.parse).toList();
      final currentParts = currentClean.split('.').map(int.parse).toList();

      final maxLength = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;

      while (latestParts.length < maxLength) {
        latestParts.add(0);
      }
      while (currentParts.length < maxLength) {
        currentParts.add(0);
      }

      for (int i = 0; i < maxLength; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  static int? _versionInt(Object? value) {
    return switch (value) {
      int number => number,
      num number => number.toInt(),
      String text => int.tryParse(text.trim()),
      _ => null,
    };
  }

  void _resetAfterFailedCheck() {
    latestVersion = version;
    latestBuildNumber = buildNumber > 0 ? buildNumber : null;
    latestVersionNum = 0;
    latestUpdateLog = '';
    prerelease = false;
    downloadUrl = '';
    latestAndroidAbis = const {};
    latestWindowsMsixAvailable = false;
    isHasNewVersion.value = false;
  }
}
