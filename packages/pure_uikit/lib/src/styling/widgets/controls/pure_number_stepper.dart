import 'dart:async';
import 'dart:ui' show FontFeature, ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The kit's number stepper — the design sheet's `InputNumber` controls: a
/// decrement cell, the current value, and an increment cell — drawn in every
/// design language.
///
/// Where `PureSlider` is the continuous pick, this is the discrete one, and
/// every language reads the same plus-and-minus grammar its own way: Material
/// 3's circular icon buttons flanking the value, iOS's joined capsule with
/// accent halves and hairline dividers, macOS's `NSStepper` — a slim column
/// of thin chevrons beside the number —, WinUI's NumberBox with a bordered
/// value box and an attached spin column that answers hover in the accent,
/// Yaru's flat squares, shadcn's bordered buttons for forui and (following
/// its siblings) wind again, a frosted plate of translucent cells under
/// glass, and raised plates that press into themselves under neumorphic. All
/// of it is painted here, because a number control is exactly what the
/// libraries ship unevenly; the colours, radii, motion and text come from the
/// tokens, so a language re-skin and a dark switch still come out right.
///
/// Every visual answers to the same interaction contract: a press steps once
/// and a hold keeps stepping, the repeat accelerating while the finger stays
/// down; Up and Down arrow keys step while the control is focused, and at a
/// bound the key is left to the shell; a screen reader reads the value and is
/// offered increase/decrease actions on it (VoiceOver's one-finger swipe,
/// TalkBack's volume keys) plus a named button at either end; the value
/// clamps between [min] and [max], the cell past a bound greys and goes inert
/// there, and an inert control greys its numbers too.
class PureNumberStepper extends StatelessWidget {
  /// A stepper bound to [value].
  const new({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = double.infinity,
    this.step = 1,
    this.decimals = 0,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  }) : assert(min <= max, 'The PureNumberStepper min must not exceed its max.'),
       assert(step > 0, 'The PureNumberStepper step must be positive.'),
       assert(decimals >= 0, 'The PureNumberStepper cannot display negative precision.');

  /// The current value.
  final double value;

  /// Called with the next value, already clamped to [min] / [max]; null
  /// renders the control inert.
  final ValueChanged<double>? onChanged;

  /// The lower bound.
  final double min;

  /// The upper bound.
  final double max;

  /// The increment / decrement amount.
  final double step;

  /// How many decimal places to display.
  final int decimals;

  /// Whether the control responds to input; false greys it out and ignores
  /// every pointer.
  final bool enabled;

  /// The name a screen reader gives the value; the number itself always reads
  /// as the value.
  final String? semanticLabel;

  /// The design language's reading of the plus-and-minus, chosen from the
  /// resolved theme's tokens so a re-skin and a dark switch re-seat the
  /// geometry too.
  _StepperVisual _resolveVisual(PureTheme theme) {
    final radii = theme.token.scale.radii;
    return switch (theme.config.language) {
      PureDesignLanguage.material => _StepperVisual.m3Circles(),
      PureDesignLanguage.cupertino => _StepperVisual.iosCapsule(trackRadius: radii.sm),
      PureDesignLanguage.macos => _StepperVisual.nsChevronPair(trackRadius: radii.base),
      PureDesignLanguage.fluent => _StepperVisual.numberBox(trackRadius: radii.base),
      PureDesignLanguage.yaru => _StepperVisual.flatSquares(cellRadius: radii.lg),
      PureDesignLanguage.forui => _StepperVisual.borderedButtons(cellRadius: radii.base),
      // shadcn's bordered button is wind's sibling grammar everywhere the kit
      // has drawn one — the tab bar's pill, the segmented bar's track — and
      // the stepper follows suit with the same reading.
      PureDesignLanguage.wind => _StepperVisual.borderedButtons(cellRadius: radii.base),
      PureDesignLanguage.glass => _StepperVisual.frostedPlate(trackRadius: radii.lg),
      PureDesignLanguage.neumorphic => _StepperVisual.raisedPlates(trackRadius: radii.lg),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    // A null callback is every library's inert state, so folding `enabled`
    // into it once serves every branch.
    final commit = enabled ? onChanged : null;
    return _StepperCore(
      value: value,
      min: min,
      max: max,
      step: step,
      decimals: decimals,
      semanticLabel: semanticLabel,
      commit: commit,
      visual: _resolveVisual(theme),
    );
  }
}

/// The geometry a stepper lays out: absolute pixels, so the control keeps its
/// compact tier whatever the design language makes of its colour. Text still
/// rides the theme's font scale, and colour and radius come from tokens.
abstract final class _StepperMetrics {
  /// 32 — the control's height, the stepper's own compact tier.
  static const double height = 32;

