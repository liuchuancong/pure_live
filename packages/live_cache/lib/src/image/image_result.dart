import 'dart:typed_data';

import 'package:live_cache/src/models/cache_entry.dart';
import 'package:live_cache/src/models/cache_source.dart';
import 'package:meta/meta.dart';

/// Bytes the cache resolved for one request.
@immutable
final class LiveImageResult {
  /// Creates a result carrying [bytes].
  const new({required this.bytes, required this.source, required this.isExpired, required this.isStale, this.entry});

  /// The encoded image.
  final Uint8List bytes;

  /// Where the bytes came from.
  final CacheSource source;

  /// Whether the bytes are past their TTL.
  final bool isExpired;

  /// Whether the bytes are past their TTL but still allowed to stand in
  /// while the fresh copy is fetched.
  final bool isStale;

  /// The index entry behind the bytes, when they came from disk.
  final CacheEntry? entry;
}
