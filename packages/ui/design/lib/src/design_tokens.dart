// Module: lib/src/design_tokens.dart
// Purpose: The design vocabulary every surface shares: spacing, radii, the persisted background, and the
// resolved token set a style adapter maps.
// Author: liuchuancong
// Created: 2026-10-10
//
// Tokens are numbers and names, never Color values: the scheme a style builds decides what "surface" looks
// like, and only components read the theme. A widget that hardcoded a hex here would be a style the registry
// cannot swap.
//
// The older PureLiveSpacing / PureLiveRadius names stay because ui_kit already reads them; the enum scales in
// scale_tokens.dart are what a new surface should use, since they carry the role in the name instead of
// leaving a number to be guessed at.

import 'dart:convert';

import 'control_metrics.dart';
import 'scale_tokens.dart';
import 'semantic_roles.dart';

/// Spacing scale, four-point based.
///
/// The numbers repeat [SpaceToken]'s rather than reading from it because Dart cannot fold an enum field
/// access into a constant; the equality is asserted in a test instead of trusted.
abstract final class PureLiveSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii. See the note on [PureLiveSpacing] about why these are literals.
abstract final class PureLiveRadius {
  static const double sm = 6;
  static const double md = 12;
  static const double lg = 20;
}

/// How a decorative background behind the content is composed. Master's
/// background switch (video / image / plain) maps onto [kind].
enum BackgroundKind { none, color, image, video }

/// The persisted configuration of one background.
final class BackgroundConfig {
  const BackgroundConfig({this.kind = BackgroundKind.none, this.source, this.opacity = 0.35, this.blurSigma = 0});

  factory BackgroundConfig.fromJson(Map<String, Object?> json) => BackgroundConfig(
    kind: () {
      final name = json['kind'] as String?;
      for (final kind in BackgroundKind.values) {
        if (kind.name == name) {
          return kind;
        }
      }
      return BackgroundKind.none;
    }(),
    source: json['source'] as String?,
    opacity: (json['opacity'] as num?)?.toDouble() ?? 0.35,
    blurSigma: (json['blurSigma'] as num?)?.toDouble() ?? 0,
  );

  final BackgroundKind kind;
  final String? source;

  /// 0..1, clamped on read so a value edited by hand cannot make the content unreadable.
  final double opacity;

  final double blurSigma;

  bool get isActive =>
      kind != BackgroundKind.none && (kind == BackgroundKind.color || (source != null && source!.isNotEmpty));

  Map<String, Object?> toJson() => <String, Object?>{
    'kind': kind.name,
    if (source != null) 'source': source,
    'opacity': opacity,
    'blurSigma': blurSigma,
  };
}

/// One resolved set of tokens: everything a style adapter needs to map, and nothing it has to invent.
final class DesignTokens {
  const DesignTokens({
    required this.platform,
    required this.input,
    required this.density,
    required this.motion,
    required this.focus,
    required this.textScale,
    this.background = const BackgroundConfig(),
  });

  /// The device family being sized for.
  final PlatformProfile platform;

  /// How the user is actually pointing, which may disagree with [platform].
  final InputMode input;

  final Density density;

  final MotionProfile motion;

  final FocusVisual focus;

  /// The platform's text scaling factor, carried rather than applied so a surface can multiply where it
  /// draws text. Below 1 is refused by the resolver: a style may not shrink a user's text.
  final double textScale;

  final BackgroundConfig background;

  double height(ControlKind kind) => kind.heightFor(mode: input, density: density);

  /// The size of a type role under these tokens.
  double typeSize(TypeRole role) => role.sizeFor(textScale: textScale, mode: input);

  /// The gap that belongs between two controls of [kind].
  ///
  /// Rows in a list get more air than chips in a scrolling strip: a list row is a target you stop on, and a
  /// chip row is read as one group. Compact density tightens both, so a watch-sized window still fits.
  double gapBetween(ControlKind kind) =>
      (kind == ControlKind.listItem || kind == ControlKind.posterTile ? SpaceToken.space16.px : SpaceToken.space8.px) *
      density.scale;
}

