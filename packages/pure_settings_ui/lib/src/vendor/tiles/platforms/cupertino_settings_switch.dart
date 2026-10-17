import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/settings_switch_base.dart';
import 'package:pure_settings_ui/src/vendor/utils/settings_theme.dart';

// Measured on iOS 27 (iPhone 17 Pro simulator). All sizes are in points.
const double _kTrackWidth = 63.0;
const double _kTrackHeight = 28.0;
const double _kThumbWidth = 37.0;
const double _kThumbHeight = 24.0;
const double _kThumbInset = 2.0;

/// How far the thumb moves between OFF and ON.
const double _kTravel = _kTrackWidth - _kThumbWidth - 2 * _kThumbInset;

/// Size of the glass lens while the switch is held.
const double _kLensWidth = 59.33;
const double _kLensHeight = 39.67;

/// How far the lens can be dragged past either rest position.
const double _kMaxOverDrag = 3.33;

/// A drag flips the value once the lens is this far past the opposite rest
/// position. The midpoint is not the trigger.
const double _kFlipDistance = 1.0;

/// After a tap, the lens shrinks back into the thumb once the thumb is this
/// close to its destination (the last part of the travel).
const double _kReleaseDistance = 3.5;

const Color _kOffTrackLight = Color(0xFFC5C5C7);
const Color _kOffTrackDark = Color(0xFF5A5A5E);
const Color _kCellLight = Color(0xFFFFFFFF);
const Color _kCellDark = Color(0xFF1C1C1E);
const Color _kWhite = Color(0xFFFFFFFF);
const Color _kBlack = Color(0xFF000000);

/// Grows the thumb into the lens: ~0.17 s response, damping ratio 0.62, so
/// it overshoots by about 4% after ~100 ms and settles in ~200 ms.
const SpringDescription _kPressSpring = SpringDescription(
  mass: 1,
  stiffness: 1444,
  damping: 47.1,
);

/// Shrinks the lens back into the thumb (critically damped, ~210 ms).
const SpringDescription _kReleaseSpring = SpringDescription(
  mass: 1,
  stiffness: 784,
  damping: 56,
);

/// Moves the thumb between OFF and ON (critically damped). It covers most
/// of the 22 pt in ~300 ms.
const SpringDescription _kPositionSpring = SpringDescription(
  mass: 1,
  stiffness: 225,
  damping: 30,
);

const Tolerance _kPositionTolerance = Tolerance(distance: 0.01, velocity: 0.1);
const Tolerance _kPressTolerance = Tolerance(distance: 0.001, velocity: 0.01);

const Duration _kTrackOnDuration = Duration(milliseconds: 350);
const Duration _kTrackOffDuration = Duration(milliseconds: 210);
const Duration _kTintDuration = Duration(milliseconds: 390);
const Duration _kCatchUpDuration = Duration(milliseconds: 120);

/// An on/off switch that looks and moves like the iOS 26+ `UISwitch`, the
/// "Liquid Glass" switch.
///
/// At rest it is a 63x28 capsule track with a 37x24 white pill thumb. While
/// it is pressed or dragged, the thumb turns into a larger clear glass lens
/// that bends the track underneath it and overflows the track. Everything is
/// painted in Flutter with a [CustomPainter]: there is no platform view, no
/// shader and no backdrop filter.
///
/// The widget always takes 63x28 of layout space. The lens paints outside
/// that box (up to about 12.5 points past the track ends and 6 points above
/// and below), so leave some room around the switch and do not clip it
/// tightly.
///
/// Like `UISwitch`:
///
///  * Tapping toggles the value.
///  * Dragging moves the lens with the finger. The value flips while the
///    finger is still down, once the lens passes the opposite end, not at
///    the midpoint. Letting go snaps the thumb to the current value.
///  * A drag that starts vertically is left to the enclosing scroll view.
///  * iOS and macOS play a light haptic on every value change.
///
/// The switch does not keep its own state. [onChanged] is called with the
/// new value, and the parent rebuilds it with that value. If [onChanged] is
/// null, the switch is disabled: it is drawn at half opacity and ignores
/// input.
///
/// The OFF track is `#C5C5C7` in light mode and `#5A5A5E` in dark mode, and
/// the ON track is the system green, unless [inactiveTrackColor] or
/// [activeTrackColor] is set. Light or dark comes from the [CupertinoTheme],
/// or from the platform brightness when the theme does not set one.
class CupertinoSettingsSwitch extends StatefulWidget {
  /// Creates an iOS 26+ style switch.
  const CupertinoSettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when the user toggles the switch.
  ///
  /// If null, the switch is disabled.
  final ValueChanged<bool>? onChanged;

