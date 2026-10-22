import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/provider/pure_config_provider.dart';

/// The shape an avatar can take.
enum PureAvatarShape {
  /// Fully circular — the disc every platform's contact avatar draws.
  circle,

  /// Rounded square, cornered by the active language's own control radius and
  /// capped at a quarter of the edge so a dense 16dp avatar keeps straight
  /// sides instead of turning into a blob.
  rounded,
}

/// The three tiers a call site's edge length falls in, and what each one costs.
enum _AvatarTier {
  /// 24 and under: the dense list row, where the initials take their widest cut
  /// of the disc.
  micro,

  /// 25 to 40: the row and card avatar the app pages ask for most.
  standard,

  /// Above 40: the profile-sized disc, whose initials stop growing because a
  /// 96dp circle does not carry 44pt type.
  prominent,
}

extension _AvatarTierMetrics on _AvatarTier {
  /// The tier [edge] falls in — the design sheet's three avatar steps.
  static _AvatarTier forEdge(double edge) => switch (edge) {
    <= 24 => _AvatarTier.micro,
    <= 40 => _AvatarTier.standard,
    _ => _AvatarTier.prominent,
  };

  /// The share of the edge the initials' font size takes.
  double get initialsRatio => switch (this) {
    _AvatarTier.micro => 0.44,
    _AvatarTier.standard => 0.38,
    _AvatarTier.prominent => 0.34,
  };

  /// The share of the edge a placeholder glyph takes; a hair wider than the
  /// type, because a silhouette reads smaller than the letters beside it.
  double get glyphRatio => switch (this) {
    _AvatarTier.micro => 0.56,
    _AvatarTier.standard => 0.52,
    _AvatarTier.prominent => 0.48,
  };
}

/// The plate the disc is painted on, addressed by tests and diagnostics.
const ValueKey<String> _plateKey = ValueKey<String>('PureAvatar.plate');

/// The rim over the plate's edge, addressed by tests and diagnostics.
const ValueKey<String> _rimKey = ValueKey<String>('PureAvatar.rim');

/// The kit's avatar: one widget that draws the real shape of the control.
///
/// The visual is the one WinUI's Persona puts on: the neutral disc on a
/// hairline ring — the ellipse (or square, per the size tier) whose initials
/// give way to the silhouette under its 24px step. All of it is painted here,
/// from the theme's own tokens — colours, radii, shadows and text — so a dark
/// switch and the user's text scale come out right. The config's `language`
/// names the avatar's identity key only — a non-fluent value keeps compiling
/// and simply draws this disc.
///
/// Drawn once, one content contract holds: the call site's [ImageProvider]
/// wins, an image that fails to load is replaced by the same fallback a missing
/// image gets, then come [PureAvatar.initialsOf], then the call site's [icon],
/// then the silhouette; the edge the call site hands is the edge that is laid
/// out; [PureAvatarShape.rounded] is a real rounded square; and the display
/// name — or the [semanticLabel] a call site puts up instead — is what a
/// screen reader hears, with the painted initials kept out of the reading
/// order so the name is never announced twice.
class PureAvatar extends StatelessWidget {
  /// An avatar.
  const new({
    this.name,
    this.src,
    this.size,
    this.shape = PureAvatarShape.circle,
    this.icon,
    this.semanticLabel,
    super.key,
  });

  /// The display name; used for the initials fallback.
  final String? name;

  /// An optional image.
  final ImageProvider? src;

  /// The edge length; defaults to the large control height.
  final double? size;

  /// Circle or a rounded square.
  final PureAvatarShape shape;

  /// The glyph drawn when there is no image and no name to take initials from —
  /// the anonymous row and the account with no display name yet. The silhouette
  /// is what the avatar falls back to when this is null too.
  final IconData? icon;

  /// The name a screen reader hears. Defaults to [name]; a call site that keeps
  /// the name off the disc — a bare photo, an anti-doxxing row — can still name
  /// the avatar here.
  final String? semanticLabel;

  /// The initials from [name]: the first letters of up to two words.
  static String initialsOf(String? name) {
    if (name == null) {
      return '';
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    final letters = parts.take(2).map((word) => word.substring(0, 1)).join();
    return letters.toUpperCase();
  }

  /// The geometry, colours and cast the avatar draws — the fluent visual.
  static _AvatarVisual _visual(PureTheme theme) => _AvatarVisual.fluent(theme);

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    final edge = size ?? theme.token.scale.controlHeightLG;
    return _AvatarCore(
      // The config's language is the avatar's identity key in tests and
      // diagnostics only; the drawing itself is fluent.
      key: ValueKey('PureAvatar.${language.name}'),
      edge: edge,
      shape: shape,
      visual: _visual(theme),
      src: src,
      initials: initialsOf(name),
      icon: icon,
      semanticsLabel: semanticLabel ?? name,
    );
  }
}

/// The surface, the rim and the type the avatar is painted with.
/// Everything is resolved from the theme when the avatar builds, so a dark
/// switch and the user's text scale come out of the same tokens the kit's
/// other content reads.
@immutable
final class _AvatarVisual {
  /// An avatar visual.
  const new({
    required this.surface,
    required this.initialsColor,
    required this.glyphColor,
    required this.roundedRadius,
    this.ring,
    this.ringWidth = 1,
    this.minInitialsEdge = 0,
  });

