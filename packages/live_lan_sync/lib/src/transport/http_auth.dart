/// The HTTP header and scheme names the protocol uses (spec §14.3), plus
/// the canonical-string definition every signature covers.
abstract final class LanSyncHttpAuth {
  /// The sender's device id header.
  static const deviceId = 'X-LanSync-Device';

  /// The request timestamp header, milliseconds since epoch.
  static const timestamp = 'X-LanSync-Timestamp';

  /// The single-use request nonce header.
  static const nonce = 'X-LanSync-Nonce';

  /// The signature header, `LanSyncHMAC <hex>`.
  static const authorization = 'Authorization';

  /// The Authorization scheme prefix.
  static const scheme = 'LanSyncHMAC';

  /// How far a request timestamp may drift from the receiver's clock.
  static const clockTolerance = Duration(minutes: 2);

  /// The request target a signature covers: the path and, when present,
  /// the query — so no query parameter can change without breaking it.
  static String target(Uri uri) => uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;

  /// The canonical string the signature covers: method, target (path and
  /// query), timestamp, nonce and the SHA-256 of the body, one per line.
  static String canonical({
    required String method,
    required String path,
    required int timestampMs,
    required String nonce,
    required String bodySha256Hex,
  }) => '$method\n$path\n$timestampMs\n$nonce\n$bodySha256Hex';
}
