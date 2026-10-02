import 'package:pure_live/shared/platforms/danmaku_emoji.dart';
import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';

/// 斗鱼弹幕细节：表情结构是 `img_url`，键名统一包在方括号里。
mixin DouyuDanmakuCapability on LiveDanmakuCapabilityDefaults {
  @override
  UnifiedEmojiModel? parseDanmakuEmoji(Map<String, dynamic> json, String fallbackKey) {
    final key = fallbackKey.startsWith('[') && fallbackKey.endsWith(']') ? fallbackKey : '[$fallbackKey]';
    return UnifiedEmojiModel(
      primaryKey: key,
      text: key,
      url: json['img_url']?.toString() ?? '',
      localFile: json['local_file']?.toString() ?? '',
    );
  }
}
