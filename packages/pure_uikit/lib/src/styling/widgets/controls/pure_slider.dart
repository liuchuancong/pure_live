import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The design sheet's slider: one track that carries a value, drawn in every
/// design language. Where the switch flips, this runs — the Material 3 rail
/// with its outlined 4dp inactive track, its thicker active stroke in the
/// accent, its handle that rests as a dot and swells under the pointer inside
/// a tinted state layer, and its bubble that names the value while the drag
/// runs; the iOS track that reads as two notches around a shadowed white knob
/// with no label at all; the Aqua pull whose filled groove runs into a rounded
/// square knob with one tick mark per division dropped under the rail; the
/// WinUI rail with its large bordered knob that swells on hover; Ubuntu's thin
/// dark track with the accent run under a flat round knob; the crisp shadcn
/// (and its wind sibling's) hairline with its bordered knob; a frosted rail
/// that blurs the page behind a luminous knob under glass; and an inset groove
/// whose knob sits raised until the drag presses it back in under neumorphic.
/// All of it is painted here, because a value that answers to a keyboard, a
/// screen reader and nine sheets at once is exactly what the nine libraries
/// refuse to share; the colours, radii, motion and text come from the tokens,
/// so a language re-skin and a dark switch still come out right.
///
/// Every visual answers to the same interaction contract: the whole track is
/// one hit target, so a pointer drags from anywhere on it and a tap moves the
/// value to where it landed; hover and drag swell the handle and its state
/// layer; the kit's focus ring circles the handle while it holds focus; Left
/// and Right (and Down and Up) move one step, Home and End run to the bounds;
/// `slider` semantics carrying the value, the two neighbours and the two
/// actions name the control to a screen reader in every language; the handle
/// animates its size back down when the drag lets go; and a null `onChanged`
/// (or `enabled: false`) fades the whole control to its language's disabled
/// alpha and swallows pointer and keyboard alike.
class PureSlider extends StatelessWidget {
  /// A slider carrying [value] between [min] and [max].
  const new({
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.enabled = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.onChangeStart,
    this.onChangeEnd,
    super.key,
  }) : assert(divisions == null || divisions > 0, 'A slider divides its range at least once.');

  /// The current value.
  final double value;

  /// Called with each new value; null (or `enabled: false`) disables the
  /// slider, fades it and swallows every pointer and key.
  final ValueChanged<double>? onChanged;

  /// The lower bound.
  final double min;

  /// The upper bound.
  final double max;

  /// How many equal steps the range is cut into. A stepped slider snaps its
  /// value to those notches — and the language that owns a tick mark (macOS's
  /// Aqua rail above all) draws one per notch. Null leaves the value
  /// continuous.
  final int? divisions;

  /// Whether the slider responds to input.
  final bool enabled;

  /// An externally managed focus node.
  final FocusNode? focusNode;

  /// Whether it takes focus on first appearance.
  final bool autofocus;

  /// The name a screen reader reads beside the value; the value itself is
  /// always read.
  final String? semanticLabel;

  /// Called when a pointer lands on the track — the moment a caller that
  /// shows the value in its own chrome should start listening.
  final VoidCallback? onChangeStart;

  /// Called when the pointer lets go.
  final VoidCallback? onChangeEnd;

  /// One step of the keyboard's arithmetic: a notch of [divisions] where the
  /// value has them, and a twentieth of the range on a continuous track. The
  /// twentieth is the kit's own answer to the question the libraries leave
  /// implicit — a slider with no notches still has to move by something.
  double get _step {
    final span = max - min;
    final divisions = this.divisions;
    if (divisions != null && span.isFinite) {
      return span / divisions;
    }
    return span / _continuousDivisions;
  }

  static const int _continuousDivisions = 20;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    final span = max - min;
    // A value outside its own bounds still draws inside the rail, and a rail
    // whose bounds collapsed keeps its handle at the near end rather than
    // dividing by nothing.
    final clamped = span > 0 ? value.clamp(min, max) : min;
    final fraction = span > 0 ? ((clamped - min) / span).clamp(0.0, 1.0) : 0.0;
    return _SliderCore(
      // The branch a slider draws is its identity in tests and diagnostics.
      key: ValueKey('PureSlider.${language.name}'),
      visual: switch (language) {
        // Material 3 and the iOS, macOS and WinUI rails each draw their own
        // geometry, from their own sheet.
        PureDesignLanguage.material => _SliderVisual.material(theme),
        PureDesignLanguage.cupertino => _SliderVisual.cupertino(theme),
        PureDesignLanguage.macos => _SliderVisual.macos(theme),
        PureDesignLanguage.fluent => _SliderVisual.fluent(theme),
        PureDesignLanguage.yaru => _SliderVisual.yaru(theme),
        // The tab bar folds wind into the material/forui utility-class
        // grammar it shares with them; the slider keeps that family tie and
        // draws the same crisp hairline the shadcn branch does.
        PureDesignLanguage.forui || PureDesignLanguage.wind => _SliderVisual.forui(theme),
        // Glass and neumorphic are intentionally distinctive languages, so
        // the slider answers to their own materials rather than a role.
        PureDesignLanguage.glass => _SliderVisual.glass(theme),
        PureDesignLanguage.neumorphic => _SliderVisual.neumorphic(theme),
      },
      value: clamped,
      fraction: fraction,
      min: min,
      max: max,
      step: _step,
      divisions: divisions,
      // A null callback is every language's own inert state, so folding
      // `enabled` into it once gives the core a single verdict.
      report: enabled ? onChanged : null,
      onChangeStart: onChangeStart,
      onChangeEnd: onChangeEnd,
      focusNode: focusNode,
      autofocus: autofocus,
      semanticLabel: semanticLabel,
    );
  }
}

