import 'dart:ui' as ui;

import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/consts/background_source.dart';
import 'package:pure_live/core/models/background_config.dart';
import 'package:pure_live/domains/wallpaper/domain/background_controller.dart';

/// Paints the configured background behind the whole app.
///
/// Mounted once, in the root `MaterialApp.builder`, so every page shares it.
/// With no wallpaper selected the layer paints nothing and the themed scaffold
/// colours show, which is why the pages only go transparent while
/// [BackgroundConfig.hasBackground] is true (see [WallpaperCanvasTransparency]).
class AppBackgroundLayer extends StatelessWidget {
  const AppBackgroundLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = BackgroundController.to;
    return Obx(() {
      final config = controller.config.v;
      final bool hasBackground = config.hasBackground;
      // The tree keeps its shape whether or not a wallpaper is set: the layer
      // used to return `child` on its own and a Stack around it otherwise, so
      // applying or clearing a background swapped the widget type above the
      // Navigator and deactivated that whole subtree (title bar included) for a
      // frame. An empty placeholder keeps `child` at the same position, and the
      // empty frame paints nothing - which is what returning `child` was for.
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (hasBackground) _BackgroundSurface(config: config, controller: controller) else const SizedBox.shrink(),
          // The mask exists to keep page text readable over a photo or video.
          if (hasBackground) ColoredBox(color: _maskColor(config, Theme.of(context))) else const SizedBox.shrink(),
          child,
        ],
      );
    });
  }

  /// A light palette needs a light wash over artwork: darkening it would leave
  /// the dark text unreadable.
  ///
  /// Read from the brightness rather than from `scaffoldBackgroundColor`: pages
  /// below [WallpaperCanvasTransparency] see a transparent scaffold colour, and
  /// the mask must not flip to black just because a picture owns the canvas.
  static Color _maskColor(BackgroundConfig config, ThemeData theme) {
    final bool lightSurface = theme.brightness == Brightness.light;
    return (lightSurface ? Colors.white : Colors.black).withValues(alpha: config.maskOpacity);
  }
}

/// Stops the pages from painting their own canvas while a wallpaper is set.
///
/// The transparency has to be applied in the tree rather than through the app
/// theme: GetX reads the `GetMaterialApp(theme:)` argument only once - its
/// `GetRootState.didUpdateWidget` is commented out - so `theme:` / `darkTheme:`
/// edits made after startup never reach a page, and the wallpaper used to be
/// visible only on screens that hard-coded a transparent background.
///
/// This sits directly above the Navigator and below the desktop title bar, so
/// every route, dialog and menu inherits it. It keeps one widget shape in both
/// states, so toggling a wallpaper never remounts the Navigator.
class WallpaperCanvasTransparency extends StatelessWidget {
  const WallpaperCanvasTransparency({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = BackgroundController.to;
    return Obx(() => WallpaperCanvasTheme(ownsCanvas: controller.occupiesCanvas.value, child: child));
  }
}

/// The pure half of [WallpaperCanvasTransparency]: a [Theme] with a transparent
/// scaffold colour while a wallpaper owns the canvas.
///
/// Split out so the decision can be tested without a storage-backed controller.
class WallpaperCanvasTheme extends StatelessWidget {
  const WallpaperCanvasTheme({super.key, required this.ownsCanvas, required this.child});

  final bool ownsCanvas;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Theme(
      data: ownsCanvas ? theme.copyWith(scaffoldBackgroundColor: Colors.transparent) : theme,
      child: child,
    );
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
