import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';
import '../support/sync_doubles.dart';

const _allPolicies = ScopeSyncCapabilities(
  supportsDelete: true,
  supportsBidirectional: true,
  supportsMerge: true,
  supportedPolicies: {
    ConflictPolicy.preferLocal,
    ConflictPolicy.preferRemote,
    ConflictPolicy.merge,
    ConflictPolicy.keepBoth,
  },
);

/// One simulated device whose events are recorded.
final class _Device {
  new(this.id, {ConflictPolicy? policy, ScopeSyncCapabilities capabilities = _allPolicies, int vectorCap = 32})
    : adapter = MemoryScopeAdapter(capabilities: capabilities) {
    engine = SyncEngine(
      store: store,
      localDeviceId: id,
      adapters: [adapter],
      options: LanSyncOptions(
        maxRetries: 0,
        maxVersionVectorEntries: vectorCap,
        scopeConflictPolicies: {'favorites': ?policy},
      ),
      now: () => DateTime.utc(2026, 11, 3, 12),
      sleep: (_) async {},
    );
    engine.events.listen(events.add);
  }

  final String id;
  final MemoryLanSyncStore store = MemoryLanSyncStore();
  final MemoryScopeAdapter adapter;
  final List<LanSyncEvent> events = <LanSyncEvent>[];
  late final SyncEngine engine;

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

  Future<SyncTask> syncWith(_Device peer, {SyncDirection direction = SyncDirection.bidirectional}) =>
      engine.synchronize(
        channel: LoopbackChannel(peer: peer.engine, callerId: id),
        scopes: const {'favorites'},
        direction: direction,
      );

  String? title(String entityId) => adapter.entities[entityId]?['title'] as String?;
}

Future<void> _pair(_Device a, _Device b) async {
  for (final (holder, peer) in [(a, b), (b, a)]) {
    await holder.store.putDeviceTrust(
      DeviceTrust(
        deviceId: peer.id,
        keyFingerprint: 'sha256:${'ab' * 32}',
        displayName: peer.id,
        pairedAt: DateTime.utc(2026, 11, 3),
        readScopes: const {'favorites'},
        writeScopes: const {'favorites'},
      ),
    );
  }
}

/// Both devices hold `x` = "original", then each edits it without seeing
/// the other's edit.
Future<(_Device, _Device)> _concurrentEdits({ConflictPolicy? policyA, ConflictPolicy? policyB}) async {
  final a = _Device('device-a', policy: policyA);
  final b = _Device('device-b', policy: policyB);
  await _pair(a, b);
  await a.edit('x', 'original');
  await b.syncWith(a, direction: SyncDirection.pull);
  await a.edit('x', 'edited on a');
  await b.edit('x', 'edited on b');
  return (a, b);
}

Future<void> _settled() => Future<void>.delayed(Duration.zero);