/// The geometry, colours and motion one language puts on its rail, its runs of
/// colour and its handle. Everything is resolved from the theme when the
/// slider builds, so a language re-skin, a dark switch and the user's motion
/// settings all come out of the same tokens the kit's other controls read.
@immutable
final class _SliderVisual {
  const new({
    required this.height,
    required this.trackHeight,
    required this.activeHeight,
    required this.radius,
    required this.trackSurface,
    required this.trackOutline,
    required this.outlineWidth,
    required this.inactiveColor,
    required this.activeColor,
    required this.handleSize,
    required this.handleGrown,
    required this.handleRadius,
    required this.handleColor,
    required this.handleOutline,
    required this.handleOutlineWidth,
    required this.handleShadow,
    required this.halo,
    required this.haloSize,
    required this.frosted,
    required this.grooved,
    required this.segmented,
    required this.tickMarks,
    required this.tickColor,
    required this.tickDrop,
    required this.disabledAlpha,
    required this.curve,
    required this.bubble,
  });

  /// Material 3: a 4dp rail with the outline's hairline around it and 4dp of
  /// track ahead of the handle, the passed part an 8dp stroke in the accent,
  /// and a handle that rests as a 4dp dot, swells to the token's own control
  /// step inside a tinted state layer under the pointer, and names the value
  /// in a bubble while the drag runs. An inactive slider keeps 38 percent of
  /// its colour — the number M3 puts on a disabled control — and the box is
  /// the 44dp touch target the sheet asks for.
  factory material(PureTheme theme) {
    final base = theme.slider;
    return _SliderVisual(
      height: 44,
      trackHeight: base.railHeight,
      activeHeight: base.railHeight * 2,
      radius: BorderRadius.circular(PureRadii.pill),
      trackSurface: null,
      trackOutline: theme.colors.border,
      outlineWidth: theme.token.motion.lineWidth * 2,
      inactiveColor: theme.colors.fillTertiary,
      activeColor: base.trackColor,
      handleSize: PureRadii.xs,
      handleGrown: base.handleSize - PureRadii.xs,
      handleRadius: PureRadii.pill,
      handleColor: base.trackColor,
      handleOutline: null,
      handleOutlineWidth: 0,
      handleShadow: ({required pressed}) => const [],
      halo: theme.colors.primary.withValues(alpha: 0.12),
      haloSize: theme.token.scale.sizes.xs,
      frosted: false,
      grooved: false,
      segmented: false,
      // M3 puts its notches on the track itself, punched in the fill's own ink.
      tickMarks: true,
      tickColor: theme.colors.textLightSolid,
      tickDrop: 0,
      disabledAlpha: 0.38,
      curve: Curves.easeOutCubic,
      bubble: _SliderBubble(
        color: base.trackColor,
        foreground: theme.colors.textLightSolid,
        radius: BorderRadius.circular(PureRadii.sm),
        fontSize: theme.token.type.fontSizeSM,
        label: _describeValue,
      ),
    );
  }

  /// iOS: a thin round track whose filled portion reads darker than the rail
  /// ahead of it, broken into two notches around a white knob with its subtle
  /// shadow. iOS puts no label on its slider, so the bubble and the marks are
  /// both absent — the knob is the whole story.
  factory cupertino(PureTheme theme) {
    final base = theme.slider;
    return _SliderVisual(
      height: theme.token.scale.controlHeightSM,
      trackHeight: base.railHeight - 1,
      activeHeight: base.railHeight - 1,
      radius: BorderRadius.circular(PureRadii.pill),
      trackSurface: null,
      trackOutline: null,
      outlineWidth: 0,
      // The rail's own grey, and the darker one the value has run over: iOS
      // answers its filled portion by deepening the track, not by accenting it.
      inactiveColor: theme.colors.fillSecondary,
      activeColor: theme.colors.fill,
      handleSize: base.handleSize + PureRadii.xs,
      handleGrown: 0,
      handleRadius: PureRadii.pill,
      handleColor: theme.colors.white,
      handleOutline: null,
      handleOutlineWidth: 0,
      handleShadow: ({required pressed}) => theme.token.motion.boxShadowTertiary,
      halo: null,
      haloSize: 0,
      frosted: false,
      grooved: false,
      segmented: true,
      tickMarks: false,
      tickColor: theme.colors.textTertiary,
      tickDrop: 0,
      disabledAlpha: base.disabledOpacity,
      curve: Curves.easeOutCubic,
      bubble: null,
    );
  }

