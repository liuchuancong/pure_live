import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_settings_ui/src/vendor/tiles/tile_press.dart';

// What the four painted switches (`CupertinoSettingsSwitch`,
// `MacosSettingsSwitch`, `FluentSettingsSwitch` and `AdwaitaSettingsSwitch`)
// do the same way. This library is internal: `settings_ui.dart` does not
// export it. The widgets share no base class, because their constructors and
// fields are public API. Their State classes and painters share these.

/// Adds the properties that every switch widget has to [properties].
void debugFillSwitchProperties(
  DiagnosticPropertiesBuilder properties, {
  required bool value,
  required ValueChanged<bool>? onChanged,
  required Color? activeTrackColor,
  required Color? inactiveTrackColor,
}) {
  properties.add(
    FlagProperty('value', value: value, ifTrue: 'on', ifFalse: 'off'),
  );
  properties.add(
    ObjectFlagProperty<ValueChanged<bool>>(
      'onChanged',
      onChanged,
      ifNull: 'disabled',
    ),
  );
  properties.add(ColorProperty('activeTrackColor', activeTrackColor));
  properties.add(ColorProperty('inactiveTrackColor', inactiveTrackColor));
}

/// Light or dark for a switch in [context]: the [CupertinoTheme] brightness
/// (which follows the Material theme inside a `MaterialApp`), or the
/// platform brightness when the theme does not set one.
Brightness switchBrightnessOf(BuildContext context) =>
    CupertinoTheme.maybeBrightnessOf(context) ?? Brightness.light;

/// The State of a switch widget, without its look and its motion.
///
/// It toggles on a tap, on Space or Enter and on the accessibility action,
/// knows about reduced motion, the text direction and the keyboard focus
/// highlight, remembers where a drag went down, and builds the semantics,
/// focus and gesture widgets around the painter ([buildSwitch]).
abstract class SettingsSwitchState<T extends StatefulWidget> extends State<T> {
  late final Map<Type, Action<Intent>> _actions = tileActivateActions(
    handleTap,
  );

  /// The platform asks for less motion, so values jump instead of animating.
  bool reduceMotion = false;
  bool _showFocusHighlight = false;

  /// A horizontal drag is moving the knob.
  bool dragging = false;
  double _dragDownX = 0;

  /// The widget's `value`.
  bool get value;

  /// The widget's `onChanged`.
  ValueChanged<bool>? get onChanged;

  bool get enabled => onChanged != null;

  TextDirection get textDirection =>
      Directionality.maybeOf(context) ?? TextDirection.ltr;

  /// +1 in left-to-right layouts, -1 in right-to-left ones.
  double get direction => textDirection == TextDirection.rtl ? -1 : 1;

