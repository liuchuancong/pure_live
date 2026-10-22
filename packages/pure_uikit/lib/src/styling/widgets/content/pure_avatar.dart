import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:pure_uikit/src/styling/config/pure_design_language.dart';
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

/// The kit's avatar: one widget that draws the real shape of the control in
/// every `PureDesignLanguage` — Material 3's tonal disc tinted from the primary
/// ramp; iOS's grey circle carrying the initials; macOS's contact circle, the
/// accent lit from the top and the letters in white; the ellipse (or square, per
/// the size tier) WinUI's Persona puts on a hairline ring, whose initials give
/// way to the silhouette under its 24px step; Ubuntu's flat fill with no ring
/// and no cast; shadcn's muted disc inside its `ring` border; a frosted disc
/// that blurs the page behind it under glass; an extruded disc under neumorphic,
/// lit top-left and cast bottom-right; and the wind sibling's crisp, high-
/// contrast disc. All of it is painted here, from the theme's own tokens —
/// colours, radii, shadows and text — because the nine widget libraries the kit
/// otherwise dispatches to disagree about the fallback chain, the dark ramp and
/// the corner geometry, and an avatar that changes what it shows the moment the
/// language changes is a defect, not a re-skin.
///
/// Drawn once, one content contract holds everywhere: the call site's [ImageProvider]
/// wins, an image that fails to load is replaced by the same fallback a missing
/// image gets, then come [PureAvatar.initialsOf], then the call site's [icon],
/// then the silhouette; the edge the call site hands is the edge that is laid
/// out, in every language; [PureAvatarShape.rounded] is a real rounded square
/// everywhere; and the display name — or the [semanticLabel] a call site puts up
/// instead — is what a screen reader hears, with the painted initials kept out
/// of the reading order so the name is never announced twice. Switching
/// `UiConfig.language` re-skins every avatar.
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

  /// The geometry, colours and cast the active language puts on the disc.
  _AvatarVisual _visual(PureTheme theme) => switch (theme.config.language) {
    PureDesignLanguage.material => _AvatarVisual.material(theme),
    PureDesignLanguage.cupertino => _AvatarVisual.cupertino(theme),
    PureDesignLanguage.macos => _AvatarVisual.macos(theme),
    PureDesignLanguage.fluent => _AvatarVisual.fluent(theme),
    PureDesignLanguage.yaru => _AvatarVisual.yaru(theme),
    PureDesignLanguage.forui => _AvatarVisual.forui(theme),
    PureDesignLanguage.glass => _AvatarVisual.glass(theme),
    PureDesignLanguage.neumorphic => _AvatarVisual.neumorphic(theme),
    PureDesignLanguage.wind => _AvatarVisual.wind(theme),
  };

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final language = theme.config.language;
    final edge = size ?? theme.token.scale.controlHeightLG;
    return _AvatarCore(
      // The branch a language draws is its identity in tests and diagnostics.
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

/// The surface, the rim, the cast and the type one design language puts on an
/// avatar. Everything is resolved from the theme when the avatar builds, so a
/// language re-skin, a dark switch and the user's text scale all come out of the
/// same tokens the kit's other content reads.
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
    this.gradient,
    this.shadow,
    this.frosted = false,
    this.minInitialsEdge = 0,
    this.initialsWeight = FontWeight.w600,
  });

  /// Material 3's tonal disc: the primary's level-1 background carrying the
  /// letters in the primary's own text role, so an avatar picks the theme's
  /// accent up without a picture. The square form is the token's control radius.
  factory material(PureTheme theme) => _AvatarVisual(
    surface: theme.colors.primaryBg,
    initialsColor: theme.colors.primaryText,
    glyphColor: theme.colors.primaryText.withValues(alpha: 0.7),
    roundedRadius: theme.token.scale.radii.base,
    initialsWeight: FontWeight.w500,
  );

  /// iOS's contact circle: the flat grey fill the platform puts behind an
  /// unknown photo, the initials in the secondary label role, and no ring or
  /// cast — the disc is the whole ornament. Its square form is the app-icon
  /// squircle the home screen draws.
  factory cupertino(PureTheme theme) => _AvatarVisual(
    surface: theme.colors.fillSecondary,
    initialsColor: theme.colors.textSecondary,
    glyphColor: theme.colors.textQuaternary,
    roundedRadius: theme.token.scale.radii.lg,
    initialsWeight: FontWeight.w500,
  );

  /// macOS's contact circle: the accent disc lit from the top toward white, the
  /// letters in the solid-on-brand text role, and the faint cast the platform
  /// puts under a round control.
  factory macos(PureTheme theme) => _AvatarVisual(
    surface: theme.colors.primary,
    gradient: LinearGradient(
      begin: AlignmentDirectional.topCenter,
      end: AlignmentDirectional.bottomCenter,
      colors: [Color.lerp(theme.colors.primary, theme.colors.white, 0.28)!, theme.colors.primary],
    ),
    initialsColor: theme.colors.textLightSolid,
    glyphColor: theme.colors.textLightSolid.withValues(alpha: 0.85),
    roundedRadius: theme.token.scale.radii.base,
    shadow: theme.token.motion.boxShadowTertiary,
  );

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

  /// Ubuntu's flat disc: a fill and nothing else — no ring, no gradient, no
  /// cast — and the rounder container the kit's other Yaru surfaces ask for.
  factory yaru(PureTheme theme) => _AvatarVisual(
    surface: theme.colors.fillTertiary,
    initialsColor: theme.colors.textSecondary,
    glyphColor: theme.colors.textQuaternary,
    roundedRadius: theme.token.scale.radii.lg,
    initialsWeight: FontWeight.w500,
  );

  /// shadcn's muted avatar: the muted fill inside its `ring` border, the letters
  /// in the muted-foreground role, and the card radius on the square form.
  factory forui(PureTheme theme) => _AvatarVisual(
    surface: theme.colors.fill,
    initialsColor: theme.colors.textSecondary,
    glyphColor: theme.colors.textQuaternary,
    ring: theme.colors.border,
    ringWidth: theme.token.motion.lineWidth,
    roundedRadius: theme.token.scale.radii.sm,
  );

  /// Glass: the frosted disc. The plate is a translucent frost with a light rim,
  /// and the page behind it is blurred under the frost when the device can
  /// afford a backdrop filter — see [_AvatarCore].
  factory glass(PureTheme theme) => _AvatarVisual(
    surface: theme.isDark ? Colors.white.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.55),
    initialsColor: theme.colors.text,
    glyphColor: theme.colors.textSecondary,
    ring: theme.isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.7),
    ringWidth: theme.token.motion.lineWidth,
    roundedRadius: theme.token.scale.radii.lg,
    frosted: true,
  );

  /// Neumorphic: the extruded disc — the container's own colour lifted out of
  /// the page by a light from the top left and a cast to the bottom right, the
  /// letters sunk into the surface rather than painted on it.
  factory neumorphic(PureTheme theme) {
    List<BoxShadow> raised() => [
      BoxShadow(color: theme.colors.shadowBase, blurRadius: 6, offset: const Offset(3, 3)),
      BoxShadow(
        color: theme.colors.white.withValues(alpha: theme.isDark ? 0.04 : 0.8),
        blurRadius: 6,
        offset: const Offset(-3, -3),
      ),
    ];

    return _AvatarVisual(
      surface: theme.colors.bgContainer,
      initialsColor: theme.colors.textSecondary,
      glyphColor: theme.colors.textTertiary,
      roundedRadius: theme.token.scale.radii.lg,
      shadow: raised(),
    );
  }

  /// Wind's crisp disc: the elevated surface with a hard hairline around it and
  /// the letters in the primary text role at the heaviest weight the kit uses —
  /// the utility-class grammar its shadcn sibling draws, with the corners
  /// tightened to the token's smallest radius.
  factory wind(PureTheme theme) => _AvatarVisual(
    surface: theme.colors.bgElevated,
    initialsColor: theme.colors.text,
    glyphColor: theme.colors.textTertiary,
    ring: theme.colors.border,
    ringWidth: theme.token.motion.lineWidth,
    roundedRadius: theme.token.scale.radii.xs,
    initialsWeight: FontWeight.w700,
  );

  /// The plate's fill. Ignored when [gradient] is set: a `BoxDecoration` carries
  /// one or the other, and the languages that ramp their disc (macOS) read the
  /// ramp.
  final Color surface;

  /// The disc's colour ramp, for the languages that light their plate.
  final Gradient? gradient;

  /// The initials' colour.
  final Color initialsColor;

  /// The placeholder glyph's colour — one step quieter than the letters, so a
  /// silhouette never out-shouts a name.
  final Color glyphColor;

  /// The square form's radius before the shared cap; see [PureAvatarShape.rounded].
  final double roundedRadius;

  /// The plate's ring colour; null draws the languages with no outline at all.
  final Color? ring;

  /// The ring's width.
  final double ringWidth;

  /// The plate's cast; only the raised and extruded grammars carry one.
  final List<BoxShadow>? shadow;

  /// Whether the disc frosts the page behind it through a backdrop filter.
  final bool frosted;

  /// The smallest edge this language still paints initials into; below it the
  /// language answers with the glyph instead. Zero is every language but
  /// WinUI's, which stops at its Persona step.
  final double minInitialsEdge;

  /// The initials' weight: the platform's own label weight, from Material's
  /// medium to wind's bold.
  final FontWeight initialsWeight;
}

