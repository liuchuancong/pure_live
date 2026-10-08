import 'dart:ui' as ui;

import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';

class DanmakuEmoteLoader {
  DanmakuEmoteLoader._();

  static final DanmakuEmoteLoader instance = DanmakuEmoteLoader._();

  final Set<String> _handled = <String>{};
  static const int maxHandled = 512;

  int _inFlight = 0;
  static const int maxInFlight = 4;

  void ensureRegistered(Iterable<LiveEmote> emotes) {
    for (final emote in emotes) {
      final url = emote.url.trim();
      final code = emote.code;
      if (url.isEmpty || code.isEmpty) continue;
      final key = '$code\u0000$url';
      if (!_handled.add(key)) continue;
      while (_handled.length > maxHandled) {
        _handled.remove(_handled.first);
      }
      if (_inFlight >= maxInFlight) continue;
      _inFlight++;
      _load(code: code, url: url).whenComplete(() => _inFlight--);
    }
  }

  Future<void> _load({required String code, required String url}) async {
    try {
      final bytes = await HttpClient.instance.getBytes(url);
      if (bytes.isEmpty) return;
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final info = EmojiInfo(
        id: code,
        keys: <String>[code],
        asset: url,
        sourceType: EmojiSourceType.network,
        width: image.width.toDouble(),
        height: image.height.toDouble(),
      );
      final atlas = EmojiAtlas.instance;
      atlas.register(info);
      atlas.resolveLoadedImage(info, image);
    } catch (error, stackTrace) {
      CoreLog.error('danmaku emote load failed: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    }
  }
}
