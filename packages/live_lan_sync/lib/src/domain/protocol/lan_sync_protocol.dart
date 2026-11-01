/// The protocol version this engine speaks and the path prefix it serves.
///
/// The protocol version governs the communication structure and exchange
/// flow; a scope's schema version governs its payload shape. The two are
/// negotiated separately and a mismatch is an explicit error, never a
/// silent reinterpretation (spec §14.4).
final class LanSyncProtocol {
  /// Never instantiated.
  const new _();

  /// The protocol version this package implements.
  static const int current = 1;

  /// The API path prefix every protocol request lives under.
  static const String apiPrefix = '/sync/v1/';
}
