import 'package:pure_live/shared/platforms/danmaku_emoji.dart';
import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';

/// 虎牙弹幕细节：表情结构是 `sName`/`sEscape`/`sUrl`/`sFlexiUrl`，
/// 优先用弹性地址 `sFlexiUrl`。
mixin HuyaDanmakuCapability on LiveDanmakuCapabilityDefaults {
  @override
  UnifiedEmojiModel? parseDanmakuEmoji(Map<String, dynamic> json, String fallbackKey) {
    final key = json['sName']?.toString() ?? '';
    final escapeField = json['sEscape']?.toString() ?? '';
    final flexiUrl = json['sFlexiUrl']?.toString() ?? '';
    final url = json['sUrl']?.toString() ?? '';
    return UnifiedEmojiModel(
      primaryKey: key,
      secondaryKey: escapeField.isNotEmpty ? escapeField : null,
      text: key,
      url: flexiUrl.isNotEmpty ? flexiUrl : url,
      localFile: json['local_file']?.toString() ?? '',
    );
  }
}
