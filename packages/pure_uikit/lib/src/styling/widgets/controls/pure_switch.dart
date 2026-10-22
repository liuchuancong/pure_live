import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The kit's switch: one widget that draws the real shape of the control in
/// every `PureDesignLanguage` — the Material 3 pill whose circular handle
/// grows toward the thumb side, carries the tick and stretches into a
/// teardrop on press, the iOS stadium with its springing white knob, the
/// slimmer macOS accent rail, the WinUI rounded-rect with its border and
/// inset knob, the Ubuntu pill with its flat knob, the shadcn (and its wind
/// sibling's) crisp high-contrast track, a frosted stadium with a luminous
/// knob under glass, and an extruded track whose knob sits pressed-in when
/// off and raised when on under neumorphic. All of it is painted here, from
/// the theme's own tokens — colours, radii, geometry and motion — because
/// the nine widget libraries the kit otherwise dispatches to answer to nine
/// different accents, focus contracts and disabled alphabets; drawn once
/// here, one interaction contract holds everywhere: a null `onChanged`
/// renders the switch disabled, hover and pressed tint the track, focus
/// draws the kit's ring, Space and Enter toggle, and a screen reader hears
/// the same `toggled` state in every language. Switching `UiConfig.language`
/// re-skins every switch.
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
      // A null callback is every language's own inert state, so folding
      // `enabled` into it once gives the core a single verdict.
      select: enabled ? onChanged : null,
      visual: switch (language) {
        // Material 3 and the iOS/macOS rail each draw their own geometry.
        PureDesignLanguage.material => _SwitchVisual.material(theme),
        PureDesignLanguage.cupertino => _SwitchVisual.cupertino(theme),
        PureDesignLanguage.macos => _SwitchVisual.macos(theme),
        PureDesignLanguage.fluent => _SwitchVisual.fluent(theme),
        PureDesignLanguage.yaru => _SwitchVisual.yaru(theme),
        // The tab bar folds wind into the material/forui utility-class
        // grammar it shares with them; the switch keeps that family tie and
        // draws the same crisp, high-contrast pill.
        PureDesignLanguage.forui || PureDesignLanguage.wind => _SwitchVisual.forui(theme),
        // Glass and neumorphic are intentionally distinctive languages, so
        // the switch answers to their own materials rather than a role.
        PureDesignLanguage.glass => _SwitchVisual.glass(theme),
        PureDesignLanguage.neumorphic => _SwitchVisual.neumorphic(theme),
      },
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel,
    );
  }
}

