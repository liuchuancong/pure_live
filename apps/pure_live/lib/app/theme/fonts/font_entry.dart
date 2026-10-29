import 'package:flutter/foundation.dart' show immutable;

import 'package:pure_live/app/theme/fonts/font_defaults.dart' show kDefaultFontFamily;

/// Which half of the font manager a face belongs to.
enum FontRegion {
  /// The faces a Chinese viewer expects first: the bundled MiSans, the
  /// system's own Chinese face and the free-font collection.
  domestic,

  /// The Google Fonts catalogue.
  overseas,
}

/// Where a face's bytes come from.
enum FontSource {
  /// Shipped inside the app (MiSans).
  bundled,

  /// The device's own face, named by `chinese_font_library`.
  system,

  /// A face from jaywcjlove/free-font, fetched on demand and cached on the
  /// device.
  freeFont,

  /// A family `google_fonts` fetches and registers on demand.
  google,
}

/// One face the font manager lists.
@immutable
final class FontEntry {
  /// Creates an entry; [id] is the family the theme stores.
  const FontEntry({
    required this.id,
    required this.name,
    required this.region,
    required this.source,
    this.category,
    this.bytes = 0,
    this.url,
    this.fallbackUrl,
  });

  /// The family id the theme and the danmaku style store.
  final String id;

  /// The shown name.
  final String name;

  /// Which half of the catalogue it belongs to.
  final FontRegion region;

  /// Where the bytes come from.
  final FontSource source;

  /// The free-font taxonomy (`heiti`, `songti`, …), null for the rest.
  final String? category;

  /// The file size in bytes, when known.
  final int bytes;

  /// The address the files are fetched from, for [FontSource.freeFont].
  final String? url;

  /// A second host for the same file, tried when [url] fails.
  final String? fallbackUrl;

  /// Whether the face is the one the app ships with.
  bool get isDefault => id == kDefaultFontFamily;

  /// Whether the id stands for the system's own Chinese face.
  bool get isSystem => source == FontSource.system;
}
