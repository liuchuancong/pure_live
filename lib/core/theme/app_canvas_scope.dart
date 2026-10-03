import 'package:flutter/widgets.dart';

/// Opacity of surfaces and chrome while a background picture owns the canvas.
///
/// Low enough that the picture reads through cards, tab strips and bars, high
/// enough that text on them keeps its contrast. One value, used by the wallpaper
/// theme (cards, tab bars, rails, menus), the desktop title bar and the desktop
/// navigation rail.
const double kWallpaperSurfaceOpacity = 0.55;

/// Marks a subtree whose pages must not paint their own canvas.
///
/// The background layer paints the app wallpaper behind the Navigator. Pages
/// that own a deliberately different backdrop - the live room is black, with or
/// without a theme - have to know when that wallpaper is showing, and a live
/// playback page may not import the wallpaper domain. The decision is published
/// here instead: the wallpaper layer sets [ownedByBackground], and any page can
/// ask without knowing where the picture comes from.
///
/// Absent, or `false`, means the page paints its own backdrop as before.
class AppCanvasScope extends InheritedWidget {
  const AppCanvasScope({super.key, required this.ownedByBackground, required super.child});

  /// Whether a background layer is painting the canvas behind this subtree.
  final bool ownedByBackground;

  static bool ownedByBackgroundOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppCanvasScope>()?.ownedByBackground ?? false;

  @override
  bool updateShouldNotify(AppCanvasScope oldWidget) => oldWidget.ownedByBackground != ownedByBackground;
}