/// The avatar's body: the plate, its rim, the picture or the fallback that sits
/// on it, and the semantics that name it. The layers are the shared contract —
/// the fill and its cast under the clipped body, the rim painted over the body
/// so a ring survives a photo, and exactly one clip per avatar whatever the
/// language asks for.
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

  /// The active language's grammar.
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
  /// the language's own radius, capped at a quarter of the edge so a dense
  /// avatar keeps straight sides.
  BorderRadius? get _radius =>
      shape == PureAvatarShape.circle ? null : BorderRadius.circular(visual.roundedRadius.clamp(0.0, edge / 4));

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
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
      child: SizedBox.square(dimension: edge, child: _plate(theme, radius)),
    );
  }

  /// The fill, the cast and the rim: the plate, with the clipped body inside it
  /// so the rim paints over a picture's edge. The clip is the body's own — one
  /// per avatar, whatever the language asks for — and it is a `ClipRRect` only
  /// for the square form, so a disc stays an oval.
  Widget _plate(PureTheme theme, BorderRadius? radius) {
    final boxShape = radius == null ? BoxShape.circle : BoxShape.rectangle;
    final body = radius == null ? ClipOval(child: _body(theme)) : ClipRRect(borderRadius: radius, child: _body(theme));
    return DecoratedBox(
      key: _plateKey,
      // The cast is painted by this node, outside the clip below it, so an
      // extruded disc keeps the shadow it throws past its own diameter.
      decoration: BoxDecoration(
        shape: boxShape,
        color: visual.gradient == null ? visual.surface : null,
        gradient: visual.gradient,
        borderRadius: radius,
        boxShadow: visual.shadow,
      ),
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

  /// What the disc is filled with: the frost the glass language blurs, the
  /// picture the call site has, or the fallback chain below it. The frost is
  /// laid under whichever of the two the call site gave, so an anonymous frosted
  /// disc still blurs the page rather than only a photo.
  Widget _body(PureTheme theme) {
    final fallback = _fallback(theme);
    final src = this.src;
    final content = src == null
        ? fallback
        // A picture that cannot be decoded is the same avatar as a call site
        // with no picture at all: the initials, the glyph, the silhouette.
        : Image(image: src, fit: BoxFit.cover, errorBuilder: (context, error, stack) => fallback);
    if (!visual.frosted || !theme.canBlur) {
      return content;
    }
    return Stack(fit: StackFit.expand, children: [_frost(theme), content]);
  }

  /// The frosted layer: the page behind the disc, blurred at a sigma that grows
  /// with the avatar and stops short of a smear on a 96dp profile disc.
  Widget _frost(PureTheme theme) {
    final sigma = (edge * 0.18).clamp(6.0, 20.0);
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: const SizedBox.expand(),
    );
  }

  /// The fallback chain: the initials the name gives, then the call site's glyph
  /// (or the silhouette), with the language's own size rule for when a disc is
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
            fontWeight: visual.initialsWeight,
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
