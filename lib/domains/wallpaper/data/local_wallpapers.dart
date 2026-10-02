/// Wallpaper sets that ship with the app and never leave the device.
///
/// * Solid colours and gradients come from the compiled-in palette table
///   ([kWallpaperSolidPalette], [kWallpaperGradients]).
/// * The deepin set is 26 files under the public iTab CDN - the URLs are
///   derived, so there is no index to download either.
library;

import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_presets.dart';

/// Public CDN holding the deepin wallpaper set.
const String kItabFilesBase = 'https://files.itab.link';

/// Server-side resize preset used for grid thumbnails.
const String kThumbProcess = 'x-oss-process=image/resize,limit_0,m_fill,w_400,h_225/quality,q_72/format,webp';

/// The 26 deepin/UOS wallpapers, named by hand from the artwork.
const Map<int, String> kDeepinNames = <int, String>{
  0: 'Purple Salt Flats Sunset',
  1: 'Antelope Canyon Waves',
  2: 'Autumn Forest Canopy',
  3: 'Sunset Mountain Ridge',
  4: 'Deepin Logo Gradient',
  5: 'Deepin Logo Ribbons',
  6: 'Neon Vortex Glow',
  7: 'Aurora Borealis Night',
  8: 'Sandstone Canyon Passage',
  9: 'Starry Desert Dunes',
  10: 'Desert Dunes at Dawn',
  11: 'White Facade Blue Sky',
  12: 'Blue Betta Fish',
  13: 'Vestrahorn Beach Reflection',
  14: 'Snowy Ridges at Dusk',
  15: 'Emerald Coast Aerial',
  16: 'Peak Above the Clouds',
  17: 'Dune Ripples at Sunset',
  18: 'Crescent Dune Moonlight',
  19: 'Misty Lake at Dawn',
  20: 'Foggy Pine Forest',
  21: 'Frozen Lake Sunrise',
  22: 'Snow Peak at Sunset',
  23: 'Jellyfish in Blue Water',
  24: 'Eagle Over the Falls',
  25: 'Mountain Lake Reflection',
};

/// `https://…/x.jpg` → the same URL with the CDN resize applied. A URL that
/// already carries a processed copy is left alone.
String cdnThumb(String url) {
  if (url.isEmpty || url.contains('x-oss-process')) return url;
  final separator = url.contains('?') ? '&' : '?';
  return '$url$separator$kThumbProcess';
}

/// Entries of the compiled-in sources.
class LocalWallpapers {
  const LocalWallpapers._();

  /// Flat swatches first, then the gradient ramp.
  static final List<WallpaperItem> solidItems = <WallpaperItem>[
    for (var i = 0; i < kWallpaperSolidPalette.length; i++)
      WallpaperItem(
        id: 'flat-$i',
        name: kWallpaperSolidPalette[i],
        file: 'solid-color#flat-$i',
        css: 'solid ${kWallpaperSolidPalette[i]}',
        gradient: <WallpaperGradientStop>[
          WallpaperGradientStop(color: kWallpaperSolidPalette[i], pos: 0),
          WallpaperGradientStop(color: kWallpaperSolidPalette[i], pos: 100),
        ],
      ),
    for (var i = 0; i < kWallpaperGradients.length; i++)
      WallpaperItem(
        id: 'gradient-$i',
        name: kWallpaperGradients[i].name,
        file: 'solid-color#gradient-$i',
        css: kWallpaperGradients[i].stops.map((stop) => '${stop.$1} ${stop.$2.round()}%').join(', '),
        deg: kWallpaperGradients[i].deg,
        gradient: <WallpaperGradientStop>[
          for (final (color, pos) in kWallpaperGradients[i].stops) WallpaperGradientStop(color: color, pos: pos),
        ],
      ),
  ];

  /// The deepin/UOS set.
  static final List<WallpaperItem> deepinItems = <WallpaperItem>[
    for (final entry in kDeepinNames.entries)
      WallpaperItem(
        id: '${entry.key}',
        name: entry.value,
        file: '$kItabFilesBase/wallpaper/deepin/${entry.key}.jpg',
        thumb: cdnThumb('$kItabFilesBase/wallpaper/deepin/${entry.key}.jpg'),
      ),
  ];

  /// The list belonging to one local source id, or empty for a server source.
  static List<WallpaperItem> of(String sourceId) => switch (sourceId) {
    WallpaperSourceIds.solidColor => solidItems,
    WallpaperSourceIds.deepin => deepinItems,
    _ => const <WallpaperItem>[],
  };
}
