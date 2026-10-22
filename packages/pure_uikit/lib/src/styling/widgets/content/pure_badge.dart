import 'dart:math' show max, min;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/scales/radii.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// A count, a dot or a short tag, drawn in the nine design languages' own badge
/// grammars — the kit's answer to Ant's `Badge`.
///
/// The three roles are one contract in every language: a [count] is a bubble
/// whose number collapses to `max+` past [max], a [dot] is the bare marker, and
/// a [label] is the same bubble worn as a tag. Anchored to a [child] the badge
/// rides that child's top-right corner and overlaps it, knocking a ring of the
/// container colour out from under the bubble so it stays legible over an
/// avatar or a thumbnail; with no [child] it stands alone as the tag.
///
/// All of it is painted here, from the theme's own tokens — colours, radii,
/// type — because the nine widget libraries the kit otherwise dispatches to
/// disagree about almost everything a badge is made of: three of them name a
/// badge's colour by what it *means* rather than by a value, several require a
/// label, and none of them owns the corner-anchor grammar a count over a 36dp
/// avatar needs. Drawn once, one contract holds everywhere: the overlap, the
/// ring, the cap, the semantics and the user's text scale behave the same in
/// every language, while the shape stays each platform's own — Material 3's
/// accent pill, the iOS red bubble with its soft cast, the macOS capsule with
/// its gloss, the WinUI `InfoBadge` (a dot, or a pill rimmed with the system
/// stroke), Yaru's flat circle, shadcn's bordered pill, a frosted bubble under
/// glass, a raised chip under neumorphic and the crisper rimmed pill its wind
/// sibling draws. Switching `UiConfig.language` re-skins every badge.
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

  /// An optional background override (defaults to the error colour). Every
  /// language takes it as its own body colour and derives the rim, the cast and
  /// the type from it — except the neumorphic chip, whose surface carries no
  /// hue, so there it is the colour of the type instead.
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

  /// The geometry, colours and body one language puts on the bubble.
  _BadgeVisual _visual(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.material => _BadgeVisual.material(theme),
    PureDesignLanguage.cupertino => _BadgeVisual.cupertino(theme),
    PureDesignLanguage.macos => _BadgeVisual.macos(theme),
    PureDesignLanguage.fluent => _BadgeVisual.fluent(theme),
    PureDesignLanguage.yaru => _BadgeVisual.yaru(theme),
    PureDesignLanguage.forui => _BadgeVisual.forui(theme),
    PureDesignLanguage.glass => _BadgeVisual.glass(theme),
    PureDesignLanguage.neumorphic => _BadgeVisual.neumorphic(theme),
    PureDesignLanguage.wind => _BadgeVisual.wind(theme),
  };

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
      // The branch a language draws is its identity in tests and diagnostics.
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
          // The overlap is the language's own — the platforms that round their
          // bubbles tighter let them tuck a little closer into the corner.
          top: -visual.overlap,
          right: -visual.overlap,
          child: mark,
        ),
      ],
    );
  }
}

