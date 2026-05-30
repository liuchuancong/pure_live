import 'dart:convert';

class DouyinEmojiModel {
  final String originUri;
  final String displayName;
  final int hide;
  final DouyinEmojiUrl emojiUrl;
  final String localFile;

  DouyinEmojiModel({
    required this.originUri,
    required this.displayName,
    required this.hide,
    required this.emojiUrl,
    required this.localFile,
  });

  factory DouyinEmojiModel.fromJson(Map<String, dynamic> json) {
    return DouyinEmojiModel(
      originUri: json['origin_uri'] ?? '',
      displayName: json['display_name'] ?? '',
      hide: json['hide'] ?? 0,
      emojiUrl: DouyinEmojiUrl.fromJson(json['emoji_url'] ?? {}),
      localFile: json['local_file'] ?? '',
    );
  }

  static List<DouyinEmojiModel> parseEmojiList(String rawJsonStr) {
    final List<dynamic> decoded = jsonDecode(rawJsonStr);
    return decoded.map((item) => DouyinEmojiModel.fromJson(item as Map<String, dynamic>)).toList();
  }
}

class DouyinEmojiUrl {
  final String uri;
  final List<String> urlList;

  DouyinEmojiUrl({required this.uri, required this.urlList});

  factory DouyinEmojiUrl.fromJson(Map<String, dynamic> json) {
    return DouyinEmojiUrl(uri: json['uri'] ?? '', urlList: List<String>.from(json['url_list'] ?? []));
  }
}
