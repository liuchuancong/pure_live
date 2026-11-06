import 'package:live_cache/src/models/cache_priority.dart';
import 'package:meta/meta.dart';

/// One indexed cache file.
///
/// The entry owns the bookkeeping only: the file lives at the path derived
/// from [key] and [category], so losing the index never loses the images.
@immutable
final class CacheEntry {
  /// Creates an entry for the file named [key].
  const new({
    required this.key,
    required this.category,
    required this.size,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.priority,
    this.expiresAt,
    this.etag,
    this.lastModified,
    this.version,
  });

  /// The SHA-256 file stem.
  final String key;

  /// The policy category that decides the folder and the TTL.
  final String category;

  /// The file's size in bytes.
  final int size;

  /// When the bytes were written.
  final DateTime createdAt;

  /// When the file was last served; the LRU key during cleanup.
  final DateTime lastAccessedAt;

  /// When the bytes stop being fresh; null means permanent.
  final DateTime? expiresAt;

  /// The priority used when the cache is over its cap.
  final CachePriority priority;

  /// The strong validator the server supplied, for a conditional refresh.
  final String? etag;

  /// The last-modified validator the server supplied.
  final String? lastModified;

  /// The business version this copy belongs to.
  final String? version;

  /// Whether the entry never expires on its own.
  bool get isPermanent => expiresAt == null;

  /// Whether the bytes are past their TTL at [now].
  bool isExpiredAt(DateTime now) => !(expiresAt == null) && !expiresAt!.isAfter(now);

  /// Whether a copy expired at [now] may still be drawn while it refreshes:
  /// within the policy's stale window, or forever when [maxStale] is null.
  bool isUsableWhenStale(DateTime now, Duration? maxStale) {
    if (!isExpiredAt(now)) {
      return true;
    }
    if (maxStale == null) {
      return true;
    }
    return now.isBefore(expiresAt!.add(maxStale));
  }

  /// The entry with the named fields replaced.
  CacheEntry copyWith({
    int? size,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    DateTime? expiresAt,
    CachePriority? priority,
    String? etag,
    String? lastModified,
    String? version,
    bool clearExpiresAt = false,
  }) => CacheEntry(
    key: key,
    category: category,
    size: size ?? this.size,
    createdAt: createdAt ?? this.createdAt,
    lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
    expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
    priority: priority ?? this.priority,
    etag: etag ?? this.etag,
    lastModified: lastModified ?? this.lastModified,
    version: version ?? this.version,
  );

  /// The JSON object stored in the index.
  Map<String, Object?> toJson() => {
    'category': category,
    'size': size,
    'createdAt': createdAt.toUtc().millisecondsSinceEpoch,
    'lastAccessedAt': lastAccessedAt.toUtc().millisecondsSinceEpoch,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().millisecondsSinceEpoch,
    'priority': priority.name,
    if (etag != null) 'etag': etag,
    if (lastModified != null) 'lastModified': lastModified,
    if (version != null) 'version': version,
  };

  /// Reads an entry under [key]; null when the object is not a valid entry.
  static CacheEntry? fromJson(String key, Object? json) {
    if (json is! Map) {
      return null;
    }
    final category = json['category'];
    final size = json['size'];
    final createdAt = json['createdAt'];
    final lastAccessedAt = json['lastAccessedAt'];
    if (category is! String || size is! int || createdAt is! int || lastAccessedAt is! int) {
      return null;
    }
    final expiresAt = json['expiresAt'];
    return CacheEntry(
      key: key,
      category: category,
      size: size,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true),
      lastAccessedAt: DateTime.fromMillisecondsSinceEpoch(lastAccessedAt, isUtc: true),
      expiresAt: expiresAt is int ? DateTime.fromMillisecondsSinceEpoch(expiresAt, isUtc: true) : null,
      priority: CachePriority.fromName(json['priority'] as String?),
      etag: json['etag'] as String?,
      lastModified: json['lastModified'] as String?,
      version: json['version'] as String?,
    );
  }
}
