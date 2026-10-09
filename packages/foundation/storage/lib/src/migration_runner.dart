// Module: lib/src/migration_runner.dart
// Purpose: Run the per-domain v1 -> v2 migration the migration docs describe: confirm, copy, park rejects,
//          count-check, mark done, and be safe to run twice.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/migration/v1-to-v2.md (流程 + "v1 数据只读不改" + "失败可跳过重试" + "绝不清空") and
// docs/migration/database-migration.md (每域四步:读 v1 → 字段映射 → 写 v2 → 计数校验;单条失败进"待处理",
// 不阻塞整体). The key-name tables in those docs are data the v1 source used to carry and it is no longer in
// this repository, so this file implements the *flow* and leaves each domain's mapping to its own spec.

import 'dart:async';

import 'stores.dart';

/// One v1 record on its way out: a stable id, and the payload the mapping function will read.
final class SourceRecord {
  const SourceRecord({required this.key, required this.fields});

  /// Used to remember what already moved, so a retried domain does not duplicate a row.
  final String key;
  final Map<String, Object?> fields;
}

/// One domain's work: read v1, map one record, hand the result to v2.
///
/// The reader is the only access this type gives to v1, which is what makes "v1 只读" structural rather than
/// a promise in a comment.
final class MigrationDomainSpec {
  const MigrationDomainSpec({
    required this.name,
    required this.read,
    required this.map,
    required this.write,
    this.expectedCount,
  });

  final String name;

  /// The v1 side. Streamed so a big history box does not have to fit in memory at once.
  final Stream<SourceRecord> Function() read;

  /// The field mapping. Throw (or call [MigrationReject]) to park the record instead of failing the domain.
  final Object? Function(SourceRecord record) map;

  /// The v2 side. Implementations must be idempotent per record key - the runner skips keys it already
  /// recorded as migrated, and a crash between "written" and "recorded" lands here again.
  final Future<void> Function(Object? migrated) write;

  /// The count the domain says it should hold. When given and it disagrees with what was scanned, the domain
  /// is reported and left incomplete rather than marked done (database-migration.md step 4).
  final int? expectedCount;
}

/// Why one record did not move. It is a bucket, not a failure: the domain keeps going.
final class RejectedRecord {
  const RejectedRecord({required this.domain, required this.key, required this.reason});

  factory RejectedRecord.fromMap(Map<String, Object?> json) =>
      RejectedRecord(domain: '${json['domain']}', key: '${json['key']}', reason: '${json['reason']}');

  Map<String, Object?> toMap() => <String, Object?>{'domain': domain, 'key': key, 'reason': reason};

  final String domain;
  final String key;
  final String reason;

  @override
  String toString() => 'RejectedRecord($domain/$key: $reason)';
}

/// Thrown by a mapping function to park the current record.
final class MigrationReject implements Exception {
  const MigrationReject(this.reason);

  final String reason;

  @override
  String toString() => 'MigrationReject($reason)';
}

/// What happened to one domain.
final class DomainReport {
  const DomainReport({
    required this.domain,
    required this.scanned,
    required this.migrated,
    required this.rejected,
    required this.skipped,
    required this.completed,
    this.error,
  });

  final String domain;

  /// Records the reader produced this run (not counting ones a previous run already moved).
  final int scanned;
  final int migrated;
  final int rejected;

  /// Records not read at all because a previous run moved them - the resume in "失败可跳过重试".
  final int skipped;

  /// True when the domain may be skipped on the next run.
  final bool completed;

  /// A domain-level failure (the reader threw). Per-record problems are in [rejected] instead.
  final String? error;

  /// scanned == migrated + rejected, i.e. nothing vanished between the two stores.
  bool get countsReconcile => scanned == migrated + rejected;

  bool get isClean => completed && error == null && countsReconcile;

  @override
  String toString() =>
      'DomainReport($domain: $migrated+$rejected/$scanned, completed:$completed'
      '${error == null ? '' : ', error:$error'})';
}

