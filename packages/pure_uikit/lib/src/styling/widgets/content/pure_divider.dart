import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The key every grammar puts on its stroke, so the rule a language drew is
/// addressable in tests and diagnostics wherever a divider carries one (a
/// labelled rule has two, one per side of the text).
const ValueKey<String> _ruleKey = ValueKey<String>('PureDivider.rule');

/// A separator between content: one widget, nine self-painted grammars.
///
/// Nothing here is borrowed. Each design language's own rule is drawn from the
/// theme's tokens — Material's full-bleed hairline riding the 16dp band its
/// `Divider` reserves, iOS's separator inset from the leading edge alone, the
/// macOS rule inset from the Mac grid's content margin at both ends, WinUI's
/// subtle full-bleed stroke at the faintest border tone, Yaru's flat rule,
/// shadcn's and forui's border-coloured hairline, the glass sheet's lit edge
/// under its seam, neumorphic's engraved groove (dark wall, floor, lit lip),
/// and wind's crisp double-weight line. Every library's divider is a line and a
/// colour; only the line's weight, its insets, its band and the number of
/// layers stacking across it differ, which is exactly what [_Visual] carries.
///
/// Two tokens decide the geometry, the same pair the libraries resolve their own
/// separators against: the stroke comes from `motion.lineWidth`-family
/// ([_Visual.layers] weights, so a bold language and a hairline language stay
/// distinguishable and both thicken with the seed), the colour from
/// `colors.border` / `colors.borderSecondary`. A [color] from the call site
/// replaces the base layer and leaves the derived layers (the glass lit edge,
/// the neumorphic floor and lip) to the theme, because those are the grammar,
/// not the tone.
///
/// The layout contract: the rule spans the slot it is given along its own axis —
/// width when [axis] is horizontal, height when it is vertical — so [extent]
/// stays what it always was, the band the stroke is centred *in* across the
/// rule (height horizontal, width vertical), never its length. A slot with an
/// unbounded main axis therefore has to bound the rule itself, the same way
/// Flutter's own `Divider`/`VerticalDivider` require it. [indent] and
/// [endIndent] run along the rule (leading/trailing horizontal, top/bottom
/// vertical) and fall back to the language's own inset where its grammar has
/// one — only iOS and macOS inset a horizontal rule by themselves, the other
/// seven run edge to edge, and an upright rule insets nothing unless the call
/// site says so.
class PureDivider extends StatelessWidget {
  /// A rule, optionally indented at either end, optionally set in an
  /// [extent]-wide band, optionally drawn in [color] instead of the language's
  /// own separator tone, optionally turned vertical, and optionally broken by a
  /// [label] with the text centred in it.
  const new({
    this.indent,
    this.endIndent,
    this.extent,
    this.color,
    this.axis = Axis.horizontal,
    this.label,
    this.semanticLabel,
    super.key,
  });

  /// The gap left before the line begins.
  final double? indent;

  /// The gap left after the line ends.
  final double? endIndent;

  /// The band the line is centred in, or null for the language's own.
  final double? extent;

  /// A rule colour of its own, for a divider that separates a different kind of
  /// block than the list rows the token's separator serves.
  final Color? color;

  /// Which way the rule runs. [Axis.vertical] turns the same grammar upright —
  /// a column separator keeps its language's weight, its band and its layers,
  /// and spans the height it is given instead of the width.
  final Axis axis;

  /// Text centred in the rule, splitting it into two segments; the labelled
  /// grammar every language answers with its own stroke either side.
  final String? label;

  /// The name a screen reader gives the rule. Flutter's semantics ships no
  /// separator role, so a bare rule says nothing and stays out of the a11y
  /// tree; naming one here — or setting [label] — is what puts it in.
  final String? semanticLabel;