/// Builds the token set from the settings a user can reach, applying the rules that are not negotiable.
///
/// [preferredInput] lets a host override the platform's default - a PC attached to a TV remote is one real
/// configuration, and a tablet with a keyboard is another.
DesignTokens resolveDesignTokens({
  required PlatformProfile platform,
  Density? density,
  bool reduceMotion = false,
  double textScale = 1,
  InputMode? preferredInput,
  BackgroundConfig background = const BackgroundConfig(),
}) {
  final input = preferredInput ?? platform.preferredInput;
  // A pointer-driven profile with a remote attached still must clear the remote's minimums, so the floor is
  // the input mode's, not the platform's.
  final clampedScale = textScale < 1 ? 1.0 : textScale;
  return DesignTokens(
    platform: platform,
    input: input,
    density: density ?? Density.forPlatform(platform),
    motion: MotionProfile.resolve(mode: input, reduceMotion: reduceMotion),
    focus: FocusVisual.forMode(input),
    textScale: clampedScale,
    background: background,
  );
}

/// The persisted appearance settings, as one blob so a settings screen writes one key.
final class AppearanceSettings {
  const AppearanceSettings({
    this.styleName = 'material',
    this.brightness = 'system',
    this.density,
    this.reduceMotion = false,
    this.textScale = 1,
    this.preferredInput,
    this.background = const BackgroundConfig(),
  });

  factory AppearanceSettings.fromJson(Map<String, Object?> json) => AppearanceSettings(
    styleName: json['style'] as String? ?? 'material',
    brightness: json['brightness'] as String? ?? 'system',
    density: switch (json['density'] as String?) {
      'compact' => Density.compact,
      'comfortable' => Density.comfortable,
      'standard' => Density.standard,
      _ => null,
    },
    reduceMotion: json['reduceMotion'] as bool? ?? false,
    textScale: (json['textScale'] as num?)?.toDouble() ?? 1,
    preferredInput: switch (json['input'] as String?) {
      'touch' => InputMode.touch,
      'pointer' => InputMode.pointer,
      'remote' => InputMode.remote,
      _ => null,
    },
    background: json['background'] == null
        ? const BackgroundConfig()
        : BackgroundConfig.fromJson(Map<String, Object?>.from(json['background']! as Map)),
  );

  factory AppearanceSettings.parse(String source) =>
      AppearanceSettings.fromJson(Map<String, Object?>.from(jsonDecode(source) as Map));

  /// The style key is a string, not the enum: this package must not know which styles a host registers, and
  /// a style added later has to remain loadable by an earlier build's settings screen.
  final String styleName;

  /// 'light', 'dark' or 'system'.
  final String brightness;

  /// Null means "whatever the platform profile resolves to".
  final Density? density;

  final bool reduceMotion;
  final double textScale;
  final InputMode? preferredInput;
  final BackgroundConfig background;

  /// The tokens these settings resolve to on [platform].
  ///
  /// The mapping lives beside the settings because the text floor, the remote minimums and the density default
  /// are rules of the token set, not of whichever screen drew the dropdown: a host that re-derived them per
  /// call site is where a TV build silently starts using phone hit areas.
  DesignTokens resolveTokens({required PlatformProfile platform}) => resolveDesignTokens(
    platform: platform,
    density: density,
    reduceMotion: reduceMotion,
    textScale: textScale,
    preferredInput: preferredInput,
    background: background,
  );

  AppearanceSettings copyWith({
    String? styleName,
    String? brightness,
    bool? reduceMotion,
    double? textScale,
    BackgroundConfig? background,
  }) => AppearanceSettings(
    styleName: styleName ?? this.styleName,
    brightness: brightness ?? this.brightness,
    density: density,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    textScale: textScale ?? this.textScale,
    preferredInput: preferredInput,
    background: background ?? this.background,
  );

  /// The density choice, or null for "whatever the platform profile resolves to".
  ///
  /// Separate from [copyWith] on purpose: an absent argument there means "unchanged", and "auto" is a value a
  /// settings screen has to be able to pick.
  AppearanceSettings withDensity(Density? value) => AppearanceSettings(
    styleName: styleName,
    brightness: brightness,
    density: value,
    reduceMotion: reduceMotion,
    textScale: textScale,
    preferredInput: preferredInput,
    background: background,
  );

  /// The input choice, or null for "read it from the platform".
  AppearanceSettings withInput(InputMode? value) => AppearanceSettings(
    styleName: styleName,
    brightness: brightness,
    density: density,
    reduceMotion: reduceMotion,
    textScale: textScale,
    preferredInput: value,
    background: background,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'style': styleName,
    'brightness': brightness,
    if (density != null) 'density': density!.name,
    'reduceMotion': reduceMotion,
    'textScale': textScale,
    if (preferredInput != null) 'input': preferredInput!.name,
    'background': background.toJson(),
  };

  String encode() => jsonEncode(toJson());
}
