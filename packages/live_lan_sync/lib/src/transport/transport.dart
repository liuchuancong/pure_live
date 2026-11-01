/// The transport: the TLS server, the pinned client, request signing and
/// replay protection (spec §14).
///
/// TLS is mandatory. The server presents the device's `TlsIdentity`; the
/// client trusts no certificate authority and accepts exactly the
/// certificate fingerprint pinned at pairing. Inside that channel every
/// protocol request is signed with HMAC-SHA256 over the per-peer pairing
/// secret — derived during pairing, never sent — and guarded against
/// replay by timestamps and single-use nonces.
library;

export 'http_auth.dart';
export 'http_json.dart';
export 'lan_sync_http_client.dart';
export 'lan_sync_http_server.dart';
export 'replay_guard.dart';
export 'request_signer.dart';
