import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The kit's switch: one widget that draws the real shape of the control in
/// the WinUI ToggleSwitch grammar — the rounded-rect rail with its border, the
/// knob sliding inside it with a margin, the accent filling on, and hover and
/// pressed answering on the accent itself. All of it is painted here, from
/// the theme's own tokens — colours, radii, geometry and motion; drawn once
/// here, one interaction contract holds: a null `onChanged`
/// renders the switch disabled, hover and pressed tint the track, focus
/// draws the kit's ring, Space and Enter toggle, and a screen reader hears
/// the same `toggled` state.
class PureSwitch extends StatelessWidget {
  /// A switch bound to [value].
  const new({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    super.key,
  });

  /// Whether the switch is on.
  final bool value;

  /// Called with the next value; null (or `enabled: false`) renders the
  /// switch disabled and swallows every tap.
  final ValueChanged<bool>? onChanged;

  /// Whether the switch responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// The name a screen reader reads beside the toggle state; the switch
  /// itself carries no text to be read.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    return _SwitchCore(
      // The branch a switch draws is its identity in tests and diagnostics.
      key: ValueKey('PureSwitch.${language.name}'),
      value: value,
      // A null callback is the inert state, so folding `enabled` into it once
      // gives the core a single verdict.
      select: enabled ? onChanged : null,
      visual: _SwitchVisual.fluent(theme),
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel,
    );
  }
}

/// The geometry, colours and motion the track and the
/// knob are drawn with. Everything is resolved from the theme when the switch
/// builds, so a dark switch and the user's motion settings all come
/// out of the same tokens the kit's other controls read.
@immutable
final class _SwitchVisual {
  /// A switch visual.
  const new({
    required this.width,
    required this.height,
    required this.knob,
    required this.margin,
    required this.radius,
    required this.curve,
    required this.disabledAlpha,
    required this.trackColor,
    required this.borderColor,
    required this.knobColor,
    required this.knobShadow,
    required this.borderWidth,
  });

  /// WinUI's ToggleSwitch: the rounded-rect rail with its border, the knob
  /// sliding inside it with a margin, the accent filling on, and hover and
  /// pressed answering on the accent itself — the on-content states the
  /// control is known for.
  factory fluent(PureTheme theme) {
    final base = theme.switchToken;
    final height = base.height - 2;
    return _SwitchVisual(
      width: base.width - 4,
      height: height,
      knob: height - 8,
      margin: 4,
      radius: BorderRadius.circular(theme.token.scale.radii.sm),
      curve: Curves.easeOutCubic,
      disabledAlpha: base.disabledOpacity,
      trackColor: ({required on, required hovered, required pressed}) => on
          ? _accentState(theme, hovered: hovered, pressed: pressed)
          : _stateLayer(theme.colors.fillSecondary, theme, hovered: hovered, pressed: pressed),
      borderColor: ({required on}) => on ? null : theme.colors.borderSecondary,
      borderWidth: theme.token.motion.lineWidth,
      knobColor: ({required on}) => base.handleColor,
      knobShadow: ({required on}) => const [],
    );
  }

  /// The track's width.
  final double width;

  /// The track's height.
  final double height;

  /// The knob's diameter.
  final double knob;

  /// The gap between the knob and the track edge it rests against.
  final double margin;

  /// The track's corner radius; the rail reads as a rounded
  /// rectangle rather than a stadium.
  final BorderRadius radius;

  /// The curve the knob slides and the colours fade on.
  final Curve curve;

  /// The opacity of a disabled switch.
  final double disabledAlpha;

  /// The track colour for the toggle state plus the hover and pressed tints.
  final Color Function({required bool on, required bool hovered, required bool pressed}) trackColor;

  /// The track's outline colour; null draws no outline (and the width is then
  /// unread).
  final Color? Function({required bool on}) borderColor;

  /// The track's outline width.
  final double borderWidth;

  /// The knob colour for the toggle state.
  final Color Function({required bool on}) knobColor;

  /// The knob's shadows.
  final List<BoxShadow> Function({required bool on}) knobShadow;

  /// The accent track's hover and pressed states, straight from the primary
  /// role's own tokens.
  static Color _accentState(PureTheme theme, {required bool hovered, required bool pressed}) {
    if (pressed) {
      return theme.colors.primaryActive;
    }
    if (hovered) {
      return theme.colors.primaryHover;
    }
    return theme.colors.primary;
  }