  /// The track color when the switch is on.
  ///
  /// Defaults to [CupertinoColors.systemGreen].
  final Color? activeTrackColor;

  /// The track color when the switch is off.
  ///
  /// Defaults to `#C5C5C7` in light mode and `#5A5A5E` in dark mode.
  final Color? inactiveTrackColor;

  @override
  State<CupertinoSettingsSwitch> createState() =>
      _CupertinoSettingsSwitchState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    debugFillSwitchProperties(
      properties,
      value: value,
      onChanged: onChanged,
      activeTrackColor: activeTrackColor,
      inactiveTrackColor: inactiveTrackColor,
    );
  }
}

class _CupertinoSettingsSwitchState
    extends SettingsSwitchState<CupertinoSettingsSwitch>
    with TickerProviderStateMixin {
  /// Thumb offset from the OFF rest position, in points (0 = OFF, 22 = ON).
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: _restFor(widget.value),
  )..addListener(_maybeReleaseAfterTap);

  /// 0 = resting thumb, 1 = glass lens. Overshoots a little past 1.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  /// 0 = OFF track color, 1 = ON track color.
  late final AnimationController _trackOn = AnimationController(
    vsync: this,
    value: widget.value ? 1 : 0,
  );

  /// How much of the track color still tints the thumb after a release.
  late final AnimationController _tint = AnimationController(vsync: this);

  /// Eases the lens onto the finger when a drag starts, instead of jumping
  /// by the touch slop.
  late final AnimationController _catchUp = AnimationController(
    vsync: this,
    duration: _kCatchUpDuration,
    value: 1,
  )..addListener(_handleCatchUpTick);

  /// The lens is shown (a finger is down, or a tap is still moving the thumb).
  bool _pressed = false;

  /// A tap toggled the switch: shrink the lens when the thumb is almost there.
  bool _releaseWhenArrived = false;

  bool _dragValue = false;
  double _dragStartPosition = 0;
  double _dragFingerDelta = 0;
  double _dragCatchUpOffset = 0;

  @override
  bool get value => widget.value;

  @override
  ValueChanged<bool>? get onChanged => widget.onChanged;

  static double _restFor(bool value) => value ? _kTravel : 0;

  @override
  void didUpdateWidget(CupertinoSettingsSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animateTrack(widget.value);
      // While dragging, the finger owns the thumb. It snaps on release.
      if (!dragging) _animatePosition(_restFor(widget.value));
    }
    if (!enabled && (dragging || _pressed)) {
      dragging = false;
      _releaseWhenArrived = false;
      _releaseLens();
      _animatePosition(_restFor(widget.value));
    }
  }

  @override
  void dispose() {
    _position.dispose();
    _press.dispose();
    _trackOn.dispose();
    _tint.dispose();
    _catchUp.dispose();
    super.dispose();
  }

  // Animations.

  /// Runs [spring] on [controller], from where it is to [target].
  static void _spring(
    AnimationController controller,
    SpringDescription spring,
    double target,
    double velocity,
    Tolerance tolerance,
  ) {
    controller.animateWith(
      SpringSimulation(
        spring,
        controller.value,
        target,
        velocity,
        tolerance: tolerance,
        snapToEnd: true,
      ),
    );
  }

  void _pressLens() {
    if (reduceMotion) return;
    _pressed = true;
    _spring(_press, _kPressSpring, 1, _press.velocity, _kPressTolerance);
  }

  void _releaseLens() {
    if (!_pressed) return;
    _pressed = false;
    if (reduceMotion) {
      _press.value = 0;
      return;
    }
    // The thumb comes back tinted by the track, then fades to white. A press
    // too short to grow the lens leaves little tint.
    _tint.value = (_press.value / 0.5).clamp(0.0, 1.0);
    _tint.animateTo(0, duration: _kTintDuration, curve: Curves.easeInOut);
    _spring(_press, _kReleaseSpring, 0, _press.velocity, _kPressTolerance);
  }

  void _animatePosition(double target, {double velocity = 0}) {
    if (reduceMotion) {
      _position.value = target;
      return;
    }
    _spring(_position, _kPositionSpring, target, velocity, _kPositionTolerance);
  }

  void _animateTrack(bool on) => animate(
    _trackOn,
    on ? 1 : 0,
    duration: on ? _kTrackOnDuration : _kTrackOffDuration,
    curve: Curves.easeOut,
  );

  void _maybeReleaseAfterTap() {
    if (!_releaseWhenArrived || dragging) return;
    final double distance = (_position.value - _restFor(widget.value)).abs();
    if (distance <= _kReleaseDistance) {
      _releaseWhenArrived = false;
      _releaseLens();
    }
  }

  void _commit(bool value) {
    widget.onChanged?.call(value);
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      HapticFeedback.lightImpact();
    }
  }

  // Taps, keyboard and accessibility actions.

  void _handleTapDown(TapDownDetails details) {
    // A finger is down again: keep the lens until it lifts.
    _releaseWhenArrived = false;
    _pressLens();
  }

  @override
  void handleTap() {
    if (!enabled) return;
    _pressLens();
    _releaseWhenArrived = true;
    _commit(!widget.value);
    // If the parent rebuilds with the new value, the thumb starts moving and
    // the lens shrinks near the end of the travel. If it does not, the thumb
    // stays put and the lens shrinks right after the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeReleaseAfterTap();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _handleTapCancel() {
    // A scroll or a drag took over. A drag keeps the lens (it presses again
    // right after this).
    if (!dragging) _releaseLens();
  }

  // Dragging.

  @override
  void handleDragStart(DragStartDetails details) {
    dragging = true;
    _releaseWhenArrived = false;
    _dragValue = widget.value;
    _dragStartPosition = _position.value;
    _dragFingerDelta = dragDelta(details.localPosition.dx);
    // The finger has already moved by the touch slop. Follow it from the
    // point where it touched down, but ease into that instead of jumping.
    _dragCatchUpOffset =
        _dragStartPosition - _rubberBand(_dragStartPosition + _dragFingerDelta);
    if (reduceMotion) {
      _catchUp.value = 1;
    } else {
      _catchUp.forward(from: 0);
    }
    _pressLens();
    _updateDragPosition();
  }

  @override
  void handleDragUpdate(DragUpdateDetails details) {
    if (!dragging) return;
    _dragFingerDelta = dragDelta(details.localPosition.dx);
    _updateDragPosition();
  }

  void _handleCatchUpTick() {
    if (dragging) _updateDragPosition();
  }

  void _updateDragPosition() {
    final double target = _rubberBand(_dragStartPosition + _dragFingerDelta);
    final double lag = 1 - Curves.easeOutCubic.transform(_catchUp.value);
    _position.value = target + _dragCatchUpOffset * lag;

    if (!_dragValue && target > _kTravel + _kFlipDistance) {
      _dragValue = true;
      _commit(true);
    } else if (_dragValue && target < -_kFlipDistance) {
      _dragValue = false;
      _commit(false);
    }
  }

  @override
  void handleDragEnd(DragEndDetails details) {
    _finishDrag(direction * (details.primaryVelocity ?? 0));
  }

  @override
  void handleDragCancel() => _finishDrag(0);

  void _finishDrag(double velocity) {
    if (!dragging) return;
    dragging = false;
    _catchUp.value = 1;
    _releaseLens();
    _animatePosition(
      _restFor(widget.value),
      velocity: velocity.clamp(-600.0, 600.0),
    );
  }

  /// Follows the finger 1:1 between the rest positions, then resists and
  /// stops [_kMaxOverDrag] points past them.
  static double _rubberBand(double position) {
    if (position > _kTravel) {
      return _kTravel +
          _kMaxOverDrag * _tanh((position - _kTravel) / _kMaxOverDrag);
    }
    if (position < 0) {
      return -_kMaxOverDrag * _tanh(-position / _kMaxOverDrag);
    }
    return position;
  }

  static double _tanh(double x) {
    final double e = math.exp(2 * math.min(x, 20.0));
    return (e - 1) / (e + 1);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = switchBrightnessOf(context) == Brightness.dark;
    final bool highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;

    const CupertinoDynamicColor green = CupertinoColors.systemGreen;
    final Color activeColor =
        widget.activeTrackColor ??
        (isDark
            ? (highContrast ? green.darkHighContrastColor : green.darkColor)
            : (highContrast ? green.highContrastColor : green.color));
    final Color inactiveColor =
        widget.inactiveTrackColor ??
        (isDark ? _kOffTrackDark : _kOffTrackLight);
    // The glass shows the cell behind it. Inside a settings list that is the
    // section background.
    final Color backdropColor =
        context
            .dependOnInheritedWidgetOfExactType<SettingsTheme>()
            ?.themeData
            .settingsSectionBackground ??
        (isDark ? _kCellDark : _kCellLight);
    final Color? focusColor = showFocusRing
        ? HSLColor.fromColor(
                activeColor.withValues(alpha: kCupertinoFocusColorOpacity),
              )
              .withLightness(kCupertinoFocusColorBrightness)
              .withSaturation(kCupertinoFocusColorSaturation)
              .toColor()
        : null;

    return buildSwitch(
      onTapDown: _handleTapDown,
      onTapCancel: _handleTapCancel,
      disabledOpacity: 0.5,
      size: const Size(_kTrackWidth, _kTrackHeight),
      painter: _SwitchPainter(
        position: _position,
        press: _press,
        trackOn: _trackOn,
        tint: _tint,
        activeColor: activeColor,
        inactiveColor: inactiveColor,
        backdropColor: backdropColor,
        isDark: isDark,
        textDirection: textDirection,
        focusColor: focusColor,
      ),
    );
  }
}

