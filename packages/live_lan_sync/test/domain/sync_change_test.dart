import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

void main() {
  group('SyncChange', () {
    SyncChange change({SyncOperation operation = SyncOperation.upsert}) {
      final createdAt = DateTime.utc(2026, 11, 1, 12, 30);
      return SyncChange(
        operationId: 'op-1',
        scope: 'favorites',
        entityType: 'favorite',
        entityId: 'room-1',
        originDeviceId: 'device-a',
        operation: operation,
        schemaVersion: 1,
        revision: const VersionVector.empty().incremented('device-a'),
        createdAt: createdAt,
        payload: {'platform': 'huya', 'roomId': '123', 'title': '例子'},
      );
    }

    test('json round trip preserves every field', () {
      final original = change();
      final restored = SyncChange.fromJson(original.toJson());
      expect(restored.operationId, original.operationId);
      expect(restored.scope, original.scope);
      expect(restored.entityType, original.entityType);
      expect(restored.entityId, original.entityId);
      expect(restored.originDeviceId, original.originDeviceId);
      expect(restored.operation, original.operation);
      expect(restored.schemaVersion, original.schemaVersion);
      expect(restored.revision, original.revision);
      expect(restored.createdAt, original.createdAt);
      expect(restored.payload, original.payload);
    });

    test('string encoding round trips', () {
      final original = change();
      final restored = SyncChange.decode(original.encode());
      expect(restored, isA<SyncChange>());
      expect(restored.toJson(), original.toJson());
    });

    test('deletes are tombstones and need no payload', () {
      final tombstone = change(operation: SyncOperation.delete);
      expect(tombstone.isTombstone, isTrue);

      final json = tombstone.toJson()..remove('payload');
      final restored = SyncChange.fromJson(json);
      expect(restored.isTombstone, isTrue);
      expect(restored.payload, isEmpty);
    });

    test('the deduplication key is the operation id', () {
      expect(change().deduplicationKey, 'op-1');
      final copy = SyncChange.fromJson(change().toJson());
      expect(copy.deduplicationKey, change().deduplicationKey);
    });

    test('a non-object payload is rejected loudly', () {
      final json = change().toJson()..['payload'] = 'not-an-object';
      expect(() => SyncChange.fromJson(json), throwsFormatException);
    });
  });

  group('SyncCursor', () {
    test('json round trip and per-peer scoping', () {
      final syncedAt = DateTime.utc(2026, 11, 3);
      final cursor = SyncCursor(
        peerDeviceId: 'device-b',
        scope: 'favorites',
        localCheckpoint: 'op-10',
        remoteCheckpoint: 'op-20',
        lastSuccessfulSyncAt: syncedAt,
      );
      final restored = SyncCursor.fromJson(cursor.toJson());
      expect(restored.peerDeviceId, 'device-b');
      expect(restored.scope, 'favorites');
      expect(restored.localCheckpoint, 'op-10');
      expect(restored.remoteCheckpoint, 'op-20');
      expect(restored.lastSuccessfulSyncAt, syncedAt);
    });

    test('advancing produces a new cursor and keeps the local side', () {
      const cursor = SyncCursor(peerDeviceId: 'device-b', scope: 'favorites', localCheckpoint: 'op-10');
      final advancedAt = DateTime.utc(2026, 11, 4);
      final advanced = cursor.advanced(remoteCheckpoint: 'op-20', at: advancedAt);
      expect(advanced.remoteCheckpoint, 'op-20');
      expect(advanced.localCheckpoint, 'op-10');
      expect(advanced.lastSuccessfulSyncAt, advancedAt);
    });
  });

  group('SyncTask', () {
    test('json round trip preserves fields and enums', () {
      const task = SyncTask(
        taskId: 't-1',
        peerDeviceId: 'device-b',
        direction: SyncDirection.bidirectional,
        scopes: {'favorites', 'settings'},
        status: SyncTaskStatus.transferring,
        stage: SyncTaskStage.changes,
        totalChanges: 10,
        completedChanges: 4,
      );
      final restored = SyncTask.fromJson(task.toJson());
      expect(restored.taskId, 't-1');
      expect(restored.direction, SyncDirection.bidirectional);
      expect(restored.scopes, const {'favorites', 'settings'});
      expect(restored.status, SyncTaskStatus.transferring);
      expect(restored.stage, SyncTaskStage.changes);
      expect(restored.completedChanges, 4);
    });

    test('progress combines changes and bytes', () {
      const task = SyncTask(
        taskId: 't-1',
        peerDeviceId: 'device-b',
        scopes: {'favorites'},
        status: SyncTaskStatus.transferring,
        totalChanges: 10,
        completedChanges: 5,
        totalBytes: 100,
        transferredBytes: 25,
      );
      expect(task.progress, closeTo(0.375, 0.0001));
      expect(task.isActive, isTrue);
    });

    test('finishing marks the terminal state', () {
      final failedAt = DateTime.utc(2026, 11, 3);
      final task = const SyncTask(
        taskId: 't-1',
        peerDeviceId: 'device-b',
        scopes: {'favorites'},
        status: SyncTaskStatus.transferring,
      ).finished(status: SyncTaskStatus.failed, at: failedAt, error: 'peer unreachable');
      expect(task.status, SyncTaskStatus.failed);
      expect(task.isActive, isFalse);
      expect(task.error, 'peer unreachable');
      expect(task.completedAt, failedAt);
    });
  });

  group('LanSyncError', () {
    test('carries its classification and retryability', () {
      const error = LanSyncError(
        category: LanSyncErrorCategory.authentication,
        code: 'session_auth_failed',
        message: 'The device could not be authenticated.',
      );
      expect(error.retryable, isFalse);
      expect(error.toString(), contains('session_auth_failed'));
    });

    test('withTask annotates without mutating', () {
      const error = LanSyncError(
        category: LanSyncErrorCategory.transport,
        code: 'request_failed',
        message: 'The request failed.',
        retryable: true,
      );
      final annotated = error.withTask(taskId: 't-1', stage: 'changes');
      expect(annotated.taskId, 't-1');
      expect(annotated.stage, 'changes');
      expect(error.taskId, isNull);
    });

    test('json form excludes debug context', () {
      const error = LanSyncError(
        category: LanSyncErrorCategory.storage,
        code: 'store_write_failed',
        message: 'Saving the cursor failed.',
        debugContext: r'Hive box path C:\secret\path',
      );
      expect(error.encode(), isNot(contains('secret')));
      expect(error.toJson(), isNot(containsValue(r'Hive box path C:\secret\path')));
    });
  });

  group('DeviceTrust', () {
    DeviceTrust trust() {
      final pairedAt = DateTime.utc(2026, 11, 3);
      return DeviceTrust(
        deviceId: 'device-b',
        keyFingerprint: 'sha256:abc',
        displayName: 'Phone',
        pairedAt: pairedAt,
        readScopes: const {'favorites'},
        writeScopes: const {'favorites', 'settings'},
        filePermissions: const {DeviceFilePermission.send},
      );
    }

    test('json round trip preserves grants', () {
      final restored = DeviceTrust.decode(trust().encode());
      expect(restored.deviceId, 'device-b');
      expect(restored.readScopes, {'favorites'});
      expect(restored.writeScopes, {'favorites', 'settings'});
      expect(restored.allowsSendFiles, isTrue);
      expect(restored.allowsReceiveFiles, isFalse);
      expect(restored.allowsRead('favorites'), isTrue);
      expect(restored.allowsWrite('history'), isFalse);
    });

    test('revocation keeps the record but kills every permission', () {
      final revoked = trust().revoke();
      expect(revoked.revoked, isTrue);
      expect(revoked.allowsRead('favorites'), isFalse);
      expect(revoked.allowsWrite('favorites'), isFalse);
      expect(revoked.allowsSendFiles, isFalse);
      expect(revoked.canInitiateSync, isFalse);
    });

    test('pairing grants no file permissions by default', () {
      final pairedAt = DateTime.utc(2026, 11, 3);
      final plain = DeviceTrust(
        deviceId: 'device-b',
        keyFingerprint: 'sha256:abc',
        displayName: 'Phone',
        pairedAt: pairedAt,
      );
      expect(plain.filePermissions, isEmpty);
      expect(plain.allowsSendFiles, isFalse);
      expect(plain.allowsReceiveFiles, isFalse);
    });
  });

  group('SyncDevice', () {
    test('identity is the device id, addresses merge without duplicating', () {
      const device = SyncDevice(
        deviceId: 'device-b',
        deviceName: 'Phone',
        platform: 'android',
        appVersion: '4.0.0',
        protocolVersion: 1,
        addresses: ['192.168.1.5'],
      );
      final updated = device.mergedWith(
        const SyncDevice(
          deviceId: 'device-b',
          deviceName: 'Phone',
          platform: 'android',
          appVersion: '4.0.0',
          protocolVersion: 1,
          addresses: ['192.168.1.5', '192.168.1.9'],
          port: 46000,
        ),
      );
      expect(updated.addresses, ['192.168.1.5', '192.168.1.9']);
      expect(updated.port, 46000);
      expect(device == updated, isTrue, reason: 'same deviceId is the same device');
    });
  });
}
