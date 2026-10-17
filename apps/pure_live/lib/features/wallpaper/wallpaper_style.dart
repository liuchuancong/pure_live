import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/painting.dart' show BoxFit, FileImage, ImageProvider;
import 'package:flutter/widgets.dart' show Alignment, Color;
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart' show
    BackgroundConfig, BackgroundOverlay, GradientBackground, ImageBackground,
    ProviderImageSource, SolidBackground;

/// The translation from the persisted wallpaper choices to
/// `pure_uikit_background`'s [BackgroundConfig] — the shape the app's
/// background layer paints.
///
/// Preferences store primitives only, so this file is the one place that
/// knows both shapes; a stored document never holds the package's type.
/// A choice that cannot be honoured (no colours, a picture whose file has
/// disappeared) resolves to null — the caller keeps its themed surface,
/// exactly the reference's "no wallpaper" behaviour.

/// The largest blur the picker offers; the reference stopped where weaker
/// devices begin dropping frames and this build keeps the same ceiling.
const double kWallpaperMaxBlurSigma = 20;

/// Builds the app background layer's configuration from [appearance], or
/// null when nothing should be painted.
///
/// A picture path that no longer exists degrades to null rather than to a
/// black surface, mirroring the reference's `imageProvider` guard.
BackgroundConfig? wallpaperConfigOf(AppearancePreferences appearance) {
  final overlay = _imageOverlay(appearance);
  return switch (appearance.wallpaperKind) {
    WallpaperKind.none => null,
    WallpaperKind.solid => _solid(appearance.wallpaperColor, overlay),
    WallpaperKind.gradient => _gradient(appearance, overlay),
    WallpaperKind.image => _image(appearance, overlay),
  };
}

/// Builds the token form of the same choice, for the consumers that style a
/// background layer's config.
BackgroundConfig? _solid(int? argb, BackgroundOverlay? overlay) =>
    argb == null ? null : SolidBackground(color: Color(argb), overlay: overlay);

BackgroundConfig? _gradient(AppearancePreferences appearance, BackgroundOverlay? overlay) {
  final colors = [for (final argb in appearance.wallpaperGradientColors) Color(argb)];
  if (colors.length < 2) {
    return null;
  }
  final stops = appearance.wallpaperGradientStops;
  final (begin, end) = gradientAlignment(appearance.wallpaperGradientAngle);
  return GradientBackground(
    colors: colors,
    stops: stops.length == colors.length ? stops : null,
    begin: begin,
    end: end,
    overlay: overlay,
  );
}

BackgroundConfig? _image(AppearancePreferences appearance, BackgroundOverlay? overlay) {
  final provider = _imageProvider(appearance.wallpaperImagePath);
  if (provider == null) {
    return null;
  }
  return ImageBackground(
    source: ProviderImageSource(provider),
    fit: _boxFit(appearance.wallpaperFit),
    blurSigma: appearance.wallpaperBlur.clamp(0, kWallpaperMaxBlurSigma).toDouble(),
    overlay: overlay,
  );
}

/// The picture's scrim, over black, at the chosen strength; zero strength
/// paints none.
BackgroundOverlay? _imageOverlay(AppearancePreferences appearance) {
  if (appearance.wallpaperKind != WallpaperKind.image) {
    return null;
  }
  final strength = appearance.wallpaperScrim.clamp(0.0, 1.0);
  return strength <= 0 ? null : BackgroundOverlay(color: Colors.black, opacity: strength);
}

ImageProvider? _imageProvider(String path) {
  if (path.isEmpty || !File(path).existsSync()) {
    return null;
  }
  return FileImage(File(path));
}

/// The `BoxFit` a stored name names; anything else is cover.
BoxFit _boxFit(String name) => switch (name) {
  'contain' => BoxFit.contain,
  'fill' => BoxFit.fill,
  _ => BoxFit.cover,
};

/// Converts a CSS gradient angle (0 points up, clockwise positive) into the
/// alignment pair a Flutter linear gradient runs between.
(Alignment, Alignment) gradientAlignment(int cssDegrees) {
  final radians = cssDegrees * math.pi / 180;
  // The gradient line points along (sin, -cos); the runs go begin -> end.
  final x = math.sin(radians);
  final y = -math.cos(radians);
  return (Alignment(-x, -y), Alignment(x, y));
}