/// The geometry, colours and body one design language puts on a badge. Every
/// colour is resolved from the theme when the badge builds, so a language
/// re-skin and a dark switch come out of the same tokens the kit's other
/// controls read — while the geometry stays absolute pixels, because these are
/// the sizes the seven platforms publish for their own badges and a badge that
/// grew with the app's density would no longer be theirs.
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
    this.sheen,
    this.cast,
    this.strokeWidth = 0,
    this.alpha = 1,
    this.frosted = false,
  });

  /// Material 3: the accent pill, 18dp tall, whose single digit rides a circle
  /// of its own height — the flat filled bubble the platform's spec draws, with
  /// the on-colour type in it and no rim, shadow or sheen to soften it.
  factory material(PureTheme theme) {
    final bt = theme.badge;
    return _BadgeVisual(
      dotSize: 6,
      height: 18,
      minWidth: 18,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      padInline: 6,
      radius: PureRadii.pill,
      halo: 2,
      overlap: 4,
      fill: () => bt.background,
      foreground: (body) => bt.foreground,
      painter: _bubble,
    );
  }

  /// iOS: the red count bubble. systemRed rather than the accent, because that
  /// is the only colour Apple allows a badge to be; the weight is the one the
  /// iOS badge stack carries, and the soft coloured cast under the bubble is
  /// what makes it read as lifted off the icon.
  factory cupertino(PureTheme theme) {
    final bt = theme.badge;
    final colors = theme.colors;
    return _BadgeVisual(
      dotSize: 9,
      height: 20,
      minWidth: 20,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      padInline: 6,
      radius: PureRadii.pill,
      halo: 2,
      overlap: 3,
      fill: () => colors.error,
      foreground: (body) => bt.foreground,
      cast: (body) => [
        BoxShadow(
          color: body.withValues(alpha: theme.isDark ? 0.45 : 0.35),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
      painter: _bubble,
    );
  }

  /// macOS: the rounded capsule count — the same red, but Aqua-glossed from a
  /// light top edge down into the pure colour, which is the one thing that
  /// separates it from its iOS sibling at a glance.
  factory macos(PureTheme theme) {
    final bt = theme.badge;
    final colors = theme.colors;
    return _BadgeVisual(
      dotSize: 8,
      height: 18,
      minWidth: 18,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      padInline: 7,
      radius: PureRadii.pill,
      halo: 2,
      overlap: 3,
      fill: () => colors.error,
      foreground: (body) => bt.foreground,
      sheen: (body) => [Color.lerp(body, colors.white, 0.24)!, body],
      painter: _bubble,
    );
  }

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

  /// Yaru: the flat circle. Ubuntu's badge has no cast, no rim and no gloss —
  /// the flat fill the Yaru palette is known for — and it is the widest marker
  /// of the nine, because Ubuntu reads a dot at a glance and wants it seen.
  factory yaru(PureTheme theme) {
    final bt = theme.badge;
    final colors = theme.colors;
    return _BadgeVisual(
      dotSize: 10,
      height: 16,
      minWidth: 16,
      fontSize: 10,
      fontWeight: FontWeight.w500,
      padInline: 4,
      radius: PureRadii.pill,
      halo: 2,
      overlap: 4,
      fill: () => colors.error,
      foreground: (body) => bt.foreground,
      painter: _bubble,
    );
  }

  /// shadcn: the bordered pill. The utility-class badge is its own fill wrapped
  /// in a rim a shade deeper than that fill, which is what `border-border`
  /// resolves to once the badge is tinted rather than outlined.
  factory forui(PureTheme theme) {
    final bt = theme.badge;
    final colors = theme.colors;
    return _BadgeVisual(
      dotSize: 8,
      height: 18,
      minWidth: 20,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      padInline: 7,
      radius: PureRadii.pill,
      halo: 2,
      overlap: 4,
      fill: () => bt.background,
      foreground: (body) => bt.foreground,
      stroke: (body) => Color.lerp(body, theme.isDark ? colors.white : colors.shadowBase, 0.24)!,
      strokeWidth: theme.token.motion.lineWidth,
      painter: _outlined,
    );
  }

  /// Glass: the frosted bubble. The body lets the page through and the backdrop
  /// behind it blurs, so the badge reads as a pane of glass with the colour
  /// painted into it; a specular cap, a light rim and its own soft lift are what
  /// make the edge findable. Where the device cannot afford the filter the pure
  /// colour stands in, exactly as the kit's other frosted surfaces answer.
  factory glass(PureTheme theme) {
    final bt = theme.badge;
    return _BadgeVisual(
      dotSize: 8,
      height: 20,
      minWidth: 20,
      fontSize: 11,
      fontWeight: FontWeight.w500,
      padInline: 8,
      radius: PureRadii.pill,
      halo: 2,
      overlap: 3,
      alpha: 0.72,
      frosted: true,
      fill: () => bt.background,
      foreground: (body) => bt.foreground,
      stroke: (body) => theme.isDark ? Colors.white.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.72),
      strokeWidth: theme.token.motion.lineWidth,
      sheen: (body) => [
        Colors.white.withValues(alpha: theme.isDark ? 0.2 : 0.42),
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.12),
      ],
      cast: (body) => [
        BoxShadow(color: theme.colors.shadowBase.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
      ],
      painter: _frosted,
    );
  }

  /// Neumorphic: the raised chip. The chip is the surface itself — the light
  /// falling from the top left and the shadow from the bottom right are the only
  /// colour it gets — so the count's hue moves into the type, and the knockout
  /// ring is what separates a lifted chip from the surface it lifts off.
  factory neumorphic(PureTheme theme) {
    final colors = theme.colors;
    List<BoxShadow> raised() => [
      BoxShadow(color: colors.shadowBase, blurRadius: 5, offset: const Offset(2.5, 2.5)),
      BoxShadow(
        color: colors.white.withValues(alpha: theme.isDark ? 0.05 : 0.75),
        blurRadius: 5,
        offset: const Offset(-2.5, -2.5),
      ),
    ];

    return _BadgeVisual(
      dotSize: 10,
      height: 20,
      minWidth: 20,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      padInline: 8,
      radius: theme.token.scale.radii.lg,
      halo: 2,
      overlap: 4,
      fill: () => colors.bgContainer,
      foreground: (body) => body,
      cast: (body) => raised(),
      painter: _bubble,
    );
  }

  /// Wind: the crisp pill. The fork's utility badge is the tightest of the nine,
  /// with a rim harder than its shadcn sibling's and the language's own control
  /// radius instead of a stadium, which is what makes it read as a pill laid on
  /// a surface rather than a hole cut in one.
  factory wind(PureTheme theme) {
    final bt = theme.badge;
    final colors = theme.colors;
    return _BadgeVisual(
      dotSize: 7,
      height: 16,
      minWidth: 16,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      padInline: 5,
      radius: theme.token.scale.radii.base,
      halo: 1.5,
      overlap: 4,
      fill: () => bt.background,
      foreground: (body) => bt.foreground,
      stroke: (body) => Color.lerp(body, theme.isDark ? colors.white : colors.shadowBase, 0.4)!,
      strokeWidth: theme.token.motion.lineWidth,
      painter: _outlined,
    );
  }

  /// The standalone dot's diameter; every language draws it as a circle,
  /// whatever shape its bubble takes.
  final double dotSize;

  /// The bubble's height — the absolute size the platform publishes, and the
  /// floor the type is centred in.
  final double height;

  /// The bubble's narrowest it may be: one digit rides a circle of this size,
  /// and only a longer count pushes it into a pill.
  final double minWidth;

  /// The count's type size, before the theme's text scale rides on it.
  final double fontSize;

  /// The count's weight — the bold numerals the mobile badges ask for, the w500
  /// the desktop and utility ones settle for.
  final FontWeight fontWeight;

  /// The type's padding on either side; with [minWidth] it decides where the
  /// circle stops being one and starts growing into a pill.
  final double padInline;

  /// The bubble's corner radius. `PureRadii.pill` is the stadium languages,
  /// a token radius the two whose badge is a rounded shape laid on the surface.
  final double radius;

  /// The width of the knockout ring an anchored badge wears; the ring is drawn
  /// in the container colour, concentric with the bubble it sits under.
  final double halo;

  /// How far an anchored badge reaches past its child's corner.
  final double overlap;

  /// The body colour before a call site overrides it.
  final Color Function() fill;

  /// The type's colour, read off the body this call resolved — the on-colour for
  /// the filled languages, the body itself for the one whose surface has no hue.
  final Color Function(Color body) foreground;

  /// The bubble's rim; null draws the outline-free languages, the flat ones.
  final Color? Function(Color body)? stroke;

  /// The rim's width; 0 draws no rim at all.
  final double strokeWidth;

  /// The body's ramp, for the languages whose badge is glossed or frosted rather
  /// than flat.
  final List<Color>? Function(Color body)? sheen;

  /// The bubble's casts: iOS's coloured lift, neumorphic's raised pair (the dark
  /// one first, so the light edge lands on top of it), glass's soft float.
  final List<BoxShadow>? Function(Color body)? cast;

  /// How far the frosted language lets the page through its own body; 1 is a
  /// pure colour.
  final double alpha;

  /// Whether the bubble frosts what is behind it through a backdrop filter.
  final bool frosted;

  /// The body's painter, built from the colours this call resolved.
  final _BadgePainter painter;

  /// The count's style: the language's own badge type, riding the caption role
  /// so the user's text scale and the app's font family travel with it — the
  /// same fold the tab bar's cells make.
  TextStyle labelStyle(PureTheme theme) {
    final ratio = theme.text.caption.fontSize! / theme.token.type.fontSizeSM;
    return theme.text.caption.copyWith(fontSize: fontSize * ratio, height: 1, fontWeight: fontWeight);
  }
}

