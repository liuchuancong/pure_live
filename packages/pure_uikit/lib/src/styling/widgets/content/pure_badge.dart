import 'dart:math' show max, min;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A count, a dot or a short tag — the kit's answer to Ant's `Badge`.
///
/// The three roles are one contract: a [count] is a bubble whose number
/// collapses to `max+` past [max], a [dot] is the bare marker, and a [label] is
/// the same bubble worn as a tag. Anchored to a [child] the badge rides that
/// child's top-right corner and overlaps it, knocking a ring of the container
/// colour out from under the bubble so it stays legible over an avatar or a
/// thumbnail; with no [child] it stands alone as the tag.
///
/// All of it is painted here, from the theme's own tokens — colours, radii,
/// type — because no widget library owns the corner-anchor grammar a count
/// over a 36dp avatar needs. The shape is the WinUI `InfoBadge`: a dot, or a
/// pill rimmed with the system stroke. Drawn once, one contract holds: the
/// overlap, the ring, the cap, the semantics and the user's text scale behave
/// the same whatever the config says, and its `language` names the badge's
/// identity key only — a non-fluent value keeps compiling and simply draws
/// this badge.
class PureBadge extends StatelessWidget {
  /// A badge.
  const new({
    this.child,
    this.count,
    this.label,
    this.dot = false,
    this.enabled = true,
    this.max = 99,
    this.color,
    this.semanticLabel,
    super.key,
  });

  /// The widget the badge is anchored to; omit for a standalone badge.
  final Widget? child;

  /// A numeric count; shows `max+` when it exceeds [max]. Null hides the count.
  final int? count;

  /// A text label for the bubble (used when [count] is null).
  final String? label;

  /// Whether to render a small dot instead of a bubble.
  final bool dot;

  /// Whether the badge is shown at all.
  final bool enabled;

  /// The count ceiling before it collapses to `max+`.
  final int max;

  /// An optional background override (defaults to the error colour). The body
  /// takes it as its own fill and derives the rim and the type from it.
  final Color? color;

  /// The name a screen reader gives this badge. A counted or labelled badge
  /// already says that itself and reads [text]; a bare [dot] has nothing to be
  /// read and stays silent unless it is named here.
  final String? semanticLabel;

  /// The text this badge draws, after the [max] cap and the [dot] fold. Null is
  /// a badge with nothing to say: the dot form, or a call with neither a count
  /// nor a label.
  String? get text {
    if (dot) {
      return null;
    }
    final count = this.count;
    if (count != null) {
      return count > max ? '$max+' : '$count';
    }
    return label;
  }

  /// Whether the badge draws a shape at all. False leaves the [child] — or
  /// nothing, standalone — and takes the whole bubble out of the tree.
  bool get shows => enabled && (dot || text != null);

  /// The geometry, colours and body the badge draws — the fluent visual.
  static _BadgeVisual _visual(PureTheme theme) => _BadgeVisual.fluent(theme);

  @override
  Widget build(BuildContext context) {
    final anchor = child;
    if (!shows) {
      // An off badge is not an empty slot: whatever it was anchored to keeps its
      // own size, which is what a muted notification count has to look like.
      return anchor ?? const SizedBox.shrink();
    }
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    final visual = _visual(theme);
    final mark = _BadgeMark(
      // The config's language is the badge's identity key in tests and
      // diagnostics only; the drawing itself is fluent.
      key: ValueKey('PureBadge.${language.name}'),
      visual: visual,
      text: text,
      labelStyle: visual.labelStyle(theme),
      // Over a child the bubble wears its knockout ring; alone it does not,
      // because there is nothing behind it to knock out.
      ring: anchor != null,
      fillOverride: color,
      semanticsLabel: semanticLabel,
    );
    if (anchor == null) {
      return mark;
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        anchor,
        Positioned(
          // How far the bubble reaches past its child's corner.
          top: -visual.overlap,
          right: -visual.overlap,
          child: mark,
        ),
      ],
    );
  }
}

