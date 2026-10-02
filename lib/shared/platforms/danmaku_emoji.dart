import 'dart:convert';

/// 站点弹幕表情的统一表示。
///
/// 各站点返回的表情 JSON 字段结构互不相同（B 站是 `emoji`/`url`，抖音是
/// `display_name`/`emoji_url.url_list`，斗鱼是 `img_url`，虎牙是
/// `sName`/`sEscape`/`sUrl`……）。站点在自己的能力实现里把它映射成这个统一模型，
/// 通用弹幕渲染只认识这一个结构。
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

/// 站点专有的弹幕表情 JSON 解析器。
///
/// [fallbackKey] 是对象形态表情表里的键名（列表形态传空串）。返回 null 表示该
/// 条目不算表情，会被跳过。
typedef DanmakuEmojiParser = UnifiedEmojiModel? Function(Map<String, dynamic> json, String fallbackKey);

/// 用站点自己的解析器把表情 JSON 展开成统一列表。
///
/// 站点没有解析器时返回空列表：与"该站点不提供弹幕表情"等价。
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