  /// 32 — the side of a flanking step cell; a square a pill radius turns into
  /// the Material circle.
  static const double cellSide = 32;

  /// 44 — the width of the value column: room for the numbers a stepper
  /// reaches, tabular so the figure does not jitter as it steps.
  static const double valueWidth = 44;

  /// 4 — the air between two unjoined cells (and the glass plate's inset).
  static const double gap = 4;

  /// 1 — the hairline between joined cells and stacked chevron segments.
  static const double hairline = 1;

  /// 2 — the focus ring's width.
  static const double focusWidth = 2;

  /// 34 — the width of the attached spin column, WinUI NumberBox's own.
  static const double spinWidth = 34;

  /// 23 — the width of the standalone chevron column, macOS NSStepper slim.
  static const double chevronWidth = 23;

  /// 24 — its height; NSStepper is a smaller control than the sheet's row.
  static const double chevronHeight = 24;

  /// 13 — the value text size, before the theme's font scale.
  static const double valueFontSize = 13;

  /// The hold-to-repeat contract: the first repeat lands 400ms after the
  /// press, and every following gap shrinks to [holdDecay] of the last — the
  /// acceleration a held stepper answers with — never below [holdFloor].
  static const Duration holdStart = Duration(milliseconds: 400);

  /// The floor the accelerating repeat settles at.
  static const Duration holdFloor = Duration(milliseconds: 60);

  /// The multiplier each repeat gap takes from the one before it.
  static const double holdDecay = 0.7;
}

/// Which of the three arrangements a design language puts its cells in: the
/// step buttons flanking the value, a spin column attached to a bordered
/// value box, or a standalone chevron column beside the number.
enum _StepperLayout {
  /// `-  value  +` in a row (Material, iOS, Yaru, shadcn, glass, neumorphic).
  flanking,

  /// The value box with up/down cells stacked against its right edge
  /// (WinUI's NumberBox).
  numberBox,

  /// The number in plain text with the up/down column standing beside it
  /// (macOS's NSStepper).
  chevronPair,
}

/// How one design language paints the stepper: the arrangement of its cells,
/// the glyphs they carry, the fills and hairlines each state draws, and the
/// colour of a glyph in each state.
@immutable
final class _StepperVisual {
  const new({
    required this.layout,
    required this.joined,
    required this.increaseIcon,
    required this.decreaseIcon,
    required this.iconSize,
    required this.cellRadius,
    required this.capsule,
    required this.divider,
    required this.hoverTint,
    required this.pressedTint,
    required this.restTint,
    required this.cellBorder,
    required this.shadows,
    required this.glyph,
    required this.track,
    required this.focusRadius,
  });

