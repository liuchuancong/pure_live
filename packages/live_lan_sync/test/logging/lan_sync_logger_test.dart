import 'dart:io' show FileSystemException;

import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:live_log/live_log.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';
import '../support/sync_doubles.dart';

void main() {
  group('LanSyncLogger', () {
    test('records land in the host tree under the subsystem categories', () {
      final memory = MemorySink();
      final host = LiveLog.root(sinks: [memory]);
      final logger = LanSyncLogger(
        host.forCategory('lan_sync'),
        config: const LanSyncLoggingConfig(level: LogLevel.debug),
      );

      logger.area(LanSyncLogArea.sync).info('batch applied', fields: {'scope': 'favorites'});
      logger.area(LanSyncLogArea.transfer).debug('chunk received', fields: {'index': 1});

      final categories = memory.records.map((record) => record.category).toList();
      expect(categories, containsAll(['lan_sync.sync', 'lan_sync.transfer']));
    });

    test('child views nest one level deeper', () {
      final memory = MemorySink();
      final logger = LanSyncLogger(LiveLog.root(sinks: [memory]));
      logger.area(LanSyncLogArea.sync).child('favorites').info('hello');

      expect(memory.records.single.category, 'sync.favorites');
    });

    test('the silent logger emits nothing anywhere', () {
      final memory = MemorySink();
      final logger = LanSyncLogger.silent;

      logger.area(LanSyncLogArea.sync).info('invisible');
      logger.area(LanSyncLogArea.sync).child('favorites').error('also invisible');

      expect(memory.records, isEmpty, reason: 'the silent tree has no sinks and builds nothing');
    });

    test('shortFingerprint keeps a readable prefix', () {
      final fingerprint = 'sha256:${'ab' * 32}';
      final short = LanSyncLog.shortFingerprint(fingerprint);
      expect(short, 'sha256:abababababab…');
      expect(short.length, lessThan(fingerprint.length));
      expect(LanSyncLog.shortFingerprint('short'), 'short');
    });

    test('scrub strips file paths from file-system errors', () {
      const error = FileSystemException('Cannot open file', r'C:\Users\x\secret.ttf');
      final scrubbed = LanSyncLog.scrub(error)! as FileSystemException;
      expect(scrubbed.path, '');
      expect(scrubbed.message, 'Cannot open file');
      expect(LanSyncLog.scrub(StateError('plain')), isA<StateError>());
    });
  });

  group('payload discipline through a real sync', () {
    test('payloads never reach the log even when the scope churns', () async {
      final memory = MemorySink();
      final host = LiveLog.root(sinks: [memory], minLevel: LogLevel.debug);
      final logger = LanSyncLogger(
        host.forCategory('lan_sync'),
        config: const LanSyncLoggingConfig(level: LogLevel.debug),
      );

      final storeA = MemoryLanSyncStore();
      final storeB = MemoryLanSyncStore();
      final adapterA = MemoryScopeAdapter();
      final adapterB = MemoryScopeAdapter();
      final engineA = SyncEngine(
        store: storeA,
        localDeviceId: 'device-a',
        adapters: [adapterA],
        logger: logger,
        now: () => DateTime.utc(2026, 11, 3),
        sleep: (_) async {},
      );
      final engineB = SyncEngine(
        store: storeB,
        localDeviceId: 'device-b',
        adapters: [adapterB],
        logger: logger,
        now: () => DateTime.utc(2026, 11, 3),
        sleep: (_) async {},
      );
      for (final (holder, peer) in [(storeA, 'device-b'), (storeB, 'device-a')]) {
        await holder.putDeviceTrust(
          DeviceTrust(
            deviceId: peer,
            keyFingerprint: 'sha256:${'ab' * 32}',
            displayName: peer,
            pairedAt: DateTime.utc(2026, 11, 3),
            readScopes: const {'favorites'},
            writeScopes: const {'favorites'},
          ),
        );
      }

      const secret = 'SECRET-TOKEN-VALUE-42';
      adapterA.entities['x'] = {'title': secret};
      await engineA.recordLocalChange(
        scope: 'favorites',
        entityType: 'favorite',
        entityId: 'x',
        payload: {'title': secret},
      );

      final task = await engineB.synchronize(
        channel: LoopbackChannel(peer: engineA, callerId: 'device-b'),
        scopes: const {'favorites'},
        direction: SyncDirection.pull,
      );
      expect(task.status, SyncTaskStatus.completed);

      final dumped = memory.records.map((record) => '${record.message} ${record.fields}').join('\n');
      expect(dumped, isNot(contains(secret)), reason: 'payloads are business data, never logged');
      expect(dumped, contains('sync finished'));
    });

    test('the log shows lifecycle events with device and counts', () async {
      final memory = MemorySink();
      final host = LiveLog.root(sinks: [memory], minLevel: LogLevel.debug);
      final logger = LanSyncLogger(
        host.forCategory('lan_sync'),
        config: const LanSyncLoggingConfig(level: LogLevel.debug),
      );

      final storeA = MemoryLanSyncStore();
      final storeB = MemoryLanSyncStore();
      final adapterA = MemoryScopeAdapter();
      final adapterB = MemoryScopeAdapter();
      final engineA = SyncEngine(
        store: storeA,
        localDeviceId: 'device-a',
        adapters: [adapterA],
        logger: logger,
        now: () => DateTime.utc(2026, 11, 3),
        sleep: (_) async {},
      );
      final engineB = SyncEngine(
        store: storeB,
        localDeviceId: 'device-b',
        adapters: [adapterB],
        logger: logger,
        now: () => DateTime.utc(2026, 11, 3),
        sleep: (_) async {},
      );
      for (final (holder, peer) in [(storeA, 'device-b'), (storeB, 'device-a')]) {
        await holder.putDeviceTrust(
          DeviceTrust(
            deviceId: peer,
            keyFingerprint: 'sha256:${'ab' * 32}',
            displayName: peer,
            pairedAt: DateTime.utc(2026, 11, 3),
            readScopes: const {'favorites'},
            writeScopes: const {'favorites'},
          ),
        );
      }
      adapterA.entities['x'] = {'title': 'one'};
      await engineA.recordLocalChange(
        scope: 'favorites',
        entityType: 'favorite',
        entityId: 'x',
        payload: {'title': 'one'},
      );

      await engineB.synchronize(
        channel: LoopbackChannel(peer: engineA, callerId: 'device-b'),
        scopes: const {'favorites'},
        direction: SyncDirection.pull,
      );

      final text = memory.records.map((record) => '${record.category} ${record.message} ${record.fields}').join('\n');
      expect(text, contains('sync started'));
      expect(text, contains('batch applied'));
      expect(text, contains('sync finished'));
      expect(text, contains('device: device-a'));
      expect(text, isNot(contains('operationId')), reason: 'no raw change dumps');
    });
  });
}
