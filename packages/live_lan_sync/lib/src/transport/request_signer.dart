import 'dart:convert' show ascii, base64Url;
import 'dart:math' show Random;

import 'package:crypto/crypto.dart' as crypto show Hmac, sha256;

/// HMAC-SHA256 request signing over the per-peer pairing secret.
///
/// Every protocol request a client sends carries a signature over the
/// canonical string from `LanSyncHttpAuth.canonical` — method, path,
/// timestamp, single-use nonce and the body's SHA-256 — keyed with the
/// 32-byte secret both ends derived during pairing. TLS (pinned to the
/// server's certificate) keeps the exchange confidential and authenticates
/// the server; the signature authenticates the client and binds every
/// request to one pairing (spec §9.1, §14.3).
abstract final class RequestSigner {
  /// The hex signature over [canonical] with [secret].
  static String sign({required String canonical, required List<int> secret}) =>
      crypto.Hmac(crypto.sha256, secret).convert(ascii.encode(canonical)).toString();

  /// Whether [signature] authenticates [canonical] with [secret]. The
  /// comparison runs in time independent of where a wrong signature first
  /// differs.
  static bool verify({required String canonical, required String signature, required List<int> secret}) {
    final expected = sign(canonical: canonical, secret: secret);
    if (signature.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < expected.length; i++) {
      diff |= signature.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// A fresh single-use nonce for one request.
  static String newNonce([Random? random]) {
    final generator = random ?? Random.secure();
    final bytes = List<int>.generate(16, (_) => generator.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// The SHA-256 hex digest of a request body, the last canonical line.
  static String bodyHash(List<int> body) => crypto.sha256.convert(body).toString();
}