  /// Material 3: circular icon buttons flanking the value — a state-layer
  /// grey behind the glyph on hover, a deeper one pressed, the cell at a
  /// bound greyed and inert.
  factory m3Circles() {
    return _StepperVisual(
      layout: _StepperLayout.flanking,
      joined: false,
      increaseIcon: Icons.add,
      decreaseIcon: Icons.remove,
      iconSize: 18,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      capsule: (theme) => null,
      divider: (theme) => null,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      restTint: (theme) => null,
      cellBorder: (theme) => null,
      shadows: (theme, {required pressed}) => const [],
      glyph: (theme, {required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        return theme.colors.text;
      },
      track: (theme, strip) => strip,
      focusRadius: BorderRadius.circular(PureRadii.md),
    );
  }

  /// iOS: the stepper's own capsule — two accent-halved cells joined to the
  /// number by hairline dividers on a bordered white plate, the pressed half
  /// filling grey, the glyph answering in the accent alone.
  factory iosCapsule({required double trackRadius}) {
    final radius = BorderRadius.circular(trackRadius);
    return _StepperVisual(
      layout: _StepperLayout.flanking,
      joined: true,
      increaseIcon: Icons.add,
      decreaseIcon: Icons.remove,
      iconSize: 16,
      cellRadius: BorderRadius.zero,
      capsule: (theme) => BoxDecoration(
        color: theme.colors.bgContainer,
        borderRadius: radius,
        border: Border.all(color: theme.colors.borderSecondary),
      ),
      divider: (theme) => theme.colors.borderSecondary,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      restTint: (theme) => null,
      cellBorder: (theme) => null,
      shadows: (theme, {required pressed}) => const [],
      glyph: (theme, {required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        return theme.colors.primary;
      },
      track: (theme, strip) => strip,
      focusRadius: radius,
    );
  }

  /// macOS: the NSStepper's slim chevron column beside the number — a small
  /// bordered capsule of two stacked segments over a hairline, grey at rest,
  /// darkening under the pointer.
  factory nsChevronPair({required double trackRadius}) {
    final radius = BorderRadius.circular(trackRadius);
    return _StepperVisual(
      layout: _StepperLayout.chevronPair,
      joined: true,
      increaseIcon: Icons.expand_less,
      decreaseIcon: Icons.expand_more,
      iconSize: 12,
      cellRadius: BorderRadius.zero,
      capsule: (theme) => BoxDecoration(
        color: theme.colors.bgContainer,
        borderRadius: radius,
        border: Border.all(color: theme.colors.borderSecondary),
      ),
      divider: (theme) => theme.colors.borderSecondary,
      hoverTint: (theme) => theme.colors.fillTertiary,
      pressedTint: (theme) => theme.colors.fillSecondary,
      restTint: (theme) => null,
      cellBorder: (theme) => null,
      shadows: (theme, {required pressed}) => const [],
      glyph: (theme, {required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
      track: (theme, strip) => strip,
      focusRadius: radius,
    );
  }

  /// Windows: the WinUI NumberBox — a bordered value box with the spin column
  /// attached to its right edge over a hairline, answering hover in the
  /// accent the way the library's repeat buttons do.
  factory numberBox({required double trackRadius}) {
    final radius = BorderRadius.circular(trackRadius);
    return _StepperVisual(
      layout: _StepperLayout.numberBox,
      joined: true,
      increaseIcon: Icons.keyboard_arrow_up,
      decreaseIcon: Icons.keyboard_arrow_down,
      iconSize: 16,
      cellRadius: BorderRadius.zero,
      capsule: (theme) => BoxDecoration(
        color: theme.colors.bgContainer,
        borderRadius: radius,
        border: Border.all(color: theme.colors.borderSecondary),
      ),
      divider: (theme) => theme.colors.borderSecondary,
      hoverTint: (theme) => theme.colors.primaryBg,
      pressedTint: (theme) => theme.colors.primaryBgHover,
      restTint: (theme) => null,
      cellBorder: (theme) => null,
      shadows: (theme, {required pressed}) => const [],
      glyph: (theme, {required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (pressed) {
          return theme.colors.primaryActive;
        }
        if (hovered) {
          return theme.colors.primary;
        }
        return theme.colors.textSecondary;
      },
      track: (theme, strip) => strip,
      focusRadius: radius,
    );
  }

  /// Ubuntu: Yaru's flat squares — no plate, no border at rest, a header
  /// button's rounded fill appearing under the pointer and deepening on
  /// press.
  factory flatSquares({required double cellRadius}) {
    final radius = BorderRadius.circular(cellRadius);
    return _StepperVisual(
      layout: _StepperLayout.flanking,
      joined: false,
      increaseIcon: Icons.add,
      decreaseIcon: Icons.remove,
      iconSize: 16,
      cellRadius: radius,
      capsule: (theme) => null,
      divider: (theme) => null,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      restTint: (theme) => null,
      cellBorder: (theme) => null,
      shadows: (theme, {required pressed}) => const [],
      glyph: (theme, {required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        return theme.colors.text;
      },
      track: (theme, strip) => strip,
      focusRadius: radius,
    );
  }

  /// shadcn's button — and wind's, the sibling the kit's other controls keep
  /// it beside: a bordered, plate-filled cell that clouds on hover and
  /// presses deeper, around a full set of corners.
  factory borderedButtons({required double cellRadius}) {
    final radius = BorderRadius.circular(cellRadius);
    return _StepperVisual(
      layout: _StepperLayout.flanking,
      joined: false,
      increaseIcon: Icons.add,
      decreaseIcon: Icons.remove,
      iconSize: 16,
      cellRadius: radius,
      capsule: (theme) => null,
      divider: (theme) => null,
      hoverTint: (theme) => theme.colors.fill,
      pressedTint: (theme) => theme.colors.fillSecondary,
      restTint: (theme) => theme.colors.bgContainer,
      cellBorder: (theme) => theme.colors.borderSecondary,
      shadows: (theme, {required pressed}) => const [],
      glyph: (theme, {required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
      track: (theme, strip) => strip,
      focusRadius: radius,
    );
  }

  /// The glass language: a frosted plate (real backdrop blur when the device
  /// can afford it) under translucent, hairline-rimmed cells that cloud over
  /// as the pointer works them.
  factory frostedPlate({required double trackRadius}) {
    final radius = BorderRadius.circular(trackRadius);
    Color frost(PureTheme theme, double alpha) =>
        theme.isDark ? Colors.white.withValues(alpha: alpha) : Colors.black.withValues(alpha: alpha);
    return _StepperVisual(
      layout: _StepperLayout.flanking,
      joined: false,
      increaseIcon: Icons.add,
      decreaseIcon: Icons.remove,
      iconSize: 16,
      cellRadius: BorderRadius.circular(PureRadii.pill),
      capsule: (theme) => null,
      divider: (theme) => null,
      hoverTint: (theme) => frost(theme, 0.12),
      pressedTint: (theme) => frost(theme, 0.18),
      restTint: (theme) => frost(theme, 0.06),
      cellBorder: (theme) => theme.isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.6),
      shadows: (theme, {required pressed}) => const [],
      glyph: (theme, {required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (pressed || hovered) {
          return theme.colors.primary;
        }
        return theme.colors.text;
      },
      track: (theme, strip) {
        final plate = DecoratedBox(
          decoration: BoxDecoration(
            color: theme.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.55),
            borderRadius: radius,
            border: Border.all(
              color: theme.isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.7),
            ),
          ),
          child: Padding(padding: const EdgeInsets.all(_StepperMetrics.gap), child: strip),
        );
        if (!theme.canBlur) {
          return plate;
        }
        return ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: plate),
        );
      },
      focusRadius: radius,
    );
  }

  /// The neumorphic language: plates raised out of the surface (light from
  /// the top left, shadow from the bottom right) that press into it — the
  /// shadows reversing — while the finger holds them.
  factory raisedPlates({required double trackRadius}) {
    final radius = BorderRadius.circular(trackRadius);
    List<BoxShadow> raised(PureTheme theme) => [
      BoxShadow(color: theme.colors.shadowBase, blurRadius: 6, offset: const Offset(3, 3)),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.8),
        blurRadius: 6,
        offset: const Offset(-3, -3),
      ),
    ];
    List<BoxShadow> sunk(PureTheme theme) => [
      for (final shadow in raised(theme))
        BoxShadow(color: shadow.color, blurRadius: shadow.blurRadius, offset: -shadow.offset),
    ];
    return _StepperVisual(
      layout: _StepperLayout.flanking,
      joined: false,
      increaseIcon: Icons.add,
      decreaseIcon: Icons.remove,
      iconSize: 16,
      cellRadius: radius,
      capsule: (theme) => null,
      divider: (theme) => null,
      hoverTint: (theme) => theme.colors.bgElevated,
      pressedTint: (theme) => theme.colors.bgContainer,
      restTint: (theme) => theme.colors.bgContainer,
      cellBorder: (theme) => null,
      shadows: (theme, {required pressed}) => pressed ? sunk(theme) : raised(theme),
      glyph: (theme, {required hovered, required pressed, required enabled}) {
        if (!enabled) {
          return theme.colors.textQuaternary;
        }
        if (pressed || hovered) {
          return theme.colors.text;
        }
        return theme.colors.textSecondary;
      },
      track: (theme, strip) => strip,
      focusRadius: radius,
    );
  }

  /// Which of the three arrangements the cells sit in.
  final _StepperLayout layout;

  /// Whether the cells are flush inside the [capsule] (their own radius
  /// defers to the clip, and hairline dividers join them) rather than
  /// standing apart as individual buttons.
  final bool joined;

  /// The glyph on the increment cell.
  final IconData increaseIcon;

  /// The glyph on the decrement cell.
  final IconData decreaseIcon;

  /// The glyph size inside a cell.
  final double iconSize;

  /// The corner radius of a cell that is not flush in a capsule.
  final BorderRadius cellRadius;

  /// The frame around a joined strip — the plate, border and corner the
  /// capsule paints; null for the languages whose cells float free.
  final BoxDecoration? Function(PureTheme theme) capsule;

  /// The hairline between joined cells or stacked segments; null is the
  /// languages that divide nothing.
  final Color? Function(PureTheme theme) divider;

  /// The fill behind a hovered cell.
  final Color? Function(PureTheme theme) hoverTint;

  /// The fill behind a pressed cell.
  final Color? Function(PureTheme theme) pressedTint;

  /// The fill a cell carries at rest; null is the flat languages.
  final Color? Function(PureTheme theme) restTint;

  /// The border around each cell; null is the borderless languages.
  final Color? Function(PureTheme theme) cellBorder;

  /// The shadows a cell draws, the pressed flag letting neumorphic reverse
  /// its emboss; every other language answers with the empty list.
  final List<BoxShadow> Function(PureTheme theme, {required bool pressed}) shadows;

  /// The glyph colour in each state.
  final Color Function(PureTheme theme, {required bool hovered, required bool pressed, required bool enabled}) glyph;

  /// Wraps the assembled control: the glass plate and its blur; every other
  /// language passes the strip through.
  final Widget Function(PureTheme theme, Widget strip) track;

  /// The corner radius of the focus ring drawn around the whole control.
  final BorderRadius focusRadius;
}

/// The stepper's interaction core, shared by every language: it owns the
/// focus, the hold-to-repeat timer and its acceleration, the arrow-key
/// stepping, the min/max clamping and the value semantics, and lays the
/// cells out in the visual's arrangement.
class _StepperCore extends StatefulWidget {
  const new({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.decimals,
    required this.semanticLabel,
    required this.commit,
    required this.visual,
  });

  final double value;

  final double min;

  final double max;

  final double step;

  final int decimals;

  final String? semanticLabel;

  /// The live commit channel; null is the inert control (the caller's null
  /// `onChanged` or `enabled: false`, folded into one flag upstream).
  final ValueChanged<double>? commit;

  final _StepperVisual visual;

  @override
  State<_StepperCore> createState() => _StepperCoreState();
}

class _StepperCoreState extends State<_StepperCore> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'PureNumberStepper');
  Timer? _holdTimer;

