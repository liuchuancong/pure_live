import 'package:built_collection/built_collection.dart';
import 'package:built_value/built_value.dart';

import 'package:pure_live/l10n/translations.dart';

part 'background_library_models.g.dart';

/// The built-in wallpaper sources, in the library's tab order.
enum WallpaperSourceId {
  /// The iTab official picture library.
  official,

  /// Wallhaven through the same API.
  wallhaven,

  /// Bing's daily pictures.
  bing,

  /// The compiled-in deepin/UOS set.
  deepin,

  /// The live/video wallpaper list.
  video,
}

/// Every category the library offers. The id is the stable key; its words
/// live in the app's translations, never in the source tables.
enum WallpaperCategoryId {
  officialNature,
  officialAnime,
  officialArt,
  officialArchitecture,
  officialLife,
  officialTexture,
  officialOther,
  wallhavenPopular,
  wallhavenMinimalism,
  wallhavenPatterns,
  wallhavenLandscape,
  wallhavenNature,
  wallhavenCosplay,
  wallhavenSpiderMan,
  wallhavenGhibli,
  wallhavenNaruto,
  wallhavenSciFi,
  wallhavenAnime,
  wallhavenAnimeGirls,
  wallhavenCyberpunk,
  wallhavenPixelArt,
  wallhavenArtwork,
  wallhavenCityscape,
  wallhavenDigitalArt,
  wallhavenFantasyArt,
  wallhavenFinalFantasy,
}

/// One source's category: the id whose words the UI resolves, and the
/// source's own filter value (`category=nature`, `q=id:2278`, or empty for
/// the unfiltered group).
abstract class WallpaperCategory implements Built<WallpaperCategory, WallpaperCategoryBuilder> {
  /// Builds from a builder [updates] callback.
  factory WallpaperCategory([void Function(WallpaperCategoryBuilder)? updates]) = _$WallpaperCategory;

  WallpaperCategory._();

  /// The stable category key.
  WallpaperCategoryId get id;

  /// The API's filter value; empty means "no filter".
  String get query;
}

/// One built-in source: what the tab says, how many rows a page holds, and
/// the categories it offers (empty for a single-list source).
abstract class WallpaperSource implements Built<WallpaperSource, WallpaperSourceBuilder> {
  /// Builds from a builder [updates] callback.
  factory WallpaperSource([void Function(WallpaperSourceBuilder)? updates]) = _$WallpaperSource;

  WallpaperSource._();

  /// The source's identity.
  WallpaperSourceId get id;

  /// The API page size; a local source answers everything in one go.
  int get pageSize;

  /// The categories, in display order; empty for a single-list source.
  BuiltList<WallpaperCategory> get categories;

  /// Whether the entries are compiled into the app (no network).
  bool get isLocal => id == WallpaperSourceId.deepin;

  /// Whether the source's entries are clips.
  bool get isVideo => id == WallpaperSourceId.video;
}

/// One picture or clip from a source.
abstract class WallpaperItem implements Built<WallpaperItem, WallpaperItemBuilder> {
  /// Builds from a builder [updates] callback.
  factory WallpaperItem([void Function(WallpaperItemBuilder)? updates]) = _$WallpaperItem;

  WallpaperItem._();

  /// The source's own id, or the URL when it sends none.
  String get id;

  /// The display name, often the artwork's title or the URL stem.
  String get name;

  /// The picture, or the clip's playable address.
  String get url;

  /// A grid-sized copy; equals [url] when the source sends no separate one.
  String get thumb;

  /// Whether [url] is a clip.
  bool get video;
}

/// The source tab's words.
extension WallpaperSourceText on WallpaperSource {
  /// The source's localized name.
  String label(Translations t) => switch (id) {
    WallpaperSourceId.official => t.settings.wallpaperSourceOfficial,
    WallpaperSourceId.wallhaven => t.settings.wallpaperSourceWallhaven,
    WallpaperSourceId.bing => t.settings.wallpaperSourceBing,
    WallpaperSourceId.deepin => t.settings.wallpaperSourceDeepin,
    WallpaperSourceId.video => t.settings.wallpaperSourceVideo,
  };
}

/// The category chip's words.
extension WallpaperCategoryText on WallpaperCategory {
  /// The category's localized name.
  String label(Translations t) => switch (id) {
    WallpaperCategoryId.officialNature => t.settings.wallpaperCategoryNature,
    WallpaperCategoryId.officialAnime => t.settings.wallpaperCategoryAnime,
    WallpaperCategoryId.officialArt => t.settings.wallpaperCategoryArt,
    WallpaperCategoryId.officialArchitecture => t.settings.wallpaperCategoryArchitecture,
    WallpaperCategoryId.officialLife => t.settings.wallpaperCategoryLife,
    WallpaperCategoryId.officialTexture => t.settings.wallpaperCategoryTexture,
    WallpaperCategoryId.officialOther => t.settings.wallpaperCategoryOther,
    WallpaperCategoryId.wallhavenPopular => t.settings.wallpaperCategoryPopular,
    WallpaperCategoryId.wallhavenMinimalism => t.settings.wallpaperCategoryMinimalism,
    WallpaperCategoryId.wallhavenPatterns => t.settings.wallpaperCategoryPatterns,
    WallpaperCategoryId.wallhavenLandscape => t.settings.wallpaperCategoryLandscape,
    WallpaperCategoryId.wallhavenNature => t.settings.wallpaperCategoryNature,
    WallpaperCategoryId.wallhavenCosplay => t.settings.wallpaperCategoryCosplay,
    WallpaperCategoryId.wallhavenSpiderMan => t.settings.wallpaperCategorySpiderMan,
    WallpaperCategoryId.wallhavenGhibli => t.settings.wallpaperCategoryGhibli,
    WallpaperCategoryId.wallhavenNaruto => t.settings.wallpaperCategoryNaruto,
    WallpaperCategoryId.wallhavenSciFi => t.settings.wallpaperCategorySciFi,
    WallpaperCategoryId.wallhavenAnime => t.settings.wallpaperCategoryAnimeWallhaven,
    WallpaperCategoryId.wallhavenAnimeGirls => t.settings.wallpaperCategoryAnimeGirls,
    WallpaperCategoryId.wallhavenCyberpunk => t.settings.wallpaperCategoryCyberpunk,
    WallpaperCategoryId.wallhavenPixelArt => t.settings.wallpaperCategoryPixelArt,
    WallpaperCategoryId.wallhavenArtwork => t.settings.wallpaperCategoryArtwork,
    WallpaperCategoryId.wallhavenCityscape => t.settings.wallpaperCategoryCityscape,
    WallpaperCategoryId.wallhavenDigitalArt => t.settings.wallpaperCategoryDigitalArt,
    WallpaperCategoryId.wallhavenFantasyArt => t.settings.wallpaperCategoryFantasyArt,
    WallpaperCategoryId.wallhavenFinalFantasy => t.settings.wallpaperCategoryFinalFantasy,
  };
}
