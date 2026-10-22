import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The design sheet's checkbox: one small square of agreement, drawn in every
/// design language. Where the tab bar slides a pill, this ticks — the M3
/// rounded square with its 2px outline and circular state-layer halo under
/// material, the iOS 17+ list-row circle under cupertino (the circle Settings
/// ships today, chosen over the legacy square tick — the note is the shape,
/// not the tick), Ubuntu's fatter check on the distribution accent under yaru,
/// the top-lit accent control of macOS, the WinUI box with its flat-cut,
/// right-leaning checkmark under fluent, the inverted ink square forui and
/// wind share, a frosted square that blurs what sits behind it under glass,
/// and a pressed-in well that swallows its own accent tick under neumorphic.
/// All of it is painted here, because a box that must speak nine grammars off
/// one token set is exactly what the nine libraries refuse to share; the
/// colours, radii, motion and text come from the tokens, so a language
/// re-skin and a dark switch still come out right.
///
/// Every visual answers to the same interaction contract: hover and pressed
/// tints, a disabled box (a null `onChanged` or `enabled: false`) that greys
/// out and answers nothing, the kit's focus ring with Space (and Enter, and
/// the remote's select keys) choosing while the box holds focus,
/// `checked`/`enabled` screen-reader traits on every box, and a tick that
/// scales and fades in on the token's fast motion. The value type is a plain
/// `bool` — the contract carries no mixed state — so the M3 indeterminate
/// dash has nothing to draw and is deliberately absent.
class PureCheckbox extends StatelessWidget {
  /// A checkbox bound to [value].
  const new({
    required this.value,
    required this.onChanged,
    this.label,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// Whether the box is checked.
  final bool value;

  /// Called with the next value; null (or `enabled: false`) disables it.
  final ValueChanged<bool>? onChanged;

  /// An optional trailing label.
  final String? label;

  /// Whether the box responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final select = onChanged;
    return _CheckboxBox(
      visual: _BoxVisual.resolve(theme),
      value: value,
      live: enabled && select != null,
      // The next state of a box is its own opposite; a box with nothing to
      // call never speaks, and the control guards the rest.
      toggle: () => select?.call(!value),
      label: label,
      // The label rides the body role: a checkbox sits in running text, not
      // in a button's tight line.
      labelStyle: theme.text.body.copyWith(color: theme.colors.text),
      gap: theme.token.scale.sizes.sm,
      focusNode: focusNode,
      autofocus: autofocus,
    );
  }
}

/// How one design language paints the box: its edge and corner, the two
/// states' surfaces, the tick's own geometry, the halo that answers a hover,
/// the motion's ink, the dim a disabled box falls to, and whether the surface
/// is frosted. Every value is a function of the resolved theme, so a dark
/// switch or an accent change re-skins the branch without a rebuild of it.
@immutable
final class _BoxVisual {
  const new({
    required this.boxSize,
    required this.radius,
    required this.face,
    required this.halo,
    required this.haloGrow,
    required this.haloRadius,
    required this.tick,
    required this.tickCap,
    required this.tickWeight,
    required this.tickColor,
    required this.disabledAlpha,
    required this.frosted,
  });