  /// The nine rules, one grammar per design language.
  static _Visual _resolveVisual(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.material => _Visual.material(theme),
    PureDesignLanguage.cupertino => _Visual.cupertino(theme),
    PureDesignLanguage.macos => _Visual.macos(theme),
    PureDesignLanguage.fluent => _Visual.fluent(theme),
    PureDesignLanguage.yaru => _Visual.yaru(theme),
    PureDesignLanguage.forui => _Visual.forui(theme),
    PureDesignLanguage.glass => _Visual.glass(theme),
    PureDesignLanguage.neumorphic => _Visual.neumorphic(theme),
    PureDesignLanguage.wind => _Visual.wind(theme),
  };

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final vertical = axis == Axis.vertical;
    final visual = _resolveVisual(theme);
    final layers = visual.layers(theme, color ?? visual.color);
    final thickness = layers.fold<double>(0, (total, layer) => total + layer.width);
    // Where the language insets by itself, the call site can still ask for a
    // full-bleed rule by naming 0 — `??`, not `||`, keeps that answer. Only the
    // horizontal grammar insets itself: a language's separator inset is a
    // convention about where its rows begin, not about where its columns do.
    final start = indent ?? (vertical ? 0 : visual.startInset);
    final end = endIndent ?? (vertical ? 0 : visual.endInset);
    // The band across the rule. A labelled rule leaves it to its own text when
    // the grammar draws no gap, so words are never centred in a hairline.
    final requested = extent ?? visual.band;
    final band = label == null || requested > 0 ? math.max(requested, thickness) : 0.0;

    final Widget line;
    if (label case final text?) {
      final gap = theme.token.scale.sizes.sm;
      final labelStyle = theme.text.label.copyWith(color: theme.colors.textSecondary);
      line = Flex(
        direction: vertical ? Axis.vertical : Axis.horizontal,
        children: [
          Expanded(child: _stroke(layers, thickness, vertical: vertical, spansSlot: false)),
          if (vertical) SizedBox(height: gap) else SizedBox(width: gap),
          Text(text, style: labelStyle),
          if (vertical) SizedBox(height: gap) else SizedBox(width: gap),
          Expanded(child: _stroke(layers, thickness, vertical: vertical, spansSlot: false)),
        ],
      );
    } else {
      line = _stroke(layers, thickness, vertical: vertical, spansSlot: true);
    }

    // The insets run along the rule, the band across it; `Align` rather than a
    // tight box because a band taller than the stroke must not stretch it, and
    // a minimum rather than a fixed band where the text is the taller of the
    // two, so the words are never cut by the gap they sit in.
    final inset = vertical
        ? EdgeInsets.only(top: start, bottom: end)
        : EdgeInsetsDirectional.only(start: start, end: end);
    Widget body = Padding(padding: inset, child: line);
    if (band > 0) {
      // An unlabelled rule is centred in its band; a labelled one takes the band
      // as a minimum, so the gap is never shorter than the words it holds.
      body = label == null
          ? SizedBox(
              height: vertical ? null : band,
              width: vertical ? band : null,
              child: Align(alignment: AlignmentDirectional.center, child: body),
            )
          : ConstrainedBox(
              constraints: vertical ? BoxConstraints(minWidth: band) : BoxConstraints(minHeight: band),
              child: body,
            );
    }