  /// Whether to draw the keyboard focus ring.
  bool get showFocusRing => _showFocusHighlight && enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  }

  /// Animates [controller] to [target], or jumps there with reduced motion.
  void animate(
    AnimationController controller,
    double target, {
    Duration? duration,
    Curve curve = Curves.linear,
  }) {
    if (reduceMotion) {
      controller.value = target;
    } else {
      controller.animateTo(target, duration: duration, curve: curve);
    }
  }

  /// Toggles the value: a tap, Space or Enter, or the accessibility action.
  void handleTap() {
    if (!enabled) return;
    onChanged!(!value);
  }

  void _handleFocusHighlight(bool show) {
    if (show != _showFocusHighlight) {
      setState(() => _showFocusHighlight = show);
    }
  }

  void _handleDragDown(DragDownDetails details) {
    _dragDownX = details.localPosition.dx;
  }

  /// How far a pointer at [x] is from where it went down, toward the ON end.
  ///
  /// The knob follows the pointer from there, not from where the drag was
  /// recognized (a touch slop of 18 px later, most of the travel).
  double dragDelta(double x) => direction * (x - _dragDownX);

  // Each style moves its knob in its own way.
  void handleDragStart(DragStartDetails details);
  void handleDragUpdate(DragUpdateDetails details);
  void handleDragEnd(DragEndDetails details);
  void handleDragCancel();

  /// Puts [painter], at [size], inside what every style has: a semantics
  /// node, keyboard focus, the hand cursor on the web, and the tap and
  /// horizontal drag gestures. A disabled switch has none of the callbacks.
  ///
  /// [onTap] replaces [handleTap] for a tap (the keyboard and accessibility
  /// keep [handleTap]). With [disabledOpacity], a disabled switch is drawn
  /// at that opacity. [wrapGestures] puts widgets between the focus and the
  /// gesture detector.
  Widget buildSwitch({
    required Size size,
    required CustomPainter painter,
    GestureTapDownCallback? onTapDown,
    GestureTapUpCallback? onTapUp,
    VoidCallback? onTap,
    GestureTapCancelCallback? onTapCancel,
    ValueChanged<bool>? onShowHoverHighlight,
    FocusNode? focusNode,
    bool autofocus = false,
    bool semanticsContainer = false,
    double? disabledOpacity,
    Widget Function(Widget gestures)? wrapGestures,
  }) {
    Widget child = RepaintBoundary(
      child: CustomPaint(size: size, painter: painter),
    );
    if (disabledOpacity != null) {
      child = Opacity(opacity: enabled ? 1 : disabledOpacity, child: child);
    }
    child = GestureDetector(
      excludeFromSemantics: true,
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? onTapDown : null,
      onTapUp: enabled ? onTapUp : null,
      onTap: enabled ? onTap ?? handleTap : null,
      onTapCancel: enabled ? onTapCancel : null,
      onHorizontalDragDown: enabled ? _handleDragDown : null,
      onHorizontalDragStart: enabled ? handleDragStart : null,
      onHorizontalDragUpdate: enabled ? handleDragUpdate : null,
      onHorizontalDragEnd: enabled ? handleDragEnd : null,
      onHorizontalDragCancel: enabled ? handleDragCancel : null,
      child: child,
    );
    return Semantics(
      container: semanticsContainer,
      toggled: value,
      enabled: enabled,
      onTap: enabled ? handleTap : null,
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: focusNode,
        autofocus: autofocus,
        actions: _actions,
        onShowFocusHighlight: _handleFocusHighlight,
        onShowHoverHighlight: onShowHoverHighlight,
        mouseCursor: enabled && kIsWeb
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: wrapGestures?.call(child) ?? child,
      ),
    );
  }
}

/// The drag of the macOS, Windows and GNOME switches: the knob follows the
/// pointer between the two ends, and letting go past the middle picks that
/// side.
mixin SettingsSwitchKnobDrag<T extends StatefulWidget>
    on SettingsSwitchState<T> {
  double _dragStartPosition = 0;

  /// Where the knob is: 0 = OFF end, 1 = ON end.
  AnimationController get position;

  /// How far the knob moves between OFF and ON.
  double get travel;

  /// Shows or drops the pressed look.
  void setPressed(bool pressed);

  /// A drag ended, or was cancelled, with the knob on the [newValue] side.
  void settleDrag(bool newValue);

  @override
  void handleDragStart(DragStartDetails details) {
    dragging = true;
    position.stop();
    _dragStartPosition = position.value;
    setPressed(true);
    _followPointer(details.localPosition.dx);
  }

  @override
  void handleDragUpdate(DragUpdateDetails details) {
    if (dragging) _followPointer(details.localPosition.dx);
  }

  /// Moves the knob with the pointer, counted from where it went down, so
  /// the knob does not lag behind by the drag slop.
  void _followPointer(double x) {
    final double delta = dragDelta(x) / travel;
    position.value = (_dragStartPosition + delta).clamp(0.0, 1.0);
  }

  @override
  void handleDragEnd(DragEndDetails details) => _finishDrag();

  @override
  void handleDragCancel() => _finishDrag();

  void _finishDrag() {
    if (!dragging) return;
    dragging = false;
    settleDrag(position.value >= 0.5);
  }
}

/// Paints a switch. Every look is symmetric left to right, so right-to-left
/// layouts just mirror the canvas: ON is then on the left.
abstract class SettingsSwitchPainter extends CustomPainter {
  SettingsSwitchPainter({required this.textDirection, super.repaint});

  final TextDirection textDirection;

  /// Paints the left-to-right switch, with OFF at the left end.
  void paintSwitch(Canvas canvas, Size size);

  /// A [width] x [height] track in the middle of [size].
  Rect centerTrack(Size size, double width, double height) => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: width,
    height: height,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    if (textDirection == TextDirection.rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    paintSwitch(canvas, size);
    canvas.restore();
  }
}
