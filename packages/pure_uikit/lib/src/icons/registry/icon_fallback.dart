import 'package:flutter/material.dart' show IconData, Icons;
import 'package:pure_uikit/src/icons/registry/icon_mapping.dart';

/// The universal answer when nothing else registered the key.
///
/// Falling here is a registration bug, not a runtime state, so the glyph is
/// deliberately conspicuous, and the resolver reports the tier so a debug
/// session can name the key that missed.
abstract final class PureIconFallback {
  /// The broken-image glyph every unresolved key draws.
  static const PureIconSource source = PureIconGlyph(glyph);

  /// The glyph itself, for APIs that only take an [IconData].
  static const IconData glyph = Icons.broken_image_outlined;

  /// Whether [candidate] is this fallback source.
  static bool isFallback(PureIconSource candidate) => identical(candidate, source);
}
