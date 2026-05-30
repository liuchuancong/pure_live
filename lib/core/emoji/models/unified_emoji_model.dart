import 'dart:convert';
import 'package:pure_live/core/sites.dart';

class UnifiedEmojiModel {
  final String primaryKey;
  final String? secondaryKey;
  final String text;
  final String url;
  final String localFile;

  UnifiedEmojiModel({
    required this.primaryKey,
    this.secondaryKey,
    required this.text,
    required this.url,
    required this.localFile,
  });

  factory UnifiedEmojiModel.fromPlatform(Map<String, dynamic> json, String platform, String fallbackKey) {
    String pKey = '';
    String? sKey;
    String txt = '';
    String imgUrl = '';
    String filename = '';

    if (platform == Sites.bilibiliSite) {
      final String emojiField = json['emoji']?.toString() ?? '';
      pKey = emojiField.isNotEmpty ? emojiField : fallbackKey;
      txt = pKey;
      imgUrl = json['url'] ?? '';
      filename = json['local_file'] ?? '';
    } else if (platform == Sites.douyinSite) {
      pKey = json['display_name'] ?? '';
      txt = pKey;
      final emojiUrl = json['emoji_url'] ?? {};
      final urlList = emojiUrl['url_list'] as List?;
      imgUrl = (urlList != null && urlList.isNotEmpty) ? urlList.first.toString() : '';
      filename = json['local_file'] ?? '';
    } else if (platform == Sites.douyuSite) {
      pKey = fallbackKey.startsWith('[') && fallbackKey.endsWith(']') ? fallbackKey : "[$fallbackKey]";
      txt = pKey;
      imgUrl = json['img_url'] ?? '';
      filename = json['local_file'] ?? '';
    } else if (platform == Sites.huyaSite) {
      pKey = json['sName'] ?? '';
      final String escapeField = json['sEscape'] ?? '';
      if (escapeField.isNotEmpty) {
        sKey = escapeField;
      }
      txt = pKey;
      final String sUrl = json['sUrl'] ?? '';
      final String sFlexiUrl = json['sFlexiUrl'] ?? '';
      imgUrl = sFlexiUrl.isNotEmpty ? sFlexiUrl : sUrl;
      filename = json['local_file'] ?? '';
    }

    return UnifiedEmojiModel(primaryKey: pKey, secondaryKey: sKey, text: txt, url: imgUrl, localFile: filename);
  }

  static List<UnifiedEmojiModel> parseToUnifiedList(String rawJsonStr, String platform) {
    final List<UnifiedEmojiModel> unifiedList = [];
    final decoded = jsonDecode(rawJsonStr);

    if (decoded is List) {
      for (var item in decoded) {
        if (item is Map<String, dynamic>) {
          unifiedList.add(UnifiedEmojiModel.fromPlatform(item, platform, ''));
        }
      }
    } else if (decoded is Map<String, dynamic>) {
      decoded.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          unifiedList.add(UnifiedEmojiModel.fromPlatform(value, platform, key));
        }
      });
    }

    return unifiedList;
  }
}
