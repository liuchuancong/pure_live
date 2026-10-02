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

  /// Primary display name.
  final String name;

  /// English display name; may be empty.
  final String nameEn;

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
    required this.name,
    required this.count,
    this.nameEn = '',
    this.apiQuery = '',
    this.hidden = false,
  });

  String localizedName(String languageCode) {
    if (languageCode == 'zh') return name.isNotEmpty ? name : nameEn;
    return nameEn.isNotEmpty ? nameEn : name;
  }
}

/// A top-level group of wallpapers.
class WallpaperSource {
  final String id;
  final String name;
  final String nameEn;
  final WallpaperKind kind;
  final bool categorized;
  final int count;
  final List<WallpaperGroup> groups;

  const WallpaperSource({
    required this.id,
    required this.name,
    required this.kind,
    required this.categorized,
    required this.groups,
    this.nameEn = '',
    this.count = 0,
  });

  String localizedName(String languageCode) {
    if (languageCode == 'zh') return name.isNotEmpty ? name : nameEn;
    return nameEn.isNotEmpty ? nameEn : name;
  }

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

  static WallpaperSource _single(String id, String name, String nameEn, WallpaperKind kind, int count) =>
      WallpaperSource(
        id: id,
        name: name,
        nameEn: nameEn,
        kind: kind,
        categorized: false,
        count: count,
        groups: <WallpaperGroup>[WallpaperGroup(id: 'all', name: name, nameEn: nameEn, count: count, hidden: true)],
      );

  /// The compiled-in source tree.
  ///
  /// Group counts are hints for the subtitles; the grid reports the real number
  /// once a page loads.
  factory WallpaperCatalog.builtIn() {
    // The "all" bucket of the official set is absent by design: it overlaps the
    // seven groups and would only duplicate content.
    WallpaperSource images(
      String id,
      String name,
      String nameEn,
      bool categorized,
      List<(String, String, String, int)> groups,
    ) => WallpaperSource(
      id: id,
      name: name,
      nameEn: nameEn,
      kind: WallpaperKind.image,
      categorized: categorized,
      count: groups.fold(0, (sum, group) => sum + group.$4),
      groups: <WallpaperGroup>[
        for (final (groupId, groupZh, groupEn, count) in groups)
          WallpaperGroup(
            id: groupId,
            name: groupZh,
            nameEn: groupEn,
            apiQuery: groupId,
            count: count,
            hidden: !categorized,
          ),
      ],
    );

    return WallpaperCatalog(
      sources: <WallpaperSource>[
        images(WallpaperSourceIds.official, '官方壁纸', 'Official', true, const <(String, String, String, int)>[
          ('nature', '自然', 'Nature', 240),
          ('acg', '动漫', 'Anime', 240),
          ('art', '艺术', 'Art', 155),
          ('architecture', '建筑', 'Architecture', 28),
          ('life', '生命', 'Life', 31),
          ('geometry', '纹理', 'Texture', 72),
          ('other', '其他', 'Other', 240),
        ]),
        WallpaperSource(
          id: WallpaperSourceIds.wallhaven,
          name: 'Wallhaven',
          nameEn: 'Wallhaven',
          kind: WallpaperKind.image,
          categorized: true,
          count: 4532,
          groups: const <WallpaperGroup>[
            WallpaperGroup(id: 'popular', name: '热门', nameEn: 'Popular', count: 233),
            WallpaperGroup(id: 'minimalism', name: '极简主义', nameEn: 'Minimalism', apiQuery: 'id:2278', count: 240),
            WallpaperGroup(id: 'patterns', name: '图案', nameEn: 'Patterns', apiQuery: 'id:869', count: 240),
            WallpaperGroup(id: 'landscape', name: '风景', nameEn: 'Landscape', apiQuery: 'id:711', count: 240),
            WallpaperGroup(id: 'nature', name: '自然', nameEn: 'Nature', apiQuery: 'id:37', count: 240),
            WallpaperGroup(id: 'cosplay', name: 'Cosplay', nameEn: 'Cosplay', apiQuery: 'id:12757', count: 240),
            WallpaperGroup(id: 'spiderman', name: '蜘蛛侠', nameEn: 'Spider-Man', apiQuery: 'id:2319', count: 240),
            WallpaperGroup(id: 'ghibli', name: '吉卜力', nameEn: 'Ghibli', apiQuery: 'id:1748', count: 240),
            WallpaperGroup(id: 'naruto', name: '火影忍者', nameEn: 'Naruto', apiQuery: 'id:78174', count: 219),
            WallpaperGroup(id: 'sci-fi', name: '科幻', nameEn: 'Sci-Fi', apiQuery: 'id:14', count: 240),
            WallpaperGroup(id: 'anime', name: '日漫', nameEn: 'Anime', apiQuery: 'id:1', count: 240),
            WallpaperGroup(id: 'anime-girls', name: '动漫女孩', nameEn: 'Anime Girls', apiQuery: 'id:5', count: 240),
            WallpaperGroup(id: 'cyberpunk', name: '赛博朋克', nameEn: 'Cyberpunk', apiQuery: 'id:376', count: 240),
            WallpaperGroup(id: 'pixel-art', name: '像素艺术', nameEn: 'Pixel Art', apiQuery: 'id:2321', count: 240),
            WallpaperGroup(id: 'artwork', name: 'Artwork', nameEn: 'Artwork', apiQuery: 'id:323', count: 240),
            WallpaperGroup(id: 'cityscape', name: 'Cityscape', nameEn: 'Cityscape', apiQuery: 'id:479', count: 240),
            WallpaperGroup(
              id: 'digital-art',
              name: 'Digital Art',
              nameEn: 'Digital Art',
              apiQuery: 'id:13',
              count: 240,
            ),
            WallpaperGroup(
              id: 'fantasy-art',
              name: 'Fantasy Art',
              nameEn: 'Fantasy Art',
              apiQuery: 'id:853',
              count: 240,
            ),
            WallpaperGroup(
              id: 'final-fantasy',
              name: 'Final Fantasy',
              nameEn: 'Final Fantasy',
              apiQuery: 'id:997',
              count: 240,
            ),
          ],
        ),
        _single(WallpaperSourceIds.bing, '必应壁纸', 'Bing', WallpaperKind.image, 2030),
        _single(WallpaperSourceIds.deepin, 'deepin', 'deepin', WallpaperKind.image, 26),
        _single(WallpaperSourceIds.video, '动态壁纸', 'Live Wallpapers', WallpaperKind.video, 125),
        _single(WallpaperSourceIds.solidColor, '纯色渐变', 'Colors', WallpaperKind.gradient, 151),
      ],
    );
  }
}