    final name = semanticLabel ?? label;
    return KeyedSubtree(
      // The grammar a divider draws is its identity in tests and diagnostics.
      key: ValueKey('PureDivider.${theme.config.language.name}'),
      child: name == null
          ? body
          : Semantics(
              key: const ValueKey('PureDivider.named'),
              container: true,
              label: name,
              // The printed text is the name the node already carries, so it is
              // not read a second time.
              excludeSemantics: true,
              child: body,
            ),
    );
  }

  /// One stroke: [thickness] across the rule, the language's layers stacked in
  /// hard slabs along it, spanning the slot's length when [spansSlot] (the
  /// labelled segments are sized by the flex they sit in instead).
  ///
  /// The slab stack runs on fixed alignments, never directional ones: a lit
  /// edge is a property of the light, not of the reading order, so an RTL locale
  /// mirrors the rule's insets and not its shading.
  Widget _stroke(List<_RuleLayer> layers, double thickness, {required bool vertical, required bool spansSlot}) {
    final cumulative = <double>[];
    var across = 0.0;
    for (final layer in layers) {
      across += layer.width;
      cumulative.add(across / thickness);
    }
    // Each layer keeps its own colour, so a two-layer grammar is one hard edge,
    // not a fade: duplicate every interior stop and every colour.
    final stops = <double>[0];
    for (var i = 0; i < cumulative.length - 1; i++) {
      stops
        ..add(cumulative[i])
        ..add(cumulative[i]);
    }
    stops.add(1);
    final decoration = BoxDecoration(
      gradient: LinearGradient(
        begin: vertical ? Alignment.centerLeft : Alignment.topCenter,
        end: vertical ? Alignment.centerRight : Alignment.bottomCenter,
        colors: [
          for (final layer in layers) ...[layer.color, layer.color],
        ],
        stops: stops,
      ),
    );
    return DecoratedBox(
      key: _ruleKey,
      decoration: decoration,
      child: vertical
          ? SizedBox(width: thickness, height: spansSlot ? double.infinity : null)
          : SizedBox(height: thickness, width: spansSlot ? double.infinity : null),
    );
  }
}

/// One slab of a rule: the colour it paints and how far across the stroke that
/// colour runs. A hairline language is a single layer of `lineWidth`; the
/// bevelled grammars stack two or three, which is what makes an engraved groove
/// read as carved rather than as a darker line.
@immutable
final class _RuleLayer {
  /// A slab.
  const new({required this.color, required this.width});

  /// The colour the slab paints.
  final Color color;

  /// How far across the stroke it runs.
  final double width;
}

/// How one design language rules its separators: the stroke's layers, the band
/// the rule rides in, the insets the grammar takes by itself, and the tone it
/// answers in when the call site names none.
@immutable
final class _Visual {
  /// A divider grammar.
  const new({
    required this.band,
    required this.startInset,
    required this.endInset,
    required this.color,
    required this.layers,
  });

  /// The single-hairline grammars, which differ only in band, tone and inset.
  factory flat({
    required double band,
    required Color color,
    required double weight,
    double startInset = 0,
    double endInset = 0,
  }) {
    return _Visual(
      band: band,
      startInset: startInset,
      endInset: endInset,
      color: color,
      layers: (theme, base) => [_RuleLayer(color: base, width: weight)],
    );
  }

  /// Android Material: a single hairline of the list's own separator tone,
  /// full-bleed, riding the 16dp band `Divider`'s `height` reserves. Ubuntu's
  /// Yaru sibling keeps the same band and the same flat stroke — the two
  /// grammars differ by colour ramp, not by geometry.
  factory material(PureTheme theme) =>
      _Visual.flat(band: 16, color: theme.colors.border, weight: theme.token.motion.lineWidth);

  /// iOS: the grouped-table separator, a hairline inset 16pt from the leading
  /// edge only and running flush to the trailing one — the rule every UIKit row
  /// is measured against. It draws no band: the cells above and below already
  /// answer for the gap.
  factory cupertino(PureTheme theme) =>
      _Visual.flat(band: 0, color: theme.colors.borderSecondary, weight: theme.token.motion.lineWidth, startInset: 16);

  /// macOS: the same hairline inset from both ends by the Mac grid's content
  /// margin, because a pane's rule stops short of the window's rounded corners
  /// instead of running under them.
  factory macos(PureTheme theme) => _Visual.flat(
    band: 0,
    color: theme.colors.borderSecondary,
    weight: theme.token.motion.lineWidth,
    startInset: 20,
    endInset: 20,
  );

