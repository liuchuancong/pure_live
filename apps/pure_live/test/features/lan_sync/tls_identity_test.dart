import 'dart:math' show Random;

import 'package:flutter_test/flutter_test.dart';
import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:pure_live/features/lan_sync/data/tls_identity_provider.dart';

/// The credential store over a seeded StoragePrefs namespace is process
/// global; a tiny in-test store keeps these tests independent.
final class _MemoryCredentials implements SecureCredentialStore {
  final Map<String, List<int>> _values = <String, List<int>>{};

  @override
  Future<void> write(SecureKey key, List<int> bytes) async => _values[key.id] = bytes;

  @override
  Future<List<int>?> read(SecureKey key) async => _values[key.id];

  @override
  Future<void> delete(SecureKey key) async => _values.remove(key.id);
}

void main() {
  group('DeviceTlsIdentity', () {
    test('rebuilding from the stored key reproduces the fingerprint', () {
      final identity = DeviceTlsIdentity.build(deviceName: 'Desktop', random: Random(7));
      final fingerprint = identity.fingerprint;

      expect(fingerprint, startsWith('sha256:'));
      final keyDer = DeviceTlsIdentity.keyBundle(identity);
      final reloaded = DeviceTlsIdentity.build(deviceName: 'Desktop', fromBundle: keyDer);
      expect(reloaded.fingerprint, fingerprint, reason: 'same key and name, same certificate');
    });

    test('the same key with another name is a different certificate', () {
      final identity = DeviceTlsIdentity.build(deviceName: 'Desktop', random: Random(7));
      final keyDer = DeviceTlsIdentity.keyBundle(identity);
      final renamed = DeviceTlsIdentity.build(deviceName: 'Study', fromBundle: keyDer);
      expect(renamed.fingerprint, isNot(identity.fingerprint));
    });

    test('ensure persists and reloads the same identity', () async {
      final credentials = _MemoryCredentials();
      final first = await DeviceTlsIdentity.ensure(credentials: credentials, deviceName: 'Desktop', random: Random(3));
      final second = await DeviceTlsIdentity.ensure(credentials: credentials, deviceName: 'Desktop');

      expect(second.fingerprint, first.fingerprint);
    });

    test('a corrupted bundle is a configuration error, not a crash', () {
      expect(
        () => DeviceTlsIdentity.build(deviceName: 'Desktop', fromBundle: [1, 2, 3]),
        throwsA(isA<LanSyncError>().having((e) => e.code, 'code', 'tls_bundle_invalid')),
      );
    });

    test('boringssl accepts the generated certificate and key', () {
      final identity = DeviceTlsIdentity.build(deviceName: 'Desktop', random: Random(11));
      final certificatePem = String.fromCharCodes(identity.certificateChainPem);
      expect(certificatePem, contains('-----BEGIN CERTIFICATE-----'));
      expect(String.fromCharCodes(identity.privateKeyPem), contains('-----BEGIN PRIVATE KEY-----'));

      // The real acceptance: SecurityContext must take both, or the server
      // cannot serve TLS at all.
      final context = identity.serverContext();
      expect(context, isNotNull);
    });
  });
}
