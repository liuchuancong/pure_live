import 'dart:convert';

class BilibiliEmojiModel {
  final String emoji;
  final String descript;
  final String url;
  final int isDynamic;
  final int inPlayerArea;
  final int width;
  final int height;
  final int identity;
  final int unlockNeedGift;
  final int perm;
  final int unlockNeedLevel;
  final int emoticonValueType;
  final int bulgeDisplay;
  final String unlockShowText;
  final String unlockShowColor;
  final String emoticonUnique;
  final String unlockShowImage;
  final int emoticonId;
  final String localFile;

  BilibiliEmojiModel({
    required this.emoji,
    required this.descript,
    required this.url,
    required this.isDynamic,
    required this.inPlayerArea,
    required this.width,
    required this.height,
    required this.identity,
    required this.unlockNeedGift,
    required this.perm,
    required this.unlockNeedLevel,
    required this.emoticonValueType,
    required this.bulgeDisplay,
    required this.unlockShowText,
    required this.unlockShowColor,
    required this.emoticonUnique,
    required this.unlockShowImage,
    required this.emoticonId,
    required this.localFile,
  });

  factory BilibiliEmojiModel.fromJson(Map<String, dynamic> json) {
    return BilibiliEmojiModel(
      emoji: json['emoji'] ?? '',
      descript: json['descript'] ?? '',
      url: json['url'] ?? '',
      isDynamic: json['is_dynamic'] ?? 0,
      inPlayerArea: json['in_player_area'] ?? 0,
      width: json['width'] ?? 0,
      height: json['height'] ?? 0,
      identity: json['identity'] ?? 0,
      unlockNeedGift: json['unlock_need_gift'] ?? 0,
      perm: json['perm'] ?? 0,
      unlockNeedLevel: json['unlock_need_level'] ?? 0,
      emoticonValueType: json['emoticon_value_type'] ?? 0,
      bulgeDisplay: json['bulge_display'] ?? 0,
      unlockShowText: json['unlock_show_text'] ?? '',
      unlockShowColor: json['unlock_show_color'] ?? '',
      emoticonUnique: json['emoticon_unique'] ?? '',
      unlockShowImage: json['unlock_show_image'] ?? '',
      emoticonId: json['emoticon_id'] ?? 0,
      localFile: json['local_file'] ?? '',
    );
  }

  static Map<String, BilibiliEmojiModel> parseEmojiRegistry(String rawJsonStr) {
    final Map<String, dynamic> decoded = jsonDecode(rawJsonStr);
    return decoded.map((key, value) => MapEntry(key, BilibiliEmojiModel.fromJson(value as Map<String, dynamic>)));
  }
}
