import 'dart:io' show Directory;

import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';
import '../support/sync_doubles.dart';
import '../support/tls_fixtures.dart';

/// One simulated device for the lifecycle test: its own stores, identity,
/// engine and (for the server side) pairing responder.
final class _Device {
  new(this.id, String name, this.identity)
    : store = MemoryLanSyncStore(),
      credentials = MemoryCredentialStore(),
      adapter = MemoryScopeAdapter(),
      logger = LanSyncLogger.silent {
    deviceConfig = LanSyncDeviceConfig(deviceId: id, deviceName: name, platform: 'windows', appVersion: '4.0.0');
    responder = PairingResponder(
      store: store,
      credentials: credentials,
      security: const LanSyncSecurityConfig(),
      deviceConfig: deviceConfig,
      tlsIdentity: identity,
    );
    engine = SyncEngine(
      store: store,
      localDeviceId: id,
      adapters: [adapter],
      options: const LanSyncOptions(maxRetries: 0),
      logger: logger,
    );
    initiator = PairingInitiator(
      store: store,
      credentials: credentials,
      deviceConfig: deviceConfig,
      tlsIdentity: identity,
      pollInterval: const Duration(milliseconds: 50),
    );
  }

  final String id;
  final MemoryLanSyncStore store;
  final MemoryCredentialStore credentials;
  final MemoryScopeAdapter adapter;
  final LanSyncLogger logger;
  final TlsIdentity identity;
  late final LanSyncDeviceConfig deviceConfig;
  late final PairingResponder responder;
  late final SyncEngine engine;
  late final PairingInitiator initiator;
  late final DeviceTrustService trustService = DeviceTrustService(store: store, credentials: credentials);

  LanSyncHttpClient? channel;

  void edit(String entityId, String title) {
    adapter.entities[entityId] = {'title': title};
  }

  Future<void> record(String entityId) => engine.recordLocalChange(
    scope: 'favorites',
    entityType: 'favorite',
    entityId: entityId,
    payload: adapter.entities[entityId] ?? const <String, Object?>{},
  );

  Future<void> dispose() async {
    await channel?.dispose();
    await responder.dispose();
    await engine.dispose();
  }
}

/// The full two-device lifecycle over real TLS: pair through the server's
/// routes, sync favorites with the pairing-derived secret, revoke, and
/// watch every door close. This is the deployment story minus the physical
/// network — the same code both devices run, over loopback instead of
/// Wi-Fi.
void main() {
  late Directory root;
  late _Device a;
  late _Device b;
  late LanSyncHttpServer server;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('lan_sync_lifecycle');
    a = _Device('device-a', 'Desktop', loadTlsIdentity('device_a'));
    b = _Device('device-b', 'Phone', loadTlsIdentity('device_b'));

    server = LanSyncHttpServer(
      store: a.store,
      credentials: a.credentials,
      deviceConfig: a.deviceConfig,
      serverConfig: const LanSyncServerConfig(listenOnAllInterfaces: false),
      tlsIdentity: a.identity,
      pairingResponder: a.responder,
      securityConfig: const LanSyncSecurityConfig(),
      logger: a.logger,
    );
    await server.start();
    a.engine.attachTo(server);
  });

  tearDown(() async {
    await b.channel?.dispose();
    await server.dispose();
    await a.dispose();
    await b.dispose();
    await root.delete(recursive: true);
  });

  test('pair through the routes, sync both ways, then revocation closes every door', () async {
    // 1. A opens its pairing window; B starts the ceremony over TLS.
    a.responder.openPairingWindow();
    final incoming = a.responder.requests.first;
    final outgoing = await b.initiator.begin(host: '127.0.0.1', port: server.port!);
    final request = await incoming;

    // 2. Both screens show the same code; both users confirm.
    expect(request.sas, outgoing.sas);
    final acceptedOnA = a.responder.accept(
      request.sessionId,
      grants: const PairingGrants(readScopes: {'favorites'}, writeScopes: {'favorites'}),
    );
    final outcomeB = await outgoing.confirm(
      grants: const PairingGrants(readScopes: {'favorites'}, writeScopes: {'favorites'}),
    );
    final outcomeA = await acceptedOnA;
    expect(outcomeA, isA<PairingCompleted>());
    expect(outcomeB, isA<PairingCompleted>());

    // 3. B opens the working channel: the pinned certificate is the one the
    // ceremony authenticated, and the request signature key is the secret
    // both sides derived from the code both users compared.
    final trustOnB = (await b.store.deviceTrust(a.id))!;
    b.channel = LanSyncHttpClient(
      localDeviceId: b.id,
      peerDeviceId: a.id,
      host: '127.0.0.1',
      port: server.port!,
      credentials: b.credentials,
      pinnedPeerFingerprint: trustOnB.keyFingerprint,
    );

    a.edit('x', '来自桌面');
    await a.record('x');
    b.edit('y', 'from the phone');
    await b.record('y');

    final task = await b.engine.synchronize(channel: HttpPeerSyncChannel(b.channel!), scopes: const {'favorites'});
    expect(task.status, SyncTaskStatus.completed, reason: task.error);
    expect(a.adapter.entities.keys, unorderedEquals(['x', 'y']));
    expect(b.adapter.entities.keys, unorderedEquals(['x', 'y']));

    // 4. A revokes B (the user un-pairs). B still holds a valid secret and
    // the right fingerprint, but the door is closed at the trust check.
    await a.trustService.revokeDevice(b.id);
    final after = await b.engine.synchronize(channel: HttpPeerSyncChannel(b.channel!), scopes: const {'favorites'});
    expect(after.status, SyncTaskStatus.failed);
    expect(after.error, contains('peer_not_paired'));
  });

  test('a closed window refuses new challenges; the open session still finishes', () async {
    a.responder.openPairingWindow();
    final incoming = a.responder.requests.first;
    final outgoing = await b.initiator.begin(host: '127.0.0.1', port: server.port!);
    final request = await incoming;

    // The running session runs to its end — only NEW challenges are gated.
    a.responder.closePairingWindow();
    await expectLater(
      b.initiator.begin(host: '127.0.0.1', port: server.port!),
      throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'pairing_window_closed')),
    );

    // The established session completes when both users confirm.
    final acceptedOnA = a.responder.accept(request.sessionId);
    final outcome = await outgoing.confirm();
    expect(await acceptedOnA, isA<PairingCompleted>());
    expect(outcome, isA<PairingCompleted>());
  });
}
