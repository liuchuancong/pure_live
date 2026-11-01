import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';
import '../support/sync_doubles.dart';
import '../support/tls_fixtures.dart';

void main() {
  test('two devices sync both ways over pinned TLS and signed requests', () async {
    final identityA = loadTlsIdentity('device_a');
    final identityB = loadTlsIdentity('device_b');
    final secret = List<int>.generate(32, (i) => (i * 13) % 256);
    final pairedAt = DateTime.utc(2026, 11, 3);

    // device-a serves.
    final storeA = MemoryLanSyncStore();
    final credentialsA = MemoryCredentialStore();
    final adapterA = MemoryScopeAdapter();
    await storeA.putDeviceTrust(
      DeviceTrust(
        deviceId: 'device-b',
        keyFingerprint: identityB.fingerprint,
        displayName: 'Phone',
        pairedAt: pairedAt,
        readScopes: const {'favorites'},
        writeScopes: const {'favorites'},
      ),
    );
    await credentialsA.write(SecureKey.peerPairing('device-b'), secret);
    final engineA = SyncEngine(store: storeA, localDeviceId: 'device-a', adapters: [adapterA]);
    final serverA = LanSyncHttpServer(
      store: storeA,
      credentials: credentialsA,
      deviceConfig: const LanSyncDeviceConfig(
        deviceId: 'device-a',
        deviceName: 'Desktop',
        platform: 'windows',
        appVersion: '4.0.0',
      ),
      serverConfig: const LanSyncServerConfig(listenOnAllInterfaces: false),
      tlsIdentity: identityA,
    );
    engineA.attachTo(serverA);
    await serverA.start();
    addTearDown(serverA.dispose);

    // device-b connects.
    final storeB = MemoryLanSyncStore();
    final credentialsB = MemoryCredentialStore();
    final adapterB = MemoryScopeAdapter();
    await storeB.putDeviceTrust(
      DeviceTrust(
        deviceId: 'device-a',
        keyFingerprint: identityA.fingerprint,
        displayName: 'Desktop',
        pairedAt: pairedAt,
        readScopes: const {'favorites'},
        writeScopes: const {'favorites'},
      ),
    );
    await credentialsB.write(SecureKey.peerPairing('device-a'), secret);
    final engineB = SyncEngine(store: storeB, localDeviceId: 'device-b', adapters: [adapterB]);
    final client = LanSyncHttpClient(
      localDeviceId: 'device-b',
      peerDeviceId: 'device-a',
      host: '127.0.0.1',
      port: serverA.port!,
      credentials: credentialsB,
      pinnedPeerFingerprint: identityA.fingerprint,
    );
    addTearDown(client.dispose);
    final channel = HttpPeerSyncChannel(client);

    adapterA.entities['x'] = {'title': '来自桌面'};
    await engineA.recordLocalChange(
      scope: 'favorites',
      entityType: 'favorite',
      entityId: 'x',
      payload: {'title': '来自桌面'},
    );
    adapterB.entities['y'] = {'title': 'from the phone'};
    await engineB.recordLocalChange(
      scope: 'favorites',
      entityType: 'favorite',
      entityId: 'y',
      payload: {'title': 'from the phone'},
    );

    final task = await engineB.synchronize(channel: channel, scopes: const {'favorites'});
    expect(task.status, SyncTaskStatus.completed, reason: task.error);
    expect(adapterA.entities, {
      'x': {'title': '来自桌面'},
      'y': {'title': 'from the phone'},
    });
    expect(adapterB.entities, adapterA.entities);

    final again = await engineB.synchronize(channel: channel, scopes: const {'favorites'});
    expect(again.status, SyncTaskStatus.completed);
    expect(adapterA.appliedOperationIds, hasLength(1));
    expect(adapterB.appliedOperationIds, hasLength(1));
  });
}
