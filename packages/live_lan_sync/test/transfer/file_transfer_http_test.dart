import 'dart:io' show Directory;

import 'package:crypto/crypto.dart' as crypto show sha256;
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

import '../support/file_doubles.dart';
import '../support/memory_stores.dart';
import '../support/tls_fixtures.dart';

void main() {
  test('a file travels over pinned TLS: signed binary chunks, verified, committed', () async {
    final root = Directory.systemTemp.createTempSync('live_lan_sync_http');
    addTearDown(() => root.deleteSync(recursive: true));
    final identityA = loadTlsIdentity('device_a');
    final identityB = loadTlsIdentity('device_b');
    final secret = List<int>.generate(32, (i) => (i * 5 + 3) % 256);
    final pairedAt = DateTime.utc(2026, 11, 3);

    // device-a receives.
    final storeA = MemoryLanSyncStore();
    final credentialsA = MemoryCredentialStore();
    final inbox = DirectoryFileAdapter(Directory('${root.path}/a'));
    await storeA.putDeviceTrust(
      DeviceTrust(
        deviceId: 'device-b',
        keyFingerprint: identityB.fingerprint,
        displayName: 'Phone',
        pairedAt: pairedAt,
        filePermissions: const {DeviceFilePermission.receive},
      ),
    );
    await credentialsA.write(SecureKey.peerPairing('device-b'), secret);
    final receiver = FileReceiver(store: storeA, adapters: [inbox]);
    addTearDown(receiver.dispose);
    final server = LanSyncHttpServer(
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
    receiver.attachTo(server);
    await server.start();
    addTearDown(server.dispose);

    // device-b sends.
    final storeB = MemoryLanSyncStore();
    final credentialsB = MemoryCredentialStore();
    final outbox = DirectoryFileAdapter(Directory('${root.path}/b'));
    await storeB.putDeviceTrust(
      DeviceTrust(
        deviceId: 'device-a',
        keyFingerprint: identityA.fingerprint,
        displayName: 'Desktop',
        pairedAt: pairedAt,
        filePermissions: const {DeviceFilePermission.send},
      ),
    );
    await credentialsB.write(SecureKey.peerPairing('device-a'), secret);
    final client = LanSyncHttpClient(
      localDeviceId: 'device-b',
      peerDeviceId: 'device-a',
      host: '127.0.0.1',
      port: server.port!,
      credentials: credentialsB,
      pinnedPeerFingerprint: identityA.fingerprint,
    );
    addTearDown(client.dispose);
    final sender = FileSender(
      store: storeB,
      adapters: [outbox],
      config: const LanSyncTransferConfig(chunkBytes: 64 * 1024),
    );
    addTearDown(sender.dispose);

    final bytes = testBytes(5 * 64 * 1024 + 123);
    outbox.offer('font-1', bytes);
    final record = await sender.send(channel: HttpPeerFileChannel(client), category: 'font', fileId: 'font-1');

    expect(record.status, FileTransferStatus.completed, reason: record.error);
    expect(record.manifest.totalChunks, 6);
    expect(
      crypto.sha256.convert(inbox.received('font-1').readAsBytesSync()).toString(),
      crypto.sha256.convert(bytes).toString(),
    );

    final again = await sender.send(channel: HttpPeerFileChannel(client), category: 'font', fileId: 'font-1');
    expect(again.status, FileTransferStatus.skipped, reason: 'the same content is not sent twice');
  });
}
