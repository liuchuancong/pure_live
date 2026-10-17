import 'package:flutter/gestures.dart' show PointerDeviceKind, computeHitSlop;
import 'package:flutter/widgets.dart';

/// The actions of a row or a switch that the keyboard activates: Space or
/// Enter on the focused one calls [activate]. Internal.
Map<Type, Action<Intent>> tileActivateActions(
  VoidCallback activate,
) => <Type, Action<Intent>>{
  ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => activate()),
  ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
    onInvoke: (_) => activate(),
  ),
};

/// Tracks the pointer that presses a tile or a sidebar row, for the styles
/// that show the pressed state as soon as a pointer goes down (GTK's
/// `:active`, WinUI's `Pressed`). The press ends when the pointer goes up,
/// leaves the row or starts to scroll the list. The row wires the handlers
/// to a [Listener] and calls [startPress] for the pointers it accepts.
/// Internal.
mixin TilePressTracking<T extends StatefulWidget> on State<T> {
  /// Whether a pointer is pressing the tile.
  bool pressed = false;

  /// The pointer that pressed the tile, while it is down.
  int? _pressPointer;
  Offset _pressOrigin = Offset.zero;

  void startPress(PointerDownEvent event) {
    _pressPointer = event.pointer;
    _pressOrigin = event.position;
    _setPressed(true);
  }

  void handlePressMove(PointerMoveEvent event) {
    // A pointer that went down on the row still reports here after the row
    // has left the tree, when it has no context and no box.
    if (event.pointer != _pressPointer || !mounted) return;
    final box = context.findRenderObject()! as RenderBox;
    final inside = box.size.contains(box.globalToLocal(event.position));
    // A finger that moves past the slop is scrolling the list, which takes
    // the gesture (GTK drops `:active` then too). A mouse stays pressed until
    // it leaves the tile.
    final scrolling =
        event.kind != PointerDeviceKind.mouse &&
        (event.position - _pressOrigin).distance >
            computeHitSlop(event.kind, null);
    if (!inside || scrolling) releasePress();
  }

  void handlePressEnd(PointerEvent event) {
    if (event.pointer == _pressPointer) releasePress();
  }

  void releasePress() {
    _pressPointer = null;
    _setPressed(false);
  }

  /// Forgets the press without a rebuild, for `didUpdateWidget`.
  void resetPress() {
    pressed = false;
    _pressPointer = null;
  }

  void _setPressed(bool value) {
    if (pressed != value && mounted) setState(() => pressed = value);
  }
}