  /// Android Material's M3 checkbox: a rounded square with a 2px outline,
  /// the accent fill and white check when checked, the tick scaled in, and
  /// the circular state layer behind it that M3 tints on hover and press.
  /// The indeterminate dash M3 also ships has no here to show — the contract
  /// is a plain `bool` with no mixed state — so only the two faces exist.
  factory material() {
    BorderRadius corner(PureTheme theme) => BorderRadius.circular(theme.token.scale.radii.xs);
    return _BoxVisual(
      boxSize: (theme) => theme.checkbox.boxSize,
      radius: corner,
      face: (theme, {required checked, required hovered, required pressed, required live}) {
        if (checked) {
          return BoxDecoration(
            color: pressed
                ? theme.colors.primaryActive
                : hovered
                ? theme.colors.primaryHover
                : theme.colors.primary,
            borderRadius: corner(theme),
          );
        }
        return BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: corner(theme),
          // M3 leaves the empty box outlined rather than filled; the outline
          // darkens towards the text colour as the pointer arrives.
          border: Border.all(color: pressed || hovered ? theme.colors.text : theme.colors.border, width: 2),
        );
      },
      halo: (theme, {required checked, required hovered, required pressed}) {
        if (checked) {
          return null;
        }
        if (pressed) {
          return theme.colors.primary.withValues(alpha: 0.12);
        }
        if (hovered) {
          return theme.colors.primary.withValues(alpha: 0.08);
        }
        return null;
      },
      // The state layer is a 40dp circle around the 18dp M3 box, so it grows
      // well past the edge — unlike every other language here.
      haloGrow: 12,
      haloRadius: (_) => BorderRadius.circular(PureRadii.pill),
      tick: _check(0.22, 0.51, 0.42, 0.70, 0.80, 0.30),
      tickCap: StrokeCap.round,
      tickWeight: 0.14,
      tickColor: onAccent,
      // M3's disabled ink is 38%, the spec's number, not the token ramp's.
      disabledAlpha: (_) => 0.38,
      frosted: false,
    );
  }

  /// iOS's list-row checkbox: a circle, the accent fill and white check when
  /// on, a bare grey ring when off, and no halo anywhere — iOS answers a
  /// press in the fill itself, and a pointer is a foreign concept on a phone.
  factory cupertino() {
    BorderRadius circle(PureTheme theme) => BorderRadius.circular(PureRadii.pill);
    return _BoxVisual(
      // The list row's target is a touch larger than the token box; iOS
      // circles are read at 20, not 16.
      boxSize: (theme) => theme.checkbox.boxSize + theme.token.scale.sizes.xxs,
      radius: circle,
      face: (theme, {required checked, required hovered, required pressed, required live}) {
        if (checked) {
          return BoxDecoration(
            color: pressed ? theme.colors.primaryActive : theme.colors.primary,
            borderRadius: circle(theme),
          );
        }
        return BoxDecoration(
          borderRadius: circle(theme),
          border: Border.all(
            color: pressed || hovered ? theme.colors.textTertiary : theme.colors.borderSecondary,
            width: 2,
          ),
        );
      },
      halo: (_, {required checked, required hovered, required pressed}) => null,
      haloGrow: 0,
      haloRadius: circle,
      tick: _check(0.26, 0.52, 0.43, 0.68, 0.75, 0.34),
      tickCap: StrokeCap.round,
      tickWeight: 0.13,
      tickColor: onAccent,
      disabledAlpha: (theme) => theme.checkbox.disabledOpacity,
      frosted: false,
    );
  }