/// The whole run, ready for the wizard's summary screen.
final class MigrationSummary {
  const MigrationSummary({required this.reports, required this.rejections, this.cancelled = false});

  final List<DomainReport> reports;
  final List<RejectedRecord> rejections;

  /// Set when the user did not confirm: nothing was read, written or marked (v1-to-v2.md's 摘要 → 确认).
  final bool cancelled;

  int get migrated => reports.fold(0, (sum, report) => sum + report.migrated);

  int get rejected => rejections.length;

  bool get isComplete => !cancelled && reports.isNotEmpty && reports.every((report) => report.isClean);

  /// The difference report: the numbers the wizard shows before it claims a migration finished.
  List<String> get discrepancies => <String>[
    for (final domain in reports)
      if (!domain.countsReconcile)
        '${domain.domain}: scanned ${domain.scanned} but accounted for ${domain.migrated + domain.rejected}',
    for (final domain in reports)
      if (domain.error != null) '${domain.domain}: ${domain.error}',
  ];
}

/// What a run already did, so a second run cannot duplicate it and a crash mid-domain resumes.
abstract interface class MigrationJournal {
  Future<bool> isDomainCompleted(String domain);

  Future<void> markDomainCompleted(String domain);

  Future<Set<String>> migratedKeys(String domain);

  Future<void> recordMigrated(String domain, Iterable<String> keys);

  /// The 待处理 list. Rejected records stay here until whoever owns that bucket picks them up.
  Future<void> parkRejected(Iterable<RejectedRecord> rejections);

  Future<List<RejectedRecord>> pendingRejections();
}

/// The per-domain migration described above.
final class MigrationRunner {
  const MigrationRunner({required MigrationJournal journal}) : _journal = journal;

  final MigrationJournal _journal;

  /// [confirmed] is asked once before anything is read. A wizard that never got a yes must not touch either
  /// store, so the default is false rather than true.
  Future<MigrationSummary> run(List<MigrationDomainSpec> domains, {Future<bool> Function()? confirmed}) async {
    final answer = confirmed == null ? false : await confirmed();
    if (!answer) {
      return MigrationSummary(reports: const <DomainReport>[], rejections: const <RejectedRecord>[], cancelled: true);
    }

    final reports = <DomainReport>[];
    final rejections = <RejectedRecord>[];
    for (final domain in domains) {
      final report = await _runDomain(domain, rejections);
      reports.add(report);
    }
    if (rejections.isNotEmpty) {
      await _journal.parkRejected(rejections);
    }
    return MigrationSummary(reports: reports, rejections: rejections, cancelled: false);
  }

