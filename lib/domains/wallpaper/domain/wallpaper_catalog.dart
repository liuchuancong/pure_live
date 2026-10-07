/// Data model for the wallpaper browser.
///
/// Everything the browser shows comes from one of three places and these types
/// do not care which: the iTab wallpaper API for the picture library, the iTab
/// CDN for the live wallpapers and the deepin set, or tables compiled into the
/// app for solid colours and gradients. The source tree is therefore a
/// constant - no catalog download, mirror probe or per-category shard has to
/// succeed before the settings page can draw a frame.
library;

/// What kind of media an entry describes.
enum WallpaperKind { image, video, gradient }

/// Locale key of a source's display name.
///
/// Derived from the identifier instead of carried next to it: the catalog is a
/// `const` tree, so a row could always be added with an empty name or a name
/// only in one language, and the browser would paint the blank. One derivation
/// plus the bundle test makes a missing label a test failure.
String wallpaperSourceNameKey(String id) => 'wallpaper_source_${wallpaperNameSlug(id)}';

/// Locale key of a group's display name, namespaced by its source because
/// `nature` exists in the official set and in Wallhaven at the same time.
String wallpaperGroupNameKey(String sourceId, String groupId) =>
    'wallpaper_group_${wallpaperNameSlug(sourceId)}_${wallpaperNameSlug(groupId)}';

String wallpaperNameSlug(String value) => value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();

/// One colour stop of a gradient.
class WallpaperGradientStop {
  final String color;

  /// Position in percent, following the CSS description.
  final double pos;

  const WallpaperGradientStop({required this.color, required this.pos});
}

/// One wallpaper entry.
class WallpaperItem {
  /// Absolute URL of the picture/video, or a synthetic key for a gradient
  /// (which has no file at all).
  final String file;
  final String? id;
  final String? name;

  /// Poster image of a live wallpaper.
  final String? poster;

  /// Grid-sized copy of [file]; the API usually supplies one.
  final String? thumb;

  /// Gradient only: the CSS description, kept for reference and export.
  final String? css;

  /// Gradient only: CSS angle in degrees (0 points up, clockwise positive).
  final int deg;
  final List<WallpaperGradientStop>? gradient;

  const WallpaperItem({
    required this.file,
    this.id,
    this.name,
    this.poster,
    this.thumb,
    this.css,
    this.deg = 0,
    this.gradient,
  });

  /// Stable identity used to compare "in use" and to key lists.
  String get key => file.isNotEmpty ? file : 'item:${id ?? name ?? css ?? ''}';
}

/// One group of entries inside a source.
class WallpaperGroup {
  final String id;

  /// The source this group belongs to; its identifier namespaces [nameKey] so
  /// two sources can both offer a `nature` group.
  final String sourceId;

  /// Value of the source's own filter parameter. Empty means "no filter", which
  /// is how Wallhaven's *popular* group is requested.
  final String apiQuery;

  /// Hint shown in the row subtitle; the real total arrives with the page.
  final int count;

  /// True for sources that expose a single group, so the browser can skip the
  /// group list and open the grid straight away.
  final bool hidden;

  const WallpaperGroup({
    required this.id,
    required this.sourceId,
    required this.count,
    this.apiQuery = '',
    this.hidden = false,
  });

  String get nameKey => wallpaperGroupNameKey(sourceId, id);
}

/// A top-level group of wallpapers.
class WallpaperSource {
  final String id;
  final WallpaperKind kind;
  final bool categorized;
  final int count;
  final List<WallpaperGroup> groups;

  const WallpaperSource({
    required this.id,
    required this.kind,
    required this.categorized,
    required this.groups,
    this.count = 0,
  });

  String get nameKey => wallpaperSourceNameKey(id);

  /// Groups the browser lists. Single-group sources surface only their one
  /// entry, and empty groups are dropped.
  List<WallpaperGroup> get visibleGroups {
    if (!categorized) {
      final hiddenOnes = groups.where((group) => group.hidden).toList(growable: false);
      return hiddenOnes.isNotEmpty ? hiddenOnes : groups;
    }
    return groups.where((group) => group.count > 0).toList(growable: false);
  }
}

