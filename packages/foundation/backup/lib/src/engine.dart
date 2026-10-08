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

/// Produces a manifest plus the payload it describes.
final class BackupEngine {
  const BackupEngine({
    required this.sources,
    required this.isCredentialKey,
    this.appVersion = '0.0.0',
    this.schemaVersion = 1,
  });

  final List<DomainSource> sources;

  /// True for keys that hold a credential; those are never written into an archive.
  final bool Function(String key) isCredentialKey;
  final String appVersion;
  final int schemaVersion;

  Future<BackupBundle> build({Clock? clock}) async {
    final domains = <BackupDomain>[];
    final payload = <String, Map<String, Object?>>{};
    for (final source in sources) {
      final snapshot = await source.snapshot();
      final safe = Map<String, Object?>.fromEntries(
        snapshot.entries.where((entry) => !isCredentialKey(entry.key)),
      );
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
  const RestoreEngine({required this.targets, required this.isCredentialKey});

  final List<DomainTarget> targets;
  final bool Function(String key) isCredentialKey;

  /// [onlyDomains] restricts a retry to what previously failed; null applies every domain in the manifest.
  Future<RestoreReport> apply(BackupBundle bundle, {Set<String>? onlyDomains}) async {
    final problem = bundle.manifest.validate(supportedSchemaVersions: const <int>{1});
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
      final safe = Map<String, Object?>.fromEntries(
        values.entries.where((entry) => !isCredentialKey(entry.key)),
      );
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

int _sizeOf(Map<String, Object?> values) {
  var bytes = 0;
  for (final entry in values.entries) {
    bytes += entry.key.length;
    final value = entry.value;
    bytes += switch (value) {
      final String text => text.length,
      final Map<Object?, Object?> nested => _sizeOf(Map<String, Object?>.from(nested)),
      final List<Object?> list => list.length,
      null => 0,
      _ => 8,
    };
  }
  return bytes;
}
