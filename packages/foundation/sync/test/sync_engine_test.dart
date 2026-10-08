// Module: test/sync_engine_test.dart
// Purpose: Verify pull and push conflict handling, tombstones and the credential exclusion on both paths.
// Author: liuchuancong
// Created: 2026-10-08
import 'package:pure_live_sync/pure_live_sync.dart';
import 'package:test/test.dart';

bool _isCredentialKey(String key) => key.startsWith('auth.');

final class _Remote implements RemoteStore {
  _Remote({List<SyncRecord> records = const <SyncRecord>[]}) : this.records = records;

  List<SyncRecord> records;
  final List<SyncRecord> pushed = <SyncRecord>[];

  @override
  Future<List<SyncRecord>> fetchSince(SyncCursor cursor) async => records;

  @override
  Future<SyncCursor> push(List<SyncRecord> batch) async {
    pushed.addAll(batch);
    return const SyncCursor('cursor-2');
  }
}

final class _Local implements LocalStore {
  _Local(Map<String, SyncRecord>? existing, {List<SyncRecord>? pending})
      : _existing = Map<String, SyncRecord>.of(existing ?? <String, SyncRecord>{}),
        _pending = pending ?? <SyncRecord>[];


  final Map<String, SyncRecord> _existing;
  final List<SyncRecord> _pending;
  final List<SyncRecord> applied = <SyncRecord>[];
  final List<String> marked = <String>[];

  @override
  Future<List<SyncRecord>> pendingChanges() async => List<SyncRecord>.of(_pending);

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
  Future<void> markPushed(List<String> keys) async => marked.addAll(keys);
}

final _t1 = DateTime.utc(2026, 10, 8, 10);
final _t2 = DateTime.utc(2026, 10, 8, 11);

