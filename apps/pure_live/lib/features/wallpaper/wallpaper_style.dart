/// The translation from the persisted wallpaper choices to the two systems
/// that paint: `pure_uikit_background`'s [BackgroundConfig] (the app's
/// background layer) and `pure_uikit`'s [PureBackgroundStyle] (the design
/// tokens).
///
/// Preferences store primitives only, so this file is the one place that
/// knows both shapes; a stored document never holds either package's type.
/// A choice that cannot be honoured (no colours, a picture whose file has
/// disappeared) resolves to null — the caller keeps its themed surface,
/// exactly the reference's "no wallpaper" behaviour.
library;

import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/material.dart' show Colors;
import 'package:flutter/painting.dart' show BoxFit, FileImage, ImageProvider;
import 'package:flutter/widgets.dart' show Alignment, Color;
import 'package:pure_live/app/theme/appearance_preferences/appearance_preferences.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureBackgroundStyle;
import 'package:pure_uikit_background/pure_uikit_background.dart'
    show
        BackgroundConfig,
        BackgroundOverlay,
        GradientBackground,
        ImageBackground,
        ProviderImageSource,
        SolidBackground;

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
/// surface with `pure_uikit`'s [PureBackgroundStyle] instead of the
/// background layer's config.
PureBackgroundStyle? wallpaperStyleOf(AppearancePreferences appearance) {
  final scrim = _imageOverlay(appearance);
  return switch (appearance.wallpaperKind) {
    WallpaperKind.none => null,
    WallpaperKind.solid => appearance.wallpaperColor == null
        ? null
        : PureBackgroundStyle.solid(color: Color(appearance.wallpaperColor!)),
    WallpaperKind.gradient => _tokenGradient(appearance),
    WallpaperKind.image => switch (_imageProvider(appearance.wallpaperImagePath)) {
      null => null,
      final provider => PureBackgroundStyle.image(
        image: provider,
        fit: _boxFit(appearance.wallpaperFit),
        scrim: scrim?.color,
        scrimStrength: scrim?.opacity ?? 0,
        blurSigma: appearance.wallpaperBlur.clamp(0, kWallpaperMaxBlurSigma).toDouble(),
      ),
    },
  };
}

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

PureBackgroundStyle? _tokenGradient(AppearancePreferences appearance) {
  final colors = [for (final argb in appearance.wallpaperGradientColors) Color(argb)];
  if (colors.length < 2) {
    return null;
  }
  final stops = appearance.wallpaperGradientStops;
  final (begin, end) = gradientAlignment(appearance.wallpaperGradientAngle);
  return PureBackgroundStyle.gradient(
    colors: colors,
    stops: stops.length == colors.length ? stops : const <double>[],
    begin: begin,
    end: end,
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
