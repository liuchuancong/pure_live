import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/memory_stores.dart';
import '../support/tls_fixtures.dart';

void main() {
  const deviceA = LanSyncDeviceConfig(
    deviceId: 'device-a',
    deviceName: 'Desktop',
    platform: 'windows',
    appVersion: '4.0.0',
  );
  const security = LanSyncSecurityConfig();
  final identityA = loadTlsIdentity('device_a');
  final identityB = loadTlsIdentity('device_b');
  final secret = List<int>.generate(32, (i) => i * 7 % 256);

  /// Two paired ends over loopback TLS, exactly as a completed pairing
  /// leaves them: the server is device-a, the client device-b; both hold the
  /// same pairing secret, and the client pins device-a's certificate.
  Future<(LanSyncHttpServer, LanSyncHttpClient)> ends({
    String clientId = 'device-b',
    List<int>? clientSecret,
    String? pin,
    bool revokeB = false,
  }) async {
    final serverStore = MemoryLanSyncStore();
    final serverCredentials = MemoryCredentialStore();
    final clientCredentials = MemoryCredentialStore();
    await serverStore.putDeviceTrust(
      DeviceTrust(
        deviceId: 'device-b',
        keyFingerprint: identityB.fingerprint,
        displayName: 'Phone',
        pairedAt: DateTime.utc(2026, 11, 3),
        revoked: revokeB,
      ),
    );
    await serverCredentials.write(SecureKey.peerPairing('device-b'), secret);
    await clientCredentials.write(SecureKey.peerPairing(deviceA.deviceId), clientSecret ?? secret);

    final server = LanSyncHttpServer(
      store: serverStore,
      credentials: serverCredentials,
      deviceConfig: deviceA,
      serverConfig: const LanSyncServerConfig(listenOnAllInterfaces: false),
      tlsIdentity: identityA,
      securityConfig: security,
    );
    await server.start();
    addTearDown(server.dispose);

    final client = LanSyncHttpClient(
      localDeviceId: clientId,
      peerDeviceId: deviceA.deviceId,
      host: '127.0.0.1',
      port: server.port!,
      credentials: clientCredentials,
      pinnedPeerFingerprint: pin ?? identityA.fingerprint,
    );
    addTearDown(client.dispose);
    return (server, client);
  }

  test('hello negotiates the protocol over pinned TLS', () async {
    final (_, client) = await ends();
    final result = await client.hello(local: deviceA);
    expect(result.protocolVersion, LanSyncProtocol.current);
    expect(result.device['deviceId'], deviceA.deviceId);
    expect(result.device['tlsFingerprint'], identityA.fingerprint);
  });

  test('registered routes receive authenticated requests, UTF-8 intact', () async {
    final (server, client) = await ends();
    server.route(
      'POST',
      '/echo',
      (request) async => <String, Object?>{'sender': request.senderDeviceId, 'echo': request.body['message']},
    );
    final answer = await client.invoke('POST', '/echo', body: {'message': '你好'});
    expect(answer['sender'], 'device-b');
    expect(answer['echo'], '你好');
  });

  test('a certificate other than the pinned one is refused before sending', () async {
    final (_, client) = await ends(pin: identityB.fingerprint);
    await expectLater(
      client.device(),
      throwsA(
        isA<LanSyncError>()
            .having((e) => e.category, 'category', LanSyncErrorCategory.identityMismatch)
            .having((e) => e.retryable, 'retryable', isFalse),
      ),
    );
  });

  test('a malformed pin is a configuration error', () {
    expect(
      () => LanSyncHttpClient(
        localDeviceId: 'device-b',
        peerDeviceId: 'device-a',
        host: '127.0.0.1',
        port: 1,
        credentials: MemoryCredentialStore(),
        pinnedPeerFingerprint: 'not-a-fingerprint',
      ),
      throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'pin_invalid')),
    );
  });

  test('an unpaired sender is refused', () async {
    final (_, client) = await ends(clientId: 'ghost');
    await expectLater(client.device(), throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'peer_not_paired')));
  });

  test('a wrong pairing secret fails verification', () async {
    final (_, client) = await ends(clientSecret: List<int>.filled(32, 7));
    await expectLater(
      client.device(),
      throwsA(
        isA<LanSyncError>()
            .having((e) => e.category, 'category', LanSyncErrorCategory.authentication)
            .having((e) => e.code, 'code', 'signature_invalid'),
      ),
    );
  });

  test('a revoked device is refused', () async {
    final (_, client) = await ends(revokeB: true);
    await expectLater(client.device(), throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'peer_not_paired')));
  });

  test('an unsupported protocol version is an explicit conflict', () async {
    final (_, client) = await ends();
    await expectLater(
      client.hello(
        local: const LanSyncDeviceConfig(
          deviceId: 'device-b',
          deviceName: 'Phone',
          platform: 'android',
          appVersion: '4.0.0',
          protocolVersion: 99,
        ),
      ),
      throwsA(isA<LanSyncError>().having((e) => e.category, 'category', LanSyncErrorCategory.protocolIncompatible)),
    );
  });

  test('events reach the connected peer over pinned WSS', () async {
    final (server, client) = await ends();
    final received = <Map<String, Object?>>[];
    final subscription = client.events().listen(received.add);
    addTearDown(subscription.cancel);

    // The socket needs a moment to complete the upgrade before the
    // broadcast fires.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    server.broadcast(<String, Object?>{'type': 'syncStarted', 'taskId': 't-1'});
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(received, isNotEmpty);
    expect(received.first['type'], 'syncStarted');
    expect(received.first['taskId'], 't-1');
  });
}
