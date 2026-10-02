import 'package:pure_live/core/index.dart';

/// Fill modes offered by the display row and cycled by the preview's fill
/// action. The order follows the settings page's own row, so cycling from the
/// preview walks the same list the user sees there.
const List<BoxFit> kWallpaperFitModes = <BoxFit>[
  BoxFit.cover,
  BoxFit.contain,
  BoxFit.fill,
  BoxFit.fitWidth,
  BoxFit.fitHeight,
  BoxFit.none,
  BoxFit.scaleDown,
];

/// Mask presets. The preview steps through fixed values instead of dragging the
/// settings slider, so one tap always lands on a readable wash.
const List<double> kWallpaperMaskSteps = <double>[
  0,
  0.05,
  0.1,
  0.15,
  0.2,
  0.25,
  0.3,
  0.35,
  0.4,
  0.45,
  0.5,
  0.55,
  0.6,
  0.65,
  0.7,
  0.75,
  0.8,
  0.85,
  0.9,
  0.95,
  1,
];

/// Blur presets (sigma). 0 is "off", so the cycle always has a way back.
const List<double> kWallpaperBlurSteps = <double>[0, 2, 4, 6, 8, 12, 16, 24, 32, 48];

/// Localised label of one blur preset.
String wallpaperBlurLabel(double sigma) => sigma <= 0 ? i18n('wallpaper_blur_off') : '${sigma.round()}';

/// Localised label of one fill mode.
String wallpaperFitLabel(BoxFit fit) => switch (fit) {
  BoxFit.fill => i18n('wallpaper_fit_fill'),
  BoxFit.contain => i18n('wallpaper_fit_contain'),
  BoxFit.cover => i18n('wallpaper_fit_cover'),
  BoxFit.fitWidth => i18n('wallpaper_fit_fit_width'),
  BoxFit.fitHeight => i18n('wallpaper_fit_fit_height'),
  BoxFit.none => i18n('wallpaper_fit_none'),
  BoxFit.scaleDown => i18n('wallpaper_fit_scale_down'),
};

/// Localised label of one mask preset.
String wallpaperMaskLabel(double step) => '${(step * 100).round()}%';

/// Index of the preset closest to [value], so a stored opacity that is not one
/// of the presets still highlights a sensible entry.
int wallpaperMaskIndex(double value) {
  var best = 0;
  var bestDelta = double.infinity;
  for (var i = 0; i < kWallpaperMaskSteps.length; i++) {
    final double delta = (kWallpaperMaskSteps[i] - value).abs();
    if (delta < bestDelta) {
      bestDelta = delta;
      best = i;
    }
  }
  return best;
}

/// Index of the blur preset closest to [value].
int wallpaperBlurIndex(double value) {
  var best = 0;
  var bestDelta = double.infinity;
  for (var i = 0; i < kWallpaperBlurSteps.length; i++) {
    final double delta = (kWallpaperBlurSteps[i] - value).abs();
    if (delta < bestDelta) {
      bestDelta = delta;
      best = i;
    }
  }
  return best;
}
