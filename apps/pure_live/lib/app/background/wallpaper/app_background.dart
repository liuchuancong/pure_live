import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/background/library/background_presets.dart' show kDefaultGradientBegin, kDefaultGradientEnd;
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/wallpaper/background_video_source.dart';
import 'package:pure_live/features/room/room.dart';
import 'package:pure_live/shared/shared.dart';
import 'package:pure_uikit_background/pure_uikit_background.dart'
    show
        AppVisibleScope,
        BackgroundConfig,
        BackgroundOverlay,
        GradientBackground,
        ImageBackground,
        ProviderImageSource,
        PureBackground,
        SolidBackground,
        VideoBackground;

/// Tells the shell whether a wallpaper is under it, so the shell's own
/// fill can turn translucent (the theme's surface otherwise covers it).
final class BackgroundActiveScope extends InheritedWidget {
  /// Publishes [active] to the shell.
  const BackgroundActiveScope({required this.active, required super.child, super.key});

  /// Whether a background config is painting behind the shell.
  final bool active;

  /// The nearest answer; false outside the app root.
  static bool isActiveOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackgroundActiveScope>()?.active ?? false;

  @override
  bool updateShouldNotify(BackgroundActiveScope old) => active != old.active;
}

/// The app-wide wallpaper: paints the saved image or looping muted video
/// behind every route, with the theme's scrim for legibility.
///
/// A video pauses when the app is hidden and while a room has a player:
/// one decoder at a time, and the last frame stays as a poster.
final class AppBackground extends ConsumerWidget {
  /// Paints the saved background behind [child].
  const AppBackground({required this.child, super.key});

  /// The app (the router's navigator).
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(backgroundSettingsProvider);
    final config = _configOf(context, settings);
    final roomActive = ref.watch(roomProvider.select((state) => state.handle != null));
    final paused = !AppVisibleScope.isVisibleOf(context) || roomActive;
    return BackgroundActiveScope(
      active: config != null,
      child: PureBackground(config: config, paused: paused, child: child),
    );
  }

  BackgroundConfig? _configOf(BuildContext context, BackgroundSettings settings) {
    if (!settings.active) return null;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final light = theme.brightness == Brightness.light;
    final overlay = BackgroundOverlay(
      // A light palette needs a white wash over artwork; darkening it
      // would leave dark text unreadable.
      color: light ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      opacity: settings.maskOpacity,
    );
    final underlay = SolidBackground(color: colors.canvas);
    final letterbox = settings.fit == BoxFit.cover || settings.fit == BoxFit.fill ? null : 24.0;
    switch (settings.kind) {
      case BackgroundKind.none:
        return null;
      case BackgroundKind.solid:
        return SolidBackground(color: settings.solidColor, overlay: overlay);
      case BackgroundKind.gradient:
        return GradientBackground(
          colors: settings.gradientColors,
          begin: kDefaultGradientBegin,
          end: kDefaultGradientEnd,
          overlay: overlay,
        );
      case BackgroundKind.image:
        final path = settings.imagePath;
        final url = settings.imageUrl;
        final provider = path.isNotEmpty && File(path).existsSync()
            ? FileImage(File(path))
            : (url.isNotEmpty ? cachedImage(url) : null);
        if (provider == null) return null;
        return ImageBackground(
          source: ProviderImageSource(provider),
          fit: settings.fit,
          placeholderColor: colors.canvas,
          underlay: underlay,
          fallback: underlay,
          letterboxBlurSigma: letterbox,
          blurSigma: settings.blurSigma,
          overlay: overlay,
        );
      case BackgroundKind.video:
        final uri = _videoUri(settings);
        if (uri == null) return null;
        return VideoBackground(
          source: AppBackgroundVideoSource(uri),
          fit: settings.fit,
          underlay: underlay,
          fallback: underlay,
          blurSigma: settings.blurSigma,
          overlay: overlay,
        );
    }
  }

  /// A local file first (uploaded), then a network URL.
  static Uri? _videoUri(BackgroundSettings settings) {
    final path = settings.videoPath;
    if (path.isNotEmpty && File(path).existsSync()) return Uri.file(path);
    final url = settings.videoUrl;
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
    return uri;
  }
}