  /// macOS's checkbox: the small rounded square, the accent fill carrying a
  /// subtle top-light gradient (light lands from above, the flat accent sits
  /// below), the white check, and a hairline-shaded empty box — the control
  /// grammar `MacosCheckbox` is known for, painted from the tokens.
  factory macos() {
    BorderRadius corner(PureTheme theme) => BorderRadius.circular(theme.token.scale.radii.xs);
    return _BoxVisual(
      // The macOS box runs a hair under the token edge; its controls are the
      // small ones of the platform.
      boxSize: (theme) => theme.checkbox.boxSize - 2 * theme.token.motion.lineWidth,
      radius: corner,
      face: (theme, {required checked, required hovered, required pressed, required live}) {
        if (checked) {
          final base = pressed
              ? theme.colors.primaryActive
              : hovered
              ? theme.colors.primaryHover
              : theme.colors.primary;
          return BoxDecoration(
            borderRadius: corner(theme),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topCenter,
              end: AlignmentDirectional.bottomCenter,
              colors: [
                // The crown of light the accent controls carry; kept subtle
                // in the dark, where the fill is already the brightest thing.
                Color.lerp(base, theme.colors.white, theme.isDark ? 0.08 : 0.28)!,
                base,
              ],
            ),
            border: Border.all(color: base),
          );
        }
        return BoxDecoration(
          color: pressed
              ? theme.colors.fill
              : hovered
              ? theme.colors.fillQuaternary
              : theme.colors.bgContainer,
          borderRadius: corner(theme),
          border: Border.all(color: theme.colors.border),
        );
      },
      halo: (_, {required checked, required hovered, required pressed}) => null,
      haloGrow: 0,
      haloRadius: corner,
      tick: _check(0.22, 0.50, 0.40, 0.68, 0.80, 0.28),
      tickCap: StrokeCap.round,
      // The check is heavier than the box is wide: macOS cuts it bold.
      tickWeight: 0.2,
      tickColor: onAccent,
      disabledAlpha: (theme) => theme.checkbox.disabledOpacity,
      frosted: false,
    );
  }

  /// Windows Fluent's WinUI checkbox: the rounded 3px square (the corner is
  /// the identity, a flat absolute like the tab bar's ink strip), a full
  /// hairline around the empty box, the accent fill when checked, and the
  /// WinUI checkmark — a short lead-in that bottoms out low, a long exit
  /// stroke that leaves high, both cut flat rather than rounded.
  factory fluent() {
    const corner = BorderRadius.all(Radius.circular(3));
    BorderRadius rounded(PureTheme theme) => corner;
    return _BoxVisual(
      boxSize: (theme) => theme.checkbox.boxSize,
      radius: rounded,
      face: (theme, {required checked, required hovered, required pressed, required live}) {
        if (checked) {
          final fill = pressed
              ? theme.colors.primaryActive
              : hovered
              ? theme.colors.primaryHover
              : theme.colors.primary;
          return BoxDecoration(
            color: fill,
            borderRadius: corner,
            border: Border.all(color: fill),
          );
        }
        return BoxDecoration(
          color: pressed
              ? theme.colors.fill
              : hovered
              ? theme.colors.bgElevated
              : theme.colors.bgContainer,
          borderRadius: corner,
          // WinUI lifts only the border's grey under the pointer; the square
          // itself never takes a fill while it is empty.
          border: Border.all(
            color: pressed
                ? theme.colors.text
                : hovered
                ? theme.colors.textSecondary
                : theme.colors.border,
          ),
        );
      },
      halo: (_, {required checked, required hovered, required pressed}) => null,
      haloGrow: 0,
      haloRadius: rounded,
      tick: _check(0.17, 0.55, 0.35, 0.74, 0.85, 0.24),
      tickCap: StrokeCap.butt,
      tickWeight: 0.11,
      tickColor: onAccent,
      disabledAlpha: (theme) => theme.checkbox.disabledOpacity,
      frosted: false,
    );
  }

  /// Ubuntu Yaru's checkbox: the rounded square on the distribution accent —
  /// under the Yaru language the seed is the orange #E95420 the app configures,
  /// so the fill comes from the token rather than a hard-coded orange, and the
  /// dark theme's lighter orange comes out of the ramp for free. The check
  /// itself is Ubuntu's: fatter than Material's, round-cut, sitting low.
  factory yaru() {
    BorderRadius corner(PureTheme theme) => BorderRadius.circular(theme.token.scale.radii.sm);
    return _BoxVisual(
      boxSize: (theme) => theme.checkbox.boxSize,
      radius: corner,
      face: (theme, {required checked, required hovered, required pressed, required live}) {
        if (checked) {
          return BoxDecoration(
            color: pressed
                ? theme.colors.primaryActive
                : hovered
                ? theme.colors.primaryHover
                : theme.colors.primary,
            borderRadius: corner(theme),
          );
        }
        return BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: corner(theme),
          border: Border.all(color: pressed || hovered ? theme.colors.textSecondary : theme.colors.border, width: 2),
        );
      },
      halo: (_, {required checked, required hovered, required pressed}) => null,
      haloGrow: 0,
      haloRadius: corner,
      tick: _check(0.18, 0.52, 0.38, 0.72, 0.84, 0.26),
      tickCap: StrokeCap.round,
      tickWeight: 0.2,
      tickColor: onAccent,
      disabledAlpha: (theme) => theme.checkbox.disabledOpacity,
      frosted: false,
    );
  }

  /// forui's shadcn checkbox, and the wind branch that sits in the same arm
  /// here as it does in the tab bar's grammar table: a crisp square that
  /// inverts the ink ramp when it is checked — `text` becomes the fill and
  /// the page's own container the tick — the high-contrast answer the accent
  /// ramp is not.
  factory crisp() {
    BorderRadius corner(PureTheme theme) => BorderRadius.circular(theme.token.scale.radii.sm);
    return _BoxVisual(
      // The shadcn box is smaller than the token's; it reads as a glyph.
      boxSize: (theme) => theme.checkbox.boxSize + theme.token.scale.sizes.xxs - theme.token.motion.lineWidth * 4,
      radius: corner,
      face: (theme, {required checked, required hovered, required pressed, required live}) {
        if (checked) {
          return BoxDecoration(
            color: _onInk(theme, hovered: hovered, pressed: pressed),
            borderRadius: corner(theme),
            border: Border.all(
              color: _onInk(theme, hovered: hovered, pressed: pressed),
            ),
          );
        }
        return BoxDecoration(
          color: theme.colors.bgContainer,
          borderRadius: corner(theme),
          // shadcn's empty box lifts its border to the ink itself.
          border: Border.all(
            color: pressed
                ? theme.colors.text
                : hovered
                ? theme.colors.textSecondary
                : theme.colors.border,
          ),
        );
      },
      halo: (_, {required checked, required hovered, required pressed}) => null,
      haloGrow: 0,
      haloRadius: corner,
      tick: _check(0.22, 0.52, 0.41, 0.71, 0.80, 0.30),
      tickCap: StrokeCap.round,
      // The high-contrast check: the heaviest stroke in the kit after the
      // macOS box's.
      tickWeight: 0.2,
      // The tick is the ink's negative, not white: the box inverts, so the
      // check rides the page colour.
      tickColor: (theme) => theme.colors.bgContainer,
      disabledAlpha: (theme) => theme.checkbox.disabledOpacity,
      frosted: false,
    );
  }

  /// The glass language: a frosted square — real backdrop blur where the
  /// device can afford it, the same white film and hairline the tab bar's
  /// glass track wears — and a gradient accent fill when checked, the tick
  /// in white over it.
  factory glass() {
    BorderRadius corner(PureTheme theme) => BorderRadius.circular(theme.token.scale.radii.sm);
    return _BoxVisual(
      boxSize: (theme) => theme.checkbox.boxSize + theme.token.scale.sizes.xxs,
      radius: corner,
      face: (theme, {required checked, required hovered, required pressed, required live}) {
        if (checked) {
          return BoxDecoration(
            borderRadius: corner(theme),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: [theme.colors.primary, Color.lerp(theme.colors.primary, theme.colors.link, 0.35)!],
            ),
            boxShadow: [
              BoxShadow(color: theme.colors.primary.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          );
        }
        final film = theme.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.55);
        return BoxDecoration(
          color: pressed
              ? Color.lerp(film, theme.colors.fillSecondary, 0.5)
              : hovered
              ? Color.lerp(film, Colors.white, 0.25)
              : film,
          borderRadius: corner(theme),
          border: Border.all(
            color: theme.isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.7),
          ),
        );
      },
      halo: (_, {required checked, required hovered, required pressed}) => null,
      haloGrow: 0,
      haloRadius: corner,
      tick: _check(0.22, 0.51, 0.42, 0.70, 0.80, 0.30),
      tickCap: StrokeCap.round,
      tickWeight: 0.14,
      tickColor: onAccent,
      disabledAlpha: (theme) => theme.checkbox.disabledOpacity,
      frosted: true,
    );
  }

  /// The neumorphic language: the same surface as the page, raised on two
  /// shadows while empty and pressed into a well when checked — the tick then
  /// drawn in the accent itself, because the well has no fill for a white
  /// check to sit on.
  factory neumorphic() {
    BorderRadius corner(PureTheme theme) => BorderRadius.circular(theme.token.scale.radii.base);
    List<BoxShadow> raised(PureTheme theme) => [
      BoxShadow(color: theme.colors.shadowBase, blurRadius: 5, offset: const Offset(2.5, 2.5)),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.7),
        blurRadius: 5,
        offset: const Offset(-2.5, -2.5),
      ),
    ];
    List<BoxShadow> sunk(PureTheme theme) => [
      for (final shadow in raised(theme))
        BoxShadow(color: shadow.color, blurRadius: shadow.blurRadius, offset: -shadow.offset),
    ];
    return _BoxVisual(
      boxSize: (theme) => theme.checkbox.boxSize,
      radius: corner,
      face: (theme, {required checked, required hovered, required pressed, required live}) {
        if (checked) {
          return BoxDecoration(
            // The well deepens under the finger; the accent wash marks the
            // chosen box without a fill.
            color: pressed
                ? Color.lerp(theme.colors.bgContainer, theme.colors.primaryBg, 0.7)
                : Color.lerp(theme.colors.bgContainer, theme.colors.primaryBg, hovered ? 0.5 : 0.3),
            borderRadius: corner(theme),
            boxShadow: sunk(theme),
          );
        }
        return BoxDecoration(
          color: pressed
              ? theme.colors.fillTertiary
              : hovered
              ? theme.colors.fillQuaternary
              : theme.colors.bgContainer,
          borderRadius: corner(theme),
          boxShadow: raised(theme),
        );
      },
      halo: (_, {required checked, required hovered, required pressed}) => null,
      haloGrow: 0,
      haloRadius: corner,
      tick: _check(0.22, 0.52, 0.41, 0.70, 0.80, 0.30),
      tickCap: StrokeCap.round,
      tickWeight: 0.15,
      // No fill to carry a white check: the tick is the accent.
      tickColor: (theme) => theme.colors.primary,
      disabledAlpha: (theme) => theme.checkbox.disabledOpacity,
      frosted: false,
    );
  }

  /// The branch one design language paints, chosen from the resolved theme
  /// exactly the way the tab bar's `_resolveVisual` is.
  factory resolve(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.material => _BoxVisual.material(),
    PureDesignLanguage.cupertino => _BoxVisual.cupertino(),
    PureDesignLanguage.macos => _BoxVisual.macos(),
    PureDesignLanguage.fluent => _BoxVisual.fluent(),
    PureDesignLanguage.yaru => _BoxVisual.yaru(),
    // Wind shares the crisp branch the way the tab bar puts its wind cell in
    // the same arm as material and forui — the two web-descended languages
    // read the same square.
    PureDesignLanguage.forui || PureDesignLanguage.wind => _BoxVisual.crisp(),
    PureDesignLanguage.glass => _BoxVisual.glass(),
    PureDesignLanguage.neumorphic => _BoxVisual.neumorphic(),
  };

  /// The tick colour the filled languages share: the text solid on the
  /// accent. The ink-inverted and accent-tick branches supply their own.
  static Color onAccent(PureTheme theme) => theme.colors.textLightSolid;

  /// A three-point check across the unit box, scaled into the box the painter
  /// hands it; every branch tunes its three anchors, its weight and its cap
  /// rather than writing a path of its own.
  static Path Function(Size box) _check(double x1, double y1, double x2, double y2, double x3, double y3) {
    return (box) => Path()
      ..moveTo(box.width * x1, box.height * y1)
      ..lineTo(box.width * x2, box.height * y2)
      ..lineTo(box.width * x3, box.height * y3);
  }

  /// The box's edge length in the theme; the token box size is the default
  /// and the languages that read larger or smaller override it there.
  final double Function(PureTheme theme) boxSize;

  /// The box's corner. A pill radius on a square box is the circle the
  /// iOS branch needs — one vocabulary, no shape flag.
  final BorderRadius Function(PureTheme theme) radius;

  /// The box's whole surface for one state: fill or gradient, border or
  /// shadows — each language composes its own grammar out of the tokens.
  final Decoration Function(
    PureTheme theme, {
    required bool checked,
    required bool hovered,
    required bool pressed,
    required bool live,
  })
  face;

  /// The tint behind the box on hover and press — Material's state layer,
  /// and null in the languages that answer the pointer in the box itself.
  final Color? Function(PureTheme theme, {required bool checked, required bool hovered, required bool pressed}) halo;

  /// How far the halo grows past the box's edge; 0 draws no halo at all.
  final double haloGrow;

  /// The halo's own corner, a circle in Material's hand and the box's
  /// corner elsewhere.
  final BorderRadius Function(PureTheme theme) haloRadius;

  /// The checkmark's path across the box, in the language's own geometry.
  final Path Function(Size box) tick;

  /// How the checkmark's ends are cut — round for the touch languages, flat
  /// for the WinUI one.
  final StrokeCap tickCap;

  /// The checkmark's stroke as a fraction of the box's edge.
  final double tickWeight;

  /// The checkmark's colour.
  final Color Function(PureTheme theme) tickColor;

  /// The opacity a disabled box (and its label) falls to; Material's is the
  /// M3 spec's 38%, the others the motion token's loading opacity.
  final double Function(PureTheme theme) disabledAlpha;

  /// Whether the empty box frosts what sits behind it — true only of the
  /// glass branch, and only honoured while [PureTheme.canBlur] agrees.
  final bool frosted;
}