/// The geometry, colours and motion one language puts on the track and the
/// knob. Everything is resolved from the theme when the switch builds, so a
/// language re-skin, a dark switch and the user's motion settings all come
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
    required this.trackShadow,
    required this.checkColor,
    this.knobGrown = 0,
    this.knobStretch = 0,
    this.borderWidth = 0,
    this.showsCheck = false,
    this.frosted = false,
  });

  /// Material 3: a pill track with a two-width outline when off; the circular
  /// handle grows toward the thumb side when on (with the tick inside it, per
  /// the spec), stretches into a teardrop toward the side it travels from
  /// while pressed, and the whole control drops to 38% alpha when disabled.
  factory material(PureTheme theme) {
    final base = theme.switchToken;
    return _SwitchVisual(
      width: base.width,
      height: base.height,
      knob: base.handleSize - 6,
      knobGrown: 8,
      knobStretch: 6,
      margin: 3,
      radius: BorderRadius.circular(PureRadii.pill),
      curve: Curves.easeOutCubic,
      disabledAlpha: 0.38,
      trackColor: ({required on, required hovered, required pressed}) => on
          ? _accentState(theme, hovered: hovered, pressed: pressed)
          : _stateLayer(theme.colors.bgContainer, theme, hovered: hovered, pressed: pressed),
      borderColor: ({required on}) => on ? null : theme.colors.border,
      borderWidth: theme.token.motion.lineWidth * 2,
      knobColor: ({required on}) => on ? theme.colors.primaryBg : theme.colors.border,
      checkColor: theme.colors.primary,
      knobShadow: ({required on}) => const [],
      trackShadow: null,
      showsCheck: true,
    );
  }

  /// iOS: the grey stadium that turns the success green when on, under a
  /// white knob with its subtle drop shadow, sliding with the iOS overshoot.
  factory cupertino(PureTheme theme) {
    final base = theme.switchToken;
    final height = base.height;
    return _SwitchVisual(
      width: height * 1.65,
      height: height,
      knob: height - 4,
      margin: 2,
      radius: BorderRadius.circular(PureRadii.pill),
      curve: Curves.easeOutBack,
      disabledAlpha: base.disabledOpacity,
      trackColor: ({required on, required hovered, required pressed}) => _stateLayer(
        on ? theme.colors.success : theme.colors.fillSecondary,
        theme,
        hovered: hovered,
        pressed: pressed,
      ),
      borderColor: ({required on}) => null,
      knobColor: ({required on}) => base.handleColor,
      checkColor: null,
      knobShadow: ({required on}) => theme.token.motion.boxShadowTertiary,
      trackShadow: null,
    );
  }

  /// macOS: the slimmer rail — the accent fill when on, a hairline-bordered
  /// light well when off — with the white knob and, as on the real control,
  /// no checkmark.
  factory macos(PureTheme theme) {
    final base = theme.switchToken;
    final height = base.height - 4;
    return _SwitchVisual(
      width: height * 1.9,
      height: height,
      knob: height - 4,
      margin: 2,
      radius: BorderRadius.circular(PureRadii.pill),
      curve: Curves.easeOutCubic,
      disabledAlpha: base.disabledOpacity,
      trackColor: ({required on, required hovered, required pressed}) => on
          ? _accentState(theme, hovered: hovered, pressed: pressed)
          : _stateLayer(theme.colors.bgElevated, theme, hovered: hovered, pressed: pressed),
      borderColor: ({required on}) => on ? null : theme.colors.borderSecondary,
      borderWidth: theme.token.motion.lineWidth,
      knobColor: ({required on}) => base.handleColor,
      checkColor: null,
      knobShadow: ({required on}) => theme.token.motion.boxShadow,
      trackShadow: null,
    );
  }

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
      checkColor: null,
      knobShadow: ({required on}) => const [],
      trackShadow: null,
    );
  }

  /// Ubuntu: the wide, dark pill, the flat round knob, the accent when on,
  /// and the full rounding its tab-bar sibling asks the language for.
  factory yaru(PureTheme theme) {
    final base = theme.switchToken;
    return _SwitchVisual(
      width: base.width - 2,
      height: base.height,
      knob: base.height - 6,
      margin: 3,
      radius: BorderRadius.circular(PureRadii.pill),
      curve: Curves.easeOutCubic,
      disabledAlpha: base.disabledOpacity,
      trackColor: ({required on, required hovered, required pressed}) => on
          ? _accentState(theme, hovered: hovered, pressed: pressed)
          : _stateLayer(base.uncheckedColor, theme, hovered: hovered, pressed: pressed),
      borderColor: ({required on}) => null,
      knobColor: ({required on}) => base.handleColor,
      checkColor: null,
      knobShadow: ({required on}) => const [],
      trackShadow: null,
    );
  }

  /// shadcn: the high-contrast track with its crisp hairline border and the
  /// small round knob — the same utility-class grammar the wind branch draws
  /// beside it.
  factory forui(PureTheme theme) {
    final base = theme.switchToken;
    final height = base.height - 4;
    return _SwitchVisual(
      width: height * 1.9,
      height: height,
      knob: height - 6,
      margin: 3,
      radius: BorderRadius.circular(PureRadii.pill),
      curve: Curves.easeOutCubic,
      disabledAlpha: base.disabledOpacity,
      trackColor: ({required on, required hovered, required pressed}) => on
          ? _accentState(theme, hovered: hovered, pressed: pressed)
          : _stateLayer(theme.colors.bgContainer, theme, hovered: hovered, pressed: pressed),
      borderColor: ({required on}) => on ? theme.colors.primary : theme.colors.border,
      borderWidth: theme.token.motion.lineWidth,
      knobColor: ({required on}) => base.handleColor,
      checkColor: null,
      knobShadow: ({required on}) => const [],
      trackShadow: null,
    );
  }

  /// Glass: the frosted stadium — a real backdrop blur when the device can
  /// afford it, the pure colour ramp when it cannot — with the accent laid
  /// into the frost when on and a luminous white knob.
  factory glass(PureTheme theme) {
    final base = theme.switchToken;
    Color frost({required bool hovered, required bool pressed}) {
      final alpha = pressed
          ? (theme.isDark ? 0.2 : 0.68)
          : hovered
          ? (theme.isDark ? 0.14 : 0.62)
          : (theme.isDark ? 0.08 : 0.55);
      return Colors.white.withValues(alpha: alpha);
    }

    return _SwitchVisual(
      width: base.width,
      height: base.height,
      knob: base.height - 6,
      margin: 3,
      radius: BorderRadius.circular(PureRadii.pill),
      curve: Curves.easeOutCubic,
      disabledAlpha: base.disabledOpacity,
      trackColor: ({required on, required hovered, required pressed}) {
        final frosted = frost(hovered: hovered, pressed: pressed);
        return on ? Color.lerp(frosted, theme.colors.primary.withValues(alpha: 0.6), 0.55)! : frosted;
      },
      borderColor: ({required on}) =>
          theme.isDark ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.7),
      borderWidth: theme.token.motion.lineWidth,
      knobColor: ({required on}) => Colors.white,
      checkColor: null,
      knobShadow: ({required on}) => [
        BoxShadow(color: (on ? theme.colors.primary : Colors.white).withValues(alpha: 0.55), blurRadius: 10),
      ],
      trackShadow: null,
      frosted: true,
    );
  }

  /// Neumorphic: the extruded track (light from the top left, shadow from
  /// the bottom right) and a knob pressed into the mould while off, raised
  /// out of it and carrying the accent when on.
  factory neumorphic(PureTheme theme) {
    final base = theme.switchToken;
    List<BoxShadow> raised() => [
      BoxShadow(color: theme.colors.shadowBase, blurRadius: 6, offset: const Offset(3, 3)),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.8),
        blurRadius: 6,
        offset: const Offset(-3, -3),
      ),
    ];
    List<BoxShadow> sunk() => [
      for (final shadow in raised())
        BoxShadow(color: shadow.color, blurRadius: shadow.blurRadius, offset: -shadow.offset),
    ];
    return _SwitchVisual(
      width: base.width,
      height: base.height,
      knob: base.height - 8,
      margin: 4,
      radius: BorderRadius.circular(PureRadii.pill),
      curve: Curves.easeOutCubic,
      disabledAlpha: base.disabledOpacity,
      trackColor: ({required on, required hovered, required pressed}) => _stateLayer(
        on ? theme.colors.primaryBg : theme.colors.bgContainer,
        theme,
        hovered: hovered,
        pressed: pressed,
      ),
      borderColor: ({required on}) => null,
      knobColor: ({required on}) => on ? theme.colors.primary : theme.colors.bgContainer,
      checkColor: null,
      knobShadow: ({required on}) => on ? raised() : sunk(),
      trackShadow: raised(),
    );
  }

  /// The track's width.
  final double width;

  /// The track's height.
  final double height;

  /// The knob's diameter while off.
  final double knob;

  /// The knob's extra diameter while on; the languages whose handle grows
  /// into the filled side (Material 3) carry a value, the rest zero.
  final double knobGrown;

  /// The knob's extra width while pressed; the language whose teardrop the
  /// drag stretches carries a value, the rest zero.
  final double knobStretch;

  /// The gap between the knob and the track edge it rests against.
  final double margin;

  /// The track's corner radius; a language whose rail reads as a rounded
  /// rectangle rather than a stadium gives its own radius here.
  final BorderRadius radius;

  /// The curve the knob slides and the colours fade on; the iOS branch picks
  /// its springy overshoot, the rest settle without one.
  final Curve curve;

  /// The opacity of a disabled switch; Material 3 answers with its spec's 38
  /// percent, the others with the token's loading opacity.
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

  /// The colour of the tick the handle carries when on, for the languages
  /// whose handle draws one.
  final Color? checkColor;

  /// The knob's shadows: the raised languages' drop shadow, the pressed-in
  /// languages' sunk mould, the glass language's glow.
  final List<BoxShadow> Function({required bool on}) knobShadow;

  /// The track's own shadows; only the extruded languages carry any.
  final List<BoxShadow>? trackShadow;

  /// Whether the handle carries the check icon when on.
  final bool showsCheck;

  /// Whether the track frosts the page behind it through a backdrop filter.
  final bool frosted;

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

  /// A neutral surface's state layer: the hover and pressed tints every
  /// language's track answers with, mixed over its own base colour.
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
/// kit's focus ring, Space/Enter activation and the toggle semantics every
/// language shares.
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

    // The knob's live geometry: grown into the filled side when the language
    // asks (Material 3), stretched toward the side it travels from while the
    // finger still holds it down (the drag's teardrop).
    final knobHeight = visual.knob + (on ? visual.knobGrown : 0);
    final knobWidth = knobHeight + (pressed ? visual.knobStretch : 0);
    final left = on ? visual.width - knobWidth - visual.margin : visual.margin;
    final outline = visual.borderColor(on: on);

    final track = AnimatedContainer(
      duration: theme.duration,
      curve: visual.curve,
      decoration: BoxDecoration(
        color: visual.trackColor(on: on, hovered: hovered, pressed: pressed),
        borderRadius: visual.radius,
        boxShadow: visual.trackShadow,
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
    final trackLayer = !visual.frosted || !theme.canBlur
        ? track
        : ClipRRect(
            borderRadius: visual.radius,
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: track),
          );

    final shape = SizedBox(
      width: visual.width,
      height: visual.height,
      child: Stack(
        // The iOS overshoot runs the knob a hair past the rail for a frame;
        // clipping it there would stop the spring dead.
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: trackLayer),
          AnimatedPositioned(
            duration: theme.duration,
            curve: visual.curve,
            left: left,
            top: (visual.height - knobHeight) / 2,
            child: AnimatedContainer(
              duration: theme.duration,
              curve: visual.curve,
              width: knobWidth,
              height: knobHeight,
              alignment: AlignmentDirectional.center,
              decoration: BoxDecoration(
                color: visual.knobColor(on: on),
                borderRadius: BorderRadius.circular(PureRadii.pill),
                boxShadow: visual.knobShadow(on: on),
              ),
              child: visual.showsCheck && on
                  ? Icon(Icons.check, size: knobHeight * 0.7, color: visual.checkColor)
                  : null,
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
