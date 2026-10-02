import 'package:pure_live/shared/platforms/danmaku_emoji.dart';
import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';

/// 抖音弹幕细节：表情结构是 `display_name` + `emoji_url.url_list[0]`。
mixin DouyinDanmakuCapability on LiveDanmakuCapabilityDefaults {
  @override
  UnifiedEmojiModel? parseDanmakuEmoji(Map<String, dynamic> json, String fallbackKey) {
    final key = json['display_name']?.toString() ?? '';
    final emojiUrl = json['emoji_url'];
    String url = '';
    if (emojiUrl is Map) {
      final urlList = emojiUrl['url_list'];
      if (urlList is List && urlList.isNotEmpty) url = urlList.first.toString();
    }
    return UnifiedEmojiModel(primaryKey: key, text: key, url: url, localFile: json['local_file']?.toString() ?? '');
  }
}
