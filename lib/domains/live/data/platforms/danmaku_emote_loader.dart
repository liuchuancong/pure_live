import 'dart:ui' as ui;

import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_live/core/logging/core_log.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/core/network/http_client.dart';

/// 把"消息自带的表情图片"注册进画面弹幕引擎（上游 M13.16）。
///
/// 引擎只认"编码 → 已解码图片"（`EmojiAtlas`），它自己不取网络图（包只依赖
/// flutter + flame，加 HTTP 会引入 dart:io 破坏 Web），所以取图与解码放在这里：
/// 本仓已有代理/Cookie 的 HTTP 栈，取到的字节解码成 [ui.Image] 后交给
/// `EmojiAtlas.register` + `resolveLoadedImage`，之后引擎按 keys 匹配就会画成图片。
///
/// 已知限制：引擎对已上屏的消息不会追溯重排，**晚注册的图只对之后的消息生效**；
/// 同一条消息若在图片到位前已经上屏，仍显示原文本。
class DanmakuEmoteLoader {
  DanmakuEmoteLoader._();

  static final DanmakuEmoteLoader instance = DanmakuEmoteLoader._();

  /// 已经处理过的编码（成功、进行中或失败）——失败不重试，避免坏图反复请求。
  final Set<String> _handled = <String>{};
  static const int maxHandled = 512;

  /// 正在加载的图片数量上限：弹幕里可能一次冒出很多表情。
  int _inFlight = 0;
  static const int maxInFlight = 4;

  /// 把这个房间里用到的表情注册进引擎；没有的就异步取图。
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
        // id 用编码：引擎按编码取 sprite，同一条消息里的同一个编码也只该有一张图。
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
      // 表情取不到不该影响弹幕本身：记一条日志就够（且不再重试）。
      CoreLog.error('danmaku emote load failed: $error');
      if (kDebugMode) debugPrintStack(stackTrace: stackTrace);
    }
  }
}
