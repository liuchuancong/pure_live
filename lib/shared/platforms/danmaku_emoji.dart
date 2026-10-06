import 'dart:convert';

class UnifiedEmojiModel {
  final String primaryKey;
  final String? secondaryKey;
  final String text;
  final String url;
  final String localFile;

  const UnifiedEmojiModel({
    required this.primaryKey,
    this.secondaryKey,
    required this.text,
    required this.url,
    required this.localFile,
  });

  List<String> get keys => <String>[
    if (primaryKey.isNotEmpty) primaryKey,
    if (secondaryKey != null && secondaryKey!.isNotEmpty) secondaryKey!,
  ];
}

typedef DanmakuEmojiParser = UnifiedEmojiModel? Function(Map<String, dynamic> json, String fallbackKey);

List<UnifiedEmojiModel> parseDanmakuEmojiList(String rawJsonStr, DanmakuEmojiParser? parser) {
  if (parser == null) return const <UnifiedEmojiModel>[];

  final List<UnifiedEmojiModel> unifiedList = <UnifiedEmojiModel>[];
  final decoded = jsonDecode(rawJsonStr);

  void add(Map<String, dynamic> json, String fallbackKey) {
    final model = parser(json, fallbackKey);
    if (model != null) unifiedList.add(model);
  }

  if (decoded is List) {
    for (final item in decoded) {
      if (item is Map<String, dynamic>) add(item, '');
    }
  } else if (decoded is Map<String, dynamic>) {
    decoded.forEach((key, value) {
      if (value is Map<String, dynamic>) add(value, key);
    });
  }

  return unifiedList;
}
