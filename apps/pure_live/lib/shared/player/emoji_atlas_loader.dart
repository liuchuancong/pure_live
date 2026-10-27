import 'dart:convert' show jsonDecode;
import 'dart:ui' show Rect;

import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:pure_live/app/logging/app_log.dart' show appLog;

/// The bundled emoticon atlas, one sprite sheet for every platform's
/// emoticons (`live_sites` packs it with `tool/pack_emoji_atlas.py`).
///
/// flame_barrage's atlas mode serves the whole catalogue from a single
/// image: the manifest maps each emoticon's message text ("[微笑]") to a
/// rect, one decode of the sheet builds every sprite, and no per-emoji file
/// is ever opened. Loading is a memo — the first caller starts it, every
/// caller awaits the same work, and a failure lets a later call retry.
Future<void> loadEmojiAtlas() {
  return _pending ??= _load();
}

Future<void>? _pending;

const String _manifestAsset = 'packages/live_sites/assets/emo/atlas/atlas.json';

Future<void> _load() async {
  try {
    final raw = await rootBundle.loadString(_manifestAsset);
    final manifest = jsonDecode(raw) as Map<String, dynamic>;
    final image = manifest['image']?.toString() ?? '';
    final rectsJson = manifest['rects'];
    if (image.isEmpty || rectsJson is! Map<String, dynamic>) return;

    final rects = <String, Rect>{
      for (final MapEntry(:key, :value) in rectsJson.entries)
        if (value is List && value.length == 4 && value.every((item) => item is num))
          key: Rect.fromLTWH(
            (value[0] as num).toDouble(),
            (value[1] as num).toDouble(),
            (value[2] as num).toDouble(),
            (value[3] as num).toDouble(),
          ),
    };
    if (rects.isEmpty) return;

    // The rects go in before the sheet resolves: the atlas branch builds a
    // sprite for every rect it can see.
    EmojiAtlas.instance.updateAtlasRects(rects);
    final info = EmojiInfo(
      id: 'bundled-atlas',
      asset: 'packages/live_sites/assets/emo/atlas/$image',
      keys: rects.keys.toList(growable: false),
      sourceType: EmojiSourceType.atlas,
    );
    EmojiAtlas.instance.registerAll([info]);
    await EmojiAtlas.instance.preloadEmoji(info);
  } on Object catch (error) {
    // The catalogue is an enhancement: without it the danmaku flies as
    // text, and the memo clears so a later room can retry.
    appLog.forCategory('player').error('the emoticon atlas could not load', error: error);
    _pending = null;
  }
}
