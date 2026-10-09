// Module: test/migration_runner_test.dart
// Purpose: Verify the v1 -> v2 migration flow: confirm first, per-record rejects, resume, and count checks.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/migration/{v1-to-v2,database-migration}.md. The key-name tables there are v1 data this
// repository no longer carries, so these tests exercise the flow with synthetic records rather than real keys.
import 'package:pure_live_storage/pure_live_storage.dart';
import 'package:test/test.dart';

SourceRecord _record(String key) => SourceRecord(key: key, fields: <String, Object?>{'k': key});

MigrationDomainSpec _domain(
  String name, {
  required List<SourceRecord> records,
  Object? Function(SourceRecord)? map,
  void Function(Object?)? sink,
  int? expectedCount,
  int? failAfter,
}) {
  var seen = 0;
  final writes = <Object?>[];
  return MigrationDomainSpec(
    name: name,
    read: () => Stream<SourceRecord>.fromIterable(records).map((record) {
      if (failAfter != null && seen >= failAfter) {
        throw StateError('the v1 box broke open');
      }
      seen++;
      return record;
    }),
    map: map ?? (SourceRecord record) => record.fields,
    // Each spec gets a fresh writer: a retried domain must show what the second attempt wrote, not what the
    // first one did.
    write: (migrated) async {
      writes.add(migrated);
      sink?.call(migrated);
    },
    expectedCount: expectedCount,
  );
}