  /// The gap the running repeat waits out; it shrinks each tick toward the
  /// floor, and resets when the finger leaves.
  Duration _holdGap = _StepperMetrics.holdStart;
  bool _focused = false;

  @override
  void dispose() {
    _endHold();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _StepperCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An inert control must not keep repeating on the timer a live one started.
    if (!_active) {
      _endHold();
    }
  }

  /// Whether the control is live.
  bool get _active => widget.commit != null;

  /// Whether another signed [delta] step stays inside the bounds; a step that
  /// would not is refused — that is what greys the cell and stops a repeat.
  bool _canStep(double delta) {
    if (!_active) {
      return false;
    }
    return delta > 0 ? widget.value < widget.max : widget.value > widget.min;
  }

  void _commit(double delta) => widget.commit!((widget.value + delta).clamp(widget.min, widget.max));

  /// The press's first step lands immediately; the hold that follows repeats,
  /// each gap a fraction of the last until the floor, and the repeat stops at
  /// a bound the same way a press is refused there.
  void _startHold(double delta) {
    _endHold();
    if (!_canStep(delta)) {
      return;
    }
    _commit(delta);
    _holdGap = _StepperMetrics.holdStart;
    _scheduleHold(delta);
  }

  void _scheduleHold(double delta) {
    _holdTimer = Timer(_holdGap, () {
      if (!mounted || !_canStep(delta)) {
        return;
      }
      _commit(delta);
      final shorter = Duration(microseconds: (_holdGap.inMicroseconds * _StepperMetrics.holdDecay).round());
      _holdGap = shorter < _StepperMetrics.holdFloor ? _StepperMetrics.holdFloor : shorter;
      _scheduleHold(delta);
    });
  }