/// Identifiers of the sources compiled into the app.
class WallpaperSourceIds {
  const WallpaperSourceIds._();

  static const String official = 'official';
  static const String wallhaven = 'wallhaven';
  static const String bing = 'bing';
  static const String deepin = 'deepin';
  static const String video = 'video';
  static const String solidColor = 'solid-color';
}

/// The whole source tree.
class WallpaperCatalog {
  final List<WallpaperSource> sources;

  const WallpaperCatalog({required this.sources});

  /// The source with [id], or null when the catalog has none.
  WallpaperSource? sourceById(String id) {
    for (final source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  /// Picture sources, in the order the library lists them.
  List<WallpaperSource> get imageSources =>
      sources.where((source) => source.kind == WallpaperKind.image).toList(growable: false);

  static WallpaperSource _single(String id, WallpaperKind kind, int count) => WallpaperSource(
    id: id,
    kind: kind,
    categorized: false,
    count: count,
    groups: <WallpaperGroup>[WallpaperGroup(id: 'all', sourceId: id, count: count, hidden: true)],
  );

  /// The compiled-in source tree.
  ///
  /// Group counts are hints for the subtitles; the grid reports the real number
  /// once a page loads. Names never appear here: they live in the locale bundles,
  /// keyed by the source and group identifiers below.
  factory WallpaperCatalog.builtIn() {
    // The "all" bucket of the official set is absent by design: it overlaps the
    // seven groups and would only duplicate content.
    WallpaperSource images(String id, bool categorized, List<(String, int)> groups) => WallpaperSource(
      id: id,
      kind: WallpaperKind.image,
      categorized: categorized,
      count: groups.fold(0, (sum, group) => sum + group.$2),
      groups: <WallpaperGroup>[
        for (final (String groupId, int count) in groups)
          WallpaperGroup(id: groupId, sourceId: id, apiQuery: groupId, count: count, hidden: !categorized),
      ],
    );

    const List<(String, String, int)> wallhavenGroups = <(String, String, int)>[
      ('popular', '', 233),
      ('minimalism', 'id:2278', 240),
      ('patterns', 'id:869', 240),
      ('landscape', 'id:711', 240),
      ('nature', 'id:37', 240),
      ('cosplay', 'id:12757', 240),
      ('spiderman', 'id:2319', 240),
      ('ghibli', 'id:1748', 240),
      ('naruto', 'id:78174', 219),
      ('sci-fi', 'id:14', 240),
      ('anime', 'id:1', 240),
      ('anime-girls', 'id:5', 240),
      ('cyberpunk', 'id:376', 240),
      ('pixel-art', 'id:2321', 240),
      ('artwork', 'id:323', 240),
      ('cityscape', 'id:479', 240),
      ('digital-art', 'id:13', 240),
      ('fantasy-art', 'id:853', 240),
      ('final-fantasy', 'id:997', 240),
    ];

    return WallpaperCatalog(
      sources: <WallpaperSource>[
        images(WallpaperSourceIds.official, true, const <(String, int)>[
          ('nature', 240),
          ('acg', 240),
          ('art', 155),
          ('architecture', 28),
          ('life', 31),
          ('geometry', 72),
          ('other', 240),
        ]),
        WallpaperSource(
          id: WallpaperSourceIds.wallhaven,
          kind: WallpaperKind.image,
          categorized: true,
          count: wallhavenGroups.fold(0, (sum, group) => sum + group.$3),
          groups: <WallpaperGroup>[
            for (final (String groupId, String apiQuery, int count) in wallhavenGroups)
              WallpaperGroup(id: groupId, sourceId: WallpaperSourceIds.wallhaven, apiQuery: apiQuery, count: count),
          ],
        ),
        _single(WallpaperSourceIds.bing, WallpaperKind.image, 2030),
        _single(WallpaperSourceIds.deepin, WallpaperKind.image, 26),
        _single(WallpaperSourceIds.video, WallpaperKind.video, 125),
        _single(WallpaperSourceIds.solidColor, WallpaperKind.gradient, 151),
      ],
    );
  }
}
