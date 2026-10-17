import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/settings_switch_base.dart';

// GtkSwitch as styled by libadwaita 1.10 (GNOME 51). All sizes are in
// logical pixels (1 CSS px).
const double _kTrackWidth = 46.0;
const double _kTrackHeight = 26.0;
const double _kKnobSize = 20.0;
const double _kPadding = 3.0;

/// How far the knob moves between OFF and ON.
const double _kTravel = _kTrackWidth - _kKnobSize - 2 * _kPadding;

/// GTK moves the knob and fades the colors in 100 ms, ease-out-cubic.
const Duration _kDuration = Duration(milliseconds: 100);
const Curve _kCurve = _EaseOutCubic();

/// The default GNOME accent (`--accent-bg-color`, "blue").
const Color _kAccentBackground = Color(0xFF3584E4);

/// `--accent-color` (the accent as used for text and focus rings).
const Color _kAccentLight = Color(0xFF0461BE);
const Color _kAccentDark = Color(0xFF81D0FF);

/// The foreground color (`--window-fg-color`) the OFF track is mixed from.
const Color _kForegroundLight = Color.fromRGBO(0, 0, 6, 0.8);
const Color _kForegroundDark = Color(0xFFFFFFFF);

const Color _kKnob = Color(0xFFFFFFFF);
const Color _kKnobOffDark = Color(0xFFD2D2D2);
const Color _kShade = Color(0xFF000006);

/// An on/off switch that looks and behaves like the GNOME switch (`GtkSwitch`
/// with the libadwaita 1.10 stylesheet, as in GNOME Settings 51).
///
/// It is a 46x26 pill track with a round 20 px white knob, inset by 3 px.
/// The ON track is the GNOME accent blue `#3584E4`, unless
/// [activeTrackColor] is set. The OFF track is the foreground color at 15%:
/// black at 12% in light mode and white at 15% in dark mode, unless
/// [inactiveTrackColor] is set. Like GTK, the track gets lighter under the
/// mouse and darker while pressed, and in dark mode the knob is light grey
/// while the switch is off and white when it is on or hovered.
///
/// Everything is painted in Flutter with a [CustomPainter]; nothing depends
/// on GTK or on a design package.
///
/// Like `GtkSwitch`:
///
///  * Clicking or tapping toggles the value.
///  * Dragging moves the knob. Letting go past the middle of the track sets
///    the value on that side.
///  * Space and Enter toggle it when it has keyboard focus, which shows a
///    2 px accent focus ring around the track.
///  * A disabled switch is drawn at half opacity.
///
/// The switch does not keep its own state. [onChanged] is called with the
/// new value, and the parent rebuilds it with that value. If [onChanged] is
/// null, the switch is disabled.
///
/// Light or dark comes from [brightness]. When it is null, it comes from the
/// [CupertinoTheme] (which follows the Material theme inside a
/// `MaterialApp`), or from the platform brightness.
class AdwaitaSettingsSwitch extends StatefulWidget {
  /// Creates a GNOME style switch.
  const AdwaitaSettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.brightness,
    this.focusNode,
    this.autofocus = false,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when the user toggles the switch.
  ///
  /// If null, the switch is disabled.
  final ValueChanged<bool>? onChanged;

  /// The track color when the switch is on.
  ///
  /// Defaults to the GNOME accent, `#3584E4`.
  final Color? activeTrackColor;

  /// The track color when the switch is off.
  ///
  /// Defaults to the foreground color at 15%: `rgba(0, 0, 6, 0.12)` in light
  /// mode and white at 15% in dark mode.
  final Color? inactiveTrackColor;

  /// Whether to use the light or the dark colors.
  ///
  /// Defaults to the [CupertinoTheme] brightness, or the platform brightness.
  final Brightness? brightness;

  /// An optional focus node to use as the focus node for this widget.
  final FocusNode? focusNode;

  /// Whether this switch should focus itself if nothing else is focused.
  final bool autofocus;

  @override
  State<AdwaitaSettingsSwitch> createState() => _AdwaitaSettingsSwitchState();

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
    properties.add(EnumProperty<Brightness>('brightness', brightness));
    properties.add(
      DiagnosticsProperty<FocusNode>(
        'focusNode',
        focusNode,
        defaultValue: null,
      ),
    );
    properties.add(
      DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false),
    );
  }
}

