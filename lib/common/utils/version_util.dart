import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class VersionUtil {
  // =========================================================
  // 当前版本
  // =========================================================

  static const String version = '2.0.16';

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
  // Release API（历史版本）
  // =========================================================

  static const String releaseUrl = 'https://api.github.com/repos/liuchuancong/pure_live/releases?per_page=30';

  // =========================================================
  // version.json 多线路
  // =========================================================

  static const List<String> versionUrls = [
    // github raw
    'https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/version.json',

    // kkgithub
    'https://raw.kkgithub.com/liuchuancong/pure_live/master/assets/version.json',

    // wget.la
    'https://wget.la/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/version.json',

    // ghproxy
    'https://ghproxy.net/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/version.json',

    // ghfast
    'https://ghfast.top/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/version.json',

    // jsdelivr
    'https://cdn.jsdelivr.net/gh/liuchuancong/pure_live@master/assets/version.json',

    // fastly
    'https://fastly.jsdelivr.net/gh/liuchuancong/pure_live@master/assets/version.json',

    // catmak
    'https://gh.catmak.name/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/version.json',

    // blfrp
    'https://g.blfrp.cn/https://raw.githubusercontent.com/liuchuancong/pure_live/master/assets/version.json',
  ];

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
  // 检查更新（最快线路）
  // =========================================================

  Future<void> checkUpdate() async {
    // 缓存命中
    if (_cachedVersionJson != null) {
      debugPrint("✅ 使用缓存版本信息");

      _applyVersionData(_cachedVersionJson!);

      return;
    }

    final completer = Completer<void>();

    bool isCompleted = false;

    final client = http.Client();

    try {
      for (final url in versionUrls) {
        Future(() async {
          try {
            final response = await client
                .get(
                  Uri.parse('$url?ts=${DateTime.now().millisecondsSinceEpoch}'),
                  headers: {'User-Agent': 'PureLive', 'Accept': 'application/json'},
                )
                .timeout(const Duration(seconds: 5));

            if (response.statusCode != 200) {
              return;
            }

            final data = jsonDecode(response.body);

            if (data == null || data is! Map<String, dynamic>) {
              return;
            }

            final String? ver = data['version']?.toString();

            if (ver == null || ver.isEmpty) {
              return;
            }

            if (isCompleted) return;

            isCompleted = true;

            _cachedVersionJson = data;

            _applyVersionData(data);

            debugPrint("✅ 更新线路获胜: $url");

            if (!completer.isCompleted) {
              completer.complete();
            }

            client.close();
          } catch (_) {}
        });
      }

      await completer.future.timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint("⚠️ 更新检查失败: $e");

      latestVersion = version;

      latestUpdateLog = '更新检查失败';
    } finally {
      client.close();
    }
  }

  // =========================================================
  // 解析 version.json
  // =========================================================

  static void _applyVersionData(Map<String, dynamic> data) {
    latestVersion = data['version']?.toString() ?? version;

    latestVersionNum = data['version_num'] ?? 0;

    latestUpdateLog = data['version_desc']?.toString() ?? '';

    prerelease = data['prerelease'] == true;

    downloadUrl = data['download_url']?.toString() ?? '';
  }

  // =========================================================
  // 加载历史版本
  // =========================================================

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

        if (latest > current) {
          return true;
        } else if (latest < current) {
          return false;
        }
      }
    } catch (_) {}

    return false;
  }
}