  /// WinUI's Persona: the neutral disc on a hairline ring — the ellipse for the
  /// circle form, the token's control radius for the square one — and the
  /// persona's own size rule, which draws the silhouette instead of initials
  /// below its 24px step because two capital letters do not fit in 16.
  factory fluent(PureTheme theme) => _AvatarVisual(
    surface: theme.colors.fillTertiary,
    initialsColor: theme.colors.text,
    glyphColor: theme.colors.textTertiary,
    ring: theme.colors.borderSecondary,
    ringWidth: theme.token.motion.lineWidth,
    roundedRadius: theme.token.scale.radii.base,
    minInitialsEdge: 24,
  );

  /// The plate's fill.
  final Color surface;

  /// The initials' colour.
  final Color initialsColor;

  /// The placeholder glyph's colour — one step quieter than the letters, so a
  /// silhouette never out-shouts a name beside it.
  final Color glyphColor;

  /// The square form's radius before the shared cap; see [PureAvatarShape.rounded].
  final double roundedRadius;

  /// The plate's ring colour; null draws no outline at all.
  final Color? ring;

  /// The ring's width.
  final double ringWidth;

  /// The smallest edge this avatar still paints initials into; below it the
  /// fallback answers with the glyph instead. WinUI's Persona step is 24:
  /// two capital letters do not fit in 16.
  final double minInitialsEdge;
}

/// The avatar's body: the plate, its rim, the picture or the fallback that sits
/// on it, and the semantics that name it. The layers are the shared contract —
/// the fill under the clipped body, the rim painted over the body
/// so a ring survives a photo, and exactly one clip per avatar.
class _AvatarCore extends StatelessWidget {
  const new({
    required this.edge,
    required this.shape,
    required this.visual,
    required this.src,
    required this.initials,
    required this.icon,
    required this.semanticsLabel,
    super.key,
  });

  /// The laid-out edge length, whatever the call site or the token ladder gave it.
  final double edge;

  /// Circle or rounded square.
  final PureAvatarShape shape;

  /// The resolved visual grammar.
  final _AvatarVisual visual;

  /// The picture, if the call site has one.
  final ImageProvider? src;

  /// The initials resolved from the display name; empty when there are none.
  final String initials;

  /// The call site's own placeholder glyph.
  final IconData? icon;

  /// The name read aloud for this avatar; null leaves the disc anonymous.
  final String? semanticsLabel;

  /// The plate's corner radius: null is the disc, a value is the square form at
  /// the visual's own radius, capped at a quarter of the edge so a dense
  /// avatar keeps straight sides.
  BorderRadius? get _radius =>
      shape == PureAvatarShape.circle ? null : BorderRadius.circular(visual.roundedRadius.clamp(0.0, edge / 4));

  @override
  Widget build(BuildContext context) {
    final radius = _radius;
    return Semantics(
      container: true,
      // A photo is an image to a screen reader; initials and the silhouette are
      // the name drawn in a disc, so they carry no image flag.
      image: src != null,
      label: semanticsLabel,
      // The letters a reader would otherwise spell out are the same name this
      // node already carries.
      excludeSemantics: true,
      child: SizedBox.square(dimension: edge, child: _plate(context, radius)),
    );
  }

  /// The fill and the rim: the plate, with the clipped body inside it
  /// so the rim paints over a picture's edge. The clip is the body's own — one
  /// per avatar — and it is a `ClipRRect` only for the square form, so a disc
  /// stays an oval.
  Widget _plate(BuildContext context, BorderRadius? radius) {
    final boxShape = radius == null ? BoxShape.circle : BoxShape.rectangle;
    final body = radius == null
        ? ClipOval(child: _body(context))
        : ClipRRect(borderRadius: radius, child: _body(context));
    return DecoratedBox(
      key: _plateKey,
      decoration: BoxDecoration(shape: boxShape, color: visual.surface, borderRadius: radius),
      child: DecoratedBox(
        key: _rimKey,
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          shape: boxShape,
          borderRadius: radius,
          border: visual.ring == null ? null : Border.all(color: visual.ring!, width: visual.ringWidth),
        ),
        child: body,
      ),
    );
  }

  /// What the disc is filled with: the picture the call site has, or the
  /// fallback chain below it.
  Widget _body(BuildContext context) {
    final fallback = _fallback(PureTheme.of(context));
    final src = this.src;
    return src == null
        ? fallback
        // A picture that cannot be decoded is the same avatar as a call site
        // with no picture at all: the initials, the glyph, the silhouette.
        : Image(image: src, fit: BoxFit.cover, errorBuilder: (context, error, stack) => fallback);
  }

  /// The fallback chain: the initials the name gives, then the call site's glyph
  /// (or the silhouette), with the persona's own size rule for when a disc is
  /// too dense to carry letters.
  Widget _fallback(PureTheme theme) {
    final tier = _AvatarTierMetrics.forEdge(edge);
    if (initials.isNotEmpty && edge >= visual.minInitialsEdge) {
      // The kit's text contract: the initials ride the label role, so the
      // user's text scale grows them with the rest of the chrome — but never
      // past half the disc, which would spill the letters out of the plate.
      final scale = theme.text.label.fontSize! / theme.token.type.fontSizeSM;
      return Center(
        child: Text(
          initials,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: theme.text.label.copyWith(
            color: visual.initialsColor,
            fontWeight: FontWeight.w600,
            fontSize: (edge * tier.initialsRatio * scale).clamp(0.0, edge * 0.5),
            height: 1,
          ),
        ),
      );
    }
    return Center(
      // The glyph is decoration over the name the semantics node already
      // carries, so it is given none of its own to be read twice.
      child: Icon(icon ?? Icons.person, size: edge * tier.glyphRatio, color: visual.glyphColor),
    );
  }
}
