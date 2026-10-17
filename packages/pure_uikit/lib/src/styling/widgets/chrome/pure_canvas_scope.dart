import 'package:flutter/widgets.dart';

/// Whether the app canvas behind the scaffold is painted by a host-provided
/// background layer (a wallpaper, a themed backdrop). When active, the scaffold
/// leaves its surface transparent so that layer shows through; pages that must
/// stay opaque keep their own background override.
final class PureCanvasScope extends InheritedWidget {
  /// Provides the canvas mode to the scaffolds below.
  const new({required this.transparent, required super.child, super.key});

  /// Whether scaffolds should render transparent surfaces.
  final bool transparent;

  /// The scope's state below, or not-transparent when absent.
  static bool transparentOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PureCanvasScope>()?.transparent ?? false;

  @override
  bool updateShouldNotify(PureCanvasScope oldWidget) => oldWidget.transparent != transparent;
}
