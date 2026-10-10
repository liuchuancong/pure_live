// Module: test/sync_cursor_test.dart
// Purpose: Verify a sync pass advances the position and that unusable remote rows are counted, not hidden.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/services/sync.md makes the cursor the load-bearing part of a pull - sync.md section on 增量拉取.
// The first engine echoed the cursor it was given, so every pull re-fetched from the same point.

import 'package:pure_live_sync/pure_live_sync.dart';
import 'package:test/test.dart';

bool _isCredentialKey(String key) => key.startsWith('auth.');

DateTime _at(int minute) => DateTime.utc(2026, 10, 10, 12, minute);

final class _Remote implements RemoteStore {
  _Remote({this.batch = const <SyncRecord>[], this.next = const SyncCursor('page-2')});

  final List<SyncRecord> batch;
  final SyncCursor next;

  final List<List<SyncRecord>> pushCalls = <List<SyncRecord>>[];
  SyncCursor fetchFrom = SyncCursor.start;

  @override
  Future<RemoteBatch> fetchSince(SyncCursor cursor) async {
    fetchFrom = cursor;
    return RemoteBatch(records: batch, cursor: next);
  }

  @override
  Future<SyncCursor> push(List<SyncRecord> records) async {
    pushCalls.add(records);
    // A real remote answers with the position its log reached after taking these rows.
    return const SyncCursor('after-push');
  }
}

final class _Local implements LocalStore {
  _Local([Map<String, SyncRecord>? existing]) : _existing = Map<String, SyncRecord>.of(existing ?? {});

  final Map<String, SyncRecord> _existing;
  final List<SyncRecord> applied = <SyncRecord>[];
  final List<String> marked = <String>[];
  List<SyncRecord> pending = <SyncRecord>[];

  @override
  Future<Map<String, SyncRecord>> readAll() async => Map<String, SyncRecord>.of(_existing);

  @override
  Future<void> apply(List<SyncRecord> records) async {
    applied.addAll(records);
    for (final record in records) {
      _existing[record.key] = record;
    }
  }

  @override
  Future<List<SyncRecord>> pendingChanges() async => pending;

  @override
  Future<void> markPushed(List<String> keys) async {
    marked.addAll(keys);
    // A local store that kept reporting an already-pushed row as pending would re-push it forever, so the
    // fake has to clear it for the idle-push case below to mean what it says.
    pending.removeWhere((record) => keys.contains(record.key));
  }
}

void main() {
  group('test_sync_cursor', () {
    test('test_syncEngine_pull_carriesTheRemoteCursorIntoTheReport', () async {
      final remote = _Remote(
        batch: <SyncRecord>[SyncRecord(key: 'favorites.a', value: 1, updatedAt: _at(0))],
      );
      final local = _Local();
      final engine = SyncEngine(remote: remote, local: local, isCredentialKey: _isCredentialKey);

      final report = await engine.pull();

      expect(report.nextCursor, const SyncCursor('page-2'));
      expect(report.applied, 1);
    });

    test('test_syncEngine_successivePullsDoNotRefetchTheSameHistory', () async {
      final remote = _Remote();
      final local = _Local();
      final engine = SyncEngine(remote: remote, local: local, isCredentialKey: _isCredentialKey);

      var cursor = SyncCursor.start;
      cursor = (await engine.pull(from: cursor)).cursorAfter(cursor);
      expect(cursor, const SyncCursor('page-2'));
      cursor = (await engine.pull(from: cursor)).cursorAfter(cursor);

      expect(remote.fetchFrom, const SyncCursor('page-2'), reason: 'the second pull must not start over');
    });

    test('test_syncEngine_aRemoteThatGivesNoNewCursorIsNotClaimedAsProgress', () async {
      final remote = _Remote(next: SyncCursor.start);
      final engine = SyncEngine(remote: remote, local: _Local(), isCredentialKey: _isCredentialKey);

      final report = await engine.pull(from: SyncCursor.start);

      expect(report.nextCursor, isNull, reason: 'same cursor in, same cursor out is not an advance');
    });

    test('test_syncEngine_push_advancesTheCursorAndIdlePushDoesNotResetIt', () async {
      final local = _Local()..pending = <SyncRecord>[SyncRecord(key: 'history.b', value: 2, updatedAt: _at(1))];
      final engine = SyncEngine(remote: _Remote(), local: local, isCredentialKey: _isCredentialKey);

      var cursor = SyncCursor.start;
      cursor = (await engine.push(known: cursor)).cursorAfter(cursor);
      expect(cursor, const SyncCursor('after-push'));

      // Idle pass: nothing pending, so the held position survives rather than becoming "beginning".
      final idle = await engine.push(known: cursor);
      expect(idle.pushed, 0);
      expect(cursorAfterBoth(cursor, idle), const SyncCursor('after-push'));
    });
  });

  group('test_sync_rejections', () {
    test('test_syncEngine_blankKeysAndCredentialKeys_areCountedSeparately', () async {
      final remote = _Remote(
        batch: <SyncRecord>[
          SyncRecord(key: '   ', value: 1, updatedAt: _at(0)),
          SyncRecord(key: 'auth.token', value: 'secret', updatedAt: _at(0)),
          SyncRecord(key: 'favorites.a', value: 2, updatedAt: _at(0)),
        ],
      );
      final local = _Local();
      final engine = SyncEngine(remote: remote, local: local, isCredentialKey: _isCredentialKey);

      final report = await engine.pull();

      expect(report.rejected, 1);
      expect(report.refusedCredentials, 1);
      expect(report.applied, 1);
      expect(local.applied.single.key, 'favorites.a');
    });

    test('test_syncEngine_aKeyRepeatedInOneBatchKeepsTheLaterRow', () async {
      final remote = _Remote(
        batch: <SyncRecord>[
          SyncRecord(key: 'settings.q', value: 'first', updatedAt: _at(0)),
          SyncRecord(key: 'settings.q', value: 'second', updatedAt: _at(5)),
        ],
      );
      final local = _Local();
      final engine = SyncEngine(remote: remote, local: local, isCredentialKey: _isCredentialKey);

      final report = await engine.pull();

      expect(report.applied, 1);
      expect(report.rejected, 1, reason: 'the collapse is a fact about the remote, worth counting');
      expect(local.applied.single.value, 'second');
    });

    test('test_syncEngine_aBatchOfOnlyUnusableRowsStillReportsProgress', () async {
      final remote = _Remote(
        batch: <SyncRecord>[SyncRecord(key: '', value: 1, updatedAt: _at(0))],
        next: const SyncCursor('page-9'),
      );
      final engine = SyncEngine(remote: remote, local: _Local(), isCredentialKey: _isCredentialKey);

      final report = await engine.pull();

      expect(report.applied, 0);
      expect(
        report.nextCursor,
        const SyncCursor('page-9'),
        reason: 'the remote did move forward even if nothing applied',
      );
    });
  });
}

SyncCursor cursorAfterBoth(SyncCursor current, SyncReport report) => report.cursorAfter(current);