void main() {
  test('test_syncEngine_pull_appliesUnknownKeys', () async {
    final local = _Local(<String, SyncRecord>{});
    final engine = SyncEngine(
      remote: _Remote(records: <SyncRecord>[
        SyncRecord(key: 'favorites.a', value: 1, updatedAt: _t1),
      ]),
      local: local,
      isCredentialKey: _isCredentialKey,
    );

    final report = await engine.pull();

    expect(report.applied, 1);
    expect(report.conflicts, 0);
    expect(local.applied.single.key, 'favorites.a');
  });

  test('test_syncEngine_pull_newerRemoteWinsAndCountsTheConflict', () async {
    final local = _Local(<String, SyncRecord>{
      'favorites.a': SyncRecord(key: 'favorites.a', value: 'old', updatedAt: _t1),
    });
    final engine = SyncEngine(
      remote: _Remote(records: <SyncRecord>[
        SyncRecord(key: 'favorites.a', value: 'new', updatedAt: _t2),
      ]),
      local: local,
      isCredentialKey: _isCredentialKey,
    );

    final report = await engine.pull();

    expect(report.conflicts, 1);
    expect(local.applied.single.value, 'new');
  });

  test('test_syncEngine_pull_olderRemoteIsIgnored', () async {
    final local = _Local(<String, SyncRecord>{
      'favorites.a': SyncRecord(key: 'favorites.a', value: 'newer', updatedAt: _t2),
    });
    final engine = SyncEngine(
      remote: _Remote(records: <SyncRecord>[
        SyncRecord(key: 'favorites.a', value: 'older', updatedAt: _t1),
      ]),
      local: local,
      isCredentialKey: _isCredentialKey,
    );

    final report = await engine.pull();

    expect(report.applied, 0);
    expect(local.applied, isEmpty);
  });

  test('test_syncEngine_equalTimestamps_goToTheRemote', () async {
    // The other device already applied that version, so accepting it converges instead of diverging.
    final local = _Local(<String, SyncRecord>{
      'favorites.a': SyncRecord(key: 'favorites.a', value: 'remote-copy', updatedAt: _t1),
    });
    final engine = SyncEngine(
      remote: _Remote(records: <SyncRecord>[
        SyncRecord(key: 'favorites.a', value: 'incoming', updatedAt: _t1),
      ]),
      local: local,
      isCredentialKey: _isCredentialKey,
    );

    final report = await engine.pull();

    expect(report.conflicts, 1);
    expect(local.applied.single.value, 'incoming');
  });

  test('test_syncEngine_localWinsPolicy_keepsTheLocalCopy', () async {
    final local = _Local(<String, SyncRecord>{
      'favorites.a': SyncRecord(key: 'favorites.a', value: 'local', updatedAt: _t1),
    });
    final engine = SyncEngine(
      remote: _Remote(records: <SyncRecord>[
        SyncRecord(key: 'favorites.a', value: 'remote', updatedAt: _t2),
      ]),
      local: local,
      isCredentialKey: _isCredentialKey,
      policy: ConflictPolicy.localWins,
    );

    expect((await engine.pull()).applied, 0);
  });

  test('test_syncEngine_tombstonePropagatesAsADeletion', () async {
    final local = _Local(<String, SyncRecord>{
      'playlist.x': SyncRecord(key: 'playlist.x', value: 'alive', updatedAt: _t1),
    });
    final engine = SyncEngine(
      remote: _Remote(records: <SyncRecord>[
        SyncRecord(key: 'playlist.x', deleted: true, updatedAt: _t2),
      ]),
      local: local,
      isCredentialKey: _isCredentialKey,
    );

    await engine.pull();

    expect(local.applied.single.deleted, isTrue);
    expect(local.applied.single.value, isNull);
  });

  test('test_syncEngine_pull_neverAppliesCredentialKeys', () async {
    final local = _Local(<String, SyncRecord>{});
    final engine = SyncEngine(
      remote: _Remote(records: <SyncRecord>[
        SyncRecord(key: 'auth.secret.bilibili', value: 'stolen', updatedAt: _t1),
        SyncRecord(key: 'favorites.ok', value: 1, updatedAt: _t1),
      ]),
      local: local,
      isCredentialKey: _isCredentialKey,
    );

    final report = await engine.pull();

    expect(report.refusedCredentials, 1);
    expect(report.applied, 1);
    expect(local.applied.map((record) => record.key), <String>['favorites.ok']);
  });

  test('test_syncEngine_push_sendsPendingAndMarksThem', () async {
    final remote = _Remote();
    final local = _Local(
      <String, SyncRecord>{},
      pending: <SyncRecord>[
        SyncRecord(key: 'favorites.a', value: 1, updatedAt: _t1),
        SyncRecord(key: 'auth.token', value: 'secret', updatedAt: _t1),
      ],
    );

    final report = await SyncEngine(
      remote: remote,
      local: local,
      isCredentialKey: _isCredentialKey,
    ).push();

    expect(report.pushed, 1);
    expect(report.refusedCredentials, 1);
    expect(remote.pushed.map((record) => record.key), <String>['favorites.a']);
    expect(local.marked, <String>['favorites.a']);
    expect(report.cursor.token, 'cursor-2');
  });

  test('test_syncEngine_push_withNothingPending_returnsStartCursor', () async {
    final report = await SyncEngine(
      remote: _Remote(),
      local: _Local(<String, SyncRecord>{}),
      isCredentialKey: _isCredentialKey,
    ).push();

    expect(report.pushed, 0);
    expect(report.cursor, SyncCursor.start);
  });

  test('test_syncRecord_jsonRoundTrip_keepsTombstoneAndTime', () {
    final record = SyncRecord(key: 'k', value: 5, updatedAt: _t2);

    final decoded = SyncRecord.fromJson(record.toJson());

    expect(decoded.key, 'k');
    expect(decoded.value, 5);
    expect(decoded.updatedAt, _t2);
    expect(decoded.deleted, isFalse);
  });

  test('test_syncRecord_deletedRecordDropsItsValue', () {
    final record = SyncRecord(key: 'k', value: 'gone', deleted: true, updatedAt: _t2);

    expect(record.toJson().containsKey('value'), isFalse);
  });
}