  Future<DomainReport> _runDomain(MigrationDomainSpec spec, List<RejectedRecord> rejections) async {
    if (await _journal.isDomainCompleted(spec.name)) {
      return DomainReport(domain: spec.name, scanned: 0, migrated: 0, rejected: 0, skipped: 0, completed: true);
    }

    final alreadyMoved = await _journal.migratedKeys(spec.name);
    var scanned = 0;
    var migrated = 0;
    var rejected = 0;
    var skipped = 0;
    final movedNow = <String>[];

    try {
      await for (final record in spec.read()) {
        scanned++;
        if (alreadyMoved.contains(record.key)) {
          // Resumed domain: the previous attempt wrote it and recorded the key, so re-writing it here would
          // be the duplicate this whole path exists to avoid.
          skipped++;
          continue;
        }
        final Object? mapped;
        try {
          mapped = spec.map(record);
        } on MigrationReject catch (error) {
          rejected++;
          rejections.add(RejectedRecord(domain: spec.name, key: record.key, reason: error.reason));
          continue;
        } catch (error) {
          // A mapping that threw something else is still one record's problem, not the domain's: an
          // unmappable row is what the "未知源/待处理" bucket exists for.
          rejected++;
          rejections.add(RejectedRecord(domain: spec.name, key: record.key, reason: '$error'));
          continue;
        }
        try {
          await spec.write(mapped);
        } catch (error) {
          // Writing failed, so the key is not recorded: the retry re-attempts exactly this record.
          rejected++;
          rejections.add(RejectedRecord(domain: spec.name, key: record.key, reason: 'write failed: $error'));
          continue;
        }
        migrated++;
        movedNow.add(record.key);
      }
    } catch (error) {
      // The v1 side broke. Anything already written is recorded so a retry resumes rather than restarts, and
      // the domain stays open - the other domains still get their turn.
      await _journal.recordMigrated(spec.name, movedNow);
      return DomainReport(
        domain: spec.name,
        scanned: scanned,
        migrated: migrated,
        rejected: rejected,
        skipped: skipped,
        completed: false,
        error: 'reading ${spec.name} failed: $error',
      );
    }

    await _journal.recordMigrated(spec.name, movedNow);

    final expected = spec.expectedCount;
    if (expected != null && expected != scanned + skipped) {
      return DomainReport(
        domain: spec.name,
        scanned: scanned,
        migrated: migrated,
        rejected: rejected,
        skipped: skipped,
        completed: false,
        error: 'expected $expected records, saw ${scanned + skipped}',
      );
    }

    await _journal.markDomainCompleted(spec.name);
    return DomainReport(
      domain: spec.name,
      scanned: scanned,
      migrated: migrated,
      rejected: rejected,
      skipped: skipped,
      completed: true,
    );
  }
}

/// A [MigrationJournal] held in the same key/value store as the settings it migrates into.
///
/// The migrated-key sets are per domain, which is what lets a retried domain skip work; the price is that a
/// very large domain carries a large key list. A Drift binding can replace that with a per-row marker without
/// changing anything above this class.
final class KeyValueMigrationJournal implements MigrationJournal {
  KeyValueMigrationJournal(this.store, {this.namespace = 'migration'});

  final KeyValueStore store;
  final String namespace;

  String _domainKey(String domain) => '$namespace.domain.$domain';

  String _keysKey(String domain) => '$namespace.keys.$domain';

  String get _rejectionsKey => '$namespace.rejections';

  @override
  Future<bool> isDomainCompleted(String domain) async => await store.read(_domainKey(domain)) == 'done';

  @override
  Future<void> markDomainCompleted(String domain) => store.write(_domainKey(domain), 'done');

  @override
  Future<Set<String>> migratedKeys(String domain) async {
    final raw = await store.read(_keysKey(domain));
    if (raw is! List) {
      return const <String>{};
    }
    return raw.map((item) => '$item').toSet();
  }

  @override
  Future<void> recordMigrated(String domain, Iterable<String> keys) async {
    if (keys.isEmpty) {
      return;
    }
    final next = <String>[...await migratedKeys(domain), ...keys];
    await store.write(_keysKey(domain), next);
  }

  @override
  Future<void> parkRejected(Iterable<RejectedRecord> rejections) async {
    if (rejections.isEmpty) {
      return;
    }
    final next = <Map<String, Object?>>[
      ...await pendingRejectionMaps(),
      for (final rejection in rejections)
        <String, Object?>{'domain': rejection.domain, 'key': rejection.key, 'reason': rejection.reason},
    ];
    await store.write(_rejectionsKey, next);
  }

  @override
  Future<List<RejectedRecord>> pendingRejections() async =>
      (await pendingRejectionMaps()).map(RejectedRecord.fromMap).toList(growable: false);

  Future<List<Map<String, Object?>>> pendingRejectionMaps() async {
    final raw = await store.read(_rejectionsKey);
    if (raw is! List) {
      return const <Map<String, Object?>>[];
    }
    return raw.whereType<Map<Object?, Object?>>().map(Map<String, Object?>.from).toList();
  }
}
