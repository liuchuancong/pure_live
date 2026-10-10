// Module: lib/src/engine.dart
// Purpose: Build and apply a backup as independent domain snapshots, with credentials refused on both ends.
// Author: liuchuancong
// Created: 2026-10-08
//
// The domain list is injected, and so is the predicate that recognises a credential key: the layout that
// marks a credential belongs to the auth package, and an L0 package may not reach into another L0
// package. Both ends refuse a credential key, so a hand-edited archive cannot smuggle one in either.

import 'package:pure_live_utils/pure_live_utils.dart';

import 'manifest.dart';

/// A named source of settings that can be snapshotted.
abstract interface class DomainSource {
  String get name;

  Future<Map<String, Object?>> snapshot();
}

/// A named destination that can accept a domain's values.
abstract interface class DomainTarget {
  String get name;

  Future<void> restore(Map<String, Object?> values);
}

/// An archive refused for exceeding a bound this build enforces.
final class BackupLimitException implements Exception {
  const BackupLimitException({required this.domain, required this.keys, required this.maxKeys});

  final String domain;
  final int keys;
  final int maxKeys;

  @override
  String toString() => 'BackupLimitException($domain holds $keys keys, limit $maxKeys)';
}

/// Produces a manifest plus the payload it describes.
final class BackupEngine {
  const BackupEngine({
    required this.sources,
    required this.isCredentialKey,
    this.appVersion = '0.0.0',
    this.schemaVersion = 1,
    this.maxKeysPerDomain = 200000,
  });

  final List<DomainSource> sources;

  /// True for keys that hold a credential; those are never written into an archive.
  final bool Function(String key) isCredentialKey;
  final String appVersion;
  final int schemaVersion;

  /// A domain larger than this is a bug or a hostile source, not a backup: a history table that grew into
  /// millions of rows would produce an archive no transport carries and no restore finishes.
  final int maxKeysPerDomain;

  Future<BackupBundle> build({Clock? clock}) async {
    final domains = <BackupDomain>[];
    final payload = <String, Map<String, Object?>>{};
    for (final source in sources) {
      final snapshot = await source.snapshot();
      final safe = Map<String, Object?>.fromEntries(snapshot.entries.where((entry) => !isCredentialKey(entry.key)));
      if (safe.length > maxKeysPerDomain) {
        throw BackupLimitException(domain: source.name, keys: safe.length, maxKeys: maxKeysPerDomain);
      }
      payload[source.name] = safe;
      domains.add(BackupDomain(name: source.name, keyCount: safe.length, bytes: _sizeOf(safe)));
    }
    return BackupBundle(
      manifest: BackupManifest(
        schemaVersion: schemaVersion,
        appVersion: appVersion,
        createdAt: (clock ?? systemClock)().toUtc(),
        domains: domains,
      ),
      payload: payload,
    );
  }
}

/// A built archive: the header and the values it describes.
final class BackupBundle {
  const BackupBundle({required this.manifest, required this.payload});

  final BackupManifest manifest;
  final Map<String, Map<String, Object?>> payload;
}

/// Applies a bundle domain by domain, recording each result instead of aborting on the first failure.
final class RestoreEngine {
  const RestoreEngine({
    required this.targets,
    required this.isCredentialKey,
    this.supportedSchemaVersions = const <int>{1},
  });

  final List<DomainTarget> targets;
  final bool Function(String key) isCredentialKey;

  /// Which manifest data versions this build may apply. A future version is refused rather than partially
  /// applied, because half-restored settings look exactly like a successful restore.
  final Set<int> supportedSchemaVersions;

  /// What [apply] would do, without touching a single target.
  ///
  /// docs/services/backup.md requires the summary-then-confirm step, and a summary computed by writing is not a
  /// summary: a user who cancels a restore halfway has the state the plan warned about, not the one they had.
  RestorePlan plan(BackupBundle bundle) {
    final problem = bundle.manifest.validate(supportedSchemaVersions: supportedSchemaVersions);
    if (problem != null) {
      throw FormatException(problem);
    }
    final byName = <String, DomainTarget>{for (final target in targets) target.name: target};
    final entries = <RestorePlanEntry>[];
    for (final domain in bundle.manifest.domains) {
      final values = bundle.payload[domain.name] ?? const <String, Object?>{};
      final refused = values.keys.where(isCredentialKey).length;
      final target = byName[domain.name];
      entries.add(
        RestorePlanEntry(
          domain: domain.name,
          keyCount: values.length - refused,
          refusedCredentials: refused,
          bytes: _sizeOf(values),
          willApply: target != null,
          reason: target == null ? 'this build has no destination named "${domain.name}"' : null,
        ),
      );
    }
    return RestorePlan(entries: List<RestorePlanEntry>.unmodifiable(entries));
  }

