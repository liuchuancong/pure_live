import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/wallpaper/wallpaper_style.dart';
import 'package:pure_uikit/pure_uikit.dart' show PureCanvasScope;
import 'package:pure_uikit_background/pure_uikit_background.dart' as bg;

/// The wallpaper the app-wide layer paints, resolved from the persisted
/// appearance; null paints nothing and the themed surfaces show.
final wallpaperBackgroundConfigProvider = Provider<bg.BackgroundConfig?>(
  (ref) => wallpaperConfigOf(ref.watch(appearancePreferencesProvider)),
);

/// Tells the subtree whether a wallpaper currently owns the backdrop, so a
/// page can drop its own opaque surface and let the layer show through
/// (the wallpaper page previews this way, as the reference's did).
final class WallpaperScope extends InheritedWidget {
  /// A scope reporting [hasWallpaper].
  const new({required this.hasWallpaper, required super.child, super.key});

  /// Whether the app-wide layer is painting a wallpaper.
  final bool hasWallpaper;

  /// The nearest scope, or null when the layer is not mounted above.
  static WallpaperScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<WallpaperScope>();

  @override
  bool updateShouldNotify(WallpaperScope oldWidget) => oldWidget.hasWallpaper != hasWallpaper;
}

/// Paints the chosen wallpaper behind the whole app.
///
/// Mounted once, in the root widget's `builder`, so every route shares the
/// layer — the reference's `AppBackgroundLayer`, over this app's
/// composition: the config comes from the appearance preferences through
/// [wallpaperBackgroundConfigProvider], and the painting itself is
/// `pure_uikit_background`'s [bg.PureBackground] dispatcher, which carries
/// the scrim overlay, the blur and the image fallbacks.
///
/// With no wallpaper set the layer paints nothing; pages keep their themed
/// surfaces. A page that wants the picture behind it passes its scaffold a
/// transparent background while [WallpaperScope.hasWallpaper] holds.
final class WallpaperBackgroundLayer extends ConsumerWidget {
  /// The app-wide wallpaper layer around [child].
  const new({required this.child, super.key});

  /// The app above the layer.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(wallpaperBackgroundConfigProvider);
    // The tree keeps its shape whether or not a wallpaper is set — the
    // dispatcher renders an empty placeholder for a null config, so applying
    // or clearing one never remounts the app above it.
    return PureCanvasScope(
      transparent: config != null,
      child: WallpaperScope(
        hasWallpaper: config != null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(child: bg.PureBackground(config: config)),
            child,
          ],
        ),
      ),
    );
  }
}
