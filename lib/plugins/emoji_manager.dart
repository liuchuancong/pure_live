import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/core/emoji/models/unified_emoji_model.dart';

class EmojiManager {
  static final EmojiManager instance = EmojiManager._internal();
  factory EmojiManager() => instance;
  EmojiManager._internal();

  final Map<String, ui.Image> _tempCache = {};
  String? _loadedPlatform;

  Future<void> preload(String platform) async {
    if (_loadedPlatform == platform) return;
    EmojiAtlas.instance.clear();
    _tempCache.clear();
    _loadedPlatform = null;

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

    await Future.wait(
      group.entries.map((e) async {
        try {
          final data = await rootBundle.load(e.key);
          final bytes = data.buffer.asUint8List();
          final codec = await ui.instantiateImageCodec(bytes, targetWidth: 24, targetHeight: 24);
          final frame = await codec.getNextFrame();
          for (var item in e.value) {
            _tempCache[item.localFile] = frame.image;
          }
        } catch (_) {}
      }),
    );

    final List<EmojiInfo> infoList = [];
    for (var entry in group.entries) {
      for (var model in entry.value) {
        final img = _tempCache[model.localFile];
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

    EmojiAtlas.instance.registerAll(infoList);
    for (var info in infoList) {
      final img = _tempCache[info.id];
      if (img != null) EmojiAtlas.instance.resolveLoadedImage(info, img);
    }
    _tempCache.clear();
    _loadedPlatform = platform;
  }

  void release() {
    EmojiAtlas.instance.clear();
    _tempCache.clear();
    _loadedPlatform = null;
  }
}