class _SwitchPainter extends SettingsSwitchPainter {
  _SwitchPainter({
    required this.position,
    required this.press,
    required this.trackOn,
    required this.tint,
    required this.activeColor,
    required this.inactiveColor,
    required this.backdropColor,
    required this.isDark,
    required super.textDirection,
    required this.focusColor,
  }) : super(repaint: Listenable.merge([position, press, trackOn, tint]));

  final Animation<double> position;
  final Animation<double> press;
  final Animation<double> trackOn;
  final Animation<double> tint;
  final Color activeColor;
  final Color inactiveColor;
  final Color backdropColor;
  final bool isDark;
  final Color? focusColor;

  @override
  void paintSwitch(Canvas canvas, Size size) {
    final Rect track = centerTrack(size, _kTrackWidth, _kTrackHeight);

    final Color trackColor = Color.lerp(
      inactiveColor,
      activeColor,
      trackOn.value.clamp(0.0, 1.0),
    )!;
    canvas.drawRSuperellipse(_capsule(track), Paint()..color = trackColor);

    if (focusColor != null) {
      canvas.drawRSuperellipse(
        _capsule(track.inflate(1.75)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = focusColor!,
      );
    }

    final double p = math.max(0.0, press.value);
    final Rect thumb = Rect.fromCenter(
      center: Offset(
        track.left + _kThumbInset + _kThumbWidth / 2 + position.value,
        track.center.dy,
      ),
      width: _kThumbWidth + (_kLensWidth - _kThumbWidth) * p,
      height: _kThumbHeight + (_kLensHeight - _kThumbHeight) * p,
    );

    // The opaque thumb hands over to the lens early in the press (and back
    // late in the release). The lens is frosted while it is small.
    final double glass = _smoothstep(0.04, 0.3, p);
    final double thumbOpacity = 1 - _smoothstep(0.12, 0.35, p);
    final double frost = 1 - _smoothstep(0.6, 1.0, p);

    if (glass > 0) {
      _paintLens(canvas, track, thumb, trackColor, glass, frost);
    }
    if (thumbOpacity > 0) {
      final Color fill = Color.lerp(
        _kWhite,
        trackColor,
        tint.value.clamp(0.0, 1.0) * (isDark ? 0.5 : 0.2),
      )!;
      canvas.drawRSuperellipse(
        _capsule(thumb),
        Paint()..color = fill.withValues(alpha: fill.a * thumbOpacity),
      );
    }
  }

  void _paintLens(
    Canvas canvas,
    Rect track,
    Rect lens,
    Color trackColor,
    double glass,
    double frost,
  ) {
    final double clarity = 1 - frost;
    final RSuperellipse lensShape = _capsule(lens);
    final double cx = lens.center.dx;
    final double cy = lens.center.dy;

    // Soft shadow, below and beside the lens only. Below, it is a blurred
    // band 3.5-6.5 pt under the lens edge, so it is faint right at the edge
    // and darkest ~5 pt down.
    final Path lensPath = Path()..addRSuperellipse(lensShape);
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(lens.left - 20, cy, lens.right + 20, lens.bottom + 20),
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addPath(lensPath, const Offset(0, 3.5))
        ..addPath(lensPath, const Offset(0, 6.5)),
      Paint()
        ..color = _kBlack.withValues(alpha: (isDark ? 0.47 : 0.2) * glass)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
    canvas.drawRSuperellipse(
      _capsule(
        Rect.fromLTRB(lens.left, lens.top + 4, lens.right, lens.bottom - 4),
      ),
      Paint()
        ..color = _kBlack.withValues(alpha: (isDark ? 0.24 : 0.1) * glass)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    if (glass < 1) {
      canvas.saveLayer(
        lens.inflate(1),
        Paint()..color = _kBlack.withValues(alpha: glass),
      );
    } else {
      canvas.save();
    }
    canvas.clipRSuperellipse(lensShape);

    // The glass minifies what is behind it: the track looks 0.76x as tall
    // and its ends are pulled in. Between the rim and the track image, the
    // lens shows the cell around the track as bands above and below. While
    // the lens is frosted, the track shows as a narrower blurred bar.
    final double halfHeight = _kTrackHeight / 2 * _lerp(0.76, 0.5, frost);
    final double imageTop = cy - halfHeight;
    final double imageBottom = cy + halfHeight;
    double stop(double y) => ((y - lens.top) / lens.height).clamp(0.0, 1.0);
    final List<Color> bands = isDark
        ? [
            _mix(backdropColor, _kWhite, 0.132),
            _mix(backdropColor, _kWhite, 0.057),
            _mix(backdropColor, _kWhite, 0.08),
            _mix(backdropColor, _kWhite, 0.101),
            _mix(backdropColor, _kWhite, 0.145),
          ]
        : [
            _mix(backdropColor, _kBlack, 0.04),
            _mix(backdropColor, _kBlack, 0.082),
            _mix(backdropColor, _kBlack, 0.05),
            backdropColor,
            backdropColor,
          ];
    canvas.drawRect(
      lens,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: bands,
          stops: [0, stop(imageTop), stop(cy), stop(imageBottom), 1],
        ).createShader(lens),
    );

    // The rim is a stack of hairlines about 1 pt deep. It darkens what is
    // under it, more at the ends than along the top and bottom, and more
    // over the bands than over the track image. Along the top and bottom it
    // ends in a bright line tinted by the track and a specular line.
    final double r = lens.height / 2;
    final double w = lens.width;
    Shader ends(double midAlpha, double endAlpha) => LinearGradient(
      colors: [
        _kBlack.withValues(alpha: endAlpha),
        _kBlack.withValues(alpha: midAlpha),
        _kBlack.withValues(alpha: midAlpha),
        _kBlack.withValues(alpha: endAlpha),
      ],
      stops: [0, r / w, 1 - r / w, 1],
    ).createShader(lens);
    Shader sides(Color color) => LinearGradient(
      colors: [
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
        color,
        color,
        color.withValues(alpha: 0),
        color.withValues(alpha: 0),
      ],
      stops: [
        0,
        0.45 * r / w,
        1.1 * r / w,
        1 - 1.1 * r / w,
        1 - 0.45 * r / w,
        1,
      ],
    ).createShader(lens);
    void rimLine(double inset, double width, Paint paint) {
      canvas.drawRSuperellipse(
        _capsule(lens.deflate(inset)),
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = width,
      );
    }

    rimLine(
      0.33,
      0.67,
      Paint()..shader = ends(isDark ? 0.72 : 0.15, isDark ? 0.8 : 0.3),
    );
    rimLine(0.83, 0.34, Paint()..shader = ends(0, isDark ? 0.3 : 0.15));

    // Where the track runs on past the lens edge, the glass pulls it in
    // over the whole end of the lens ("flare"). Where the track ends under
    // the lens, its rounded end shows instead.
    double imageLeft = cx + (track.left - cx) * 0.87;
    double imageRight = cx + (track.right - cx) * 0.87;
    final double frostInset = 0.3 * lens.height;
    imageLeft = _lerp(
      imageLeft,
      math.max(imageLeft, lens.left + frostInset),
      frost,
    );
    imageRight = _lerp(
      imageRight,
      math.min(imageRight, lens.right - frostInset),
      frost,
    );
    final double leftFlare =
        _smoothstep(-2, 1.5, lens.left - track.left) * clarity;
    final double rightFlare =
        _smoothstep(-2, 1.5, track.right - lens.right) * clarity;
    imageLeft -=
        (imageLeft - math.min(imageLeft, lens.left - halfHeight)) * leftFlare;
    imageRight +=
        (math.max(imageRight, lens.right + halfHeight) - imageRight) *
        rightFlare;
    Path image = Path()
      ..addRRect(
        RRect.fromLTRBR(
          imageLeft,
          imageTop,
          imageRight,
          imageBottom,
          Radius.circular(halfHeight),
        ),
      );
    final double flareWidth = 9.2 * lens.width / _kLensWidth;
    if (leftFlare > 0) {
      image = Path.combine(
        PathOperation.union,
        image,
        _flare(lens, imageTop, imageBottom, leftFlare, flareWidth, left: true),
      );
    }
    if (rightFlare > 0) {
      image = Path.combine(
        PathOperation.union,
        image,
        _flare(
          lens,
          imageTop,
          imageBottom,
          rightFlare,
          flareWidth,
          left: false,
        ),
      );
    }
    final Paint imagePaint = Paint()
      ..color = _lift(trackColor, isDark ? 12 : 6);
    if (frost > 0.01) {
      // While the lens forms and dissolves, the track behind it is blurred.
      imagePaint.maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * frost);
    }
    canvas.drawPath(image, imagePaint);

    if (clarity > 0) {
      canvas.save();
      canvas.clipPath(image);
      rimLine(
        0.33,
        0.67,
        Paint()
          ..color = _kBlack.withValues(alpha: (isDark ? 0.5 : 0.36) * clarity),
      );
      rimLine(
        0.83,
        0.34,
        Paint()..shader = ends(0, (isDark ? 0.25 : 0.16) * clarity),
      );
      // The track image is darker along its top edge (an inner shadow that
      // fades out ~10 pt down) and toward the rim at the ends.
      canvas.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(lens.inflate(20))
          ..addPath(image, const Offset(0, 5)),
        Paint()
          ..color = _kBlack.withValues(
            alpha: (isDark ? 0.215 : 0.087) * clarity,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
      );
      final double sideAlpha = (isDark ? 0.21 : 0.095) * clarity;
      const List<double> fade = [1.0, 1.0, 0.84, 0.5, 0.16, 0.0];
      const List<double> fadeAt = [0, 2, 5.5, 9, 12.5, 16];
      canvas.drawRect(
        lens,
        Paint()
          ..shader = LinearGradient(
            colors: [
              for (final double a in fade)
                _kBlack.withValues(alpha: sideAlpha * a),
              for (final double a in fade.reversed)
                _kBlack.withValues(alpha: sideAlpha * a),
            ],
            stops: [
              for (final double d in fadeAt) d / w,
              for (final double d in fadeAt.reversed) 1 - d / w,
            ],
          ).createShader(lens),
      );
      canvas.restore();
    }

    if (frost > 0) {
      // Milky white wash while the lens forms and dissolves.
      canvas.drawRect(
        lens,
        Paint()
          ..color = _kWhite.withValues(alpha: (isDark ? 0.3 : 0.5) * frost),
      );
    }

    rimLine(0.8, 0.4, Paint()..shader = sides(_hairline(trackColor)));
    rimLine(
      1.2,
      0.4,
      Paint()..shader = sides(_kWhite.withValues(alpha: isDark ? 0.14 : 0.9)),
    );

    canvas.restore();
  }