  /// macOS: the Aqua pull — a thin groove filled with the accent, a knob that
  /// is a rounded square rather than a circle, and one tick mark per division
  /// dropped under the rail, which is where the real control puts them.
  factory macos(PureTheme theme) {
    final base = theme.slider;
    return _SliderVisual(
      // The rail's own height, the knob over it and the row of marks under it.
      height: theme.token.scale.controlHeightSM + PureRadii.sm,
      trackHeight: base.railHeight,
      activeHeight: base.railHeight,
      radius: BorderRadius.circular(PureRadii.pill),
      trackSurface: theme.colors.bgElevated,
      trackOutline: theme.colors.borderSecondary,
      outlineWidth: theme.token.motion.lineWidth,
      inactiveColor: theme.colors.fillTertiary,
      activeColor: base.trackColor,
      handleSize: base.handleSize,
      handleGrown: 0,
      handleRadius: theme.token.scale.radii.base,
      handleColor: theme.colors.bgElevated,
      handleOutline: theme.colors.borderSecondary,
      handleOutlineWidth: theme.token.motion.lineWidth,
      handleShadow: ({required pressed}) => theme.token.motion.boxShadowTertiary,
      halo: null,
      haloSize: 0,
      frosted: false,
      grooved: false,
      segmented: false,
      tickMarks: true,
      tickColor: theme.colors.textTertiary,
      tickDrop: base.railHeight / 2 + theme.token.scale.sizes.xs,
      disabledAlpha: base.disabledOpacity,
      curve: Curves.easeOutCubic,
      bubble: null,
    );
  }

  /// WinUI: a thin outlined track with the accent run behind the knob and a
  /// large circular knob with its own border in front; the hover answer the
  /// language is known for is the knob swelling from its rest size to its
  /// larger one, and the track keeps one thickness.
  factory fluent(PureTheme theme) {
    final base = theme.slider;
    return _SliderVisual(
      // The swollen knob needs the room, and the ring around it more still.
      height: theme.token.scale.controlHeight,
      trackHeight: base.railHeight,
      activeHeight: base.railHeight,
      radius: BorderRadius.circular(PureRadii.xs),
      trackSurface: null,
      trackOutline: theme.colors.borderSecondary,
      outlineWidth: theme.token.motion.lineWidth,
      inactiveColor: theme.colors.fillSecondary,
      activeColor: base.trackColor,
      handleSize: theme.token.scale.controlHeightXS + PureRadii.xs,
      handleGrown: PureRadii.xs,
      handleRadius: PureRadii.pill,
      handleColor: base.handleColor,
      handleOutline: theme.colors.border,
      handleOutlineWidth: theme.token.motion.lineWidth * 2,
      handleShadow: ({required pressed}) => const [],
      halo: null,
      haloSize: 0,
      frosted: false,
      grooved: false,
      segmented: false,
      tickMarks: false,
      tickColor: theme.colors.textTertiary,
      tickDrop: 0,
      disabledAlpha: base.disabledOpacity,
      curve: Curves.easeOutCubic,
      bubble: null,
    );
  }

  /// Ubuntu: the thin dark track Yaru paints for its scales, the accent run up
  /// to the knob and the flat round knob over it, notched apart the way the
  /// distribution's own rail breaks. No marks and no bubble — the slider says
  /// nothing beyond its value.
  factory yaru(PureTheme theme) {
    final base = theme.slider;
    return _SliderVisual(
      height: theme.token.scale.controlHeightSM,
      trackHeight: base.railHeight,
      activeHeight: base.railHeight,
      radius: BorderRadius.circular(PureRadii.pill),
      trackSurface: null,
      trackOutline: null,
      outlineWidth: 0,
      inactiveColor: theme.colors.fill,
      activeColor: base.trackColor,
      handleSize: base.handleSize,
      handleGrown: 0,
      handleRadius: PureRadii.pill,
      handleColor: theme.colors.bgElevated,
      handleOutline: theme.colors.borderSecondary,
      handleOutlineWidth: theme.token.motion.lineWidth,
      handleShadow: ({required pressed}) => theme.token.motion.boxShadowTertiary,
      halo: theme.colors.primary.withValues(alpha: 0.12),
      haloSize: theme.token.scale.sizes.xxs,
      frosted: false,
      grooved: false,
      segmented: true,
      tickMarks: false,
      tickColor: theme.colors.textTertiary,
      tickDrop: 0,
      disabledAlpha: base.disabledOpacity,
      curve: Curves.easeOutCubic,
      bubble: null,
    );
  }