  void _endHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdGap = _StepperMetrics.holdStart;
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      return _stepFromKey(widget.step);
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      return _stepFromKey(-widget.step);
    }
    return KeyEventResult.ignored;
  }

  /// Stepping from a key: at a bound the key is left to the shell, the way
  /// the tab bar leaves an arrow past its edge.
  KeyEventResult _stepFromKey(double delta) {
    if (!_canStep(delta)) {
      return KeyEventResult.ignored;
    }
    _commit(delta);
    return KeyEventResult.handled;
  }

  String _format(double value) => value.toStringAsFixed(widget.decimals);

  @override
  Widget build(BuildContext context) {
    final theme = context.themeFor;
    final visual = widget.visual;
    var strip = switch (visual.layout) {
      _StepperLayout.flanking => _flanking(visual),
      _StepperLayout.numberBox => _numberBox(visual),
      _StepperLayout.chevronPair => _chevronPair(visual),
    };
    // The chevron column carries its capsule around the block alone; every
    // other joined arrangement caps the whole strip.
    final capsule = visual.capsule(theme);
    if (capsule != null && visual.layout != _StepperLayout.chevronPair) {
      strip = _capsule(capsule, strip);
    }
    final framed = visual.track(theme, strip);
    // The focus ring is the keyboard and remote answer for the whole control:
    // a foreground border that never shifts the layout.  Always wrapped in
    // DecoratedBox so the tree structure is stable regardless of focus state
    // (a conditional wrapper would dispose & rebuild the subtree, killing
    // any in-progress gesture on the step buttons).
    final ringed = DecoratedBox(
      decoration: _focused
          ? BoxDecoration(
              borderRadius: visual.focusRadius,
              border: Border.fromBorderSide(BorderSide(color: theme.colors.primary, width: _StepperMetrics.focusWidth)),
            )
          : const BoxDecoration(),
      position: DecorationPosition.foreground,
      child: framed,
    );
    final control = Focus(
      focusNode: _focusNode,
      canRequestFocus: _active,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: (node, event) => _handleKey(event),
      child: ringed,
    );
    final increased = _canStep(widget.step);
    final decreased = _canStep(-widget.step);
    final semantics = Semantics(
      label: widget.semanticLabel,
      value: _format(widget.value),
      increasedValue: increased ? _format((widget.value + widget.step).clamp(widget.min, widget.max)) : null,
      decreasedValue: decreased ? _format((widget.value - widget.step).clamp(widget.min, widget.max)) : null,
      onIncrease: increased ? () => _commit(widget.step) : null,
      onDecrease: decreased ? () => _commit(-widget.step) : null,
      child: control,
    );
    if (_active) {
      return semantics;
    }
    return IgnorePointer(child: semantics);
  }

  /// `-  value  +`: hairline dividers between the cells of a joined capsule,
  /// air between cells that stand alone.
  Widget _flanking(_StepperVisual visual) {
    final dividerColor = visual.divider(context.themeFor);
    final separator = visual.joined && dividerColor != null
        ? Container(width: _StepperMetrics.hairline, height: _StepperMetrics.height, color: dividerColor)
        : const SizedBox(width: _StepperMetrics.gap);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(visual, up: false, live: _canStep(-widget.step), width: _StepperMetrics.cellSide),
        separator,
        _valueCell(_StepperMetrics.valueWidth, _StepperMetrics.height),
        separator,
        _button(visual, up: true, live: _canStep(widget.step), width: _StepperMetrics.cellSide),
      ],
    );
  }

  /// The WinUI NumberBox: the value box with the spin column attached to its
  /// right edge, both hairline-separated inside one capsule.
  Widget _numberBox(_StepperVisual visual) {
    final dividerColor = visual.divider(context.themeFor);
    const segmentHeight = (_StepperMetrics.height - _StepperMetrics.hairline) / 2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _valueCell(_StepperMetrics.valueWidth, _StepperMetrics.height),
        if (dividerColor != null)
          Container(width: _StepperMetrics.hairline, height: _StepperMetrics.height, color: dividerColor),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(
              visual,
              up: true,
              live: _canStep(widget.step),
              width: _StepperMetrics.spinWidth,
              height: segmentHeight,
            ),
            if (dividerColor != null)
              Container(width: _StepperMetrics.spinWidth, height: _StepperMetrics.hairline, color: dividerColor),
            _button(
              visual,
              up: false,
              live: _canStep(-widget.step),
              width: _StepperMetrics.spinWidth,
              height: segmentHeight,
            ),
          ],
        ),
      ],
    );
  }

  /// The macOS reading: the number in plain text, the NSStepper's slim
  /// up/down column standing beside it with a capsule of its own.
  Widget _chevronPair(_StepperVisual visual) {
    final theme = context.themeFor;
    final dividerColor = visual.divider(theme);
    const segmentHeight = (_StepperMetrics.chevronHeight - _StepperMetrics.hairline) / 2;
    final block = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          visual,
          up: true,
          live: _canStep(widget.step),
          width: _StepperMetrics.chevronWidth,
          height: segmentHeight,
        ),
        if (dividerColor != null)
          Container(width: _StepperMetrics.chevronWidth, height: _StepperMetrics.hairline, color: dividerColor),
        _button(
          visual,
          up: false,
          live: _canStep(-widget.step),
          width: _StepperMetrics.chevronWidth,
          height: segmentHeight,
        ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _valueCell(_StepperMetrics.valueWidth, _StepperMetrics.height),
        const SizedBox(width: _StepperMetrics.gap * 2),
        if (visual.capsule(theme) case final capsule?) _capsule(capsule, block) else block,
      ],
    );
  }

  Widget _capsule(BoxDecoration decoration, Widget strip) {
    final radius = decoration.borderRadius ?? BorderRadius.zero;
    return DecoratedBox(
      decoration: decoration,
      child: ClipRRect(borderRadius: radius, child: strip),
    );
  }

  Widget _button(_StepperVisual visual, {required bool up, required bool live, required double width, double? height}) {
    return _StepButton(
      icon: up ? visual.increaseIcon : visual.decreaseIcon,
      label: up ? 'Increase' : 'Decrease',
      delta: up ? widget.step : -widget.step,
      live: live,
      width: width,
      height: height ?? _StepperMetrics.height,
      flush: visual.joined || visual.layout != _StepperLayout.flanking,
      visual: visual,
      focusNode: _focusNode,
      onHoldStart: _startHold,
      onHoldEnd: _endHold,
    );
  }

  Widget _valueCell(double width, double height) {
    final theme = context.themeFor;
    // The figure rides the theme's font scale, and tabular digits keep the
    // column still as the value steps.
    final fontRatio = theme.text.body.fontSize! / theme.token.type.fontSize;
    final valueStyle = theme.text.body.copyWith(
      fontSize: _StepperMetrics.valueFontSize * fontRatio,
      color: _active ? theme.colors.text : theme.colors.textQuaternary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: Center(
          child: Text(_format(widget.value), maxLines: 1, textAlign: TextAlign.center, style: valueStyle),
        ),
      ),
    );
  }
}

