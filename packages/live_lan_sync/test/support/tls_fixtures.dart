import 'dart:io' show File;

import 'package:live_lan_sync/live_lan_sync.dart';

/// The self-signed test certificates under `test/fixtures/tls/`, generated
/// once with OpenSSL (EC P-256, 100-year validity) for device-a and
/// device-b.
TlsIdentity loadTlsIdentity(String device) => TlsIdentity.fromPem(
  certificateChainPem: File('test/fixtures/tls/$device.cert.pem').readAsBytesSync(),
  privateKeyPem: File('test/fixtures/tls/$device.key.pem').readAsBytesSync(),
);