  /// shadcn — and the wind branch that shares its utility-class grammar: a
  /// crisp hairline track, the accent run up to the knob's edge, and a round
  /// knob with the accent's own border. The knob carries the value, so the
  /// bubble stays off rather than announcing a percentage the caller reads in
  /// its own units.
  factory forui(PureTheme theme) {
    final base = theme.slider;
    return _SliderVisual(
      height: theme.token.scale.controlHeightSM,
      trackHeight: base.railHeight,
      activeHeight: base.railHeight,
      radius: BorderRadius.circular(PureRadii.pill),
      trackSurface: null,
      trackOutline: null,
      outlineWidth: 0,
      inactiveColor: theme.colors.borderSecondary,
      activeColor: base.trackColor,
      handleSize: base.handleSize,
      handleGrown: 0,
      handleRadius: PureRadii.pill,
      handleColor: base.handleColor,
      handleOutline: base.handleBorderColor,
      handleOutlineWidth: theme.token.motion.lineWidth * 2,
      handleShadow: ({required pressed}) => theme.token.motion.boxShadowTertiary,
      halo: null,
      haloSize: 0,
      frosted: false,
      grooved: false,
      segmented: true,
      tickMarks: false,
      tickColor: theme.colors.textTertiary,
      tickDrop: 0,
      disabledAlpha: base.disabledOpacity,
      curve: Curves.easeOutCubic,
      bubble: null,
    );
  }

  /// Glass: a rail of frosted light — a real backdrop blur when the device can
  /// afford it, the pure colour ramp when it cannot — with the accent run laid
  /// into the frost and a knob that glows out of it.
  factory glass(PureTheme theme) {
    final base = theme.slider;
    Color frost(double alpha) => Colors.white.withValues(alpha: alpha);
    return _SliderVisual(
      height: theme.token.scale.controlHeightSM + PureRadii.sm,
      trackHeight: base.railHeight * 2,
      activeHeight: base.railHeight,
      radius: BorderRadius.circular(PureRadii.pill),
      trackSurface: frost(theme.isDark ? 0.08 : 0.55),
      trackOutline: frost(theme.isDark ? 0.25 : 0.7),
      outlineWidth: theme.token.motion.lineWidth,
      inactiveColor: frost(theme.isDark ? 0.12 : 0.25),
      activeColor: base.trackColor,
      handleSize: base.handleSize,
      handleGrown: PureRadii.xs,
      handleRadius: PureRadii.pill,
      handleColor: theme.colors.white,
      handleOutline: frost(0.7),
      handleOutlineWidth: theme.token.motion.lineWidth,
      handleShadow: ({required pressed}) => [
        BoxShadow(color: theme.colors.primary.withValues(alpha: pressed ? 0.75 : 0.55), blurRadius: 12),
      ],
      halo: null,
      haloSize: 0,
      frosted: true,
      grooved: false,
      segmented: true,
      tickMarks: false,
      tickColor: theme.colors.textTertiary,
      tickDrop: 0,
      disabledAlpha: base.disabledOpacity,
      curve: Curves.easeOutCubic,
      bubble: null,
    );
  }

  /// Neumorphic: the inset groove the language moulds its wells from — the
  /// raised track's shadow pair turned inside out — with the accent run sunk
  /// into it, and a knob that sits raised out of the mould until a drag presses
  /// it back down into it.
  factory neumorphic(PureTheme theme) {
    final base = theme.slider;
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
    return _SliderVisual(
      height: theme.token.scale.controlHeight,
      trackHeight: base.railHeight * 2,
      activeHeight: base.railHeight * 2,
      radius: BorderRadius.circular(PureRadii.pill),
      trackSurface: theme.colors.bgContainer,
      trackOutline: null,
      outlineWidth: 0,
      inactiveColor: theme.colors.fillTertiary,
      activeColor: base.trackColor,
      handleSize: base.handleSize,
      handleGrown: 0,
      handleRadius: PureRadii.pill,
      handleColor: base.handleColor,
      handleOutline: null,
      handleOutlineWidth: 0,
      handleShadow: ({required pressed}) => pressed ? sunk() : raised(),
      halo: null,
      haloSize: 0,
      frosted: false,
      grooved: true,
      segmented: true,
      tickMarks: false,
      tickColor: theme.colors.textTertiary,
      tickDrop: 0,
      disabledAlpha: base.disabledOpacity,
      curve: Curves.easeOutCubic,
      bubble: null,
    );
  }

  /// The control's own height: the box the rail is centred in, and the room a
  /// language's bubble or tick marks claim above and below it.
  final double height;

  /// The rail's thickness — the track's inactive, unpassed part.
  final double trackHeight;

  /// The passed part's thickness; Material 3 answers with a thicker stroke and
  /// the rest of the languages keep it level with the rail.
  final double activeHeight;

  /// The rail's corner. A language whose track reads as a hairline rather than
  /// a stadium gives its own radius.
  final BorderRadius radius;

  /// The rail's own bed, drawn under both runs of colour — the groove's floor,
  /// the frost's plate, the Aqua well. Null leaves the two runs as the track.
  final Color? trackSurface;

  /// The hairline around that bed; null draws none (and the width is then
  /// unread).
  final Color? trackOutline;

  /// The bed's outline width.
  final double outlineWidth;

  /// The colour of the track ahead of the handle.
  final Color inactiveColor;

  /// The colour of the track the value has run over.
  final Color activeColor;

  /// The handle's edge at rest.
  final double handleSize;

  /// How much the handle swells under the pointer; the languages whose knob
  /// answers a hover (WinUI) or a drag (Material 3) carry a value, the rest
  /// zero.
  final double handleGrown;