class _AdwaitaSettingsSwitchState
    extends SettingsSwitchState<AdwaitaSettingsSwitch>
    with TickerProviderStateMixin, SettingsSwitchKnobDrag {
  /// Knob position: 0 = OFF, 1 = ON.
  @override
  late final AnimationController position = AnimationController(
    vsync: this,
    duration: _kDuration,
    value: widget.value ? 1 : 0,
  );

  /// Track color: 0 = OFF color, 1 = ON color. Unlike the knob, it follows
  /// the value only, not the finger, like GTK's `:checked` state.
  late final AnimationController _checked = AnimationController(
    vsync: this,
    duration: _kDuration,
    value: widget.value ? 1 : 0,
  );

  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: _kDuration,
  );

  late final AnimationController _active = AnimationController(
    vsync: this,
    duration: _kDuration,
  );

  @override
  bool get value => widget.value;

  @override
  ValueChanged<bool>? get onChanged => widget.onChanged;

  @override
  double get travel => _kTravel;

  @override
  void didUpdateWidget(AdwaitaSettingsSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _animate(_checked, widget.value ? 1 : 0);
      // While dragging, the pointer owns the knob. It snaps on release.
      if (!dragging) _animate(position, widget.value ? 1 : 0);
    }
    if (!enabled) {
      if (dragging) {
        dragging = false;
        _animate(position, widget.value ? 1 : 0);
      }
      if (_hover.value != 0) _hover.value = 0;
      if (_active.value != 0) _active.value = 0;
    }
  }

  @override
  void dispose() {
    position.dispose();
    _checked.dispose();
    _hover.dispose();
    _active.dispose();
    super.dispose();
  }

  void _animate(AnimationController controller, double target) =>
      animate(controller, target, curve: _kCurve);

  @override
  void setPressed(bool pressed) => _animate(_active, pressed ? 1 : 0);

  void _handleTapEnd() {
    if (!dragging) setPressed(false);
  }

  @override
  void settleDrag(bool value) {
    setPressed(false);
    // GtkSwitch keeps the side the knob was let go on.
    if (value != widget.value) widget.onChanged?.call(value);
    // If the parent does not rebuild with the new value, the knob goes back.
    _animate(position, widget.value ? 1 : 0);
    if (value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !dragging) _animate(position, widget.value ? 1 : 0);
      });
    }
  }

  void _handleHover(bool hovering) {
    if (hovering && !enabled) return;
    _animate(_hover, hovering ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark =
        (widget.brightness ?? switchBrightnessOf(context)) == Brightness.dark;
    final Color accent = widget.activeTrackColor ?? _kAccentBackground;
    final Color focusColor =
        (widget.activeTrackColor ?? (isDark ? _kAccentDark : _kAccentLight))
            .withValues(alpha: 0.5);

    return buildSwitch(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onShowHoverHighlight: _handleHover,
      onTapDown: (_) => setPressed(true),
      onTap: () {
        _handleTapEnd();
        handleTap();
      },
      onTapCancel: _handleTapEnd,
      // `switch:disabled { filter: opacity(0.5) }`
      disabledOpacity: 0.5,
      size: const Size(_kTrackWidth, _kTrackHeight),
      painter: _AdwaitaSwitchPainter(
        position: position,
        checked: _checked,
        hover: _hover,
        active: _active,
        activeColor: accent,
        inactiveColor: widget.inactiveTrackColor,
        isDark: isDark,
        textDirection: textDirection,
        focusColor: showFocusRing ? focusColor : null,
      ),
    );
  }
}

class _AdwaitaSwitchPainter extends SettingsSwitchPainter {
  _AdwaitaSwitchPainter({
    required this.position,
    required this.checked,
    required this.hover,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
    required super.textDirection,
    required this.focusColor,
  }) : super(repaint: Listenable.merge([position, checked, hover, active]));

  final Animation<double> position;
  final Animation<double> checked;
  final Animation<double> hover;
  final Animation<double> active;
  final Color activeColor;
  final Color? inactiveColor;
  final bool isDark;
  final Color? focusColor;

  @override
  void paintSwitch(Canvas canvas, Size size) {
    final Rect track = centerTrack(size, _kTrackWidth, _kTrackHeight);
    final RRect trackShape = RRect.fromRectAndRadius(
      track,
      const Radius.circular(_kTrackHeight / 2),
    );

    final double h = hover.value;
    final double a = active.value;
    final double on = checked.value.clamp(0.0, 1.0);

    // OFF: the foreground color mixed in at 15%, 20% on hover and 25% while
    // pressed.
    final Color foreground = isDark ? _kForegroundDark : _kForegroundLight;
    final double mix = _lerp(0.15 + 0.05 * h, 0.25, a);
    Color offColor =
        inactiveColor ?? foreground.withValues(alpha: foreground.a * mix);
    if (inactiveColor != null) {
      offColor = Color.alphaBlend(
        foreground.withValues(alpha: foreground.a * (mix - 0.15)),
        offColor,
      );
    }

    // ON: the accent, with white at 10% on top on hover and rgba(0,0,6,0.2)
    // while pressed.
    Color onColor = activeColor;
    onColor = Color.alphaBlend(
      _kKnob.withValues(alpha: 0.1 * h * (1 - a)),
      onColor,
    );
    onColor = Color.alphaBlend(_kShade.withValues(alpha: 0.2 * a), onColor);

    canvas.drawRRect(
      trackShape,
      Paint()..color = Color.lerp(offColor, onColor, on)!,
    );

    if (focusColor != null) {
      // A 2 px ring with a 1 px gap around the track.
      canvas.drawRRect(
        trackShape.inflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = focusColor!,
      );
    }

    final Offset knobCenter = Offset(
      track.left + _kPadding + _kKnobSize / 2 + _kTravel * position.value,
      track.center.dy,
    );
    // `box-shadow: 0 2px 4px rgba(0, 0, 6, 0.2)`
    canvas.drawCircle(
      knobCenter.translate(0, 2),
      _kKnobSize / 2,
      Paint()
        ..color = _kShade.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    // In dark mode the knob is light grey while off, white when on or under
    // the pointer.
    final Color knob = isDark
        ? Color.lerp(_kKnobOffDark, _kKnob, _max3(on, h, a))!
        : _kKnob;
    canvas.drawCircle(knobCenter, _kKnobSize / 2, Paint()..color = knob);
  }

  @override
  bool shouldRepaint(_AdwaitaSwitchPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.checked != checked ||
        oldDelegate.hover != hover ||
        oldDelegate.active != active ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.focusColor != focusColor;
  }
}

/// GTK's `ease_out_cubic`, 1 - (1 - t)^3. [Curves.easeOutCubic] is a
/// cubic Bezier that only comes close to it.
class _EaseOutCubic extends Curve {
  const _EaseOutCubic();

  @override
  double transformInternal(double t) {
    final double rest = 1 - t;
    return 1 - rest * rest * rest;
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _max3(double a, double b, double c) {
  final double ab = a > b ? a : b;
  return ab > c ? ab : c;
}