/// The ink-inverted fill the forui and wind branches share: shadcn's primary
/// is the ink ramp itself, lightening under the pointer rather than riding
/// the accent.
Color _onInk(PureTheme theme, {required bool hovered, required bool pressed}) {
  final lighten = pressed
      ? 0.25
      : hovered
      ? 0.12
      : 0.0;
  final base = theme.colors.text;
  final partner = theme.isDark ? theme.colors.white : theme.colors.textQuaternary;
  return Color.lerp(base, partner, lighten)!;
}

/// The box and its label, and the interaction contract every language's
/// branch shares: hover and pressed states, the kit's focus ring, Space (and
/// Enter, and the remote's select keys) toggling, the disabled look, the
/// `checked`/`enabled` screen-reader traits, and the tick's scale-and-fade.
class _CheckboxBox extends StatefulWidget {
  const new({
    required this.visual,
    required this.value,
    required this.live,
    required this.toggle,
    required this.label,
    required this.labelStyle,
    required this.gap,
    required this.autofocus,
    this.focusNode,
  });

  final _BoxVisual visual;

  final bool value;

  /// Whether the box responds to anything; a false folds `enabled` and the
  /// null callback into one verdict, the way the tab bar's bar does.
  final bool live;

  final VoidCallback toggle;

  final String? label;

