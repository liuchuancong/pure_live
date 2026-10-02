import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/core/emoji/models/unified_emoji_model.dart';

class EmojiManager {
  static final EmojiManager instance = EmojiManager._internal();
  factory EmojiManager() => instance;
  EmojiManager._internal();

  String? _loadedPlatform;
  int _loadGeneration = 0;
  static const int _decodeBatchSize = 6;

  Future<void> preload(String platform) async {
    if (_loadedPlatform == platform) return;
    final generation = ++_loadGeneration;

    List<UnifiedEmojiModel> list;
    try {
      final str = await rootBundle.loadString('assets/emo/json/$platform.json');
      list = UnifiedEmojiModel.parseToUnifiedList(str, platform);
    } catch (_) {
      return;
    }

    final Map<String, List<UnifiedEmojiModel>> group = {};
    for (var m in list) {
      if (m.localFile.isEmpty) continue;
      final path = 'assets/emo/images/$platform/${m.localFile}';
      group.putIfAbsent(path, () => []).add(m);
    }

    final tempCache = <String, ui.Image>{};
    final entries = group.entries.toList(growable: false);
    for (var offset = 0; offset < entries.length; offset += _decodeBatchSize) {
      final candidateEnd = offset + _decodeBatchSize;
      final end = candidateEnd < entries.length ? candidateEnd : entries.length;
      await Future.wait(
        entries.sublist(offset, end).map((e) async {
          ui.Codec? codec;
          ui.Image? decodedImage;
          var adopted = false;
          try {
            final data = await rootBundle.load(e.key);
            final bytes = data.buffer.asUint8List();
            codec = await ui.instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 24);
            final frame = await codec.getNextFrame();
            decodedImage = frame.image;
            if (generation != _loadGeneration) return;
            for (final item in e.value) {
              tempCache[item.localFile] = frame.image;
            }
            adopted = true;
          } catch (_) {
          } finally {
            codec?.dispose();
            if (!adopted) decodedImage?.dispose();
          }
        }),
      );
      if (generation != _loadGeneration) {
        _disposeImages(tempCache.values);
        return;
      }
      // Yield between small decode groups instead of saturating every CPU core
      // and starving route/scroll frames with one unbounded Future.wait.
      await Future<void>.delayed(Duration.zero);
    }

    if (generation != _loadGeneration) {
      _disposeImages(tempCache.values);
      return;
    }

    final List<EmojiInfo> infoList = [];
    for (var entry in group.entries) {
      for (var model in entry.value) {
        final img = tempCache[model.localFile];
        if (img == null) continue;
        final keys = <String>[];
        if (model.primaryKey.isNotEmpty) keys.add(model.primaryKey);
        if (model.secondaryKey != null && model.secondaryKey!.isNotEmpty) keys.add(model.secondaryKey!);
        infoList.add(
          EmojiInfo(
            id: model.localFile,
            keys: keys,
            asset: entry.key,
            sourceType: EmojiSourceType.asset,
            width: img.width.toDouble(),
            height: img.height.toDouble(),
          ),
        );
      }
    }

    // Keep the previous platform usable until the replacement is completely
    // decoded, then swap synchronously so renderers never observe a half atlas.
    EmojiAtlas.instance.clear();
    EmojiAtlas.instance.registerAll(infoList);
    for (var info in infoList) {
      final img = tempCache[info.id];
      if (img != null) EmojiAtlas.instance.resolveLoadedImage(info, img);
    }
    tempCache.clear();
    _loadedPlatform = platform;
  }

  void _disposeImages(Iterable<ui.Image> images) {
    for (final image in images.toSet()) {
      image.dispose();
    }
  }

  void release() {
    _loadGeneration++;
    EmojiAtlas.instance.clear();
    _loadedPlatform = null;
  }
}