/// The geometry, colours and body the badge is painted with. Every colour is
/// resolved from the theme when the badge builds, so a dark switch comes out of
/// the same tokens the kit's other controls read — while the geometry stays
/// absolute pixels, because these are the sizes WinUI publishes for its own
/// `InfoBadge` and a badge that grew with the app's density would no longer be
/// theirs.
@immutable
final class _BadgeVisual {
  /// A badge visual.
  const new({
    required this.dotSize,
    required this.height,
    required this.minWidth,
    required this.fontSize,
    required this.fontWeight,
    required this.padInline,
    required this.radius,
    required this.halo,
    required this.overlap,
    required this.fill,
    required this.foreground,
    required this.painter,
    this.stroke,
    this.strokeWidth = 0,
  });

  /// WinUI's `InfoBadge`: the dot, or the pill its two-digit counts grow into,
  /// under the system stroke the control is outlined with — the rim that keeps
  /// an accent-filled badge readable against an accent surface, at the token's
  /// own hairline width.
  factory fluent(PureTheme theme) {
    final bt = theme.badge;
    return _BadgeVisual(
      dotSize: 8,
      height: 16,
      minWidth: 16,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      padInline: 5,
      radius: PureRadii.pill,
      halo: 1.5,
      overlap: 4,
      fill: () => bt.background,
      foreground: (body) => bt.foreground,
      stroke: (body) => theme.colors.borderSecondary,
      strokeWidth: theme.token.motion.lineWidth,
      painter: _outlined,
    );
  }

  /// The standalone dot's diameter.
  final double dotSize;

  /// The bubble's height — the absolute size the platform publishes, and the
  /// floor the type is centred in.
  final double height;

  /// The bubble's narrowest it may be: one digit rides a circle of this size,
  /// and only a longer count pushes it into a pill.
  final double minWidth;

  /// The count's type size, before the theme's text scale rides on it.
  final double fontSize;

  /// The count's weight — the bold numerals the badge asks for.
  final FontWeight fontWeight;

  /// The type's padding on either side; with [minWidth] it decides where the
  /// circle stops being one and starts growing into a pill.
  final double padInline;

  /// The bubble's corner radius — the stadium a pill wears.
  final double radius;

  /// The width of the knockout ring an anchored badge wears; the ring is drawn
  /// in the container colour, concentric with the bubble it sits under.
  final double halo;

  /// How far an anchored badge reaches past its child's corner.
  final double overlap;

  /// The body colour before a call site overrides it.
  final Color Function() fill;

  /// The type's colour, read off the body this call resolved.
  final Color Function(Color body) foreground;

  /// The bubble's rim; null draws no rim.
  final Color? Function(Color body)? stroke;

  /// The rim's width; 0 draws no rim at all.
  final double strokeWidth;

  /// The body's painter, built from the colours this call resolved.
  final _BadgePainter painter;

  /// The count's style: the badge's own type, riding the caption role
  /// so the user's text scale and the app's font family travel with it — the
  /// same fold the tab bar's cells make.
  TextStyle labelStyle(PureTheme theme) {
    final ratio = theme.text.caption.fontSize! / theme.token.type.fontSizeSM;
    return theme.text.caption.copyWith(fontSize: fontSize * ratio, height: 1, fontWeight: fontWeight);
  }
}

/// The colours one badge call resolved: the body the caller chose (or the
/// badge's own), the corner it is drawn at, and the rim around it.
@immutable
final class _BadgePaint {
  /// A resolved badge body.
  const new({required this.body, required this.corner, this.stroke, this.strokeWidth = 0});

  /// The bubble's fill, caller override folded in.
  final Color body;

  /// The corner radius the body is drawn with.
  final double corner;

  /// The rim's colour; null draws none.
  final Color? stroke;

  /// The rim's width.
  final double strokeWidth;
}

/// A badge's body, built from one resolved paint.
typedef _BadgePainter = CustomPainter Function(_BadgePaint paint);

/// The rimmed bubble: WinUI's system stroke around the pill, drawn inside the
/// edge so a badge never grows a hairline wider than the geometry it was given.
CustomPainter _outlined(_BadgePaint paint) => _OutlinedBubblePainter(
  body: paint.body,
  corner: paint.corner,
  stroke: paint.stroke,
  strokeWidth: paint.strokeWidth,
);

/// The same body under a hard rim. The rim is drawn inside the edge, so a badge
/// never grows a hairline wider than the geometry its visual was given.
class _OutlinedBubblePainter extends CustomPainter {
  const new({required this.body, required this.corner, required this.stroke, required this.strokeWidth});

  /// The bubble's fill.
  final Color body;

