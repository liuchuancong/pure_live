import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/common/utils/githup_mirror.dart';

class VersionUtil {
  // =========================================================
  // 当前版本
  // =========================================================
  static const String version = '2.0.18';

  // =========================================================
  // 项目地址
  // =========================================================
  static const String projectUrl = 'https://github.com/liuchuancong/pure_live';
  static const String issuesUrl = 'https://github.com/liuchuancong/pure_live/issues';
  static const String githubUrl = 'https://github.com/liuchuancong';

  static const String email = '17792321552@163.com';
  static const String emailUrl = 'mailto:17792321552@163.com?subject=PureLive Feedback';

  static const String telegramGroup = 't.me/pure_live_channel';
  static const String telegramGroupUrl = 'https://t.me/pure_live_channel';

  static const String kanbanUrl =
      'https://jackiu-notes.notion.site/50bc0d3d377445eea029c6e3d4195671?v=663125e639b047cea5e69d8264926b8b';

  // =========================================================
  // Release API
  // =========================================================
  static const String releaseUrl = 'https://api.github.com/repos/liuchuancong/pure_live/releases?per_page=30';

  // =========================================================
  // GitHub 镜像源（核心优化点）
  // =========================================================
  static final GitHubMirror mirror = GitHubMirror(owner: 'liuchuancong', repo: 'pure_live', branch: 'master');

  static List<String> get _versionUrls => mirror.mirrors('assets/version.json');

  // =========================================================
  // 状态
  // =========================================================
  final isHasNewVersion = false.obs;

  static String latestVersion = version;
  static int latestVersionNum = 0;
  static String latestUpdateLog = '';
  static bool prerelease = false;
  static String downloadUrl = '';
  static List allReleased = [];

  // =========================================================
  // 缓存
  // =========================================================
  static Map<String, dynamic>? _cachedVersionJson;

  // =========================================================
  // 检查更新（竞速版）
  // =========================================================
  Future<void> checkUpdate() async {
    if (_cachedVersionJson != null) {
      debugPrint("✅ 使用缓存版本信息");
      _applyVersionData(_cachedVersionJson!);
      return;
    }

    try {
      final data = await RaceHttp.fetchJson(
        _versionUrls.map((e) => '$e?ts=${DateTime.now().millisecondsSinceEpoch}').toList(),
        headers: {'User-Agent': 'PureLive', 'Accept': 'application/json'},
      );
      if (data == null) {
        latestUpdateLog = '更新检查失败';
        return;
      }
      _cachedVersionJson = data;
      _applyVersionData(data);
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
    latestUpdateLog = data['version_desc']?.toString() ?? '';
    prerelease = data['prerelease'] == true;
    downloadUrl = data['download_url']?.toString() ?? '';
  }

  Future<void> loadReleaseHistory() async {
    try {
      final response = await http.get(
        Uri.parse(releaseUrl),
        headers: {'User-Agent': 'PureLive', 'Accept': 'application/vnd.github+json'},
      );
      if (response.statusCode != 200) {
        debugPrint('⚠️ 获取历史版本失败: ${response.statusCode}');
        return;
      }
      final data = jsonDecode(response.body);

      if (data is List) {
        allReleased = data;
        debugPrint('✅ 历史版本加载成功: ${allReleased.length}');
      }
    } catch (e) {
      debugPrint("⚠️ 获取历史版本失败: $e");
    }
  }

  // =========================================================
  // 是否有新版本
  // =========================================================
  static bool hasNewVersion() {
    try {
      final latestVersions = latestVersion.split('-')[0].split('.');
      final versions = version.split('-')[0].split('.');

      for (int i = 0; i < latestVersions.length; i++) {
        final latest = int.parse(latestVersions[i]);
        final current = int.parse(versions[i]);

        if (latest > current) return true;
        if (latest < current) return false;
      }
    } catch (_) {}

    return false;
  }
}
