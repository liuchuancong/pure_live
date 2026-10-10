// Module: lib/src/archiver.dart
// Purpose: Put an archive somewhere, keep a bounded set of them, and bring one back.
// Author: liuchuancong
// Created: 2026-10-11
//
// The engine builds a bundle and the codec makes bytes; neither decides where the bytes go or how many copies
// of yesterday's settings the cloud should hold. Rotation is the part users notice as a bill or a full disk,
// and the retention rule has two bounds on purpose: keeping "the last eight" means a device that syncs once a
// year has eight copies of the same month, while keeping "the last 90 days" means a device that backs up every
// boot keeps every boot.

import 'dart:convert';

import 'package:pure_live_utils/pure_live_utils.dart';

import 'codec.dart';
import 'engine.dart';
import 'manifest.dart';

/// Where archives live. Byte-oriented, because the archive *is* bytes and a transport that re-serialises JSON
/// would otherwise be allowed to change what the digest covered - the codec's canonical form makes that safe,
/// but the store still must not invent content.
abstract interface class BackupArchiveStore {
  Future<void> write(String name, List<int> bytes);

  /// The archive, or null when nothing is stored under [name].
  Future<List<int>?> read(String name);

  Future<List<BackupArchive>> list();

  Future<void> delete(String name);
}

/// One archive as a store lists it.
final class BackupArchive {
  const BackupArchive({required this.name, required this.bytes, this.modifiedAt});

  final String name;
  final int bytes;

  /// Null when the store cannot say. The name carries a timestamp, so [archivedAt] still works for ordering.
  final DateTime? modifiedAt;

  /// The instant encoded in the name, falling back to the store's own modification time.
  DateTime? get archivedAt => instantFromName(name) ?? modifiedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'bytes': bytes,
    if (modifiedAt != null) 'modifiedAt': modifiedAt!.toIso8601String(),
  };

  @override
  String toString() => 'BackupArchive($name, $bytes bytes)';
}

/// How many archives, and how old, a store may hold.
final class RetentionPolicy {
  const RetentionPolicy({this.maxArchives = 8, this.maxAge = const Duration(days: 90)})
    : assert(maxArchives >= 1, 'a store that keeps no archive is not a backup');

  final int maxArchives;

  /// Archives older than this are pruned even when the count is under [maxArchives].
  final Duration maxAge;

  static const RetentionPolicy standard = RetentionPolicy();

  @override
  String toString() => 'RetentionPolicy(keep $maxArchives, drop past ${maxAge.inDays}d)';
}

/// The sortable, collision-free name for an archive taken at [at].
String backupArchiveName(DateTime at, {String appVersion = '', String extension = 'json'}) {
  final stamp = at.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  final buffer = StringBuffer('pure_live-backup-')
    ..write(stamp.year)
    ..write(two(stamp.month))
    ..write(two(stamp.day))
    ..write('T')
    ..write(two(stamp.hour))
    ..write(two(stamp.minute))
    ..write(two(stamp.second))
    ..write('Z');
  if (appVersion.trim().isNotEmpty) {
    buffer.write('-${appVersion.trim()}');
  }
  buffer.write('.$extension');
  return buffer.toString();
}

/// The timestamp in a name written by [backupArchiveName], or null for a foreign name.
DateTime? instantFromName(String name) {
  final match = RegExp(r'pure_live-backup-(\d{8})T(\d{6})Z').firstMatch(name);
  if (match == null) {
    return null;
  }
  final day = match.group(1)!;
  final clock = match.group(2)!;
  return DateTime.utc(
    int.parse(day.substring(0, 4)),
    int.parse(day.substring(4, 6)),
    int.parse(day.substring(6, 8)),
    int.parse(clock.substring(0, 2)),
    int.parse(clock.substring(2, 4)),
    int.parse(clock.substring(4, 6)),
  );
}

/// Applies [policy] to a listing, returning the names that must go.
///
/// Age first, then count, so the oldest surplus is what is deleted; a listing whose names carry no timestamp
/// and whose store reports no modification time is left alone rather than guessed at - deleting a backup is
/// the one operation here that cannot be undone by a restore.
List<String> archivesToPrune(List<BackupArchive> archives, {required RetentionPolicy policy, required DateTime now}) {
  final dated = archives.where((archive) => archive.archivedAt != null).toList(growable: false)
    ..sort((left, right) => right.archivedAt!.compareTo(left.archivedAt!));
  if (dated.length < archives.length) {
    // At least one entry could not be placed in time: only the count bound is safe to apply.
    final surplus = dated.length - policy.maxArchives;
    return surplus <= 0 ? const <String>[] : dated.skip(policy.maxArchives).map((a) => a.name).toList();
  }
  final staleCutoff = now.subtract(policy.maxAge);
  final doomed = <String>{};
  for (final archive in dated) {
    if (archive.archivedAt!.isBefore(staleCutoff)) {
      doomed.add(archive.name);
    }
  }
  final kept = dated.where((archive) => !doomed.contains(archive.name)).toList(growable: false);
  for (final archive in kept.skip(policy.maxArchives)) {
    doomed.add(archive.name);
  }
  return doomed.toList(growable: false)..sort();
}

