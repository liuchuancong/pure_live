import 'package:flutter_test/flutter_test.dart';
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/lan_sync/data/drift_lan_sync_store.dart';

import 'support/memory_json_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DriftLanSyncStore store;

  setUp(() async {
    await StoragePrefs.initSeeded(<String, Object?>{});
    store = DriftLanSyncStore(
      logStore: MemoryJsonStore('lan_sync_log'),
      cursorStore: MemoryJsonStore('lan_sync_cursors'),
      processedStore: MemoryJsonStore('lan_sync_processed'),
      taskStore: MemoryJsonStore('lan_sync_tasks'),
      conflictStore: MemoryJsonStore('lan_sync_conflicts'),
      transferStore: MemoryJsonStore('lan_sync_transfers'),
    );
  });

  SyncChange change(String entityId, {String? title, String origin = 'device-a', String? operationId}) {
    final createdAt = DateTime.utc(2026, 11, 3);
    return SyncChange(
      operationId: operationId ?? '$origin-$entityId-1',
      scope: 'favorites',
      entityType: 'favorite',
      entityId: entityId,
      originDeviceId: origin,
      operation: SyncOperation.upsert,
      schemaVersion: 1,
      revision: const VersionVector.empty().incremented(origin),
      createdAt: createdAt,
      payload: {'title': ?title},
    );
  }

  test('records a local change with a growing sequence and processed id', () async {
    final first = await store.recordLocalChange(change('x', title: 'one'));
    final second = await store.recordLocalChange(change('y', title: 'two'));

    expect(first.sequence, 1);
    expect(second.sequence, 2);
    expect((await store.latestChange(scope: 'favorites', entityId: 'x'))!.change.payload, {'title': 'one'});
    expect(await store.latestSequence(scope: 'favorites'), 2);
    expect(await store.changesAfter(scope: 'favorites', afterSequence: 0, limit: 10), hasLength(2));
    expect(await store.hasProcessedOperation(first.change.operationId), isTrue);
  });

  test('re-recording the same entity replaces its entry', () async {
    await store.recordLocalChange(change('x', title: 'one'));
    final replacement = await store.recordLocalChange(change('x', title: 'two', operationId: 'device-a-x-2'));

    expect(replacement.sequence, 2);
    expect(await store.changesAfter(scope: 'favorites', afterSequence: 0, limit: 10), hasLength(1));
    expect((await store.latestChange(scope: 'favorites', entityId: 'x'))!.change.payload, {'title': 'two'});
  });

  test('sequences recover from the log when prefs lose the counter', () async {
    final logStore = MemoryJsonStore('lan_sync_log');
    final seeded = DriftLanSyncStore(
      logStore: logStore,
      cursorStore: MemoryJsonStore('lan_sync_cursors'),
      processedStore: MemoryJsonStore('lan_sync_processed'),
      taskStore: MemoryJsonStore('lan_sync_tasks'),
      conflictStore: MemoryJsonStore('lan_sync_conflicts'),
      transferStore: MemoryJsonStore('lan_sync_transfers'),
    );
    await seeded.recordLocalChange(change('x', title: 'one'));
    await seeded.recordLocalChange(change('y', title: 'two'));

    // A fresh instance over the same log namespace, as after an upgrade
    // that lost the prefs counter: the log's highest sequence wins.
    final reopened = DriftLanSyncStore(
      logStore: logStore,
      cursorStore: MemoryJsonStore('lan_sync_cursors'),
      processedStore: MemoryJsonStore('lan_sync_processed'),
      taskStore: MemoryJsonStore('lan_sync_tasks'),
      conflictStore: MemoryJsonStore('lan_sync_conflicts'),
      transferStore: MemoryJsonStore('lan_sync_transfers'),
    );
    final next = await reopened.recordLocalChange(change('z', title: 'three', operationId: 'device-a-z-1'));

    expect(next.sequence, 3, reason: 'the counter recovers from the log');
    expect(await reopened.latestSequence(scope: 'favorites'), 3);
    expect(await reopened.changesAfter(scope: 'favorites', afterSequence: 0, limit: 10), hasLength(3));
  });

  test('commitBatch applies log, ledger, conflicts and cursor as one step', () async {
    final relayed = [change('x', title: 'from a'), change('y', title: 'from a too')];
    final conflict = SyncConflict(
      scope: 'favorites',
      entityId: 'z',
      local: change('z', title: 'local'),
      remote: change('z', title: 'remote'),
      relation: VersionRelation.concurrent,
    );
    await store.commitBatch(
      SyncBatchCommit(
        peerDeviceId: 'device-a',
        scope: 'favorites',
        relayed: relayed,
        processedOperationIds: {'op-extra'},
        conflicts: [conflict],
        cursor: const SyncCursor(
          peerDeviceId: 'device-a',
          scope: 'favorites',
        ).advanced(remoteCheckpoint: '5', at: DateTime.utc(2026, 11, 3)),
      ),
    );

    expect(await store.latestSequence(scope: 'favorites'), 2);
    expect(await store.hasProcessedOperation('op-extra'), isTrue);
    expect((await store.pendingConflicts()).single.key, 'favorites/z');
    expect((await store.cursorFor(peerDeviceId: 'device-a', scope: 'favorites'))!.remoteCheckpoint, '5');
  });

  test('trust records round trip and revoke keeps the record', () async {
    final trust = DeviceTrust(
      deviceId: 'device-b',
      keyFingerprint: 'sha256:abababababababababababababababababababababababababababababababab',
      displayName: 'Phone',
      pairedAt: DateTime.utc(2026, 11, 3),
      readScopes: {'favorites'},
    );
    await store.putDeviceTrust(trust);
    final loaded = await store.deviceTrust('device-b');
    expect(loaded!.readScopes, {'favorites'});
    expect((await store.loadDeviceTrusts()).single.deviceId, 'device-b');

    await store.putDeviceTrust(trust.revoke());
    expect((await store.deviceTrust('device-b'))!.revoked, isTrue);
    await store.removeDeviceTrust('device-b');
    expect(await store.deviceTrust('device-b'), isNull);
  });

  test('conflict resolution appends the versions and drops the record', () async {
    final conflict = SyncConflict(
      scope: 'favorites',
      entityId: 'x',
      local: change('x', title: 'local'),
      remote: change('x', title: 'remote'),
      relation: VersionRelation.concurrent,
    );
    await store.saveConflict(conflict);
    expect(await store.conflict(conflict.key), isNotNull);

    final merged = SyncChange(
      operationId: 'merged-1',
      scope: 'favorites',
      entityType: 'favorite',
      entityId: 'x',
      originDeviceId: 'device-a',
      operation: SyncOperation.upsert,
      schemaVersion: 1,
      revision: conflict.mergedHead.incremented('device-a'),
      createdAt: DateTime.utc(2026, 11, 3),
      payload: const {'title': 'merged'},
    );
    final entries = await store.commitResolution(conflictKey: conflict.key, changes: [merged]);

    expect(entries.single.sequence, 1);
    expect(await store.conflict(conflict.key), isNull);
    expect(await store.hasProcessedOperation('merged-1'), isTrue);
  });

  test('tasks and transfers round trip', () async {
    final task = SyncTask(
      taskId: 't-1',
      peerDeviceId: 'device-b',
      direction: SyncDirection.pull,
      scopes: const {'favorites'},
      status: SyncTaskStatus.completed,
      completedChanges: 3,
      startedAt: DateTime.utc(2026, 11, 3),
    );
    await store.saveTask(task);
    expect((await store.task('t-1'))!.status, SyncTaskStatus.completed);
    expect(await store.tasks(limit: 5), hasLength(1));

    final manifest = FileManifest(
      fileId: 'font-1',
      category: 'font',
      fileName: 'font.ttf',
      mimeType: 'font/ttf',
      size: 10,
      sha256: 'a' * 64,
      chunkSize: FileManifest.minChunkSize,
      chunkSha256: const <String>[],
    );
    final record = FileTransferRecord(
      transferId: 'tr-1',
      peerDeviceId: 'device-b',
      direction: FileTransferDirection.incoming,
      manifest: manifest,
      status: FileTransferStatus.completed,
      createdAt: DateTime.utc(2026, 11, 3),
      updatedAt: DateTime.utc(2026, 11, 3),
    );
    await store.saveFileTransfer(record);
    expect((await store.fileTransfer('tr-1'))!.status, FileTransferStatus.completed);
    expect(await store.fileTransfers(direction: FileTransferDirection.outgoing), isEmpty);
    await store.removeFileTransfer('tr-1');
    expect(await store.fileTransfer('tr-1'), isNull);
  });
}
