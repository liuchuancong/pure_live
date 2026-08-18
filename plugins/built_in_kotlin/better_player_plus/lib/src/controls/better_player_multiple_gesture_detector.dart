import 'package:flutter/material.dart';

///Helper class for GestureDetector used within Better Player. Used to pass
///gestures to upper GestureDetectors.
class BetterPlayerMultipleGestureDetector extends InheritedWidget {
  const BetterPlayerMultipleGestureDetector({
    super.key,
    required super.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
  });
  final void Function()? onTap;
  final void Function()? onDoubleTap;
  final void Function()? onLongPress;

  static BetterPlayerMultipleGestureDetector? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BetterPlayerMultipleGestureDetector>();

  @override
  bool updateShouldNotify(BetterPlayerMultipleGestureDetector oldWidget) => false;
}
