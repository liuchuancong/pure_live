import 'dart:convert' show base64, latin1;
import 'dart:io' show SecurityContext;

import 'package:live_lan_sync/src/domain/errors/errors.dart' show LanSyncError, LanSyncErrorCategory;
import 'package:live_lan_sync/src/pairing/fingerprint.dart' show KeyFingerprints;

/// A device's TLS identity: the certificate and private key its sync server
/// presents, and the fingerprint peers pin (spec §9.3, §20).
///
/// The certificate is self-signed and long-lived; it is the device's
/// long-term identity. Peers learn its fingerprint during pairing — the
/// fingerprint is part of the transcript both users authenticate by
/// comparing the short code — and from then on accept no other certificate
/// for this device. The private key is secret material: hosts keep the PEM
/// in their `SecureCredentialStore` and rebuild this object at start-up.
final class TlsIdentity {
  /// An identity over already-decoded parts; prefer [TlsIdentity.fromPem].
  const new({
    required this.certificateChainPem,
    required this.privateKeyPem,
    required this.certificateDer,
    this.privateKeyPassword,
  });

  /// Builds an identity from PEM-encoded material. The first certificate in
  /// [certificateChainPem] is the one peers pin.
  ///
  /// Throws a [LanSyncError] with `configuration` when the chain holds no
  /// parseable certificate.
  factory fromPem({
    required List<int> certificateChainPem,
    required List<int> privateKeyPem,
    String? privateKeyPassword,
  }) {
    final der = _firstCertificateDer(certificateChainPem);
    if (der == null) {
      throw const LanSyncError(
        category: LanSyncErrorCategory.configuration,
        code: 'tls_certificate_invalid',
        message: 'The TLS certificate could not be read.',
      );
    }
    return TlsIdentity(
      certificateChainPem: certificateChainPem,
      privateKeyPem: privateKeyPem,
      certificateDer: der,
      privateKeyPassword: privateKeyPassword,
    );
  }

  /// The PEM certificate chain the server presents.
  final List<int> certificateChainPem;

  /// The PEM private key matching the first certificate. Secret.
  final List<int> privateKeyPem;

  /// The DER bytes of the presented certificate, the input of [fingerprint].
  final List<int> certificateDer;

  /// The private key's password, when the PEM is encrypted.
  final String? privateKeyPassword;

  /// The `sha256:<hex>` fingerprint peers pin.
  String get fingerprint => KeyFingerprints.sha256(certificateDer);

  /// A fresh server context presenting this identity. No trusted roots
  /// (the constructor's default): the server never validates anything
  /// against a CA.
  SecurityContext serverContext() => SecurityContext()
    ..useCertificateChainBytes(certificateChainPem)
    ..usePrivateKeyBytes(privateKeyPem, password: privateKeyPassword);

  static List<int>? _firstCertificateDer(List<int> pem) {
    final text = latin1.decode(pem, allowInvalid: true);
    const begin = '-----BEGIN CERTIFICATE-----';
    const end = '-----END CERTIFICATE-----';
    final start = text.indexOf(begin);
    if (start < 0) return null;
    final stop = text.indexOf(end, start + begin.length);
    if (stop < 0) return null;
    final body = text.substring(start + begin.length, stop).replaceAll(RegExp(r'\s'), '');
    try {
      final der = base64.decode(body);
      return der.isEmpty ? null : der;
    } on FormatException {
      return null;
    }
  }
}
