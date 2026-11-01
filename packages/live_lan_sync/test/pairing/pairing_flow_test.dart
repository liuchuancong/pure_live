import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';
import '../support/tls_fixtures.dart';

/// One simulated device: its stores, identity and configuration.
final class _Device {
  new(this.config, this.identity);

  final LanSyncDeviceConfig config;
  final TlsIdentity identity;
  final MemoryLanSyncStore store = MemoryLanSyncStore();
  final MemoryCredentialStore credentials = MemoryCredentialStore();
}

void main() {
  const security = LanSyncSecurityConfig();
  late _Device a;
  late _Device b;
  late PairingResponder responderA;
  late LanSyncHttpServer serverA;
  late PairingInitiator initiatorB;

  setUp(() async {
    a = _Device(
      const LanSyncDeviceConfig(deviceId: 'device-a', deviceName: 'Desktop', platform: 'windows', appVersion: '4.0.0'),
      loadTlsIdentity('device_a'),
    );
    b = _Device(
      const LanSyncDeviceConfig(deviceId: 'device-b', deviceName: 'Phone', platform: 'android', appVersion: '4.0.0'),
      loadTlsIdentity('device_b'),
    );
    responderA = PairingResponder(
      store: a.store,
      credentials: a.credentials,
      security: security,
      deviceConfig: a.config,
      tlsIdentity: a.identity,
    );
    serverA = LanSyncHttpServer(
      store: a.store,
      credentials: a.credentials,
      deviceConfig: a.config,
      serverConfig: const LanSyncServerConfig(listenOnAllInterfaces: false),
      tlsIdentity: a.identity,
      securityConfig: security,
      pairingResponder: responderA,
    );
    await serverA.start();
    initiatorB = PairingInitiator(
      store: b.store,
      credentials: b.credentials,
      deviceConfig: b.config,
      tlsIdentity: b.identity,
      pollInterval: const Duration(milliseconds: 20),
    );
  });

  tearDown(() async {
    await serverA.dispose();
    await responderA.dispose();
  });

  Future<(IncomingPairing, OutgoingPairing)> startPairing() async {
    responderA.openPairingWindow();
    final incoming = responderA.requests.first;
    final outgoing = await initiatorB.begin(host: '127.0.0.1', port: serverA.port!);
    return (await incoming, outgoing);
  }

  test('both screens show the same code; both confirm; both sides trust each other', () async {
    final (incoming, outgoing) = await startPairing();
    expect(incoming.sas, matches(RegExp(r'^\d{6}$')));
    expect(incoming.sas, outgoing.sas, reason: 'without a man in the middle the codes agree');
    expect(incoming.initiator.deviceName, 'Phone');
    expect(outgoing.responder.deviceName, 'Desktop');

    final accepted = responderA.accept(incoming.sessionId, grants: const PairingGrants(readScopes: {'favorites'}));
    final outcomeB = await outgoing.confirm(grants: const PairingGrants(writeScopes: {'favorites'}));
    final outcomeA = await accepted;
    expect(outcomeA, isA<PairingCompleted>());
    expect(outcomeB, isA<PairingCompleted>());

    final trustOnA = (await a.store.deviceTrust('device-b'))!;
    expect(trustOnA.keyFingerprint, b.identity.fingerprint);
    expect(trustOnA.readScopes, {'favorites'});
    expect(trustOnA.writeScopes, isEmpty, reason: 'each side grants only what its own user chose');

    final trustOnB = (await b.store.deviceTrust('device-a'))!;
    expect(trustOnB.keyFingerprint, a.identity.fingerprint);
    expect(trustOnB.writeScopes, {'favorites'});

    final secretOnA = await a.credentials.read(SecureKey.peerPairing('device-b'));
    final secretOnB = await b.credentials.read(SecureKey.peerPairing('device-a'));
    expect(secretOnA, hasLength(32));
    expect(secretOnA, secretOnB, reason: 'both ends derived the same secret without sending it');
    expect(secretOnA!.any((byte) => byte != 0), isTrue, reason: 'the stored copy survives the session wipe');

    // The pairing is immediately usable: pinned TLS plus signed requests.
    final client = LanSyncHttpClient(
      localDeviceId: 'device-b',
      peerDeviceId: 'device-a',
      host: '127.0.0.1',
      port: serverA.port!,
      credentials: b.credentials,
      pinnedPeerFingerprint: trustOnB.keyFingerprint,
    );
    addTearDown(client.dispose);
    expect((await client.device())['deviceId'], 'device-a');
  });

  test('the initiator may confirm first and wait for the other user', () async {
    final (incoming, outgoing) = await startPairing();
    final confirmed = outgoing.confirm();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final outcomeA = await responderA.accept(incoming.sessionId);
    expect(outcomeA, isA<PairingCompleted>());
    expect(await confirmed, isA<PairingCompleted>());
  });

  test('a decline on the responder reaches the initiator', () async {
    final (incoming, outgoing) = await startPairing();
    responderA.reject(incoming.sessionId);
    final outcome = await outgoing.confirm();
    expect(outcome, isA<PairingFailed>());
    expect((outcome as PairingFailed).reason, PairingFailureReason.rejectedByPeer);
    expect(await a.store.deviceTrust('device-b'), isNull);
    expect(await b.store.deviceTrust('device-a'), isNull);
  });

  test('a decline on the initiator reaches the responder', () async {
    final (incoming, outgoing) = await startPairing();
    final accepted = responderA.accept(incoming.sessionId);
    await outgoing.reject();
    final outcome = await accepted;
    expect(outcome, isA<PairingFailed>());
    expect((outcome as PairingFailed).reason, PairingFailureReason.rejectedByPeer);
    expect(await a.store.deviceTrust('device-b'), isNull);
  });

  test('a closed pairing window refuses to start', () async {
    await expectLater(
      initiatorB.begin(host: '127.0.0.1', port: serverA.port!),
      throwsA(
        isA<LanSyncError>()
            .having((e) => e.category, 'category', LanSyncErrorCategory.permissionDenied)
            .having((e) => e.code, 'code', 'pairing_window_closed'),
      ),
    );
  });

  test('a responder claiming another certificate than it serves is caught', () async {
    // The listener presents device-a's certificate while the responder
    // claims device-b's: what a terminating man in the middle would do.
    final impostor = PairingResponder(
      store: a.store,
      credentials: a.credentials,
      security: security,
      deviceConfig: a.config,
      tlsIdentity: b.identity,
    )..openPairingWindow();
    final server = LanSyncHttpServer(
      store: a.store,
      credentials: a.credentials,
      deviceConfig: a.config,
      serverConfig: const LanSyncServerConfig(listenOnAllInterfaces: false),
      tlsIdentity: a.identity,
      pairingResponder: impostor,
    );
    await server.start();
    addTearDown(server.dispose);
    addTearDown(impostor.dispose);

    await expectLater(
      initiatorB.begin(host: '127.0.0.1', port: server.port!),
      throwsA(
        isA<LanSyncError>()
            .having((e) => e.category, 'category', LanSyncErrorCategory.identityMismatch)
            .having((e) => e.code, 'code', 'pairing_certificate_mismatch'),
      ),
    );
  });

  test('re-pairing a known device id with another certificate is refused', () async {
    await a.store.putDeviceTrust(
      DeviceTrust(
        deviceId: 'device-b',
        keyFingerprint: 'sha256:${'01' * 32}',
        displayName: 'Old phone',
        pairedAt: DateTime.utc(2026),
      ),
    );
    final (incoming, outgoing) = await startPairing();
    final accepted = responderA.accept(incoming.sessionId);
    await outgoing.confirm();
    final outcome = await accepted;
    expect(outcome, isA<PairingFailed>());
    expect((outcome as PairingFailed).reason, PairingFailureReason.identityTaken);
    expect((await a.store.deviceTrust('device-b'))!.displayName, 'Old phone', reason: 'never overwritten');
  });
}