/// The colours one badge call resolved: the body the language (or the caller)
/// chose, the corner it is drawn at, and the rim, ramp and casts that language
/// puts around it.
@immutable
final class _BadgePaint {
  /// A resolved badge body.
  const new({required this.body, required this.corner, this.stroke, this.strokeWidth = 0, this.sheen, this.cast});

  /// The bubble's fill, caller override and translucency already folded in.
  final Color body;

  /// The corner radius the body is drawn with.
  final double corner;

  /// The rim's colour; null draws none.
  final Color? stroke;

  /// The rim's width.
  final double strokeWidth;

  /// The body's ramp; null paints the flat colour.
  final List<Color>? sheen;

  /// The casts dropped under the body; null draws a flat badge.
  final List<BoxShadow>? cast;
}

/// A badge's body, built from one resolved paint.
typedef _BadgePainter = CustomPainter Function(_BadgePaint paint);

/// The flat and glossed bubbles: Material 3, iOS, macOS, Yaru and the
/// neumorphic chip. The body is one shape; what tells these five apart is what
/// each lays over it (a gloss) or drops under it (a cast).
CustomPainter _bubble(_BadgePaint paint) =>
    _BubblePainter(body: paint.body, corner: paint.corner, sheen: paint.sheen, cast: paint.cast);