void main() {
  group('identical concurrent versions', () {
    test('converge without a conflict, and later edits stay clean', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'same');
      await b.edit('x', 'same');

      final task = await b.syncWith(a, direction: SyncDirection.pull);
      expect(task.status, SyncTaskStatus.completed);
      expect(await b.engine.pendingConflicts(), isEmpty);
      final joined = (await b.store.latestChange(scope: 'favorites', entityId: 'x'))!.change;
      expect(joined.operationId, startsWith('join/'));
      expect(joined.revision['device-a'], 1);
      expect(joined.revision['device-b'], 1);

      await b.edit('x', 'next');
      await a.syncWith(b, direction: SyncDirection.pull);
      expect(await a.engine.pendingConflicts(), isEmpty, reason: 'no false conflict after the join');
      expect(a.title('x'), 'next');
    });

    test('concurrent deletes converge', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'original');
      await b.syncWith(a, direction: SyncDirection.pull);
      await a.delete('x');
      await b.delete('x');

      await b.syncWith(a);
      expect(await a.engine.pendingConflicts(), isEmpty);
      expect(await b.engine.pendingConflicts(), isEmpty);
    });

    test('joins made on both devices at once carry one id and deduplicate', () async {
      final a = _Device('device-a');
      final b = _Device('device-b');
      await _pair(a, b);
      await a.edit('x', 'same');
      await b.edit('x', 'same');
      final fromA = (await a.store.changesAfter(scope: 'favorites', afterSequence: 0, limit: 1)).single;
      final fromB = (await b.store.changesAfter(scope: 'favorites', afterSequence: 0, limit: 1)).single;

      // Both directions in flight at once: each device joins on its own.
      PeerRequest push(String sender, LoggedChange entry) => PeerRequest(
        senderDeviceId: sender,
        path: 'changes/push',
        body: {
          'scope': 'favorites',
          'after': 0,
          'through': entry.sequence,
          'changes': [entry.toJson()],
        },
      );
      await a.engine.handlePush(push('device-b', fromB));
      await b.engine.handlePush(push('device-a', fromA));
      final onA = (await a.store.latestChange(scope: 'favorites', entityId: 'x'))!.change;
      final onB = (await b.store.latestChange(scope: 'favorites', entityId: 'x'))!.change;
      expect(onA.operationId, startsWith('join/'));
      expect(onA.operationId, onB.operationId, reason: 'the same pair always joins to the same id');
      expect(onA.originDeviceId, isNot(onB.originDeviceId));

      final appliedOnA = a.adapter.appliedOperationIds.length;
      final appliedOnB = b.adapter.appliedOperationIds.length;
      await a.syncWith(b);
      await b.syncWith(a);
      expect(a.adapter.appliedOperationIds, hasLength(appliedOnA), reason: 'the joins meet and stop');
      expect(b.adapter.appliedOperationIds, hasLength(appliedOnB));
      expect(await a.engine.pendingConflicts(), isEmpty);
      expect(await b.engine.pendingConflicts(), isEmpty);
    });
  });

  group('policies', () {
    test('manual records, reports and leaves both versions alone', () async {
      final (a, b) = await _concurrentEdits();
      await b.syncWith(a, direction: SyncDirection.pull);
      await _settled();

      expect(b.title('x'), 'edited on b', reason: 'never silently overwritten');
      expect(await b.engine.pendingConflicts(), hasLength(1));
      final detected = b.events.whereType<SyncConflictDetected>().single;
      expect(detected.policy, ConflictPolicy.manual);
      expect(b.events.whereType<SyncConflictResolved>(), isEmpty);
    });

    test('preferLocal keeps this device and brings the other one along', () async {
      final (a, b) = await _concurrentEdits(policyB: ConflictPolicy.preferLocal);
      final task = await b.syncWith(a);
      await _settled();

      expect(task.status, SyncTaskStatus.completed);
      expect(b.title('x'), 'edited on b');
      expect(a.title('x'), 'edited on b', reason: 'the resolution follows both versions, so a adopts it');
      expect(await a.engine.pendingConflicts(), isEmpty);
      expect(await b.engine.pendingConflicts(), isEmpty);
      final resolved = b.events.whereType<SyncConflictResolved>().single;
      expect(resolved.automatic, isTrue);
      expect(resolved.resolution, isA<UseLocalResolution>());
    });

    test('preferRemote adopts the other device', () async {
      final (a, b) = await _concurrentEdits(policyB: ConflictPolicy.preferRemote);
      await b.syncWith(a);

      expect(b.title('x'), 'edited on a');
      expect(a.title('x'), 'edited on a');
      expect(await b.engine.pendingConflicts(), isEmpty);
    });

    test('merge asks the adapter and spreads the merged state', () async {
      final (a, b) = await _concurrentEdits(policyB: ConflictPolicy.merge);
      b.adapter.resolver = (local, remote) {
        final titles = [local.payload['title']! as String, remote.payload['title']! as String]..sort();
        return MergedResolution({'title': titles.join(' + ')});
      };
      await b.syncWith(a);

      expect(b.title('x'), 'edited on a + edited on b');
      expect(a.title('x'), 'edited on a + edited on b');
    });

    test('keepBoth keeps the other version under the id the adapter chose', () async {
      final (a, b) = await _concurrentEdits(policyB: ConflictPolicy.keepBoth);
      b.adapter.resolver = (local, remote) => KeepBothResolution(
        copyEntityId: '${remote.entityId}~${remote.originDeviceId}',
        localPayload: local.payload,
        remotePayload: remote.payload,
      );
      await b.syncWith(a);

      expect(b.title('x'), 'edited on b');
      expect(b.title('x~device-a'), 'edited on a');
      expect(a.title('x'), 'edited on b');
      expect(a.title('x~device-a'), 'edited on a');
    });

    test('an adapter that escalates leaves the conflict for the user', () async {
      final (a, b) = await _concurrentEdits(policyB: ConflictPolicy.merge);
      await b.syncWith(a, direction: SyncDirection.pull);
      await _settled();

      expect(await b.engine.pendingConflicts(), hasLength(1));
      expect(b.events.whereType<SyncConflictDetected>().single.policy, ConflictPolicy.merge);
      expect(b.events.whereType<SyncConflictResolved>(), isEmpty);
    });

    test('a policy the adapter does not honour falls back to manual', () async {
      final a = _Device('device-a');
      final b = _Device(
        'device-b',
        policy: ConflictPolicy.preferRemote,
        capabilities: const ScopeSyncCapabilities(
          supportsDelete: true,
          supportsBidirectional: true,
          supportsMerge: false,
        ),
      );
      await _pair(a, b);
      await a.edit('x', 'original');
      await b.syncWith(a, direction: SyncDirection.pull);
      await a.edit('x', 'edited on a');
      await b.edit('x', 'edited on b');

      await b.syncWith(a, direction: SyncDirection.pull);
      await _settled();
      expect(b.title('x'), 'edited on b');
      expect(b.events.whereType<SyncConflictDetected>().single.policy, ConflictPolicy.manual);
    });

    test('two devices that both prefer themselves still converge', () async {
      final (a, b) = await _concurrentEdits(policyA: ConflictPolicy.preferLocal, policyB: ConflictPolicy.preferLocal);
      await b.syncWith(a);
      await a.syncWith(b);

      expect(a.title('x'), b.title('x'), reason: 'the first decision written wins everywhere');
      expect(await a.engine.pendingConflicts(), isEmpty);
      expect(await b.engine.pendingConflicts(), isEmpty);
    });

    test('merge declared without merge support is a configuration error', () {
      expect(
        () => SyncEngine(
          store: MemoryLanSyncStore(),
          localDeviceId: 'device-a',
          adapters: [
            MemoryScopeAdapter(
              capabilities: const ScopeSyncCapabilities(
                supportsDelete: true,
                supportsBidirectional: true,
                supportsMerge: false,
                supportedPolicies: {ConflictPolicy.merge},
              ),
            ),
          ],
        ),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'merge_without_support')),
      );
    });
  });

  group('the user decides', () {
    test('a manual decision is applied, logged, and wins everywhere', () async {
      final (a, b) = await _concurrentEdits();
      await b.syncWith(a, direction: SyncDirection.pull);
      final conflict = (await b.engine.pendingConflicts()).single;

      await b.engine.resolveConflict(conflict.key, const UseRemoteResolution());
      await _settled();
      expect(b.title('x'), 'edited on a');
      expect(await b.engine.pendingConflicts(), isEmpty);
      final resolved = b.events.whereType<SyncConflictResolved>().single;
      expect(resolved.automatic, isFalse);

      await b.syncWith(a, direction: SyncDirection.push);
      expect(await a.engine.pendingConflicts(), isEmpty, reason: 'the decision follows both versions');
      expect(a.title('x'), 'edited on a');

      await a.edit('x', 'later on a');
      await b.syncWith(a, direction: SyncDirection.pull);
      expect(b.title('x'), 'later on a');
      expect(await b.engine.pendingConflicts(), isEmpty);
    });

    test('a decision taken after the local version moved on asks for a fresh look', () async {
      final (a, b) = await _concurrentEdits();
      await b.syncWith(a, direction: SyncDirection.pull);
      final key = (await b.engine.pendingConflicts()).single.key;
      await b.edit('x', 'edited on b again');

      await expectLater(
        b.engine.resolveConflict(key, const UseRemoteResolution()),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'conflict_outdated')),
      );
      final refreshed = (await b.engine.pendingConflicts()).single;
      expect(refreshed.local.payload['title'], 'edited on b again');

      await b.engine.resolveConflict(key, const UseLocalResolution());
      expect(b.title('x'), 'edited on b again');
      expect(await b.engine.pendingConflicts(), isEmpty);
    });

    test('a conflict another device settled first is superseded', () async {
      final (a, b) = await _concurrentEdits();
      await b.syncWith(a, direction: SyncDirection.pull);
      expect(await b.engine.pendingConflicts(), hasLength(1));

      // device-a sees the same conflict and decides first.
      await a.syncWith(b, direction: SyncDirection.pull);
      final onA = (await a.engine.pendingConflicts()).single;
      await a.engine.resolveConflict(onA.key, const UseLocalResolution());

      await b.syncWith(a, direction: SyncDirection.pull);
      await _settled();
      expect(b.title('x'), 'edited on a');
      expect(await b.engine.pendingConflicts(), isEmpty);
      expect(b.events.whereType<SyncConflictSuperseded>(), hasLength(1));
    });

    test('unknown keys and escalations are refused', () async {
      final (a, b) = await _concurrentEdits();
      await b.syncWith(a, direction: SyncDirection.pull);
      final key = (await b.engine.pendingConflicts()).single.key;

      await expectLater(
        b.engine.resolveConflict('favorites/nope', const UseLocalResolution()),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'conflict_unknown')),
      );
      await expectLater(
        b.engine.resolveConflict(key, const EscalateResolution()),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'conflict_needs_decision')),
      );
      expect(await b.engine.pendingConflicts(), hasLength(1));
    });
  });

  group('version vectors', () {
    test('stay within the cap, dropping only devices no longer trusted', () async {
      final a = _Device('device-a');
      final b = _Device('device-b', vectorCap: 3);
      await _pair(a, b);
      final crowded = SyncChange(
        operationId: 'crowded-1',
        scope: 'favorites',
        entityType: 'favorite',
        entityId: 'x',
        originDeviceId: 'device-a',
        operation: SyncOperation.upsert,
        schemaVersion: 1,
        revision: VersionVector(const {'old-1': 1, 'old-2': 1, 'old-3': 1, 'old-4': 1, 'device-a': 1}),
        createdAt: DateTime.utc(2026),
        payload: const {'title': 'crowded'},
      );
      await b.engine.handlePush(
        PeerRequest(
          senderDeviceId: 'device-a',
          path: 'changes/push',
          body: {
            'scope': 'favorites',
            'after': 0,
            'through': 1,
            'changes': [LoggedChange(sequence: 1, change: crowded).toJson()],
          },
        ),
      );

      await b.edit('x', 'edited on b');
      final revision = (await b.store.latestChange(scope: 'favorites', entityId: 'x'))!.change.revision;
      expect(revision.deviceIds.length, lessThanOrEqualTo(3));
      expect(revision['device-a'], 1, reason: 'trusted devices stay');
      expect(revision['device-b'], 1, reason: 'this device stays');
    });
  });
}
