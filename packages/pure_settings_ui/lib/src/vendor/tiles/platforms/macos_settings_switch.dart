import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:pure_settings_ui/src/vendor/tiles/platforms/settings_switch_base.dart';

/// The two switch sizes that System Settings uses on macOS 26 and 27.
enum MacosSettingsSwitchSize {
  /// A 36x16 track with a 21x13 knob.
  ///
  /// This is the switch in the rows of a grouped form, the one Apple's
  /// Human Interface Guidelines call a mini switch.
  regular,

  /// A 44x20 track with a 26x16 knob.
  ///
  /// System Settings uses it for the main switch of a pane, such as Wi-Fi or
  /// Bluetooth.
  large,
}

/// The measured parts of one switch size. All sizes are in points.
class _Metrics {
  const _Metrics({
    required this.trackWidth,
    required this.trackHeight,
    required this.knobWidth,
    required this.knobHeight,
  });

  final double trackWidth;
  final double trackHeight;
  final double knobWidth;
  final double knobHeight;

  Size get trackSize => Size(trackWidth, trackHeight);

  /// The gap between the knob and the track edge (1.5 for the regular size,
  /// 2 for the large one).
  double get inset => (trackHeight - knobHeight) / 2;

  /// How far the knob moves between OFF and ON.
  double get travel => trackWidth - knobWidth - 2 * inset;

  static _Metrics of(MacosSettingsSwitchSize size) => switch (size) {
    MacosSettingsSwitchSize.regular => const _Metrics(
      trackWidth: 36,
      trackHeight: 16,
      knobWidth: 21,
      knobHeight: 13,
    ),
    MacosSettingsSwitchSize.large => const _Metrics(
      trackWidth: 44,
      trackHeight: 20,
      knobWidth: 26,
      knobHeight: 16,
    ),
  };
}

/// The ON track: the macOS accent blue (`controlAccentColor`, #007AFF) as
/// System Settings renders it in a switch, measured in light and dark mode.
const Color _kOnTrackLight = Color(0xFF0476F7);
const Color _kOnTrackDark = Color(0xFF117BFC);

/// The OFF track is a fill over the card: black 10% (light) or white 10%
/// (dark), which gives the measured #DEDEDE on #F7F7F7 and #3D3E3C on the
/// dark card.
const Color _kOffTrackLight = Color(0x1A000000);
const Color _kOffTrackDark = Color(0x1AFFFFFF);

/// The knob is white in light mode. In dark mode it is a light grey when off
/// and is tinted by the track color when on (#DFEBFF with the blue accent).
const Color _kKnobLight = Color(0xFFFFFFFF);
const Color _kKnobOffDark = Color(0xFFE2E2E2);
const double _kKnobOnTintDark = 0.14;

/// `keyboardFocusIndicatorColor`: #0067F4 or #1AA9FF, both at 50%.
const Color _kFocusLight = Color(0x800067F4);
const Color _kFocusDark = Color(0x801AA9FF);
const double _kFocusRingWidth = 3;

/// A disabled switch draws its track a little paler, at 70%. With the
/// default colors that gives the measured #5D9BF4 (light) and #2365BE (dark)
/// for a disabled ON switch. In dark mode the knob loses some of its tint.
const double _kDisabledTrackOpacity = 0.7;
const double _kDisabledTrackFade = 0.1;
const Color _kDisabledTrackFadeLight = Color(0xFF808080);
const Color _kDisabledTrackFadeDark = Color(0xFFFFFFFF);
const double _kDisabledKnobTint = 0.6;

const Duration _kToggleDuration = Duration(milliseconds: 200);

const Color _kBlack = Color(0xFF000000);
const Color _kWhite = Color(0xFFFFFFFF);