  /// A neutral surface's state layer: the hover and pressed tints the track
  /// answers with, mixed over its own base colour.
  static Color _stateLayer(Color base, PureTheme theme, {required bool hovered, required bool pressed}) {
    if (pressed) {
      return Color.lerp(base, theme.colors.shadowBase, 0.16)!;
    }
    if (hovered) {
      return Color.lerp(base, theme.colors.shadowBase, 0.08)!;
    }
    return base;
  }
}

/// The switch's body: the two animated layers (track and sliding knob) under
/// one interaction contract — hover and pressed tints, disabled alpha, the
/// kit's focus ring, Space/Enter activation and the toggle semantics.
class _SwitchCore extends StatefulWidget {
  const new({
    required this.value,
    required this.select,
    required this.visual,
    required this.focusNode,
    required this.autofocus,
    required this.semanticLabel,
    super.key,
  });

  final bool value;

  /// The live callback; null is the disabled verdict the public widget has
  /// already folded `enabled` into.
  final ValueChanged<bool>? select;

  final _SwitchVisual visual;

  final FocusNode? focusNode;

  final bool autofocus;

  final String? semanticLabel;

  @override
  State<_SwitchCore> createState() => _SwitchCoreState();
}

class _SwitchCoreState extends State<_SwitchCore> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  bool get _live => widget.select != null;

  void _toggle() {
    if (_live) {
      widget.select!(!widget.value);
    }
  }

  /// Space and Enter toggle the switch, the same activation keys the kit's
  /// other controls answer to; anything else is left to the shell.
  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final activate = {LogicalKeyboardKey.space, LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter};
    if (!activate.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    _toggle();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = widget.visual;
    final live = _live;
    final on = widget.value;
    final hovered = _hovered && live;
    final pressed = _pressed && live;

    final left = on ? visual.width - visual.knob - visual.margin : visual.margin;
    final outline = visual.borderColor(on: on);

    final track = AnimatedContainer(
      duration: theme.duration,
      curve: visual.curve,
      decoration: BoxDecoration(
        color: visual.trackColor(on: on, hovered: hovered, pressed: pressed),
        borderRadius: visual.radius,
        border: outline != null ? Border.all(color: outline, width: visual.borderWidth) : null,
      ),
      // The kit's focus ring: the primary role at the other controls' width,
      // drawn over the track rather than around a wrapper.
      foregroundDecoration: _focused && live
          ? BoxDecoration(
              borderRadius: visual.radius,
              border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: 2)),
            )
          : null,
    );

    final shape = SizedBox(
      width: visual.width,
      height: visual.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: track),
          AnimatedPositioned(
            duration: theme.duration,
            curve: visual.curve,
            left: left,
            top: (visual.height - visual.knob) / 2,
            child: AnimatedContainer(
              duration: theme.duration,
              curve: visual.curve,
              width: visual.knob,
              height: visual.knob,
              alignment: AlignmentDirectional.center,
              decoration: BoxDecoration(
                color: visual.knobColor(on: on),
                borderRadius: BorderRadius.circular(PureRadii.pill),
                boxShadow: visual.knobShadow(on: on),
              ),
            ),
          ),
        ],
      ),
    );

    return Focus(
      focusNode: widget.focusNode,
      debugLabel: 'PureSwitch',
      canRequestFocus: live,
      autofocus: widget.autofocus && live,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _handleKey,
      child: MouseRegion(
        cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Builder(
          builder: (inner) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: live ? _toggle : null,
            onTapDown: live
                ? (_) {
                    Focus.of(inner).requestFocus();
                    setState(() => _pressed = true);
                  }
                : null,
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: Semantics(
              // The container keeps the toggle its own semantics node, so the
              // off and disabled flags name the control instead of merging
              // into whatever surface hosts it.
              container: true,
              toggled: on,
              enabled: live,
              inMutuallyExclusiveGroup: true,
              label: widget.semanticLabel,
              child: ExcludeSemantics(
                child: AnimatedOpacity(
                  duration: theme.duration,
                  opacity: live ? 1 : visual.disabledAlpha,
                  child: shape,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