  /// The handle's corner; [PureRadii.pill] reads as the circle every language
  /// but macOS draws, and macOS's is the Aqua pull's rounded square.
  final double handleRadius;

  /// The handle's fill.
  final Color handleColor;

  /// The handle's border colour; null draws no border.
  final Color? handleOutline;

  /// The handle's border width.
  final double handleOutlineWidth;

  /// The handle's shadows: the sheets' own drop shadow, the glass language's
  /// glow, and the neumorphic mould's raised or pressed pair depending on
  /// whether a drag is holding it down.
  final List<BoxShadow> Function({required bool pressed}) handleShadow;

  /// The state layer that swells behind the handle on hover and drag; null is
  /// the languages that answer in the knob's own size.
  final Color? halo;

  /// How much wider the halo is than the handle inside it, on each side.
  final double haloSize;

  /// Whether the rail frosts the page behind it through a backdrop filter.
  final bool frosted;

  /// Whether the rail is the language's inset groove rather than a bar.
  final bool grooved;

  /// Whether the two runs read as separate notches with a hairline gap around
  /// the handle — the iOS, Yaru, shadcn, glass and neumorphic tracks — instead
  /// of one continuous rail the accent runs over.
  final bool segmented;

  /// Whether the language draws a mark per division.
  final bool tickMarks;

  /// The marks' colour.
  final Color tickColor;

  /// How far below the rail's centre line the marks sit; macOS's Aqua rail puts
  /// them outside the groove, the rest draw them on it.
  final double tickDrop;

  /// The opacity of a disabled slider; Material 3 answers with its spec's 38
  /// percent, the others with the token's loading opacity.
  final double disabledAlpha;

  /// The curve the handle slides and swells on, and the fill and tints fade
  /// along.
  final Curve curve;

  /// The bubble a drag names the value in; null is the languages whose knob
  /// carries the value on its own.
  final _SliderBubble? bubble;

  /// The hairline the notched languages leave between the handle and the rail's
  /// far run, in the rail's own units.
  double get segmentGap => trackHeight / 2;

  /// The room the handle takes at its largest, including the halo it swells
  /// into: the box it rides stays this size so a swell keeps the knob centred
  /// on the value instead of sliding it off.
  double get handleSlot => handleSize + handleGrown + haloSize * 2;

  /// The handle's decoration at one interaction state, with the kit's focus
  /// ring folded into the shadows so it swells with the handle it names.
  BoxDecoration handleDecoration({required bool pressed, required Color? ringColor, required double ringWidth}) {
    final outline = handleOutline;
    final circle = handleRadius * 2 >= handleSize + handleGrown;
    final ring = ringColor == null || ringWidth <= 0 ? null : BoxShadow(color: ringColor, spreadRadius: ringWidth);
    return BoxDecoration(
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(handleRadius),
      color: handleColor,
      border: outline == null || handleOutlineWidth <= 0 ? null : Border.all(color: outline, width: handleOutlineWidth),
      boxShadow: [
        ...handleShadow(pressed: pressed),
        ?ring,
      ],
    );
  }
}

/// The value indicator a language's drag shows: the bubble's surface, its
/// corner, and the words it puts on the value.
@immutable
final class _SliderBubble {
  const new({
    required this.color,
    required this.foreground,
    required this.radius,
    required this.fontSize,
    required this.label,
  });

  /// The bubble's fill.
  final Color color;

  /// The value's colour on that fill.
  final Color foreground;

  /// The bubble's corner.
  final BorderRadius radius;

  /// The value's size, before the theme's font scale.
  final double fontSize;

  /// The words the value is named with.
  final String Function(double value) label;
}

/// The slider's body: the rail, its two runs of colour, its marks, its halo and
/// the handle that rides the value, under one interaction contract — the whole
/// track hit-tested for a drag, a tap that moves the value to where it landed,
/// the kit's focus ring, the step keys and Home and End, and the `slider`
/// semantics every language shares.
class _SliderCore extends StatefulWidget {
  const new({
    required this.visual,
    required this.value,
    required this.fraction,
    required this.min,
    required this.max,
    required this.step,
    required this.divisions,
    required this.report,
    required this.onChangeStart,
    required this.onChangeEnd,
    required this.focusNode,
    required this.autofocus,
    required this.semanticLabel,
    super.key,
  });

  final _SliderVisual visual;

  /// The value clamped into the range — what the handle rides and what a screen
  /// reader hears.
  final double value;

  /// That value normalised onto the 0..1 rail.
  final double fraction;

  final double min;

  final double max;

  /// One keyboard step, in the range's own units.
  final double step;

  /// The number of notches, or null for a continuous track.
  final int? divisions;

  /// The live callback; null is the disabled verdict the public widget has
  /// already folded `enabled` into.
  final ValueChanged<double>? report;

  final VoidCallback? onChangeStart;

  final VoidCallback? onChangeEnd;

  final FocusNode? focusNode;

  final bool autofocus;

  final String? semanticLabel;

  @override
  State<_SliderCore> createState() => _SliderCoreState();
}

