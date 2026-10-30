import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/background/library/background_presets.dart' show gradientAlignments;
import 'package:pure_live/app/background/settings/background_settings.dart';
import 'package:pure_live/app/background/tone/analysis/background_scrim.dart' show backgroundScrimWashFor;
import 'package:pure_live/app/background/tone/background_tone.dart'
    show backgroundScrimOpacityFor, backgroundToneProvider;
import 'package:pure_live/app/background/wallpaper/background_video_source.dart';
import 'package:pure_live/modules/live/room/room.dart';
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
    // The wash follows the palette the app is actually wearing: with following
    // on that is the wallpaper's recommendation, with it off the viewer's own
    // theme — either way its own auto plan, not the other palette's.
    final tone = ref.watch(backgroundToneProvider);
    final scrim = backgroundScrimOpacityFor(
      settings: settings,
      plans: tone?.plans,
      dark: DsTheme.of(context).brightness == Brightness.dark,
    );
    final config = _configOf(context, settings, scrim);
    final roomActive = ref.watch(roomProvider.select((state) => state.handle != null));
    // A preview page decodes its own clip; the wallpaper stands down
    // while one is up so the shell never runs two players.
    final previewing = ref.watch(backgroundPreviewOpenProvider);
    final paused = !AppVisibleScope.isVisibleOf(context) || roomActive || previewing;
    return BackgroundActiveScope(
      active: config != null,
      child: PureBackground(config: config, paused: paused, child: child),
    );
  }

  BackgroundConfig? _configOf(BuildContext context, BackgroundSettings settings, double scrim) {
    if (!settings.active) return null;
    final colors = DsTheme.colorsOf(context);
    final overlay = appBackgroundOverlay(context, opacity: scrim, blurSigma: settings.backgroundBlurSigma);
    final underlay = SolidBackground(color: colors.canvas);
    final letterbox = settings.fit == BoxFit.cover || settings.fit == BoxFit.fill ? null : 24.0;
    switch (settings.kind) {
      case BackgroundKind.none:
        return null;
      case BackgroundKind.solid:
        return SolidBackground(color: settings.solidColor, overlay: overlay);
      case BackgroundKind.gradient:
        final (begin, end) = gradientAlignments(settings.gradientDeg);
        return GradientBackground(
          colors: settings.gradientColors,
          stops: settings.gradientStops,
          begin: begin,
          end: end,
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
          overlay: overlay,
        );
      case BackgroundKind.video:
        final uri = _videoUri(settings);
        if (uri == null) return null;
        // The background blur goes on the decoded surface, not on the
        // backdrop: a video is a `Texture`, which a backdrop filter has
        // nothing to sample, so the scrim would stay a flat wash over a
        // sharp clip. The source carries the sigma itself: the package's
        // blur sits above the decoder, so toggling it there would restart
        // the clip.
        return VideoBackground(
          source: AppBackgroundVideoSource(uri, blurSigma: settings.backgroundBlurSigma),
          fit: settings.fit,
          underlay: underlay,
          fallback: underlay,
          overlay: appBackgroundOverlay(context, opacity: scrim, blurSigma: 0),
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

/// The wash colour the palette in force paints: white on a light palette
/// (darkening artwork there would leave dark text unreadable), black on the
/// dark one.
Color appBackgroundScrimColor(BuildContext context) =>
    backgroundScrimWashFor(dark: DsTheme.of(context).brightness == Brightness.dark);

/// The scrim the app paints over a background, at [opacity], with the
/// wallpaper behind it blurred by [blurSigma].
///
/// The preview page builds the same wash through [AppBackgroundScrim], so
/// what it shows is what the app would wear.
BackgroundOverlay appBackgroundOverlay(BuildContext context, {required double opacity, required double blurSigma}) =>
    BackgroundOverlay(color: appBackgroundScrimColor(context), opacity: opacity, blurSigma: blurSigma);

/// The scrim as a widget, for surfaces that stand in for the app's backdrop:
/// the preview stage paints exactly this, over exactly the same wash colour.
final class AppBackgroundScrim extends StatelessWidget {
  /// A wash at [opacity], optionally frosting the picture under it by
  /// [blurSigma].
  const AppBackgroundScrim({required this.opacity, this.blurSigma = 0, super.key});

  /// The wash opacity, `[0, 1]`.
  final double opacity;

  /// Gaussian sigma for the backdrop filter; `0` keeps the flat wash.
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final wash = ColoredBox(color: appBackgroundScrimColor(context).withValues(alpha: opacity.clamp(0.0, 1.0)));
    if (blurSigma <= 0) return wash;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: wash,
    );
  }
}

/// Whether a wallpaper preview page is on screen.
final class BackgroundPreviewOpenController extends Notifier<bool> {
  @override
  bool build() => false;

  /// The preview page opened.
  void open() => state = true;

  /// The preview page closed.
  void close() => state = false;
}

/// See [BackgroundPreviewOpenController].
final backgroundPreviewOpenProvider = NotifierProvider<BackgroundPreviewOpenController, bool>(
  BackgroundPreviewOpenController.new,
);
