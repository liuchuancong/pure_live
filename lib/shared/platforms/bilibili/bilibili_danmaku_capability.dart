import 'package:pure_live/shared/platforms/danmaku_emoji.dart';
import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';

mixin BilibiliDanmakuCapability on LiveDanmakuCapabilityDefaults {
  static final RegExp _maskedName = RegExp(r'\*{2,}|＊{2,}');

  @override
  UnifiedEmojiModel? parseDanmakuEmoji(Map<String, dynamic> json, String fallbackKey) {
    final emojiField = json['emoji']?.toString() ?? '';
    final key = emojiField.isNotEmpty ? emojiField : fallbackKey;
    return UnifiedEmojiModel(
      primaryKey: key,
      text: key,
      url: json['url']?.toString() ?? '',
      localFile: json['local_file']?.toString() ?? '',
    );
  }

  @override
  String? danmakuUserNameNoticeKey(String userName) =>
      _maskedName.hasMatch(userName) ? 'bilibili_guest_name_masked' : null;
}