/// The rimmed bubbles: WinUI's system stroke, shadcn's border and the wind
/// sibling's crisper one.
CustomPainter _outlined(_BadgePaint paint) => _OutlinedBubblePainter(
  body: paint.body,
  corner: paint.corner,
  stroke: paint.stroke,
  strokeWidth: paint.strokeWidth,
  sheen: paint.sheen,
  cast: paint.cast,
);

/// The frosted bubble: the glass language's own body, clipped to its own shape.
CustomPainter _frosted(_BadgePaint paint) => _FrostedBubblePainter(
  body: paint.body,
  corner: paint.corner,
  rim: paint.stroke,
  strokeWidth: paint.strokeWidth,
  sheen: paint.sheen,
  cast: paint.cast,
);

/// The bubble's body: the fill (or its sheen) and the soft casts the lifted
/// languages drop under it. The cast is painted first, offset and blurred, which
/// is what makes a bubble read as lifted rather than as a flat tint.
class _BubblePainter extends CustomPainter {
  const new({required this.body, required this.corner, this.sheen, this.cast});

  /// The bubble's fill.
  final Color body;

  /// The corner radius.
  final double corner;

  /// The body's ramp; null paints the flat fill.
  final List<Color>? sheen;

  /// The casts under the body.
  final List<BoxShadow>? cast;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size, corner);
    _paintCast(canvas, shape, cast);
    canvas.drawRRect(shape, _bodyPaint(size, body, sheen));
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.body != body ||
      oldDelegate.corner != corner ||
      oldDelegate.sheen != sheen ||
      oldDelegate.cast != cast;
}

/// The same body under a hard rim. The rim is drawn inside the edge, so a badge
/// never grows a hairline wider than the geometry its language was given.
class _OutlinedBubblePainter extends CustomPainter {
  const new({
    required this.body,
    required this.corner,
    required this.stroke,
    required this.strokeWidth,
    this.sheen,
    this.cast,
  });

  /// The bubble's fill.
  final Color body;

  /// The corner radius.
  final double corner;

  /// The rim's colour; null draws none.
  final Color? stroke;

  /// The rim's width.
  final double strokeWidth;

  /// The body's ramp; null paints the flat fill.
  final List<Color>? sheen;

  /// The casts under the body.
  final List<BoxShadow>? cast;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size, corner);
    _paintCast(canvas, shape, cast);
    canvas.drawRRect(shape, _bodyPaint(size, body, sheen));
    _paintStroke(canvas, shape, stroke, strokeWidth);
  }

  @override
  bool shouldRepaint(covariant _OutlinedBubblePainter oldDelegate) =>
      oldDelegate.body != body ||
      oldDelegate.corner != corner ||
      oldDelegate.stroke != stroke ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.sheen != sheen ||
      oldDelegate.cast != cast;
}

/// The glass body: the tinted pane, the specular cap that runs across its top
/// and bounces back along its bottom, and the light rim that makes the edge
/// findable. The blur itself is the widget's backdrop filter; this is the paint
/// that sits on top of it, clipped to the same shape so the sheen cannot spill
/// past the bubble.
class _FrostedBubblePainter extends CustomPainter {
  const new({
    required this.body,
    required this.corner,
    required this.rim,
    required this.strokeWidth,
    required this.sheen,
    this.cast,
  });

  /// The bubble's (translucent) fill.
  final Color body;

  /// The corner radius.
  final double corner;