class _SliderCoreState extends State<_SliderCore> {
  bool _hovered = false;
  bool _dragging = false;
  bool _focused = false;

  bool get _live => widget.report != null;

  /// Whether the handle is answering a pointer: the swell, the halo and the
  /// bubble all hang off this one verdict.
  bool get _engaged => _live && (_dragging || _hovered);

  /// The value a fraction of the rail stands for, snapped to the notches a
  /// stepped slider has and clamped into the range it belongs to.
  double _valueAt(double fraction) => _quantise(widget.min + fraction * (widget.max - widget.min));

  double _quantise(double raw) {
    final min = widget.min;
    final max = widget.max;
    final divisions = widget.divisions;
    final notch = divisions == null ? 0 : (max - min) / divisions;
    if (notch <= 0) {
      return raw.clamp(min, max);
    }
    return (min + ((raw - min) / notch).roundToDouble() * notch).clamp(min, max);
  }

  void _begin(FocusNode node) {
    if (!_live || _dragging) {
      return;
    }
    node.requestFocus();
    setState(() => _dragging = true);
    widget.onChangeStart?.call();
  }

  void _end() {
    if (!_dragging) {
      return;
    }
    setState(() => _dragging = false);
    widget.onChangeEnd?.call();
  }

  /// The keyboard's one step: Left and Down run the value down, Right and Up
  /// run it up, Home and End jump to the bounds. Whatever else the shell has in
  /// mind for a key is left to the shell.
  void _stepBy(int direction) {
    widget.report?.call(_quantise(widget.value + direction * widget.step));
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (!_live) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowUp) {
      _stepBy(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowDown) {
      _stepBy(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      widget.report!(widget.min);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      widget.report!(widget.max);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final visual = widget.visual;
    final live = _live;
    final centre = visual.height / 2;
    // The rail stops short of the widest the handle ever gets, so a knob that
    // swells under the pointer never overhangs the track it rides.
    final inset = visual.handleSlot / 2;
    final handleExtent = visual.handleSize + (_engaged ? visual.handleGrown : 0);

    return SizedBox(
      height: visual.height,
      width: double.infinity,
      child: Focus(
        focusNode: widget.focusNode,
        debugLabel: 'PureSlider',
        canRequestFocus: live,
        autofocus: widget.autofocus && live,
        onFocusChange: (focused) => setState(() => _focused = focused),
        onKeyEvent: _handleKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final node = Focus.of(context);
            final travel = (constraints.maxWidth - inset * 2).clamp(0.0, double.infinity);
            // A pointer's position read back as a fraction of the rail: the
            // whole track answers, which is the hit-test half of the contract
            // every language shares.
            double fractionAt(Offset global) {
              if (travel <= 0) {
                return 0;
              }
              final box = context.findRenderObject();
              final local = box is RenderBox ? global - box.localToGlobal(Offset.zero) : global;
              return ((local.dx - inset) / travel).clamp(0.0, 1.0);
            }

            void reportAt(Offset global) {
              widget.report?.call(_valueAt(fractionAt(global)));
            }

            final centreX = inset + widget.fraction * travel;
            final gap = visual.segmented ? visual.segmentGap : 0.0;
            final inactiveLeft = visual.segmented ? centreX + handleExtent / 2 + gap : inset;

            return MouseRegion(
              cursor: live ? SystemMouseCursors.click : MouseCursor.defer,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: live ? (_) => _begin(node) : null,
                // A tap puts the value where the finger landed — the answer the
                // Material and iOS tracks this kit used to borrow already gave,
                // kept.
                onTapUp: live
                    ? (details) {
                        reportAt(details.globalPosition);
                        _end();
                      }
                    : null,
                onTapCancel: live ? _end : null,
                onHorizontalDragStart: live
                    ? (details) {
                        _begin(node);
                        reportAt(details.globalPosition);
                      }
                    : null,
                onHorizontalDragUpdate: live ? (details) => reportAt(details.globalPosition) : null,
                onHorizontalDragEnd: live ? (_) => _end() : null,
                onHorizontalDragCancel: live ? _end : null,
                child: Semantics(
                  container: true,
                  slider: true,
                  enabled: live,
                  label: widget.semanticLabel,
                  value: _describeValue(widget.value),
                  increasedValue: _describeValue(_quantise(widget.value + widget.step)),
                  decreasedValue: _describeValue(_quantise(widget.value - widget.step)),
                  textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
                  onIncrease: live ? () => _stepBy(1) : null,
                  onDecrease: live ? () => _stepBy(-1) : null,
                  child: ExcludeSemantics(
                    child: AnimatedOpacity(
                      duration: theme.duration,
                      opacity: live ? 1 : visual.disabledAlpha,
                      child: Stack(
                        // The bubble rides above the rail and the halo hangs
                        // past the handle; neither is clipped away.
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: _SliderTrack(
                              visual: visual,
                              centre: centre,
                              left: inset,
                              travel: travel,
                              inactiveLeft: inactiveLeft,
                              fraction: widget.fraction,
                            ),
                          ),
                          Positioned(
                            left: inset,
                            top: 0,
                            width: travel,
                            height: visual.height,
                            child: _TickMarks(visual: visual, divisions: widget.divisions, travel: travel),
                          ),
                          if (visual.bubble case final bubble?)
                            _ValueIndicator(
                              visual: visual,
                              bubble: bubble,
                              value: widget.value,
                              centre: centre,
                              centreX: centreX,
                              travel: travel,
                              shown: _dragging && live,
                              sliding: !_dragging,
                              duration: theme.duration,
                            ),
                          _Handle(
                            visual: visual,
                            centre: centre,
                            centreX: centreX,
                            extent: handleExtent,
                            pressed: _dragging,
                            swollen: _engaged,
                            ringColor: live && _focused ? theme.colors.primary : null,
                            ringWidth: theme.token.motion.lineWidth * 2,
                            sliding: !_dragging,
                            duration: theme.duration,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The rail: the bed a language puts its track on — frosted, grooved, outlined
/// or nothing at all — with the run the value has passed over and the run ahead
/// of it laid on top. Two runs of one colour for the languages whose accent
/// simply overpaints the rail, and two notches with a hairline gap around the
/// handle for the ones that break it.
class _SliderTrack extends StatelessWidget {
  const new({
    required this.visual,
    required this.centre,
    required this.left,
    required this.travel,
    required this.inactiveLeft,
    required this.fraction,
  });

  final _SliderVisual visual;

  /// The rail's centre line inside the control's box.
  final double centre;

  /// Where the rail starts and how far it runs.
  final double left;

  final double travel;

  /// Where the run ahead of the handle starts: the rail's own end for the
  /// continuous languages, just past the handle for the notched ones.
  final double inactiveLeft;

  /// How much of the rail the value has run over.
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final surface = visual.trackSurface;
    final outline = visual.trackOutline;
    final bed = surface == null && outline == null
        ? null
        : DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: visual.radius,
              border: outline == null || visual.outlineWidth <= 0
                  ? null
                  : Border.all(color: outline, width: visual.outlineWidth),
              boxShadow: visual.grooved ? _groove(theme) : null,
            ),
          );
    // The glass language frosts the page behind its rail when the device can
    // afford the blur, and paints the pure colour ramp when it cannot.
    final Widget? rail = bed == null
        ? null
        : visual.frosted && theme.canBlur
        ? ClipRRect(
            borderRadius: visual.radius,
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12), child: bed),
          )
        : bed;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (rail != null)
          Positioned(
            left: left,
            top: centre - visual.trackHeight / 2,
            width: travel,
            height: visual.trackHeight,
            child: rail,
          ),
        _Run(
          color: visual.inactiveColor,
          radius: visual.radius,
          left: inactiveLeft,
          width: (left + travel - inactiveLeft).clamp(0.0, double.infinity),
          thickness: visual.trackHeight,
          centre: centre,
        ),
        _Run(
          color: visual.activeColor,
          radius: visual.radius,
          left: left,
          width: travel * fraction,
          thickness: visual.activeHeight,
          centre: centre,
        ),
      ],
    );
  }

  /// The neumorphic language's inset groove: the raised track's shadow pair
  /// turned inside out, which is how this kit reads a mould pressed into the
  /// surface.
  static List<BoxShadow> _groove(PureTheme theme) => [
    BoxShadow(
      color: theme.colors.shadowBase.withValues(alpha: theme.isDark ? 0.24 : 0.12),
      blurRadius: 4,
      offset: const Offset(2, 2),
    ),
    BoxShadow(
      color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.7),
      blurRadius: 4,
      offset: const Offset(-2, -2),
    ),
  ];
}

/// One run of the track: a bar of colour with the rail's corner, laid at the
/// thickness its language gives that part of the track — the same thickness as
/// the rail everywhere but Material 3, whose active stroke is the thicker one.
class _Run extends StatelessWidget {
  const new({
    required this.color,
    required this.radius,
    required this.left,
    required this.width,
    required this.thickness,
    required this.centre,
  });

  final Color color;

  final BorderRadius radius;

  final double left;

  final double width;

  final double thickness;

  final double centre;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: centre - thickness / 2,
      width: width,
      height: thickness,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, borderRadius: radius),
      ),
    );
  }
}

