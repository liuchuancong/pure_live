import 'package:flutter/painting.dart' show Alignment, Color;

/// One gradient the background pane offers as a swatch. The stops are the
/// TV wallpaper set's own colours, cut to a readable subset; there is no
/// server and no random source.
typedef BackgroundGradientPreset = ({List<Color> colors, Alignment begin, Alignment end});

/// A compact set of flat backgrounds, dark first so the app's text keeps
/// its contrast on any of them.
const List<Color> kBackgroundSolidPresets = [
  Color(0xFF141E30),
  Color(0xFF0B1B2B),
  Color(0xFF243949),
  Color(0xFF2B5876),
  Color(0xFF353B48),
  Color(0xFF1E3C72),
  Color(0xFF3D1635),
  Color(0xFF434343),
  Color(0xFF0BA360),
  Color(0xFFC71D6F),
  Color(0xFF667EEA),
  Color(0xFFF5F7FA),
];

/// Gradients from the TV wallpaper set (Night Fade, Malibu Beach, Plum
/// Plate, Midnight Bloom and friends), in the order the TV gallery shows
/// them.
const List<BackgroundGradientPreset> kBackgroundGradientPresets = [
  (colors: [Color(0xFFA18CD1), Color(0xFFFBC2EB)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF43E97B), Color(0xFF38F9D7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF667EEA), Color(0xFF764BA2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF6A11CB), Color(0xFF2575FC)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF2B5876), Color(0xFF4E4376)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF13547A), Color(0xFF80D0C7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF0250C5), Color(0xFFD43F8D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF7085B6), Color(0xFF87A7D9), Color(0xFFDEF3F8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF2CD8D5), Color(0xFF6B8DD6), Color(0xFF8E37D7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF3D3393), Color(0xFF2B76B9), Color(0xFF2CACD1), Color(0xFF35EB93)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFFFDFBFB), Color(0xFFEBEDEE)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF434343), Color(0xFF000000)], begin: Alignment.topLeft, end: Alignment.bottomRight),
  (colors: [Color(0xFF0FD850), Color(0xFFF9F047)], begin: Alignment.topLeft, end: Alignment.bottomRight),
];

/// The default gradient when the viewer first picks the gradient kind.
List<Color> get kDefaultBackgroundGradient => kBackgroundGradientPresets.first.colors;
Alignment get kDefaultGradientBegin => kBackgroundGradientPresets.first.begin;
Alignment get kDefaultGradientEnd => kBackgroundGradientPresets.first.end;

/// A few pictures from the TV wallpaper set's public deepin/UOS collection
/// (`files.itab.link`). They are ordinary image URLs, so they reuse the
/// image path's download, cache and failure handling; the gallery is a
/// shelf of starting points, not a second media pipeline.
const List<String> kBackgroundGalleryUrls = [
  'https://files.itab.link/wallpaper/deepin/0.jpg',
  'https://files.itab.link/wallpaper/deepin/3.jpg',
  'https://files.itab.link/wallpaper/deepin/7.jpg',
  'https://files.itab.link/wallpaper/deepin/13.jpg',
  'https://files.itab.link/wallpaper/deepin/19.jpg',
  'https://files.itab.link/wallpaper/deepin/24.jpg',
];

/// The full deepin/UOS set (26 files), named as the TV wallpaper library
/// names them. The index is the file number on the public CDN.
const List<String> kBackgroundDeepinWallpapers = [
  'Purple Salt Flats Sunset',
  'Antelope Canyon Waves',
  'Autumn Forest Canopy',
  'Sunset Mountain Ridge',
  'Deepin Logo Gradient',
  'Deepin Logo Ribbons',
  'Neon Vortex Glow',
  'Aurora Borealis Night',
  'Sandstone Canyon Passage',
  'Starry Desert Dunes',
  'Desert Dunes at Dawn',
  'White Facade Blue Sky',
  'Blue Betta Fish',
  'Vestrahorn Beach Reflection',
  'Snowy Ridges at Dusk',
  'Emerald Coast Aerial',
  'Peak Above the Clouds',
  'Dune Ripples at Sunset',
  'Crescent Dune Moonlight',
  'Misty Lake at Dawn',
  'Foggy Pine Forest',
  'Frozen Lake Sunrise',
  'Snow Peak at Sunset',
  'Jellyfish in Blue Water',
  'Eagle Over the Falls',
  'Mountain Lake Reflection',
];