extension on BuildContext {
  /// The resolved theme, read the way every component here does.
  PureTheme get themeFor => PureTheme.of(this);
}

/// One step cell: its hover, pressed and bound-inert states, the semantics
/// that name it as a button, and the press that hands the hold timer to the
/// control's state.
class _StepButton extends StatefulWidget {
  const new({
    required this.icon,
    required this.label,
    required this.delta,
    required this.live,
    required this.width,
    required this.height,
    required this.flush,
    required this.visual,
    required this.focusNode,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final IconData icon;

  final String label;

  /// The signed step this cell takes.
  final double delta;

  /// Whether the cell responds: the control is live and the value can still
  /// move this way.
  final bool live;

  final double width;

  final double height;

  /// Whether the cell sits flush inside a capsule, its own radius deferring to
  /// the clip.
  final bool flush;

  final _StepperVisual visual;

  final FocusNode focusNode;

  final ValueChanged<double> onHoldStart;

  final VoidCallback onHoldEnd;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  bool _hovered = false;
  bool _pressed = false;

  // Stable callback references: passing new closures each build would cause
  // RawGestureDetector to recreate its recognizers, which fires onTapCancel
  // mid-hold and kills the repeat timer.  The live-gate lives inside instead.
  void _onTapDown(TapDownDetails _) {
    if (!widget.live) return;
    widget.focusNode.requestFocus();
    setState(() => _pressed = true);
    widget.onHoldStart(widget.delta);
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.live) return;
    setState(() => _pressed = false);
    widget.onHoldEnd();
  }

  void _onTapCancel() {
    if (!widget.live) return;
    setState(() => _pressed = false);
    widget.onHoldEnd();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.themeFor;
    final visual = widget.visual;
    final live = widget.live;
    final color = visual.glyph(theme, hovered: _hovered, pressed: _pressed, enabled: live);
    final fill = !live
        ? null
        : _pressed
        ? visual.pressedTint(theme)
        : _hovered
        ? visual.hoverTint(theme)
        : visual.restTint(theme);
    final borderColor = visual.cellBorder(theme);

    return MouseRegion(
      cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (live) {
          setState(() => _hovered = true);
        }
      },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The press itself steps; a tap is a hold that ended before the
        // first repeat, so there is no onTap and never a double count.
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Semantics(
          button: true,
          enabled: live,
          label: widget.label,
          child: AnimatedContainer(
            duration: theme.duration,
            curve: Curves.easeOut,
            width: widget.width,
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: widget.flush ? BorderRadius.zero : visual.cellRadius,
              border: borderColor == null ? null : Border.all(color: borderColor),
              boxShadow: visual.shadows(theme, pressed: _pressed),
            ),
            child: Icon(widget.icon, size: visual.iconSize, color: color),
          ),
        ),
      ),
    );
  }
}