/// An on/off switch that looks like the switch in macOS 26 and 27 System
/// Settings.
///
/// At rest it is a capsule track with a capsule knob that is wider than it
/// is tall. [size] picks the 36x16 switch of a settings row (the default) or
/// the 44x20 switch that System Settings uses for the main switch of a pane.
/// It is painted with a [CustomPainter], so it needs no platform view and no
/// font.
///
/// Like `NSSwitch`:
///
///  * Clicking or tapping toggles the value.
///  * The knob follows a drag. Letting go past the middle flips the value.
///  * Space or Enter toggles a switch that has keyboard focus, which shows a
///    focus ring around the track.
///  * A drag that starts vertically is left to the enclosing scroll view.
///
/// The switch does not keep its own state. [onChanged] is called with the
/// new value, and the parent rebuilds it with that value. If [onChanged] is
/// null, the switch is disabled: its track is drawn paler and it ignores
/// input.
///
/// The ON track is the macOS accent blue (#007AFF, drawn as System Settings
/// renders it) and the OFF track is a 10% black (light) or white (dark)
/// fill, unless [activeTrackColor] or [inactiveTrackColor] is set. Light or
/// dark comes from the [CupertinoTheme], or from the platform brightness
/// when the theme does not set one.
///
/// The widget takes exactly the track size. The focus ring paints 3 points
/// outside it, so do not clip the switch tightly.
class MacosSettingsSwitch extends StatefulWidget {
  /// Creates a macOS System Settings style switch.
  const MacosSettingsSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeTrackColor,
    this.inactiveTrackColor,
    this.size = MacosSettingsSwitchSize.regular,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the new value when the user toggles the switch.
  ///
  /// If null, the switch is disabled.
  final ValueChanged<bool>? onChanged;

  /// The track color when the switch is on.
  ///
  /// Defaults to the macOS accent blue: #0476F7 in light mode and #117BFC in
  /// dark mode, the colors System Settings draws `controlAccentColor` with.
  final Color? activeTrackColor;

  /// The track color when the switch is off.
  ///
  /// Defaults to black at 10% in light mode and white at 10% in dark mode, so
  /// it adapts to the card behind it.
  final Color? inactiveTrackColor;

  /// The 36x16 row switch ([MacosSettingsSwitchSize.regular], the default)
  /// or the 44x20 main switch of a pane ([MacosSettingsSwitchSize.large]).
  final MacosSettingsSwitchSize size;

  @override
  State<MacosSettingsSwitch> createState() => _MacosSettingsSwitchState();

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
    properties.add(EnumProperty<MacosSettingsSwitchSize>('size', size));
  }
}

