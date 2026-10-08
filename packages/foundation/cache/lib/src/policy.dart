// Module: lib/src/policy.dart
// Purpose: Cache namespace, eviction and quota vocabulary.
// Author: liuchuancong
// Created: 2026-10-08
//
// The namespace list is docs/services/cache.md: business code and plugins must not invent their own cache
// directory, they pick one of these so quota and cleanup stay meaningful.

/// What a cache entry is for.
enum CacheNamespace {
  image,
  media,
  music,
  subtitle,
  danmaku,
  plugin,
  metadata,
  epg,
  fonts,
}

/// Which entry to drop when a namespace is over its quota.
enum CacheEviction {
  /// Drop the entry touched longest ago. The default: playback re-reads what it just used.
  leastRecentlyUsed,

  /// Drop the entry written longest ago.
  firstInFirstOut,
}

/// How long entries live and how much room they get.
final class CachePolicy {
  const CachePolicy({
    this.ttl,
    this.maxBytes = 64 * 1024 * 1024,
    this.maxEntries = 512,
    this.eviction = CacheEviction.leastRecentlyUsed,
  });

  /// How long an entry stays valid; null means it does not expire on its own.
  final Duration? ttl;

  /// Byte ceiling for the namespace.
  final int maxBytes;

  /// Entry ceiling, so a namespace of many tiny keys cannot grow unbounded.
  final int maxEntries;
  final CacheEviction eviction;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (ttl != null) 'ttlMs': ttl!.inMilliseconds,
      'maxBytes': maxBytes,
      'maxEntries': maxEntries,
      'eviction': eviction.name,
    };
  }
}

/// What one namespace currently holds.
final class CacheUsage {
  const CacheUsage({required this.namespace, required this.entries, required this.bytes});

  final CacheNamespace namespace;
  final int entries;
  final int bytes;

  Map<String, Object?> toJson() => <String, Object?>{
        'namespace': namespace.name,
        'entries': entries,
        'bytes': bytes,
      };
}