  /// [onlyDomains] restricts a retry to what previously failed; null applies every domain in the manifest.
  Future<RestoreReport> apply(BackupBundle bundle, {Set<String>? onlyDomains}) async {
    final problem = bundle.manifest.validate(supportedSchemaVersions: supportedSchemaVersions);
    if (problem != null) {
      throw FormatException(problem);
    }
    final byName = <String, DomainTarget>{for (final target in targets) target.name: target};
    final results = <String, DomainOutcome>{};
    var skippedCredentials = 0;

    for (final domain in bundle.manifest.domains) {
      if (onlyDomains != null && !onlyDomains.contains(domain.name)) {
        results[domain.name] = DomainOutcome.skipped;
        continue;
      }
      final target = byName[domain.name];
      if (target == null) {
        // No destination for this domain is a mismatch, not a failure to retry.
        results[domain.name] = DomainOutcome.skipped;
        continue;
      }
      final values = bundle.payload[domain.name] ?? const <String, Object?>{};
      final refused = values.keys.where(isCredentialKey).length;
      skippedCredentials += refused;
      final safe = Map<String, Object?>.fromEntries(values.entries.where((entry) => !isCredentialKey(entry.key)));
      try {
        await target.restore(safe);
        results[domain.name] = DomainOutcome.applied;
      } catch (_) {
        // One broken domain is recorded and the rest continue; a retry gets the failed list back.
        results[domain.name] = DomainOutcome.failed;
      }
    }
    return RestoreReport(results: results, skippedCredentials: skippedCredentials);
  }
}

/// One line of a restore preview.
final class RestorePlanEntry {
  const RestorePlanEntry({
    required this.domain,
    required this.keyCount,
    required this.refusedCredentials,
    required this.bytes,
    required this.willApply,
    this.reason,
  });

  final String domain;

  /// Rows that would be written.
  final int keyCount;

  /// Rows in the archive that will not be written because they name a credential.
  final int refusedCredentials;
  final int bytes;
  final bool willApply;

  /// Why it would not be applied.
  final String? reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'domain': domain,
    'keyCount': keyCount,
    'refusedCredentials': refusedCredentials,
    'bytes': bytes,
    'willApply': willApply,
    if (reason != null) 'reason': reason,
  };

  @override
  String toString() => '$domain: ${willApply ? "$keyCount keys" : 'skipped (${reason ?? 'unknown'})'}';
}

/// The preview of a restore: what would land, what would be refused, and what this build cannot accept.
final class RestorePlan {
  const RestorePlan({required this.entries});

  final List<RestorePlanEntry> entries;

  List<RestorePlanEntry> get applied => entries.where((entry) => entry.willApply).toList(growable: false);

  List<RestorePlanEntry> get refused => entries.where((entry) => !entry.willApply).toList(growable: false);

  int get totalKeys => applied.fold<int>(0, (sum, entry) => sum + entry.keyCount);

  int get totalBytes => applied.fold<int>(0, (sum, entry) => sum + entry.bytes);

  int get refusedCredentialKeys => entries.fold<int>(0, (sum, entry) => sum + entry.refusedCredentials);

  /// True when the archive carries a domain this build has nowhere to put. Restoring anyway leaves that
  /// domain's data unread in the archive, which the user should be told before they press the button.
  bool get hasUnmatchedDomains => refused.isNotEmpty;

  @override
  String toString() =>
      'RestorePlan(${applied.length}/${entries.length} domains, $totalKeys keys, $totalBytes bytes'
      '${refusedCredentialKeys > 0 ? ', $refusedCredentialKeys credential keys refused' : ''})';
}

int _sizeOf(Map<String, Object?> values) {
  var bytes = 0;
  for (final entry in values.entries) {
    bytes += entry.key.length;
    bytes += _valueSize(entry.value);
  }
  return bytes;
}

/// A rough size in bytes, good enough to decide whether an archive is worth downloading. A list counted by
/// element count rather than element size understates a playlist by an order of magnitude, which is the
/// difference between "this is small" and "this filled the remote".
int _valueSize(Object? value) {
  if (value == null) {
    return 0;
  }
  if (value is String) {
    return value.length;
  }
  if (value is Map) {
    return _sizeOf(Map<String, Object?>.from(value.map((k, dynamic v) => MapEntry<String, Object?>('$k', v))));
  }
  if (value is List) {
    return value.fold<int>(0, (sum, item) => sum + _valueSize(item) + 1);
  }
  if (value is bool) {
    return 1;
  }
  return 8;
}