class _MacosSettingsSwitchState extends SettingsSwitchState<MacosSettingsSwitch>
    with SingleTickerProviderStateMixin, SettingsSwitchKnobDrag {
  /// 0 = knob at the OFF end, 1 = knob at the ON end.
  @override
  late final AnimationController position = AnimationController(
    vsync: this,
    value: widget.value ? 1 : 0,
  );

  bool _pressed = false;

  @override
  bool get value => widget.value;

  @override
  ValueChanged<bool>? get onChanged => widget.onChanged;

  _Metrics get _metrics => _Metrics.of(widget.size);

  @override
  double get travel => _metrics.travel;

  @override
  void didUpdateWidget(MacosSettingsSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    // While dragging, the pointer owns the knob. It settles on release.
    if (oldWidget.value != widget.value && !dragging) {
      _animateTo(widget.value);
    }
    if (!enabled && (dragging || _pressed)) {
      dragging = false;
      _pressed = false;
      _animateTo(widget.value);
    }
  }

  @override
  void dispose() {
    position.dispose();
    super.dispose();
  }

  void _animateTo(bool value) {
    final double target = value ? 1 : 0;
    animate(
      position,
      target,
      duration: _kToggleDuration * (position.value - target).abs(),
      curve: Curves.easeInOut,
    );
  }

  @override
  void setPressed(bool pressed) {
    if (_pressed != pressed) setState(() => _pressed = pressed);
  }

  @override
  void settleDrag(bool newValue) {
    setPressed(false);
    _animateTo(newValue);
    if (newValue != widget.value) {
      widget.onChanged?.call(newValue);
      // If the parent does not take the new value, go back to the old one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !dragging && widget.value != newValue) {
          _animateTo(widget.value);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = switchBrightnessOf(context) == Brightness.dark;

    return buildSwitch(
      onTapDown: (_) => setPressed(true),
      onTapUp: (_) => setPressed(false),
      onTapCancel: () => setPressed(false),
      size: _metrics.trackSize,
      painter: _MacosSwitchPainter(
        position: position,
        metrics: _metrics,
        activeColor:
            widget.activeTrackColor ??
            (isDark ? _kOnTrackDark : _kOnTrackLight),
        inactiveColor:
            widget.inactiveTrackColor ??
            (isDark ? _kOffTrackDark : _kOffTrackLight),
        isDark: isDark,
        enabled: enabled,
        pressed: _pressed,
        textDirection: textDirection,
        focusColor: showFocusRing
            ? (isDark ? _kFocusDark : _kFocusLight)
            : null,
      ),
    );
  }
}

class _MacosSwitchPainter extends SettingsSwitchPainter {
  _MacosSwitchPainter({
    required this.position,
    required this.metrics,
    required this.activeColor,
    required this.inactiveColor,
    required this.isDark,
    required this.enabled,
    required this.pressed,
    required super.textDirection,
    required this.focusColor,
  }) : super(repaint: position);

  final Animation<double> position;
  final _Metrics metrics;
  final Color activeColor;
  final Color inactiveColor;
  final bool isDark;
  final bool enabled;
  final bool pressed;
  final Color? focusColor;

  @override
  void paintSwitch(Canvas canvas, Size size) {
    final double t = position.value.clamp(0.0, 1.0);
    final Rect track = centerTrack(
      size,
      metrics.trackWidth,
      metrics.trackHeight,
    );

    Color trackColor = Color.lerp(inactiveColor, activeColor, t)!;
    if (!enabled) {
      trackColor = Color.lerp(
        trackColor,
        (isDark ? _kDisabledTrackFadeDark : _kDisabledTrackFadeLight)
            .withValues(alpha: trackColor.a),
        _kDisabledTrackFade,
      )!;
      trackColor = trackColor.withValues(
        alpha: trackColor.a * _kDisabledTrackOpacity,
      );
    }
    canvas.drawRRect(_capsule(track), Paint()..color = trackColor);

    if (focusColor != null) {
      canvas.drawRRect(
        _capsule(track.inflate(_kFocusRingWidth / 2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _kFocusRingWidth
          ..color = focusColor!,
      );
    }

    final Rect knob = Rect.fromLTWH(
      track.left + metrics.inset + t * metrics.travel,
      track.top + metrics.inset,
      metrics.knobWidth,
      metrics.knobHeight,
    );

    // A soft shadow under the knob. It darkens the track next to the knob
    // and shows a little below the track.
    canvas.drawRRect(
      _capsule(knob.shift(const Offset(0, 0.5))),
      Paint()
        ..color = _kBlack.withValues(
          alpha: (isDark ? 0.35 : 0.2) * (enabled ? 1 : 0.5),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    final double knobTint =
        _kKnobOnTintDark * (enabled ? 1 : _kDisabledKnobTint);
    Color knobColor = isDark
        ? Color.lerp(
            _kKnobOffDark,
            Color.lerp(_kWhite, activeColor, knobTint),
            t,
          )!
        : _kKnobLight;
    if (pressed) {
      knobColor = Color.lerp(knobColor, _kBlack, isDark ? 0.08 : 0.06)!;
    }
    canvas.drawRRect(_capsule(knob), Paint()..color = knobColor);
  }

  @override
  bool shouldRepaint(_MacosSwitchPainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.metrics != metrics ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.isDark != isDark ||
        oldDelegate.enabled != enabled ||
        oldDelegate.pressed != pressed ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.focusColor != focusColor;
  }
}

RRect _capsule(Rect rect) =>
    RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide / 2));
