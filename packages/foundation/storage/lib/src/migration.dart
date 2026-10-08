// Module: lib/src/migration.dart
// Purpose: Settings migration driven by a key map, plus versioned schema steps that isolate failures per step.
// Author: liuchuancong
// Created: 2026-10-08
//
// Rules come from docs/migration/settings-migration.md and docs/migration/v1-to-v2.md: the mapping is a
// table of old key to new key with an optional conversion, unknown keys are ignored but recorded, and a
// failure in one step must not abort the rest so a retry can continue.

import 'dart:async';

import 'stores.dart';

/// The key holding the applied schema version.
const String schemaVersionKey = 'platform.schema_version';

/// One entry of the old key to new key table.
final class KeyMapping {
  const KeyMapping({
    required this.from,
    required this.to,
    this.convert,
  });

  final String from;
  final String to;

  /// Adapts the stored value, for example widening an int that became a Duration.
  final Object? Function(Object? value)? convert;

  Object? apply(Object? value) => convert == null ? value : convert!(value);
}

/// What a migration run did.
final class MigrationReport {
  MigrationReport({
    List<String>? migrated,
    List<String>? ignored,
    Map<String, String>? failures,
  }) : migrated = List<String>.unmodifiable(migrated ?? const <String>[]),
       ignored = List<String>.unmodifiable(ignored ?? const <String>[]),
       failures = Map<String, String>.unmodifiable(failures ?? const <String, String>{});

  /// Keys copied into the target store.
  final List<String> migrated;

  /// Source keys with no mapping; recorded so the table can be completed rather than silently losing data.
  final List<String> ignored;

  /// Target key to the reason it failed. The run continues past these.
  final Map<String, String> failures;

  bool get isClean => ignored.isEmpty && failures.isEmpty;

  @override
  String toString() =>
      'MigrationReport(migrated=${migrated.length}, ignored=${ignored.length}, failures=$failures)';
}

/// Copies settings from one store to another using a key table.
final class SettingsMigrator {
  const SettingsMigrator({required this.mappings});

  final List<KeyMapping> mappings;

  /// Reads every key in [source] and writes the mapped ones into [target].
  ///
  /// A conversion that throws is recorded against the target key and the run continues: losing one setting
  /// must not block the migration of the rest.
  Future<MigrationReport> run({
    required KeyValueStore source,
    required KeyValueStore target,
  }) async {
    final migrated = <String>[];
    final ignored = <String>[];
    final failures = <String, String>{};
    final bySource = <String, KeyMapping>{
      for (final mapping in mappings) mapping.from: mapping,
    };

    for (final key in await source.keys()) {
      final mapping = bySource[key];
      if (mapping == null) {
        ignored.add(key);
        continue;
      }
      try {
        await target.write(mapping.to, mapping.apply(await source.read(key)));
        migrated.add(mapping.to);
      } catch (error) {
        failures[mapping.to] = '$error';
      }
    }
    return MigrationReport(migrated: migrated, ignored: ignored, failures: failures);
  }
}

/// One forward step of a schema version.
final class SchemaStep {
  const SchemaStep({required this.fromVersion, required this.describe, required this.apply});

  /// The version this step upgrades from. Steps must chain without gaps.
  final int fromVersion;

  /// Shown in logs and in a failure message, so a stuck user can be told which step broke.
  final String describe;
  final FutureOr<void> Function(KeyValueStore store) apply;
}

/// Applies schema steps in order, recording the version after each one.
final class SchemaMigrator {
  const SchemaMigrator({required this.steps});

  final List<SchemaStep> steps;

  /// Returns the versions applied, stopping at the first failure so a retry resumes from there.
  Future<List<int>> migrate(KeyValueStore store) async {
    final applied = <int>[];
    var version = await store.readInt(schemaVersionKey, fallback: 0);
    final ordered = steps.toList()..sort((a, b) => a.fromVersion.compareTo(b.fromVersion));
    _validateChain(ordered);

    for (final step in ordered) {
      if (step.fromVersion < version) {
        continue;
      }
      if (step.fromVersion != version) {
        throw StateError(
          'schema step "${step.describe}" expects version ${step.fromVersion} but the store is at $version',
        );
      }
      await step.apply(store);
      version = step.fromVersion + 1;
      await store.write(schemaVersionKey, version);
      applied.add(step.fromVersion);
    }
    return applied;
  }

  static void _validateChain(List<SchemaStep> ordered) {
    for (var index = 1; index < ordered.length; index++) {
      final previous = ordered[index - 1];
      final current = ordered[index];
      if (current.fromVersion == previous.fromVersion) {
        throw StateError('duplicate schema step for version ${current.fromVersion}');
      }
      if (current.fromVersion > previous.fromVersion + 1) {
        throw StateError(
          'schema chain has a gap: "${previous.describe}" ends at ${previous.fromVersion + 1} but '
          '"${current.describe}" starts at ${current.fromVersion}',
        );
      }
    }
  }
}
