import 'package:pure_live/shared/platforms/danmaku_emoji.dart';
import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';

/// B 站弹幕细节：表情字段结构，以及"游客昵称被打码"的提示。
///
/// 两者都是 B 站自己的约定，因此留在站点目录里，而不是写成通用弹幕代码里的分支。
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
