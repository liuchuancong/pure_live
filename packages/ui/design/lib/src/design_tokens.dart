// Module: lib/src/design_tokens.dart
// Purpose: The design vocabulary every surface shares: spacing, radii and the
// semantic roles colors resolve to.
// Author: liuchuancong
// Created: 2026-10-10
//
// Tokens are numbers and names, never Color values: the scheme a style builds
// decides what "surface" looks like, and only components read the theme. A
// widget that hardcodes a hex here would be a style the registry cannot swap.

/// Spacing scale, four-point based.
abstract final class PureLiveSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Corner radii.
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

  /// Asset path, file path or http(s) url - the widget decides by scheme.
  final String? source;

  /// How strongly the content above must cover it; 1 means invisible.
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
