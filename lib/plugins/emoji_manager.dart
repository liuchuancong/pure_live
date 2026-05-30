import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:pure_live/core/emoji/models/unified_emoji_model.dart';

class EmojiManager {
  static final EmojiManager instance = EmojiManager._internal();
  factory EmojiManager() => instance;
  EmojiManager._internal();

  static final Map<String, ui.Image> _cache = {};
  String? _currentLoadedSite;
  RegExp? _emojiRegex;

  Map<String, ui.Image> get cache => _cache;
  RegExp? get emojiRegex => _emojiRegex;

  Future<void> preload(String site) async {
    if (_currentLoadedSite == site) return;

    clearCache();

    List<UnifiedEmojiModel> unifiedList = [];
    try {
      final jsonStr = await rootBundle.loadString('assets/emo/json/$site.json');
      unifiedList = UnifiedEmojiModel.parseToUnifiedList(jsonStr, site);
    } catch (_) {
      return;
    }

    if (unifiedList.isEmpty) return;

    final Map<String, List<String>> assetPathToKeys = {};
    for (final emoji in unifiedList) {
      if (emoji.localFile.isEmpty) continue;

      final String fullAssetPath = 'assets/emo/images/$site/${emoji.localFile}';

      if (emoji.primaryKey.isNotEmpty) {
        assetPathToKeys.putIfAbsent(fullAssetPath, () => []).add(emoji.primaryKey);
      }
      if (emoji.secondaryKey != null && emoji.secondaryKey!.isNotEmpty) {
        assetPathToKeys.putIfAbsent(fullAssetPath, () => []).add(emoji.secondaryKey!);
      }
    }

    await Future.wait(
      assetPathToKeys.entries.map((entry) async {
        final assetPath = entry.key;
        final keys = entry.value;

        try {
          final assetData = await rootBundle.load(assetPath);
          final bytes = assetData.buffer.asUint8List();

          final codec = await ui.instantiateImageCodec(bytes, targetWidth: 80, targetHeight: 80);
          final frame = await codec.getNextFrame();

          for (final key in keys) {
            _addToCache(key, frame.image);
          }
        } catch (_) {}
      }),
    );

    _rebuildRegex();
    _currentLoadedSite = site;
  }

  void _rebuildRegex() {
    if (_cache.isEmpty) {
      _emojiRegex = null;
      return;
    }

    final keys = _cache.keys.toList()..sort((a, b) => b.length.compareTo(a.length));

    final pattern = keys.map(RegExp.escape).join('|');

    _emojiRegex = RegExp(pattern);
  }

  void _addToCache(String key, ui.Image image) {
    if (_cache.containsKey(key)) {
      if (_cache[key] == image) {
        return;
      }
      _cache[key]?.dispose();
    }
    _cache[key] = image;
  }

  void clearCache() {
    final Set<ui.Image> uniqueImages = _cache.values.toSet();
    for (final img in uniqueImages) {
      img.dispose();
    }
    _cache.clear();
    _emojiRegex = null;
    _currentLoadedSite = null;
  }

  static ui.Image? getEmoji(String emojiText) => _cache[emojiText];
}