  /// The light rim; null draws none.
  final Color? rim;

  /// The rim's width.
  final double strokeWidth;

  /// The frost's ramp, top to bottom.
  final List<Color>? sheen;

  /// The casts under the body.
  final List<BoxShadow>? cast;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size, corner);
    _paintCast(canvas, shape, cast);
    canvas.drawRRect(shape, Paint()..color = body);
    final ramp = sheen;
    if (ramp != null && ramp.length > 1) {
      canvas
        ..save()
        ..clipRRect(shape)
        ..drawRect(Offset.zero & size, _bodyPaint(size, body, ramp))
        ..restore();
    }
    _paintStroke(canvas, shape, rim, strokeWidth);
  }

  @override
  bool shouldRepaint(covariant _FrostedBubblePainter oldDelegate) =>
      oldDelegate.body != body ||
      oldDelegate.corner != corner ||
      oldDelegate.rim != rim ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.sheen != sheen ||
      oldDelegate.cast != cast;
}

/// The body this badge is drawn as: the corner clamped to the shape's own
/// shortest half, so a 6dp dot under a stadium radius still comes out a circle
/// instead of an over-rounded rectangle.
RRect _shape(Size size, double corner) =>
    RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(min(corner, size.shortestSide / 2)));

Paint _bodyPaint(Size size, Color body, List<Color>? sheen) {
  final ramp = sheen;
  if (ramp == null || ramp.length < 2) {
    return Paint()..color = body;
  }
  return Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: ramp,
    ).createShader(Offset.zero & size);
}

/// The casts, in order: a language that wants its light edge on top of its
/// shadow lists the shadow first, which is exactly what the raised chip does.
void _paintCast(Canvas canvas, RRect shape, List<BoxShadow>? shadows) {
  final cast = shadows;
  if (cast == null) {
    return;
  }
  for (final shadow in cast) {
    canvas.drawRRect(
      shape.shift(shadow.offset),
      Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius),
    );
  }
}

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

/// The badge's own body: the bubble one language painted, the type it carries,
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

  /// The count's style, already read off the theme and the language.
  final TextStyle labelStyle;

  /// Whether the bubble wears its knockout ring — true anchored to a child.
  final bool ring;

  /// The caller's background override, or null for the language's own.
  final Color? fillOverride;

  /// The name a screen reader gives the badge; null leaves a counted or
  /// labelled badge to read [text] and a bare dot unannounced.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final chosen = fillOverride ?? visual.fill();
    // The frosted language lets the page through its body; where the device
    // cannot afford the blur the pure colour stands in, so the type stays
    // legible — the same answer the kit's other frosted surfaces give.
    final frost = visual.frosted && theme.canBlur;
    final body = !frost || visual.alpha == 1 ? chosen : chosen.withValues(alpha: visual.alpha);
    final style = labelStyle.copyWith(color: visual.foreground(chosen));
    final content = text;
    final box = content == null
        ? Size.square(visual.dotSize)
        : _bubbleBox(content, style, visual, Directionality.of(context));

    final Widget shape = CustomPaint(
      // The one canvas the badge paints; the branch key above names the language.
      key: const ValueKey('PureBadge.shape'),
      painter: visual.painter(
        _BadgePaint(
          body: body,
          corner: visual.radius,
          stroke: visual.stroke?.call(chosen),
          strokeWidth: visual.strokeWidth,
          sheen: visual.sheen?.call(chosen),
          cast: visual.cast?.call(chosen),
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

    final bubble = !frost
        ? shape
        : ClipRRect(
            borderRadius: BorderRadius.circular(visual.radius),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: shape),
          );

    final halo = ring ? visual.halo : 0.0;
    final mark = halo <= 0
        ? bubble
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
              child: bubble,
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
/// with, plus the language's padding, never narrower than the shape's own
/// minimum (so one digit rides a circle) and never shorter than the height the
/// language publishes. It grows past both for a user who asks for larger text,
/// because a badge that clipped its own number would be a lie.
Size _bubbleBox(String content, TextStyle style, _BadgeVisual visual, TextDirection direction) {
  final painter = TextPainter(textDirection: direction, maxLines: 1)
    ..text = TextSpan(text: content, style: style)
    ..layout();
  final measured = Size(painter.width + 2 * visual.padInline, painter.height);
  painter.dispose();
  return Size(max(visual.minWidth, measured.width), max(visual.height, measured.height));
}
