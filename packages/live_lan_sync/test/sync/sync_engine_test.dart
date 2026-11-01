import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';
import '../support/sync_doubles.dart';

/// One simulated device: a store, one `favorites` adapter, an engine.
final class _Device {
  new(
    this.id, {
    LanSyncOptions options = const LanSyncOptions(maxRetries: 0),
    MemoryLanSyncStore? store,
    MemoryScopeAdapter? adapter,
  }) : store = store ?? MemoryLanSyncStore(),
       adapter = adapter ?? MemoryScopeAdapter() {
    engine = SyncEngine(
      store: this.store,
      localDeviceId: id,
      adapters: [this.adapter],
      options: options,
      now: () => DateTime.utc(2026, 11, 3, 12),
      sleep: (_) async {},
    );
  }

  final String id;
  final MemoryLanSyncStore store;
  final MemoryScopeAdapter adapter;
  late final SyncEngine engine;

  /// Records an edit the way a host does: business write, then the log.
  Future<void> edit(String entityId, String title) async {
    adapter.entities[entityId] = {'title': title};
    await engine.recordLocalChange(
      scope: 'favorites',
      entityType: 'favorite',
      entityId: entityId,
      payload: {'title': title},
    );
  }

  Future<void> delete(String entityId) async {
    adapter.entities.remove(entityId);
    await engine.recordLocalChange(
      scope: 'favorites',
      entityType: 'favorite',
      entityId: entityId,
      operation: SyncOperation.delete,
    );
  }

  Future<SyncTask> pullFrom(_Device peer, {LoopbackChannel? channel, SyncCancellation? cancellation}) =>
      engine.synchronize(
        channel: channel ?? peer.channelFrom(this),
        scopes: const {'favorites'},
        direction: SyncDirection.pull,
        cancellation: cancellation,
      );

  Future<SyncTask> pushTo(_Device peer, {LoopbackChannel? channel}) => engine.synchronize(
    channel: channel ?? peer.channelFrom(this),
    scopes: const {'favorites'},
    direction: SyncDirection.push,
  );

  /// The channel [caller] uses to reach this device.
  LoopbackChannel channelFrom(_Device caller) => LoopbackChannel(peer: engine, callerId: caller.id);
}

/// [holder]'s trust record about [peer]: what [peer] may read from and
/// write into [holder].
Future<void> _grant(
  _Device holder,
  _Device peer, {
  Set<String> read = const {'favorites'},
  Set<String> write = const {'favorites'},
}) => holder.store.putDeviceTrust(
  DeviceTrust(
    deviceId: peer.id,
    keyFingerprint: 'sha256:${'ab' * 32}',
    displayName: peer.id,
    pairedAt: DateTime.utc(2026, 11, 3),
    readScopes: read,
    writeScopes: write,
  ),
);

Future<void> _pair(_Device a, _Device b) async {
  await _grant(a, b);
  await _grant(b, a);
}

/// A store that loses power once during a batch commit.
final class _CrashingStore extends MemoryLanSyncStore {
  int crashes = 1;

  @override
  Future<void> commitBatch(SyncBatchCommit commit) async {
    if (crashes > 0) {
      crashes--;
      throw StateError('power cut');
    }
    await super.commitBatch(commit);
  }
}