  /// Windows Fluent: WinUI's `Divider` at its faintest appearance — the stroke
  /// sits on the lightest border tone and spans the container with no inset,
  /// since Fluent's own inset axis defaults to off.
  factory fluent(PureTheme theme) =>
      _Visual.flat(band: 0, color: theme.colors.borderSecondary, weight: theme.token.motion.lineWidth);

  /// Ubuntu Yaru: the distribution's flat rule — full-bleed, one weight, the
  /// solid border tone, no bevel and no shadow. Yaru separates content with
  /// lines, never with elevation.
  factory yaru(PureTheme theme) =>
      _Visual.flat(band: 16, color: theme.colors.border, weight: theme.token.motion.lineWidth);

  /// shadcn: the border token as the rule, one weight, centred in the 16dp gap
  /// the library's own divider padding reserves on both sides.
  factory forui(PureTheme theme) =>
      _Visual.flat(band: 16, color: theme.colors.border, weight: theme.token.motion.lineWidth);

  /// The glass language: the seam a sheet meets its page at, with the light
  /// edge painted under it. Two slabs — the border hairline and a lit line of
  /// the sheet's own highlight — so the rule reads as the top of something
  /// transparent rather than as ink on paper.
  factory glass(PureTheme theme) {
    final line = theme.token.motion.lineWidth;
    return _Visual(
      band: 0,
      startInset: 0,
      endInset: 0,
      color: theme.colors.borderSecondary,
      layers: (t, base) => [
        _RuleLayer(color: base, width: line),
        _RuleLayer(
          color: t.colors.white.withValues(alpha: t.isDark ? 0.38 : 0.72),
          width: line,
        ),
      ],
    );
  }

  /// Neumorphic: a groove pressed into the mouldable base — the dark inner wall
  /// at the top, a floor of the plane's own colour, and the lit lip catching the
  /// light below it. The twin shadow that makes the language's extrusion, read
  /// as one engraved line instead of a stroke.
  factory neumorphic(PureTheme theme) {
    final line = theme.token.motion.lineWidth;
    return _Visual(
      band: 0,
      startInset: 0,
      endInset: 0,
      color: theme.colors.border,
      layers: (t, base) => [
        // The wall is the named tone pushed toward the cast colour, so a call
        // site that asks for a rule of its own still gets a carved edge.
        _RuleLayer(color: Color.lerp(base, t.colors.shadowBase, 0.55)!, width: line),
        _RuleLayer(color: t.colors.bgContainer, width: line),
        _RuleLayer(
          color: t.colors.white.withValues(alpha: t.isDark ? 0.07 : 0.75),
          width: line,
        ),
      ],
    );
  }

  /// The wind sibling: the crisp rule — the bold step of the line ladder, drawn
  /// once, in the solid border tone, with no band and no bevel. Wind separates
  /// with a harder edge rather than with a wider gap.
  factory wind(PureTheme theme) =>
      _Visual.flat(band: 0, color: theme.colors.border, weight: theme.token.motion.lineWidthBold);

  /// The band the stroke is centred in, or 0 for the grammars that draw the
  /// rule alone and leave the gap to the rows either side of it.
  final double band;

  /// The gap this language leaves before its rule by itself, on the horizontal
  /// grammar only — an inset separator is a convention about where a language's
  /// rows begin, not where its columns do; a call site's
  /// [PureDivider.indent] answers for it when it names one, 0 included.
  final double startInset;

  /// The gap this language leaves after its rule by itself, same terms.
  final double endInset;

  /// The tone the rule answers in when the call site names no colour.
  final Color color;

  /// The slabs stacked across the stroke, leading edge first: for a horizontal
  /// rule that is top to bottom, for a vertical one left to right. The closure's
  /// own `base` argument is the caller's colour where it gave one and this
  /// grammar's tone where it did not; a grammar with more than one layer derives
  /// the rest from the theme.
  final List<_RuleLayer> Function(PureTheme theme, Color base) layers;
}
