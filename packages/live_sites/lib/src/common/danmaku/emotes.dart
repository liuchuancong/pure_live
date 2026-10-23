import 'dart:convert';

import 'package:meta/meta.dart';

// Constructors spell their class name by convention here; the `.new`
// shorthand hurts readability more than the lint helps.
// ignore_for_file: unnecessary_type_name_in_constructor

/// A platform emoticon from the lists bundled under `assets/emo/json`: the
/// text that stands for it in a message and its image.
///
/// The package bundles five platforms' lists — Bilibili, Douyin, Douyu,
/// Huya and Kuaishou. Other platforms give emoticons without keys or
/// files, so none of them is shown. [localFile] names the bundled copy
/// under `assets/emo/images/<platform>/`; [url] is the platform's own
/// address for the same picture.
@immutable
final class DanmakuEmoji {
  /// Creates an emoticon.
  const DanmakuEmoji({
    required this.primaryKey,
    required this.text,
    required this.url,
    required this.localFile,
    this.secondaryKey,
  });

  /// One entry of [platform]'s list; [fallbackKey] is the entry's key when
  /// the list is a JSON object (Bilibili, Douyu), empty for a JSON array.
  factory DanmakuEmoji.fromPlatform(Map<String, dynamic> json, String platform, String fallbackKey) {
    String text(Object? value) => value is String ? value : '';
    switch (platform) {
      case 'bilibili':
        final emoji = json['emoji']?.toString() ?? '';
        final key = emoji.isNotEmpty ? emoji : fallbackKey;
        return DanmakuEmoji(primaryKey: key, text: key, url: text(json['url']), localFile: text(json['local_file']));
      case 'douyin':
        final key = text(json['display_name']);
        final urls = switch (json['emoji_url']) {
          {'url_list': final List<dynamic> list} => list,
          _ => const <dynamic>[],
        };
        return DanmakuEmoji(
          primaryKey: key,
          text: key,
          url: urls.isEmpty ? '' : urls.first.toString(),
          localFile: text(json['local_file']),
        );
      case 'kuaishou':
        return DanmakuEmoji(
          primaryKey: fallbackKey,
          text: fallbackKey,
          url: text(json['url']),
          localFile: text(json['local_file']),
        );
      case 'douyu':
        final key = fallbackKey.startsWith('[') && fallbackKey.endsWith(']') ? fallbackKey : '[$fallbackKey]';
        return DanmakuEmoji(primaryKey: key, text: key, url: text(json['img_url']), localFile: text(json['local_file']));
      case 'huya':
        final key = text(json['sName']);
        final escape = text(json['sEscape']);
        final flexible = text(json['sFlexiUrl']);
        return DanmakuEmoji(
          primaryKey: key,
          secondaryKey: escape.isEmpty ? null : escape,
          text: key,
          url: flexible.isNotEmpty ? flexible : text(json['sUrl']),
          localFile: text(json['local_file']),
        );
      default:
        return const DanmakuEmoji(primaryKey: '', text: '', url: '', localFile: '');
    }
  }

  /// The emoticons of [platform]'s bundled list [source] (a JSON array, or
  /// an object keyed by the emoticon's text). Entries that are not objects
  /// are skipped.
  static List<DanmakuEmoji> parseList(String source, String platform) => switch (jsonDecode(source)) {
    final List<dynamic> list => [
      for (final item in list)
        if (item is Map<String, dynamic>) DanmakuEmoji.fromPlatform(item, platform, ''),
    ],
    final Map<String, dynamic> map => [
      for (final MapEntry(:key, :value) in map.entries)
        if (value is Map<String, dynamic>) DanmakuEmoji.fromPlatform(value, platform, key),
    ],
    _ => const [],
  };

  /// The text that stands for the emoticon (`[dog]`, `[微笑]`).
  final String primaryKey;

  /// Another text for it (Huya's escape code such as `/{66`), or null.
  final String? secondaryKey;

  /// Display text; the same as [primaryKey].
  final String text;

  /// The platform's image address.
  final String url;

  /// File name of the bundled image, empty when there is none.
  final String localFile;

  /// The texts that stand for the emoticon, non-empty only.
  List<String> get keys => [
    if (primaryKey.isNotEmpty) primaryKey,
    if (secondaryKey case final key? when key.isNotEmpty) key,
  ];
}

/// One entry of the renderer's emoticon atlas: the bundled image and the
/// texts it replaces, without decoding anything here.
@immutable
final class DanmakuEmojiAsset {
  /// Creates an entry.
  const DanmakuEmojiAsset({required this.id, required this.keys, required this.asset});

  /// Atlas id: the image's file name.
  final String id;

  /// Texts the image replaces.
  final List<String> keys;

  /// Bundled image path.
  final String asset;
}

/// Path of [platform]'s bundled emoticon list.
String danmakuEmojiListAsset(String platform) => 'assets/emo/json/$platform.json';

/// The atlas entries registered for [platform]: emoticons without a bundled
/// file are left out, and entries sharing an image come together, in the
/// order the images first appear (so each image is decoded once). The
/// renderer drops entries whose image fails to decode.
List<DanmakuEmojiAsset> danmakuEmojiAssets(String platform, Iterable<DanmakuEmoji> emojis) {
  final byAsset = <String, List<DanmakuEmoji>>{};
  for (final emoji in emojis) {
    if (emoji.localFile.isEmpty) continue;
    byAsset.putIfAbsent('assets/emo/images/$platform/${emoji.localFile}', () => []).add(emoji);
  }
  return [
    for (final MapEntry(key: asset, value: group) in byAsset.entries)
      for (final emoji in group) DanmakuEmojiAsset(id: emoji.localFile, keys: emoji.keys, asset: asset),
  ];
}
