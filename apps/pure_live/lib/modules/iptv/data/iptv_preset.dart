/// A source the app recommends: one entry of the built-in catalogue, or of
/// the remote feed the repository publishes.
///
/// Presets are addresses like any other — importing one goes through the
/// same preview and the same reconciler as a link the viewer typed — so a
/// preset that dies is removed from the feed and nothing in the library
/// knows or cares that it ever had a special name. A playlist is "from" a
/// preset when it was imported from the preset's address.
///
/// Its words are data, not interface: they come from the feed, so they
/// carry their own languages (by language tag, `zh-CN` the fallback) the
/// way the platform manifests do.
final class IptvPreset {
  /// A preset.
  const new({
    required this.id,
    required this.names,
    required this.descriptions,
    required this.url,
    this.kind = IptvPresetKind.playlist,
    this.guideUrls = const [],
    this.tags = const [],
    this.shortLived = false,
  });

  /// The stable id the preset is known by.
  final String id;

  /// The display name by language tag.
  final Map<String, String> names;

  /// One line about what the source carries, by language tag.
  final Map<String, String> descriptions;

  /// The playlist address; for [IptvPresetKind.xtream], the panel's address.
  final String url;

  /// What the entry is.
  final IptvPresetKind kind;

  /// Guides to try when the library has none, after the ones the playlist's
  /// own header names: the first that reads and matches is kept.
  final List<String> guideUrls;

  /// Short words the grid shows as chips, by language tag.
  final List<Map<String, String>> tags;

  /// Whether the source signs its addresses so they expire (a token or a
  /// timestamp in every line): such a playlist is refreshed when the IPTV
  /// screens open and its last sync is older than [iptvShortLivedAge],
  /// because its old addresses stop playing long before any update interval
  /// would fetch new ones.
  final bool shortLived;

  /// The name in [languageTag], falling back to Chinese, then to anything.
  String nameIn(String languageTag) => _pick(names, languageTag) ?? id;

  /// The description in [languageTag].
  String descriptionIn(String languageTag) => _pick(descriptions, languageTag) ?? '';

  /// The tags in [languageTag].
  List<String> tagsIn(String languageTag) => [
    for (final tag in tags)
      if (_pick(tag, languageTag) case final String word) word,
  ];

  /// The feed's wire form, which [fromJson] reads back.
  Map<String, Object?> toJson() => {
    'id': id,
    'name': names,
    'description': descriptions,
    'url': url,
    if (kind != IptvPresetKind.playlist) 'kind': kind.name,
    if (guideUrls.isNotEmpty) 'guideUrls': guideUrls,
    if (tags.isNotEmpty) 'tags': tags,
    if (shortLived) 'shortLived': true,
  };

  /// The preset a feed entry reads back as, or null for an entry without an
  /// id or an address — a row nothing could import.
  static IptvPreset? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = '${json['id'] ?? ''}'.trim();
    final url = '${json['url'] ?? ''}'.trim();
    if (id.isEmpty || url.isEmpty) return null;
    return IptvPreset(
      id: id,
      names: _texts(json['name']),
      descriptions: _texts(json['description']),
      url: url,
      kind: IptvPresetKind.values.asNameMap()[json['kind']] ?? IptvPresetKind.playlist,
      guideUrls: [
        if (json['guideUrls'] case final List<Object?> urls)
          for (final url in urls)
            if (url is String && url.trim().isNotEmpty) url.trim(),
      ],
      tags: [
        if (json['tags'] case final List<Object?> tags)
          for (final tag in tags) _texts(tag),
      ],
      shortLived: json['shortLived'] == true,
    );
  }

  /// A feed's localized text: a plain string is Chinese, a map is by tag.
  static Map<String, String> _texts(Object? value) => switch (value) {
    final String text => {'zh-CN': text},
    final Map<Object?, Object?> map => {
      for (final MapEntry(:key, :value) in map.entries)
        if (key is String && value is String) key: value,
    },
    _ => const {},
  };

  static String? _pick(Map<String, String> texts, String languageTag) {
    if (texts.isEmpty) return null;
    final language = languageTag.split('-').first;
    return texts[languageTag] ??
        texts.entries.where((entry) => entry.key.split('-').first == language).firstOrNull?.value ??
        texts['zh-CN'] ??
        texts.values.first;
  }
}

/// What a preset entry is.
enum IptvPresetKind {
  /// An M3U/TXT playlist address.
  playlist,

  /// An Xtream Codes panel: importing it asks for the account.
  xtream,
}

/// How old a short-lived preset's sync may get before the IPTV screens
/// refresh it on entry.
const Duration iptvShortLivedAge = Duration(hours: 1);