void main() {
  late MemoryKeyValueStore store;
  late KeyValueMigrationJournal journal;
  late MigrationRunner runner;

  setUp(() {
    store = MemoryKeyValueStore();
    journal = KeyValueMigrationJournal(store);
    runner = MigrationRunner(journal: journal);
  });

  Future<void> expectDomains(Map<String, int> counts) async {
    for (final entry in counts.entries) {
      expect(await journal.migratedKeys(entry.key), hasLength(entry.value), reason: entry.key);
    }
  }

  group('test_runner_confirmation', () {
    test('test_run_withoutConfirmation_readsNothingAndWritesNothing', () async {
      var reads = 0;
      final spec = MigrationDomainSpec(
        name: 'favorites',
        read: () {
          reads++;
          return Stream<SourceRecord>.fromIterable(<SourceRecord>[_record('f1')]);
        },
        map: (SourceRecord record) => record.fields,
        write: (Object? migrated) async {},
      );

      final summary = await runner.run(<MigrationDomainSpec>[spec]);

      expect(summary.cancelled, isTrue);
      expect(reads, 0);
      expect(summary.reports, isEmpty);
      expect(await journal.isDomainCompleted('favorites'), isFalse);
    });

    test('test_run_afterConfirmation_movesTheRecords', () async {
      final moved = <Object?>[];
      final summary = await runner.run(<MigrationDomainSpec>[
        _domain('favorites', records: <SourceRecord>[_record('f1'), _record('f2')], sink: moved.add),
      ], confirmed: () async => true);

      expect(moved, hasLength(2));
      expect(summary.migrated, 2);
      expect(summary.isComplete, isTrue);
      expect(await journal.isDomainCompleted('favorites'), isTrue);
    });
  });

  group('test_runner_rejects', () {
    test('test_run_oneUnmappableRecord_isParkedAndDoesNotStopTheDomain', () async {
      final summary = await runner.run(<MigrationDomainSpec>[
        _domain(
          'history',
          records: <SourceRecord>[_record('ok'), _record('bad'), _record('ok2')],
          map: (record) {
            if (record.key == 'bad') {
              throw const MigrationReject('未知源,先进待处理');
            }
            return record.fields;
          },
        ),
      ], confirmed: () async => true);

      final report = summary.reports.single;
      expect(report.migrated, 2);
      expect(report.rejected, 1);
      expect(report.completed, isTrue);
      expect(report.countsReconcile, isTrue);
      expect(summary.discrepancies, isEmpty);
      // The bucket is the point: the record is not lost, and the domain finished.
      expect((await journal.pendingRejections()).single.reason, contains('未知源'));
    });

    test('test_run_writeFailure_parksThatRecordWithoutRecordingItAsMoved', () async {
      final summary = await runner.run(<MigrationDomainSpec>[
        _domain(
          'settings',
          records: <SourceRecord>[_record('a'), _record('b')],
          sink: (migrated) {
            if ((migrated! as Map)['k'] == 'a') {
              throw StateError('target rejected it');
            }
          },
        ),
      ], confirmed: () async => true);

      expect(summary.reports.single.rejected, 1);
      await expectDomains(<String, int>{'settings': 1});
      expect((await journal.pendingRejections()).single.reason, contains('write failed'));
    });

    test('test_run_mappingThatThrowsSomethingElse_isStillOneRecordsProblem', () async {
      final summary = await runner.run(<MigrationDomainSpec>[
        _domain(
          'settings',
          records: <SourceRecord>[_record('a'), _record('b')],
          map: (record) => record.key == 'a' ? (throw FormatException('no such key')) : record.fields,
        ),
      ], confirmed: () async => true);

      expect(summary.reports.single.migrated, 1);
      expect(summary.reports.single.rejected, 1);
      expect(summary.reports.single.error, isNull);
    });
  });

  group('test_runner_resume', () {
    test('test_run_twice_doesNotReadACompletedDomainAgain', () async {
      final moved = <Object?>[];
      final spec = _domain('favorites', records: <SourceRecord>[_record('f1')], sink: moved.add);

      await runner.run(<MigrationDomainSpec>[spec], confirmed: () async => true);
      final second = await runner.run(<MigrationDomainSpec>[
        _domain('favorites', records: <SourceRecord>[_record('f1')], sink: moved.add),
      ], confirmed: () async => true);

      expect(moved, hasLength(1));
      expect(await journal.migratedKeys('favorites'), <String>['f1']);
      expect(second.reports.single.scanned, 0, reason: 'a completed domain is not read again');
    });

    test('test_run_afterAReadFailure_resumesWithoutDuplicating', () async {
      final records = <SourceRecord>[_record('r1'), _record('r2'), _record('r3')];
      final moved = <Object?>[];
      final broken = _domain('history', records: records, failAfter: 2, sink: moved.add);

      final first = await runner.run(<MigrationDomainSpec>[broken], confirmed: () async => true);

      expect(first.reports.single.error, contains('v1 box'));
      expect(first.reports.single.completed, isFalse);
      expect(await journal.isDomainCompleted('history'), isFalse);
      expect(await journal.migratedKeys('history'), <String>['r1', 'r2']);

      final retryWrites = <Object?>[];
      final retry = _domain('history', records: records, sink: retryWrites.add);
      final second = await runner.run(<MigrationDomainSpec>[retry], confirmed: () async => true);

      // The two records the failed attempt already wrote are skipped, not written again.
      expect(second.reports.single.skipped, 2);
      expect(second.reports.single.migrated, 1);
      expect(second.reports.single.completed, isTrue);
      expect(moved, hasLength(2), reason: 'the first attempt wrote r1 and r2');
      expect(retryWrites, hasLength(1), reason: 'the retry writes only what is left');
    });

    test('test_run_withACountMismatch_leavesTheDomainOpen', () async {
      final summary = await runner.run(<MigrationDomainSpec>[
        _domain('favorites', records: <SourceRecord>[_record('f1')], expectedCount: 7),
      ], confirmed: () async => true);

      expect(summary.isComplete, isFalse);
      expect(summary.discrepancies.single, contains('expected 7'));
      expect(await journal.isDomainCompleted('favorites'), isFalse);
    });
  });

  group('test_runner_isolation', () {
    test('test_run_aFailingDomain_doesNotStopTheNextOne', () async {
      final summary = await runner.run(<MigrationDomainSpec>[
        _domain('broken', records: <SourceRecord>[_record('x')], failAfter: 0),
        _domain('good', records: <SourceRecord>[_record('y')]),
      ], confirmed: () async => true);

      expect(summary.reports.map((DomainReport report) => report.domain), <String>['broken', 'good']);
      expect(summary.reports.first.completed, isFalse);
      expect(summary.reports.last.completed, isTrue);
    });

    test('test_journal_state_survivesANewJournalOverTheSameStore', () async {
      await runner.run(<MigrationDomainSpec>[
        _domain(
          'favorites',
          records: <SourceRecord>[_record('bad')],
          map: (record) => throw const MigrationReject('unmapped'),
        ),
      ], confirmed: () async => true);

      final reopened = KeyValueMigrationJournal(store);

      expect(await reopened.isDomainCompleted('favorites'), isTrue);
      expect((await reopened.pendingRejections()).single.key, 'bad');
    });
  });
}
