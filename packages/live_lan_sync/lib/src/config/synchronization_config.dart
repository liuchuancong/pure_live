import 'package:live_lan_sync/src/domain/conflict/conflict.dart';

/// How data moves and what happens when edits collide.
///
/// Automatic sync is opt-in: a host must turn it on explicitly, and a
/// mobile platform's background limits are never promised away by defaults.
final class LanSyncOptions {
  /// The synchronization defaults.
  const new({
    this.incrementalSyncEnabled = true,
    this.batchSize = 100,
    this.maxBatchBytes = 4 * 1024 * 1024,
    this.maxRetries = 5,
    this.autoSyncEnabled = false,
    this.autoSyncInterval = const Duration(minutes: 5),
    this.defaultConflictPolicy = ConflictPolicy.manual,
    this.scopeConflictPolicies = const <String, ConflictPolicy>{},
    this.maxVersionVectorEntries = 32,
    this.tombstoneRetention = const Duration(days: 30),
    this.bidirectionalAllowed = true,
  });

  /// Whether change-log deltas are exchanged instead of full manifests.
  final bool incrementalSyncEnabled;

  /// The most changes carried in one batch.
  final int batchSize;

  /// The largest byte size one batch may reach, capping fat payloads.
  final int maxBatchBytes;

  /// How often a failed batch exchange is retried before the task fails.
  /// Retries back off exponentially; authentication, permission and protocol
  /// failures never retry regardless of this value.
  final int maxRetries;

  /// Whether the engine may start sync tasks on its own. Off by default:
  /// the host (and the user) decide when devices talk.
  final bool autoSyncEnabled;

  /// How often automatic sync re-runs while [autoSyncEnabled].
  final Duration autoSyncInterval;

  /// The policy applied to concurrent modifications a scope's adapter does
  /// not resolve itself. The safe default is to escalate instead of picking
  /// a winner silently.
  final ConflictPolicy defaultConflictPolicy;

  /// Per-scope policies overriding [defaultConflictPolicy]. A policy the
  /// scope's adapter does not honour falls back to manual.
  ///
  /// `preferLocal` and `preferRemote` decide in favour of the device that
  /// detects the conflict first; for one fixed winner, give the
  /// authoritative device `preferLocal` and the others `preferRemote`.
  final Map<String, ConflictPolicy> scopeConflictPolicies;

  /// The most device entries one entity's version vector keeps. Past it,
  /// entries of devices no longer trusted are dropped, smallest counters
  /// first; this device's and trusted devices' entries are never dropped.
  /// Dropping can only turn "newer" into "concurrent" — a conflict to
  /// settle, never a silent overwrite (spec §11.2).
  final int maxVersionVectorEntries;

  /// How long a deletion tombstone is kept before the retention policy may
  /// retire it, provided every participating device has acknowledged it.
  final Duration tombstoneRetention;

  /// Whether two-way exchange is permitted at all; scopes may narrow this
  /// further through their adapter's capabilities.
  final bool bidirectionalAllowed;

  /// Returns the human-readable problems with this configuration, or an
  /// empty list when it is usable as is.
  List<String> validate() {
    final problems = <String>[];
    if (batchSize < 1 || batchSize > 10000) {
      problems.add('synchronization.batchSize must be 1..10000');
    }
    if (maxBatchBytes < 16 * 1024) {
      problems.add('synchronization.maxBatchBytes must allow at least 16 KiB');
    }
    if (maxRetries < 0) {
      problems.add('synchronization.maxRetries must not be negative');
    }
    if (autoSyncEnabled && autoSyncInterval <= Duration.zero) {
      problems.add('synchronization.autoSyncInterval must be positive when auto sync is on');
    }
    if (maxVersionVectorEntries < 2) {
      problems.add('synchronization.maxVersionVectorEntries must be at least 2');
    }
    if (tombstoneRetention < const Duration(hours: 1)) {
      problems.add('synchronization.tombstoneRetention must be at least one hour');
    }
    return problems;
  }
}