/// Writes, prunes, lists and reads archives as one use case.
final class BackupArchiver {
  BackupArchiver({required BackupArchiveStore store, this.policy = RetentionPolicy.standard, Clock? clock})
    : _store = store,
      _clock = clock ?? systemClock;

  final BackupArchiveStore _store;
  final RetentionPolicy policy;
  final Clock _clock;

  /// Builds, encodes, writes and then prunes. Returns the archive as it now exists remotely.
  Future<ArchivedBackup> archive(
    BackupEngine engine, {
    String? name,
    bool pretty = false,
    bool Function()? skipBuild,
  }) async {
    final at = _clock().toUtc();
    final bundle = await engine.build(clock: _clock);
    final bytes = encodeBundle(bundle, pretty: pretty);
    final archiveName = name ?? backupArchiveName(at, appVersion: bundle.manifest.appVersion);
    await _store.write(archiveName, bytes);
    final deleted = await prune();
    return ArchivedBackup(
      name: archiveName,
      bytes: bytes.length,
      createdAt: at,
      manifest: bundle.manifest,
      prunedNames: deleted,
    );
  }

  /// Applies the retention policy to the store, returning the names it deleted.
  Future<List<String>> prune() async {
    final all = await _store.list();
    final doomed = archivesToPrune(all, policy: policy, now: _clock().toUtc());
    for (final name in doomed) {
      await _store.delete(name);
    }
    return doomed;
  }

  /// The newest archive the store can name, or null when it holds none.
  Future<BackupArchive?> newest() async {
    final all = await _store.list();
    if (all.isEmpty) {
      return null;
    }
    final sorted = List<BackupArchive>.of(all)
      ..sort((left, right) {
        final a = left.archivedAt ?? DateTime.utc(1970);
        final b = right.archivedAt ?? DateTime.utc(1970);
        return b.compareTo(a);
      });
    return sorted.first;
  }

  /// Reads and verifies one archive, or null when it is missing.
  Future<DecodedBackup?> load(String name, {Set<int> supportedSchemaVersions = const <int>{1}}) async {
    final bytes = await _store.read(name);
    if (bytes == null) {
      return null;
    }
    return decodeBundle(bytes, supportedSchemaVersions: supportedSchemaVersions);
  }

  /// Reads and verifies the newest archive.
  Future<DecodedBackup?> loadLatest({Set<int> supportedSchemaVersions = const <int>{1}}) async {
    final latest = await newest();
    if (latest == null) {
      return null;
    }
    return load(latest.name, supportedSchemaVersions: supportedSchemaVersions);
  }
}

/// What one [BackupArchiver.archive] produced.
final class ArchivedBackup {
  const ArchivedBackup({
    required this.name,
    required this.bytes,
    required this.createdAt,
    required this.manifest,
    required this.prunedNames,
  });

  final String name;
  final int bytes;
  final DateTime createdAt;
  final BackupManifest manifest;

  /// Archives the retention rule removed as part of this same call. A user who expects their history to grow
  /// needs to see this number, not discover it later.
  final List<String> prunedNames;

  bool get prunedAnything => prunedNames.isNotEmpty;

  @override
  String toString() =>
      'ArchivedBackup($name, $bytes bytes, ${manifest.domains.length} domains'
      '${prunedAnything ? ', pruned ${prunedNames.length}' : ''})';
}

/// A [BackupArchiveStore] in memory, for tests and for a "save to file" flow that hands the bytes on.
///
/// Bounded: the newest [maxArchives] are kept, and the count is what a test asserts on rather than a
/// convenient fiction about the remote.
final class InMemoryArchiveStore implements BackupArchiveStore {
  InMemoryArchiveStore({this.maxArchives = 32});

  final int maxArchives;
  final Map<String, List<int>> _blobs = <String, List<int>>{};
  final Map<String, DateTime> _writtenAt = <String, DateTime>{};
  int _rejected = 0;

  /// Writes refused because the store was full.
  int get rejectedCount => _rejected;

  @override
  Future<void> write(String name, List<int> bytes) async {
    if (_blobs.length >= maxArchives && !_blobs.containsKey(name)) {
      _rejected++;
      throw BackupCodecFailure(
        'the in-memory store holds $maxArchives archives',
        expected: '<=$maxArchives',
        found: _blobs.length + 1,
      );
    }
    _blobs[name] = List<int>.unmodifiable(bytes);
    _writtenAt[name] = DateTime.now().toUtc();
  }

  @override
  Future<List<int>?> read(String name) async => _blobs[name];

  @override
  Future<List<BackupArchive>> list() async {
    return <BackupArchive>[
      for (final entry in _blobs.entries)
        BackupArchive(name: entry.key, bytes: entry.value.length, modifiedAt: _writtenAt[entry.key]),
    ];
  }

  @override
  Future<void> delete(String name) async {
    _blobs.remove(name);
    _writtenAt.remove(name);
  }

  /// The stored bytes, decoded as text - a test's shortcut for "what would the user have downloaded".
  String? textOf(String name) {
    final bytes = _blobs[name];
    return bytes == null ? null : utf8.decode(bytes);
  }
}