void main() {
  group('pull', () {
    test("brings the other device's changes and relays them", () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      for (final id in ['x', 'y', 'z']) {
        await a.edit(id, 'Room $id');
      }

      final task = await b.pullFrom(a);

      expect(task.status, SyncTaskStatus.completed);
      expect(task.completedChanges, 3);
      expect(b.adapter.entities, {
        'x': {'title': 'Room x'},
        'y': {'title': 'Room y'},
        'z': {'title': 'Room z'},
      });
      final relayed = await b.store.changesAfter(scope: 'favorites', afterSequence: 0, limit: 10);
      expect(relayed, hasLength(3));
      expect(relayed.map((entry) => entry.change.originDeviceId).toSet(), {'device-a'});
    });

    test('repeating a sync applies nothing twice', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'one');
      await a.edit('y', 'two');

      await b.pullFrom(a);
      await b.pullFrom(a);
      await b.pullFrom(a);
      expect(b.adapter.appliedOperationIds, hasLength(2));

      await a.edit('x', 'one, renamed');
      await b.pullFrom(a);
      expect(b.adapter.appliedOperationIds, hasLength(3));
      expect(b.adapter.entities['x'], {'title': 'one, renamed'});
    });

    test('an interrupted sync resumes without losing or repeating anything', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      for (var i = 0; i < 250; i++) {
        await a.edit('room-$i', 'Room $i');
      }
      final channel = a.channelFrom(b)
        ..beforeCall = (route, number) {
          if (route == 'changes/pull' && number == 2) {
            throw const LanSyncError(
              category: LanSyncErrorCategory.deviceUnavailable,
              code: 'peer_unreachable',
              message: 'The Wi-Fi dropped.',
              retryable: true,
            );
          }
        };

      final interrupted = await b.pullFrom(a, channel: channel);
      expect(interrupted.status, SyncTaskStatus.failed);
      expect(b.adapter.entities, hasLength(100), reason: 'the first batch was committed before the drop');
      expect((await b.store.cursorFor(peerDeviceId: 'device-a', scope: 'favorites'))!.remoteCheckpoint, '100');

      channel.beforeCall = null;
      final resumed = await b.pullFrom(a, channel: channel);
      expect(resumed.status, SyncTaskStatus.completed);
      expect(b.adapter.entities, hasLength(250));
      expect(b.adapter.appliedOperationIds, hasLength(250), reason: 'nothing applied twice');
      expect(b.adapter.appliedOperationIds.toSet(), hasLength(250));
    });

    test('retryable failures are retried before the task gives up', () async {
      const options = LanSyncOptions(maxRetries: 2);
      final a = _Device('device-a', options: options);
      final b = _Device('device-b', options: options);
      await _pair(a, b);
      await a.edit('x', 'one');
      final channel = a.channelFrom(b)
        ..beforeCall = (route, number) {
          if (route == 'changes/pull' && number <= 2) {
            throw const LanSyncError(
              category: LanSyncErrorCategory.timeout,
              code: 'timeout',
              message: 'Slow network.',
              retryable: true,
            );
          }
        };

      final task = await b.pullFrom(a, channel: channel);
      expect(task.status, SyncTaskStatus.completed);
      expect(channel.calls['changes/pull'], 3);
      expect(b.adapter.entities, hasLength(1));
    });

    test('a crash between applying and committing loses nothing', () async {
      final a = _Device('device-a');
      final b = _Device('device-b', store: _CrashingStore());
      await _pair(a, b);
      for (final id in ['x', 'y', 'z']) {
        await a.edit(id, 'Room $id');
      }

      final crashed = await b.pullFrom(a);
      expect(crashed.status, SyncTaskStatus.failed);
      expect(crashed.error, contains('store_commit_failed'));
      expect(await b.store.cursorFor(peerDeviceId: 'device-a', scope: 'favorites'), isNull);

      final recovered = await b.pullFrom(a);
      expect(recovered.status, SyncTaskStatus.completed);
      expect(b.adapter.entities, hasLength(3), reason: 're-application after the crash is idempotent');
      final appliedAfterRecovery = b.adapter.appliedOperationIds.length;

      await b.pullFrom(a);
      expect(b.adapter.appliedOperationIds, hasLength(appliedAfterRecovery), reason: 'committed now, never again');
    });

    test('a change the adapter refuses stops the cursor right before it', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'one');
      await a.edit('y', 'two');
      await a.edit('z', 'three');
      b.adapter.refuseEntityIds.add('y');

      final partial = await b.pullFrom(a);
      expect(partial.status, SyncTaskStatus.partiallyCompleted);
      expect(partial.error, contains('could not be applied'));
      expect(b.adapter.entities.keys, unorderedEquals(['x', 'z']));
      expect((await b.store.cursorFor(peerDeviceId: 'device-a', scope: 'favorites'))!.remoteCheckpoint, '1');

      b.adapter.refuseEntityIds.clear();
      final retried = await b.pullFrom(a);
      expect(retried.status, SyncTaskStatus.completed);
      expect(b.adapter.entities.keys, unorderedEquals(['x', 'y', 'z']));
      expect(b.adapter.appliedOperationIds, hasLength(3), reason: 'z was committed the first time');
    });

    test('batches stay within the byte budget', () async {
      const options = LanSyncOptions(maxRetries: 0, maxBatchBytes: 16 * 1024);
      final a = _Device('device-a', options: options);
      final b = _Device('device-b', options: options);
      await _pair(a, b);
      final bulky = 'x' * 5000;
      for (var i = 0; i < 10; i++) {
        await a.edit('room-$i', bulky);
      }
      final channel = a.channelFrom(b);

      final task = await b.pullFrom(a, channel: channel);
      expect(task.status, SyncTaskStatus.completed);
      expect(b.adapter.entities, hasLength(10));
      expect(channel.calls['changes/pull'], greaterThanOrEqualTo(4));
    });

    test('cancellation stops at a batch boundary and keeps the progress', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      for (var i = 0; i < 250; i++) {
        await a.edit('room-$i', 'Room $i');
      }
      final cancellation = SyncCancellation();
      final channel = a.channelFrom(b)
        ..beforeCall = (route, number) {
          if (route == 'changes/pull' && number == 2) cancellation.cancel();
        };

      final task = await b.pullFrom(a, channel: channel, cancellation: cancellation);
      expect(task.status, SyncTaskStatus.cancelled);
      expect(b.adapter.entities, hasLength(200), reason: 'the batch in flight completes and commits');
      expect((await b.store.cursorFor(peerDeviceId: 'device-a', scope: 'favorites'))!.remoteCheckpoint, '200');
    });
  });

  group('deletes and causality', () {
    test('a delete propagates as a tombstone', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'one');
      await b.pullFrom(a);
      expect(b.adapter.entities.containsKey('x'), isTrue);

      await a.delete('x');
      await b.pullFrom(a);
      expect(b.adapter.entities.containsKey('x'), isFalse);
      final tombstone = await b.store.latestChange(scope: 'favorites', entityId: 'x');
      expect(tombstone!.change.isTombstone, isTrue);
    });

    test('an edit made before a delete arrived is a conflict, not a resurrection', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      final c = _Device('device-c');
      await _pair(a, b);
      await _pair(a, c);
      await _pair(b, c);
      await a.edit('x', 'one');
      await b.pullFrom(a);
      await c.pullFrom(a);

      await c.edit('x', 'edited on c');
      await a.delete('x');
      await b.pullFrom(a);
      expect(b.adapter.entities.containsKey('x'), isFalse);

      await c.pushTo(b);
      expect(b.adapter.entities.containsKey('x'), isFalse, reason: 'never silently resurrected');
      final conflict = (await b.store.pendingConflicts()).single;
      expect(conflict.key, 'favorites/x');
      expect(conflict.local.isTombstone, isTrue);
      expect(conflict.remote.payload['title'], 'edited on c');
    });

    test('an older version of an entity is skipped as stale', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      final c = _Device('device-c');
      await _pair(a, b);
      await _pair(b, c);
      await a.edit('x', 'one');
      await a.delete('x');
      await b.pullFrom(a);

      final forged = SyncChange(
        operationId: 'forged-1',
        scope: 'favorites',
        entityType: 'favorite',
        entityId: 'x',
        originDeviceId: 'device-a',
        operation: SyncOperation.upsert,
        schemaVersion: 1,
        revision: VersionVector(const {'device-a': 1}),
        createdAt: DateTime.utc(2026),
        payload: const {'title': 'zombie'},
      );
      final answer = await b.engine.handlePush(
        PeerRequest(
          senderDeviceId: 'device-c',
          path: 'changes/push',
          body: {
            'scope': 'favorites',
            'after': 0,
            'through': 1,
            'changes': [LoggedChange(sequence: 1, change: forged).toJson()],
          },
        ),
      );
      expect(answer['stale'], 1);
      expect(b.adapter.entities.containsKey('x'), isFalse);
    });

    test('concurrent edits are kept as a conflict, never overwritten', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'original');
      await b.pullFrom(a);

      await a.edit('x', 'edited on a');
      await b.edit('x', 'edited on b');
      final task = await b.pullFrom(a);

      expect(task.status, SyncTaskStatus.completed);
      expect(b.adapter.entities['x'], {'title': 'edited on b'});
      final conflict = (await b.store.pendingConflicts()).single;
      expect(conflict.relation, VersionRelation.concurrent);
      expect(conflict.local.payload['title'], 'edited on b');
      expect(conflict.remote.payload['title'], 'edited on a');
    });

    test('local edits advance the entity version for this device', () async {
      final a = _Device('device-a');
      await a.edit('x', 'one');
      await a.edit('x', 'two');
      final latest = await a.store.latestChange(scope: 'favorites', entityId: 'x');
      expect(latest!.change.revision['device-a'], 2);
      expect(await a.store.latestSequence(scope: 'favorites'), 2);
      expect(await a.store.changesAfter(scope: 'favorites', afterSequence: 0, limit: 10), hasLength(1));
    });
  });

  group('push and relay', () {
    test('push sends local changes and only once', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await b.edit('x', 'one');
      await b.edit('y', 'two');
      final channel = a.channelFrom(b);

      final task = await b.pushTo(a, channel: channel);
      expect(task.status, SyncTaskStatus.completed);
      expect(a.adapter.entities.keys, unorderedEquals(['x', 'y']));
      expect((await b.store.cursorFor(peerDeviceId: 'device-a', scope: 'favorites'))!.localCheckpoint, '2');

      await b.pushTo(a, channel: channel);
      expect(channel.calls['changes/push'], 1, reason: 'nothing new to send');
    });

    test('changes never echo back to the device they came from', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'one');
      await a.edit('y', 'two');
      await b.pullFrom(a);
      final channel = a.channelFrom(b);

      final task = await b.pushTo(a, channel: channel);
      expect(task.status, SyncTaskStatus.completed);
      expect(channel.calls['changes/push'], isNull);
      expect(
        (await b.store.cursorFor(peerDeviceId: 'device-a', scope: 'favorites'))!.localCheckpoint,
        '${await b.store.latestSequence(scope: 'favorites')}',
      );
    });

    test('changes relay across devices', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      final c = _Device('device-c');
      await _pair(a, b);
      await _pair(b, c);
      await a.edit('x', 'from a');

      await b.pullFrom(a);
      await c.pullFrom(b);
      expect(c.adapter.entities['x'], {'title': 'from a'});
      final entry = await c.store.latestChange(scope: 'favorites', entityId: 'x');
      expect(entry!.change.originDeviceId, 'device-a');
    });

    test('a two-way sync exchanges both directions in one task', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'from a');
      await b.edit('y', 'from b');

      final task = await b.engine.synchronize(channel: a.channelFrom(b), scopes: const {'favorites'});
      expect(task.status, SyncTaskStatus.completed);
      expect(a.adapter.entities.keys, unorderedEquals(['x', 'y']));
      expect(b.adapter.entities.keys, unorderedEquals(['x', 'y']));
    });

    test('a receiver that lost track rewinds the sender, which resends', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await b.edit('x', 'one');
      await b.edit('y', 'two');
      final channel = a.channelFrom(b);
      await b.pushTo(a, channel: channel);

      // device-a restores an older backup: its cursor for device-b is gone.
      await a.store.saveCursor(const SyncCursor(peerDeviceId: 'device-b', scope: 'favorites'));
      await b.edit('z', 'three');

      final task = await b.pushTo(a, channel: channel);
      expect(task.status, SyncTaskStatus.completed);
      expect(a.adapter.entities.keys, unorderedEquals(['x', 'y', 'z']));
      expect(a.adapter.appliedOperationIds, hasLength(3), reason: 'resent changes were deduplicated');
    });
  });

  group('negotiation and grants', () {
    test('a scope the other device does not share is reported, not fetched', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _grant(a, b, read: const {});
      await _grant(b, a);

      final task = await b.pullFrom(a);
      expect(task.status, SyncTaskStatus.partiallyCompleted);
      expect(task.error, contains('does not share it'));
    });

    test("this device's own grant gates what flows in", () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _grant(a, b);
      await _grant(b, a, write: const {});
      await a.edit('x', 'one');

      final task = await b.pullFrom(a);
      expect(task.status, SyncTaskStatus.partiallyCompleted);
      expect(task.error, contains('does not accept'));
      expect(b.adapter.entities, isEmpty);
    });

    test('the server refuses an ungranted pull on its own', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _grant(a, b, read: const {});
      await expectLater(
        a.engine.handlePull(
          const PeerRequest(senderDeviceId: 'device-b', path: 'changes/pull', body: {'scope': 'favorites', 'after': 0}),
        ),
        throwsA(isA<LanSyncError>().having((e) => e.category, 'category', LanSyncErrorCategory.permissionDenied)),
      );
    });

    test('an unpaired device gets nothing', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      final task = await b.pullFrom(a);
      expect(task.status, SyncTaskStatus.failed);
      expect(task.error, contains('peer_not_paired'));
    });

    test('a schema mismatch skips the scope explicitly', () async {
      final a = _Device('device-a');
      final b = _Device('device-b', adapter: MemoryScopeAdapter(schemaVersion: 2));
      await _pair(a, b);
      await a.edit('x', 'one');

      final task = await b.pullFrom(a);
      expect(task.status, SyncTaskStatus.partiallyCompleted);
      expect(task.error, contains('schema version 2 here, 1 there'));
      expect(b.adapter.entities, isEmpty);
    });

    test('an out-of-order batch is refused whole', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await b.edit('x', 'one');
      await b.edit('y', 'two');
      final entries = await b.store.changesAfter(scope: 'favorites', afterSequence: 0, limit: 10);
      await expectLater(
        a.engine.handlePush(
          PeerRequest(
            senderDeviceId: 'device-b',
            path: 'changes/push',
            body: {
              'scope': 'favorites',
              'after': 0,
              'through': 2,
              'changes': [for (final entry in entries.reversed) entry.toJson()],
            },
          ),
        ),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'batch_out_of_order')),
      );
      expect(a.adapter.entities, isEmpty);
    });
  });

  group('recording and tasks', () {
    test('recording validates its input', () async {
      final a = _Device('device-a');
      final noDeletes = _Device(
        'device-n',
        adapter: MemoryScopeAdapter(
          capabilities: const ScopeSyncCapabilities(
            supportsDelete: false,
            supportsBidirectional: true,
            supportsMerge: false,
          ),
        ),
      );
      expect(
        () => a.engine.recordLocalChange(scope: 'history', entityType: 'entry', entityId: 'x'),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'scope_unknown')),
      );
      expect(
        () => a.engine.recordLocalChange(
          scope: 'favorites',
          entityType: 'favorite',
          entityId: 'x',
          payload: {'when': DateTime.utc(2026)},
        ),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'payload_not_json')),
      );
      expect(
        () => noDeletes.engine.recordLocalChange(
          scope: 'favorites',
          entityType: 'favorite',
          entityId: 'x',
          operation: SyncOperation.delete,
        ),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'delete_unsupported')),
      );
    });

    test('tasks are persisted and published as they progress', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'one');
      final statuses = <SyncTaskStatus>[];
      final subscription = b.engine.taskUpdates.listen((task) => statuses.add(task.status));
      addTearDown(subscription.cancel);

      final task = await b.pullFrom(a);
      await Future<void>.delayed(Duration.zero);

      expect(statuses.first, SyncTaskStatus.connecting);
      expect(statuses.last, SyncTaskStatus.completed);
      final stored = await b.store.task(task.taskId);
      expect(stored!.status, SyncTaskStatus.completed);
      expect(stored.completedChanges, 1);
      expect(stored.completedAt, isNotNull);
    });

    test('two adapters for one scope are a configuration error', () {
      expect(
        () => SyncEngine(
          store: MemoryLanSyncStore(),
          localDeviceId: 'device-a',
          adapters: [MemoryScopeAdapter(), MemoryScopeAdapter()],
        ),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'scope_registered_twice')),
      );
    });
  });
}
