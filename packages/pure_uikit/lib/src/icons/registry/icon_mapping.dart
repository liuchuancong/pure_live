import 'package:flutter/widgets.dart' show IconData;
import 'package:pure_uikit/src/icons/api/pure_icon_key.dart';
import 'package:pure_uikit/src/icons/rendering/icon_builder.dart';

/// How one icon key's resource is produced.
///
/// A registration adapter chooses the shape: font glyph packages register
/// [PureIconGlyph]s (the themed draw sizes and tints them); SVG or brand
/// artwork registers a [PureIconWidget] builder (it controls its own
/// pixels, and receives the themed render context to obey size and the
/// preserve-colour rule).
sealed class PureIconSource {
  /// Sources are const-value.
  const new();
}

/// A font glyph (an [IconData] from any icon font the app declared).
final class PureIconGlyph extends PureIconSource {
  /// Wraps the glyph.
  const new(this.glyph);

  /// The glyph itself; colour and size are applied by the draw, not here.
  final IconData glyph;
}

/// A custom widget source (SVG, raster brand art, animated marks).
final class PureIconWidget extends PureIconSource {
  /// Wraps the builder.
  const new(this.builder);

  /// Builds the artwork for one themed draw.
  final PureIconBuilder builder;
}

/// One table of key-to-source answers — a language default, a platform
/// override, or the app-wide fallback mapping.
final class PureIconMapping {
  /// Builds the mapping.
  const new(this.sources);

  /// The resources this table registers.
  final Map<PureIconKey, PureIconSource> sources;

  /// The source registered for [key], null when this table does not answer.
  PureIconSource? lookup(PureIconKey key) => sources[key];
}
