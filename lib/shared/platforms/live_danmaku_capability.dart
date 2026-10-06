import 'package:pure_live/shared/platforms/danmaku_emoji.dart';

abstract interface class LiveDanmakuCapability {
  bool get connectsDanmakuOnRoomEntry;

  String? danmakuUserNameNoticeKey(String userName);

  UnifiedEmojiModel? parseDanmakuEmoji(Map<String, dynamic> json, String fallbackKey);
}

mixin LiveDanmakuCapabilityDefaults implements LiveDanmakuCapability {
  @override
  bool get connectsDanmakuOnRoomEntry => true;

  @override
  String? danmakuUserNameNoticeKey(String userName) => null;

  @override
  UnifiedEmojiModel? parseDanmakuEmoji(Map<String, dynamic> json, String fallbackKey) => null;
}