  final TextStyle labelStyle;

  final double gap;

  /// An externally managed focus node; one is owned here when it is null.
  final FocusNode? focusNode;

  final bool autofocus;

  @override
  State<_CheckboxBox> createState() => _CheckboxBoxState();
}

class _CheckboxBoxState extends State<_CheckboxBox> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;
  FocusNode? _ownedNode;

  /// The node the focus sits on: the caller's when they brought one, an
  /// owned one otherwise.
  FocusNode get _node => widget.focusNode ?? (_ownedNode ??= FocusNode(debugLabel: 'PureCheckbox'));

  @override
  void dispose() {
    // Externally managed nodes are left for their owner; the box releases
    // only what it made.
    _ownedNode?.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // The same activate set the tab bar answers — Space for keyboards, Enter
    // and the select keys for the remote.
    final activate = {
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.gameButtonA,
    };
    if (!activate.contains(event.logicalKey)) {
      return KeyEventResult.ignored;
    }
    if (widget.live) {
      widget.toggle();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = widget.visual;
    final live = widget.live;
    final box = visual.boxSize(theme);
    final radius = visual.radius(theme);
    final haloColor = visual.haloGrow > 0 && live
        ? visual.halo(theme, checked: widget.value, hovered: _hovered, pressed: _pressed)
        : null;

    final face = AnimatedContainer(
      duration: theme.duration,
      curve: Curves.easeOut,
      width: box,
      height: box,
      alignment: AlignmentDirectional.center,
      decoration: visual.face(theme, checked: widget.value, hovered: _hovered, pressed: _pressed, live: live),
      foregroundDecoration: _focused ? _focusRing(theme, radius) : null,
      child: _tick(theme, visual, box),
    );
    // The glass branch frosts what sits behind the box, real blur where the
    // device can afford it — the same policy the tab bar's track reads.
    final boxFace = !visual.frosted || !theme.canBlur
        ? face
        : ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: face),
          );

    final control = SizedBox.square(
      dimension: box,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.center,
        children: [
          if (haloColor != null)
            Positioned(
              left: -visual.haloGrow,
              top: -visual.haloGrow,
              right: -visual.haloGrow,
              bottom: -visual.haloGrow,
              child: AnimatedContainer(
                duration: theme.duration,
                curve: Curves.easeOut,
                decoration: BoxDecoration(color: haloColor, borderRadius: visual.haloRadius(theme)),
              ),
            ),
          boxFace,
        ],
      ),
    );

    final label = widget.label;
    final row = label == null
        ? control
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              control,
              SizedBox(width: widget.gap),
              // The label yields to a tight parent rather than overflowing it.
              Flexible(child: Text(label, style: widget.labelStyle)),
            ],
          );

    final widgetWithSemantics = Semantics(
      checked: widget.value,
      enabled: live,
      label: label,
      // The screen reader's own toggle, beside the tap gesture's.
      onTap: live ? widget.toggle : null,
      child: AnimatedOpacity(
        duration: theme.duration,
        curve: Curves.easeOut,
        opacity: live ? 1 : visual.disabledAlpha(theme),
        // One semantics node for the whole box: the label rides the traits
        // above rather than as its own text node.
        child: ExcludeSemantics(child: row),
      ),
    );

    final interactive = Focus(
      focusNode: _node,
      canRequestFocus: live,
      autofocus: widget.autofocus,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) => _handleKey(event),
      child: MouseRegion(
        cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: live
              ? (_) {
                  _node.requestFocus();
                  setState(() => _pressed = true);
                }
              : null,
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: live ? widget.toggle : null,
          child: widgetWithSemantics,
        ),
      ),
    );
    if (live) {
      return interactive;
    }
    return IgnorePointer(child: interactive);
  }

  /// The kit's focus ring: a 2px accent border over the box, the same answer
  /// the tab bar's cells give.
  static BoxDecoration _focusRing(PureTheme theme, BorderRadius radius) => BoxDecoration(
    borderRadius: radius,
    border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: 2)),
  );

  /// The checkmark itself: scaled and faded in on the token's fast motion —
  /// around 100ms — and excluded from semantics because the box above already
  /// says `checked`.
  Widget _tick(PureTheme theme, _BoxVisual visual, double box) {
    final size = Size.square(box);
    return ExcludeSemantics(
      child: AnimatedScale(
        scale: widget.value ? 1 : 0.4,
        duration: theme.token.motion.durationFast,
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: widget.value ? 1 : 0,
          duration: theme.token.motion.durationFast,
          curve: Curves.easeOut,
          child: CustomPaint(
            painter: _TickPainter(
              path: visual.tick(size),
              color: visual.tickColor(theme),
              stroke: visual.tickWeight * box,
              cap: visual.tickCap,
            ),
            size: size,
          ),
        ),
      ),
    );
  }
}

/// The stroked checkmark of the active branch, painted inside the box.
final class _TickPainter extends CustomPainter {
  new({required this.path, required this.color, required this.stroke, required this.cap});

  final Path path;

  final Color color;

  final double stroke;

  final StrokeCap cap;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = cap
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_TickPainter oldDelegate) =>
      oldDelegate.path != path || oldDelegate.color != color || oldDelegate.stroke != stroke || oldDelegate.cap != cap;
}
