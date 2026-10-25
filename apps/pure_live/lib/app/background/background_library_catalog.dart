import 'package:pure_live/app/background/background_library_models.dart';
import 'package:pure_live/app/background/background_presets.dart' show kBackgroundDeepinWallpapers;

WallpaperCategory _category(WallpaperCategoryId id, String query) =>
    WallpaperCategory((b) => b
      ..id = id
      ..query = query);

WallpaperSource _source(WallpaperSourceId id, int pageSize, List<WallpaperCategory> categories) => WallpaperSource(
  (b) => b
    ..id = id
    ..pageSize = pageSize
    ..categories.replace(categories),
);

/// The compiled-in source tree. The words live in the translations; this
/// table only carries identities and API filters.
final List<WallpaperSource> wallpaperSources = List.unmodifiable([
  _source(WallpaperSourceId.official, 24, [
    _category(WallpaperCategoryId.officialNature, 'nature'),
    _category(WallpaperCategoryId.officialAnime, 'acg'),
    _category(WallpaperCategoryId.officialArt, 'art'),
    _category(WallpaperCategoryId.officialArchitecture, 'architecture'),
    _category(WallpaperCategoryId.officialLife, 'life'),
    _category(WallpaperCategoryId.officialTexture, 'geometry'),
    _category(WallpaperCategoryId.officialOther, 'other'),
  ]),
  _source(WallpaperSourceId.wallhaven, 24, [
    _category(WallpaperCategoryId.wallhavenPopular, ''),
    _category(WallpaperCategoryId.wallhavenMinimalism, 'id:2278'),
    _category(WallpaperCategoryId.wallhavenPatterns, 'id:869'),
    _category(WallpaperCategoryId.wallhavenLandscape, 'id:711'),
    _category(WallpaperCategoryId.wallhavenNature, 'id:37'),
    _category(WallpaperCategoryId.wallhavenCosplay, 'id:12757'),
    _category(WallpaperCategoryId.wallhavenSpiderMan, 'id:2319'),
    _category(WallpaperCategoryId.wallhavenGhibli, 'id:1748'),
    _category(WallpaperCategoryId.wallhavenNaruto, 'id:78174'),
    _category(WallpaperCategoryId.wallhavenSciFi, 'id:14'),
    _category(WallpaperCategoryId.wallhavenAnime, 'id:1'),
    _category(WallpaperCategoryId.wallhavenAnimeGirls, 'id:5'),
    _category(WallpaperCategoryId.wallhavenCyberpunk, 'id:376'),
    _category(WallpaperCategoryId.wallhavenPixelArt, 'id:2321'),
    _category(WallpaperCategoryId.wallhavenArtwork, 'id:323'),
    _category(WallpaperCategoryId.wallhavenCityscape, 'id:479'),
    _category(WallpaperCategoryId.wallhavenDigitalArt, 'id:13'),
    _category(WallpaperCategoryId.wallhavenFantasyArt, 'id:853'),
    _category(WallpaperCategoryId.wallhavenFinalFantasy, 'id:997'),
  ]),
  _source(WallpaperSourceId.bing, 16, const []),
  _source(WallpaperSourceId.deepin, kBackgroundDeepinWallpapers.length, const []),
  _source(WallpaperSourceId.video, 24, const []),
]);

/// The deepin set as library items: compiled in, no request.
List<WallpaperItem> deepinWallpaperItems() => List.unmodifiable([
  for (final (index, name) in kBackgroundDeepinWallpapers.indexed)
    WallpaperItem(
      (b) => b
        ..id = 'deepin-$index'
        ..name = name
        ..url = 'https://files.itab.link/wallpaper/deepin/$index.jpg'
        ..thumb = 'https://files.itab.link/wallpaper/deepin/$index.jpg'
        ..video = false,
    ),
]);
