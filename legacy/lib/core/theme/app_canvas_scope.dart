import 'package:flutter/widgets.dart';

/// Opacity of the page chrome while a background picture owns the canvas.
///
/// Low enough that the picture reads through app bars, rails and bars, high
/// enough that their icons and labels keep their contrast.
const double kWallpaperSurfaceOpacity = 0.55;

/// Opacity of card surfaces while a background picture owns the canvas.
///
/// Cards hold the text a user actually reads, so they stay much more solid than
/// the chrome: the picture is a backdrop behind them, not something shining
/// through the paragraphs. It also keeps a card looking the same over a bright
/// and a dark part of the same picture.
const double kWallpaperCardOpacity = 0.82;

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
