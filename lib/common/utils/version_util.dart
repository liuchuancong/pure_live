import 'dart:io';
import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';
import 'package:pure_live/common/models/release_model.dart';

class VersionUtil {
  static const String version = '2.0.19';

  static const String projectUrl = 'https://github.com/liuchuancong/pure_live';
  static const String issuesUrl = 'https://github.com/liuchuancong/pure_live/issues';
  static const String githubUrl = 'https://github.com/liuchuancong';

  static const String email = '17792321552@163.com';
  static const String emailUrl = 'mailto:17792321552@163.com?subject=PureLive Feedback';

  static const String telegramGroup = 't.me/pure_live_channel';
  static const String telegramGroupUrl = 'https://t.me/pure_live_channel';

  static const String kanbanUrl =
      'https://jackiu-notes.notion.site/50bc0d3d377445eea029c6e3d4195671?v=663125e639b047cea5e69d8264926b8b';

  static const String releaseUrl = 'https://api.github.com/repos/liuchuancong/pure_live/releases?per_page=30';

  static final GitHubMirror mirror = GitHubMirror(owner: 'liuchuancong', repo: 'pure_live', branch: 'master');

  static List<String> get _versionUrls => mirror.mirrors('assets/version.json');

  final isHasNewVersion = false.obs;

  static String latestVersion = version;
  static int? latestBuildNumber;
  static int latestVersionNum = 0;
  static String latestUpdateLog = '';
  static bool prerelease = false;
  static String downloadUrl = '';
  static List<ReleaseModel> allReleased = [];

  static Map<String, dynamic>? _cachedVersionJson;

  static final RxBool historyLoading = false.obs;
  static final RxBool historyError = false.obs;

  Future<void> checkUpdate() async {
    if (_cachedVersionJson != null) {
      _applyVersionData(_cachedVersionJson!);
      isHasNewVersion.value = hasNewVersion();
      return;
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urls = _versionUrls.map((e) => '$e?ts=$timestamp').toList();

      final data = await RaceHttp.fetchJson(
        urls,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (data == null) {
        latestUpdateLog = '更新检查失败';
        return;
      }

      _cachedVersionJson = data;
      _applyVersionData(data);
      isHasNewVersion.value = hasNewVersion();
      debugPrint("🏁 更新线路成功");
    } catch (e) {
      debugPrint("⚠️ 更新检查失败: $e");
      latestVersion = version;
      latestUpdateLog = '更新检查失败';
    }
  }

  static void _applyVersionData(Map<String, dynamic> data) {
    latestVersion = data['version']?.toString() ?? version;
    latestVersionNum = data['version_num'] ?? 0;
    latestBuildNumber = data['build_number'];
    latestUpdateLog = data['version_desc']?.toString() ?? '';
    prerelease = data['prerelease'] == true;
    downloadUrl = data['download_url']?.toString() ?? '';
  }

  Future<void> loadReleaseHistory({bool forceRefresh = false}) async {
    if (allReleased.isNotEmpty && !forceRefresh) return;
    if (historyLoading.value) return;

    try {
      historyLoading.value = true;
      historyError.value = false;

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final urls = mirror.mirrors('assets/releases.json').map((e) => '$e?ts=$timestamp').toList();

      final dynamic rawData = await RaceHttp.fetchJson(
        urls,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (rawData == null) {
        throw const HttpException('Release payload empty');
      }

      List<dynamic> listData = [];

      if (rawData is List) {
        listData = rawData;
      } else if (rawData is Map && rawData['releases'] is List) {
        listData = rawData['releases'];
      } else {
        throw const FormatException('Invalid releases format');
      }

      allReleased = listData.map((e) => ReleaseModel.fromJson(e)).toList();

      // 按版本倒序
      allReleased.sort((a, b) => b.date.compareTo(a.date));

      debugPrint("🏁 历史版本同步成功: ${allReleased.length}");
    } catch (e, s) {
      debugPrint("⚠️ 获取历史版本失败: $e");
      debugPrintStack(stackTrace: s);

      historyError.value = true;
    } finally {
      historyLoading.value = false;
    }
  }

  static bool hasNewVersion() {
    try {
      final latestClean = latestVersion.split('-')[0].replaceAll('v', '').trim();
      final currentClean = version.split('-')[0].replaceAll('v', '').trim();

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
}