/// The notches a stepped slider's language marks — one per division, the two
/// bounds included, which is where the Aqua rail puts them under its groove.
/// A language that draws no marks, or a value that runs continuous, gets
/// nothing at all.
class _TickMarks extends StatelessWidget {
  const new({required this.visual, required this.divisions, required this.travel});

  final _SliderVisual visual;

  final int? divisions;

  final double travel;

  @override
  Widget build(BuildContext context) {
    final count = divisions;
    if (!visual.tickMarks || count == null || count <= 0 || travel <= 0) {
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: _TickPainter(
        travel: travel,
        count: count,
        drop: visual.tickDrop,
        radius: visual.trackHeight / 2,
        color: visual.tickColor,
      ),
      size: Size.infinite,
    );
  }
}

class _TickPainter extends CustomPainter {
  const new({required this.travel, required this.count, required this.drop, required this.radius, required this.color});

  final double travel;

  final int count;

  final double drop;

  final double radius;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final middle = size.height / 2 + drop;
    for (var notch = 0; notch <= count; notch++) {
      canvas.drawCircle(Offset(travel * (notch / count), middle), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) =>
      old.travel != travel || old.count != count || old.drop != drop || old.radius != radius || old.color != color;
}

/// The handle: the state layer a language swells behind it, and the knob itself
/// with its border, its shadow and the kit's focus ring, riding the value along
/// the rail.
class _Handle extends StatelessWidget {
  const new({
    required this.visual,
    required this.centre,
    required this.centreX,
    required this.extent,
    required this.pressed,
    required this.swollen,
    required this.ringColor,
    required this.ringWidth,
    required this.sliding,
    required this.duration,
  });

