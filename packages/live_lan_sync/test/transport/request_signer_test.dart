import 'package:live_lan_sync/live_lan_sync.dart';
import 'package:test/test.dart';

void main() {
  group('RequestSigner', () {
    final secret = List<int>.generate(32, (i) => i);
    final canonical = LanSyncHttpAuth.canonical(
      method: 'POST',
      path: '/sync/v1/device',
      timestampMs: 1790000000000,
      nonce: 'nonce-1',
      bodySha256Hex: RequestSigner.bodyHash(const <int>[]),
    );

    test('the empty body hash is the SHA-256 of nothing', () {
      expect(RequestSigner.bodyHash(const <int>[]), 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    });

    test('a correct signature verifies', () {
      final signature = RequestSigner.sign(canonical: canonical, secret: secret);
      expect(RequestSigner.verify(canonical: canonical, signature: signature, secret: secret), isTrue);
    });

    test('a tampered canonical string fails', () {
      final signature = RequestSigner.sign(canonical: canonical, secret: secret);
      final tampered = canonical.replaceFirst('POST', 'PUT');
      expect(RequestSigner.verify(canonical: tampered, signature: signature, secret: secret), isFalse);
    });

    test('the wrong secret fails', () {
      final signature = RequestSigner.sign(canonical: canonical, secret: secret);
      final other = List<int>.filled(32, 7);
      expect(RequestSigner.verify(canonical: canonical, signature: signature, secret: other), isFalse);
    });

    test('a truncated signature fails without throwing', () {
      expect(RequestSigner.verify(canonical: canonical, signature: 'abcd', secret: secret), isFalse);
    });

    test('nonces are fresh', () {
      expect(RequestSigner.newNonce(), isNot(RequestSigner.newNonce()));
    });
  });

  group('ReplayGuard', () {
    final now = DateTime.utc(2026, 11, 3, 12);

    test('a fresh triple is accepted once, then refused', () {
      final guard = ReplayGuard(now: () => now);
      final at = DateTime.utc(2026, 11, 3, 11, 59, 59);

      expect(guard.accept(sender: 'device-b', timestamp: at, nonce: 'n1'), isTrue);
      expect(guard.accept(sender: 'device-b', timestamp: at, nonce: 'n1'), isFalse);
      expect(guard.accept(sender: 'device-b', timestamp: at, nonce: 'n2'), isTrue);
    });

    test('stale and future timestamps are refused', () {
      final guard = ReplayGuard(now: () => now);
      expect(guard.accept(sender: 'device-b', timestamp: DateTime.utc(2026, 11, 3, 11, 57), nonce: 'n1'), isFalse);
      expect(guard.accept(sender: 'device-b', timestamp: DateTime.utc(2026, 11, 3, 12, 3), nonce: 'n2'), isFalse);
    });

    test('a refused stale request does not burn its nonce', () {
      final guard = ReplayGuard(now: () => now);
      expect(guard.accept(sender: 'device-b', timestamp: DateTime.utc(2026, 11, 3, 11, 57), nonce: 'n1'), isFalse);
      expect(guard.accept(sender: 'device-b', timestamp: DateTime.utc(2026, 11, 3, 11, 59), nonce: 'n1'), isTrue);
    });

    test('senders are isolated', () {
      final guard = ReplayGuard(now: () => now);
      final at = DateTime.utc(2026, 11, 3, 11, 59);

      expect(guard.accept(sender: 'device-b', timestamp: at, nonce: 'n1'), isTrue);
      expect(guard.accept(sender: 'device-c', timestamp: at, nonce: 'n1'), isTrue);
    });
  });
}
