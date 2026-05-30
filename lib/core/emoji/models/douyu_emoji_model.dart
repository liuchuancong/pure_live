import 'dart:convert';

class DouyuEmojiModel {
  final String simpleName;
  final String imgUrl;
  final int isDeleted;
  final int sort;
  final String localFile;

  DouyuEmojiModel({
    required this.simpleName,
    required this.imgUrl,
    required this.isDeleted,
    required this.sort,
    required this.localFile,
  });

  factory DouyuEmojiModel.fromJson(Map<String, dynamic> json) {
    return DouyuEmojiModel(
      simpleName: json['simple_name'] ?? '',
      imgUrl: json['img_url'] ?? '',
      isDeleted: json['is_deleted'] ?? 0,
      sort: (json['sort'] is double) ? (json['sort'] as double).toInt() : (json['sort'] ?? 0),
      localFile: json['local_file'] ?? '',
    );
  }

  static Map<String, DouyuEmojiModel> parseEmojiRegistry(String rawJsonStr) {
    final Map<String, dynamic> decoded = jsonDecode(rawJsonStr);
    return decoded.map((key, value) => MapEntry(key, DouyuEmojiModel.fromJson(value as Map<String, dynamic>)));
  }
}