  final _SliderVisual visual;

  final double centre;

  final double centreX;

  /// The knob's edge at the interaction state it is in.
  final double extent;

  final bool pressed;

  final bool swollen;

  final Color? ringColor;

  final double ringWidth;

  /// Whether the handle slides to its value or is told where it is.
  final bool sliding;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final slot = visual.handleSlot;
    final halo = visual.halo;
    final haloExtent = extent + visual.haloSize * 2;
    return _OnHandle(
      centreX: centreX,
      slot: slot,
      top: centre - slot / 2,
      sliding: sliding,
      duration: duration,
      curve: visual.curve,
      child: Stack(
        alignment: AlignmentDirectional.center,
        clipBehavior: Clip.none,
        children: [
          if (halo != null && swollen)
            AnimatedContainer(
              duration: duration,
              curve: visual.curve,
              width: haloExtent,
              height: haloExtent,
              decoration: BoxDecoration(color: halo, borderRadius: BorderRadius.circular(PureRadii.pill)),
            ),
          AnimatedContainer(
            duration: duration,
            curve: visual.curve,
            width: extent,
            height: extent,
            decoration: visual.handleDecoration(pressed: pressed, ringColor: ringColor, ringWidth: ringWidth),
          ),
        ],
      ),
    );
  }
}

/// The bubble a drag names the value in, riding above the rail the way M3 lifts
/// its indicator off the track and sliding with the handle it belongs to.
class _ValueIndicator extends StatelessWidget {
  const new({
    required this.visual,
    required this.bubble,
    required this.value,
    required this.centre,
    required this.centreX,
    required this.travel,
    required this.shown,
    required this.sliding,
    required this.duration,
  });

  final _SliderVisual visual;

  final _SliderBubble bubble;

  final double value;

  final double centre;

  final double centreX;

  /// How far the rail runs, which is the widest room a bubble gets before it
  /// would hang past the track's own ends.
  final double travel;

  final bool shown;

  final bool sliding;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    return _OnHandle(
      centreX: centreX,
      slot: travel,
      top: 0,
      boxHeight: centre - visual.trackHeight / 2,
      alignment: AlignmentDirectional.bottomCenter,
      sliding: sliding,
      duration: duration,
      curve: visual.curve,
      child: AnimatedScale(
        scale: shown ? 1 : 0,
        duration: duration,
        curve: visual.curve,
        alignment: Alignment.bottomCenter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bubble.color,
            borderRadius: bubble.radius,
            boxShadow: theme.token.motion.boxShadowTertiary,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: theme.token.scale.sizes.xs,
              vertical: theme.token.scale.sizes.xxs,
            ),
            child: Text(
              bubble.label(value),
              maxLines: 1,
              style: TextStyle(
                // The bubble's line rides the theme's font scale with the rest
                // of the chrome.
                fontSize: bubble.fontSize * (theme.text.caption.fontSize! / theme.token.type.fontSizeSM),
                height: 1,
                fontWeight: FontWeight.w600,
                color: bubble.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Slots a layer on the handle: centred on the value along the rail and sliding
/// there on the language's own curve — except while a drag is running, when the
/// handle is told where it is every frame and snapping is the answer.
class _OnHandle extends StatelessWidget {
  const new({
    required this.centreX,
    required this.slot,
    required this.top,
    required this.sliding,
    required this.duration,
    required this.curve,
    required this.child,
    this.boxHeight,
    this.alignment = AlignmentDirectional.center,
  });

  final double centreX;

  /// The width of the box the layer sits in, centred on the handle.
  final double slot;

  final double top;

  /// The box's height; null keeps it square with [slot], which is the handle's
  /// own case.
  final double? boxHeight;

  final bool sliding;

  final Duration duration;

  final Curve curve;

  final AlignmentDirectional alignment;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = boxHeight ?? slot;
    final box = Align(alignment: alignment, child: child);
    final left = centreX - slot / 2;
    return sliding
        ? AnimatedPositioned(
            duration: duration,
            curve: curve,
            left: left,
            top: top,
            width: slot,
            height: height,
            child: box,
          )
        : Positioned(left: left, top: top, width: slot, height: height, child: box);
  }
}

/// The value's own words: a whole number reads plainly, and a value with a
/// fraction keeps the digits it has without the padding zeros a fixed-format
/// render adds — so a bubble, a screen reader and the label beside the track
/// all say one thing.
String _describeValue(double value) {
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
}