  /// The part of the track image that fills one end of the lens, from the
  /// rim to [width] inside it, with rounded corners toward the bands.
  static Path _flare(
    Rect lens,
    double imageTop,
    double imageBottom,
    double amount,
    double width, {
    required bool left,
  }) {
    final double inner = width * amount;
    final double radius = 3.5 * amount;
    double x(double fromRim) =>
        left ? lens.left + fromRim : lens.right - fromRim;
    final double top = lens.top - 1;
    final double bottom = lens.bottom + 1;
    return Path()
      ..moveTo(x(inner + radius), imageTop)
      ..arcToPoint(
        Offset(x(inner), imageTop - radius),
        radius: Radius.circular(radius),
        clockwise: left,
      )
      ..lineTo(x(inner), top)
      ..lineTo(x(-1), top)
      ..lineTo(x(-1), bottom)
      ..lineTo(x(inner), bottom)
      ..lineTo(x(inner), imageBottom + radius)
      ..arcToPoint(
        Offset(x(inner + radius), imageBottom),
        radius: Radius.circular(radius),
        clockwise: left,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_SwitchPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.press != press ||
        oldDelegate.trackOn != trackOn ||
        oldDelegate.tint != tint ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.backdropColor != backdropColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.focusColor != focusColor;
  }
}

/// A capsule with continuous (squircle-smoothed) corners, like iOS draws it.
RSuperellipse _capsule(Rect rect) => RSuperellipse.fromRectAndRadius(
  rect,
  Radius.circular(rect.shortestSide / 2),
);

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _smoothstep(double edge0, double edge1, double x) {
  final double t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

Color _mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

/// Brightens [color] by [levels] out of 255 on each channel, the way the
/// glass lifts what it shows.
Color _lift(Color color, double levels) {
  final double d = levels / 255;
  return Color.from(
    alpha: color.a,
    red: math.min(1.0, color.r + d),
    green: math.min(1.0, color.g + d),
    blue: math.min(1.0, color.b + d),
  );
}

/// The bright rim hairline: the track color, lighter and a little more
/// saturated. Saturated colors are lifted more than greys.
Color _hairline(Color color) {
  final HSVColor hsv = HSVColor.fromColor(color);
  final double lift = _lerp(0.2, 0.55, hsv.saturation);
  return hsv
      .withValue(hsv.value + (1 - hsv.value) * lift)
      .withSaturation(math.min(1.0, hsv.saturation * 1.1))
      .toColor();
}
