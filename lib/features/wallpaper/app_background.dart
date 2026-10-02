import 'dart:ui' as ui;

import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/consts/background_source.dart';
import 'package:pure_live/core/models/background_config.dart';
import 'package:pure_live/services/background/background_controller.dart';

/// Paints the configured background behind the whole app.
///
/// Mounted once, in the root `MaterialApp.builder`, so every page shares it.
/// With no wallpaper selected the layer paints nothing and the themed scaffold
/// colours show, which is why the theme only goes transparent while
/// [BackgroundConfig.hasBackground] is true (see `main.dart`).
class AppBackgroundLayer extends StatelessWidget {
  const AppBackgroundLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = SettingsService.to.bg;
    return Obx(() {
      final config = controller.config.v;
      if (!config.hasBackground) return child;

      return Stack(
        fit: StackFit.expand,
        children: [
          _BackgroundSurface(config: config, controller: controller),
          // The mask exists to keep page text readable over a photo or video.
          ColoredBox(color: _maskColor(config, Theme.of(context))),
          child,
        ],
      );
    });
  }

  /// A light palette needs a light wash over artwork: darkening it would leave
  /// the dark text unreadable.
  static Color _maskColor(BackgroundConfig config, ThemeData theme) {
    final bool lightSurface = theme.scaffoldBackgroundColor.computeLuminance() > 0.5;
    return (lightSurface ? Colors.white : Colors.black).withValues(alpha: config.maskOpacity);
  }
}

/// Applies a Gaussian blur to media backgrounds (picture or video frame).
///
/// Solid colours and gradients are excluded: blurring a flat surface changes no
/// pixel and still costs an offscreen pass. A [sigma] of 0 returns the child
/// unchanged, saving a `saveLayer`. The blur is a per-frame GPU composite that
/// scales with sigma, which is why [BackgroundConfig.maxBlurSigma] stops where
/// weaker devices begin dropping frames.
Widget wallpaperBlurred(Widget child, double sigma) {
  if (sigma <= 0) return child;
  return ImageFiltered(
    imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: ui.TileMode.decal),
    child: child,
  );
}

class _BackgroundSurface extends StatelessWidget {
  const _BackgroundSurface({required this.config, required this.controller});

  final BackgroundConfig config;
  final BackgroundController controller;

  @override
  Widget build(BuildContext context) {
    return switch (config.source) {
      BackgroundSource.color => ColoredBox(color: config.solidColor),
      BackgroundSource.gradient => _GradientFill(colors: config.gradientColors),
      BackgroundSource.image || BackgroundSource.networkImage => wallpaperBlurred(
        _ImageFill(config: config, controller: controller),
        config.blurSigma,
      ),
      BackgroundSource.video || BackgroundSource.networkVideo => wallpaperBlurred(
        // Not const on purpose: a const instance is identical across builds, so
        // Element.updateChild skips the rebuild and poster/player changes never
        // reach the screen.
        _VideoFill(controller: controller, config: config),
        config.blurSigma,
      ),
      BackgroundSource.none => const SizedBox.shrink(),
    };
  }
}

class _GradientFill extends StatelessWidget {
  const _GradientFill({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
    );
  }
}

class _ImageFill extends StatelessWidget {
  const _ImageFill({required this.config, required this.controller});

  final BackgroundConfig config;
  final BackgroundController controller;

  @override
  Widget build(BuildContext context) {
    final image = controller.imageProvider;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Always the bottom layer: it also covers the decode window of a fresh
        // picture, so a cold start shows the palette instead of a black frame,
        // and a picture whose file has since been deleted keeps a real surface.
        _GradientFill(colors: config.gradientColors),
        // A fit that letterboxes a differently-shaped picture would otherwise
        // show flat colour bars beside it. A blurred, cover-filled copy of the
        // same picture fills those bars instead; cover/fill never letterbox, so
        // they skip the extra layer.
        if (image != null && _fitCanLetterbox(config.boxFit))
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32, tileMode: ui.TileMode.clamp),
            child: DecoratedBox(
              decoration: BoxDecoration(
                image: DecorationImage(image: image, fit: BoxFit.cover),
              ),
            ),
          ),
        if (image != null)
          DecoratedBox(
            decoration: BoxDecoration(
              image: DecorationImage(image: image, fit: config.boxFit),
            ),
          ),
      ],
    );
  }

  static bool _fitCanLetterbox(BoxFit fit) =>
      fit == BoxFit.contain ||
      fit == BoxFit.fitWidth ||
      fit == BoxFit.fitHeight ||
      fit == BoxFit.none ||
      fit == BoxFit.scaleDown;
}

class _VideoFill extends StatelessWidget {
  const _VideoFill({required this.controller, required this.config});

  final BackgroundController controller;
  final BackgroundConfig config;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // While live playback is running the wallpaper decoder is released and
      // this paints the frame captured before playback - see
      // [BackgroundController.setPlaybackActive].
      final poster = controller.posterFrame.value;
      if (poster != null) {
        return Image.memory(poster, fit: BoxFit.cover, gaplessPlayback: true);
      }

      final player = controller.videoController.value;
      // The player is lazy: right after a video wallpaper is applied the
      // controller may not exist yet. The gradient keeps the surface themed
      // rather than black while it spins up.
      if (player == null) return _GradientFill(colors: config.gradientColors);

      return Video(
        controller: player,
        fit: BoxFit.cover,
        // The wallpaper layer is pixels, not a player: media_kit's adaptive
        // controls would paint a scrub bar over every page, and a background
        // must not hold a wakelock of its own.
        controls: (state) => const SizedBox.shrink(),
        wakelock: false,
      );
    });
  }
}