  /// The corner radius.
  final double corner;

  /// The rim's colour; null draws none.
  final Color? stroke;

  /// The rim's width.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size, corner);
    canvas.drawRRect(shape, Paint()..color = body);
    _paintStroke(canvas, shape, stroke, strokeWidth);
  }

  @override
  bool shouldRepaint(covariant _OutlinedBubblePainter oldDelegate) =>
      oldDelegate.body != body ||
      oldDelegate.corner != corner ||
      oldDelegate.stroke != stroke ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// The body this badge is drawn as: the corner clamped to the shape's own
/// shortest half, so a 6dp dot under a stadium radius still comes out a circle
/// instead of an over-rounded rectangle.
RRect _shape(Size size, double corner) =>
    RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(min(corner, size.shortestSide / 2)));

void _paintStroke(Canvas canvas, RRect shape, Color? stroke, double width) {
  final colour = stroke;
  if (colour == null || width <= 0) {
    return;
  }
  canvas.drawRRect(
    shape.deflate(width / 2),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = colour,
  );
}

/// The badge's own body: the bubble the visual painted, the type it carries,
/// the knockout ring that keeps it legible over a child, and the semantics that
/// name it.
class _BadgeMark extends StatelessWidget {
  const new({
    required this.visual,
    required this.text,
    required this.labelStyle,
    required this.ring,
    required this.fillOverride,
    required this.semanticsLabel,
    super.key,
  });

  final _BadgeVisual visual;

  /// The capped count or the tag's text; null is the dot form.
  final String? text;

  /// The count's style, already read off the theme.
  final TextStyle labelStyle;

  /// Whether the bubble wears its knockout ring — true anchored to a child.
  final bool ring;

  /// The caller's background override, or null for the badge's own.
  final Color? fillOverride;

  /// The name a screen reader gives the badge; null leaves a counted or
  /// labelled badge to read [text] and a bare dot unannounced.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final chosen = fillOverride ?? visual.fill();
    final style = labelStyle.copyWith(color: visual.foreground(chosen));
    final content = text;
    final box = content == null
        ? Size.square(visual.dotSize)
        : _bubbleBox(content, style, visual, Directionality.of(context));

    final Widget shape = CustomPaint(
      // The one canvas the badge paints; the identity key above names the badge.
      key: const ValueKey('PureBadge.shape'),
      painter: visual.painter(
        _BadgePaint(
          body: chosen,
          corner: visual.radius,
          stroke: visual.stroke?.call(chosen),
          strokeWidth: visual.strokeWidth,
        ),
      ),
      child: SizedBox.fromSize(
        size: box,
        child: content == null
            ? null
            : Align(
                alignment: AlignmentDirectional.center,
                // The number is read from the node below, not from the text
                // widget, so a screen reader does not hear it twice.
                child: ExcludeSemantics(
                  child: Text(content, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: style),
                ),
              ),
      ),
    );

    final halo = ring ? visual.halo : 0.0;
    final mark = halo <= 0
        ? shape
        : Padding(
            padding: EdgeInsets.all(halo),
            // Concentric with the bubble it sits under: the ring's radius is the
            // bubble's own, clamped the way the paint clamps it, plus the ring's
            // width — otherwise a dot under a stadium ring comes out a square.
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colors.bgContainer,
                borderRadius: BorderRadius.circular(min(visual.radius, box.shortestSide / 2) + halo),
              ),
              child: shape,
            ),
          );

    final label = semanticsLabel ?? content;
    if (label == null) {
      return mark;
    }
    return Semantics(container: true, label: label, child: mark);
  }
}

/// The bubble's box for [content]: the type measured at the style it is drawn
/// with, plus the badge's padding, never narrower than the shape's own
/// minimum (so one digit rides a circle) and never shorter than the height the
/// InfoBadge publishes. It grows past both for a user who asks for larger text,
/// because a badge that clipped its own number would be a lie.
Size _bubbleBox(String content, TextStyle style, _BadgeVisual visual, TextDirection direction) {
  final painter = TextPainter(textDirection: direction, maxLines: 1)
    ..text = TextSpan(text: content, style: style)
    ..layout();
  final measured = Size(painter.width + 2 * visual.padInline, painter.height);
  painter.dispose();
  return Size(max(visual.minWidth, measured.width), max(visual.height, measured.height));
}
