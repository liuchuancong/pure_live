import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/plugins/race_http.dart';
import 'package:pure_live/common/global/app_path_manager.dart';

class EmojiManager {
  static final EmojiManager instance = EmojiManager._internal();
  factory EmojiManager() => instance;
  EmojiManager._internal();

  static final Map<String, ui.Image> _cache = {};
  String? _currentLoadedSite;

  Map<String, ui.Image> get cache => _cache;

  Future<void> preload(String site) async {
    if (_currentLoadedSite == site) return;

    clearCache();
    final cacheDir = await AppPathManager().emojiCacheDir;
    final localJsonFile = File('${cacheDir.path}/${site}_list.json');
    if (!await localJsonFile.exists()) return;

    List<dynamic> localList = [];
    try {
      final jsonStr = await localJsonFile.readAsString();
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        localList = decoded;
      }
    } catch (_) {
      return;
    }

    if (localList.isEmpty) return;

    await Future.wait(
      localList.map((emoji) async {
        final code = emoji['code']?.toString() ?? '';
        final text = emoji['text']?.toString() ?? '';
        if (code.isEmpty || text.isEmpty) return;

        final key = "[$text]";
        if (_cache.containsKey(key)) return;

        try {
          final localFile = File('${cacheDir.path}/${site}_$code.png');
          if (await localFile.exists() && await localFile.length() > 100) {
            final bytes = await localFile.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes, targetWidth: 80, targetHeight: 80);
            final frame = await codec.getNextFrame();
            _addToCache(key, frame.image);
          }
        } catch (_) {}
      }),
    );

    _currentLoadedSite = site;
  }

  Future<void> autoSilentCacheAllPlatforms(List<String> serverMirrors) async {
    if (serverMirrors.isEmpty) return;

    final List<String> platforms = Sites.supportSites
        .map((site) => site.id)
        .where((id) => id != Sites.iptvSite)
        .toList();

    final cacheDir = await AppPathManager().emojiCacheDir;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);

    for (final site in platforms) {
      try {
        final list = await _fetchRemoteEmojiList(site, serverMirrors);
        if (list.isEmpty) continue;

        await Future.wait(
          list.map((emoji) async {
            final code = emoji['code']?.toString() ?? '';
            if (code.isEmpty) return;

            final localFile = File('${cacheDir.path}/${site}_$code.png');
            if (await localFile.exists() && await localFile.length() > 100) return;

            try {
              final targetPaths = serverMirrors.map((mirror) {
                final base = mirror.endsWith('/') ? mirror.substring(0, mirror.length - 1) : mirror;
                return "$base/images/$site/$code.png";
              }).toList();

              final fastestImgUrl = await RaceHttp.findFastestUrl(targetPaths, timeout: const Duration(seconds: 5));
              if (fastestImgUrl == null) return;

              final request = await client.getUrl(Uri.parse(fastestImgUrl));
              final response = await request.close();
              if (response.statusCode == 200) {
                final bytes = await consolidateHttpClientResponseBytes(response);
                if (bytes.isNotEmpty && bytes.length > 100) {
                  await localFile.writeAsBytes(bytes);
                }
              }
            } catch (_) {}
          }),
        );
      } catch (_) {}
    }
    client.close();
  }

  Future<List<dynamic>> _fetchRemoteEmojiList(String site, List<String> serverMirrors) async {
    final cacheDir = await AppPathManager().emojiCacheDir;
    final localJsonFile = File('${cacheDir.path}/${site}_list.json');

    final jsonTargetUrls = serverMirrors.map((mirror) {
      final base = mirror.endsWith('/') ? mirror.substring(0, mirror.length - 1) : mirror;
      return "$base/json/$site.json";
    }).toList();

    try {
      final dynamic data = await RaceHttp.fetchJson(jsonTargetUrls, timeout: const Duration(seconds: 5));

      if (data != null) {
        if (data is List) {
          await localJsonFile.writeAsString(jsonEncode(data));
          return data;
        } else if (data is Map) {
          final nestedList = data['emotions'] ?? data['list'] ?? data['data'];
          if (nestedList is List) {
            await localJsonFile.writeAsString(jsonEncode(nestedList));
            return nestedList;
          }
        }
      }
    } catch (_) {}

    if (await localJsonFile.exists()) {
      try {
        final jsonStr = await localJsonFile.readAsString();
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          return decoded;
        }
      } catch (_) {}
    }

    return const [];
  }

  void _addToCache(String key, ui.Image image) {
    if (_cache.containsKey(key)) {
      _cache[key]?.dispose();
    }
    _cache[key] = image;
  }

  void clearCache() {
    for (final img in _cache.values) {
      img.dispose();
    }
    _cache.clear();
    _currentLoadedSite = null;
  }

  static ui.Image? getEmoji(String emojiText) => _cache[emojiText];
}
