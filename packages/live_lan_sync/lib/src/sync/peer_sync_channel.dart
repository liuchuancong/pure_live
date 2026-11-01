import 'package:live_lan_sync/src/transport/lan_sync_http_client.dart' show LanSyncHttpClient;

/// The engine's view of one peer: a request–response call per protocol
/// route (spec §14.2). The HTTP implementation is the production path;
/// tests and embedded hosts can supply their own.
abstract interface class PeerSyncChannel {
  /// The device on the other end.
  String get peerDeviceId;

  /// Sends [body] to [route] (e.g. `changes/pull`) and returns the decoded
  /// answer. Failures arrive as `LanSyncError`s.
  Future<Map<String, Object?>> call(String route, Map<String, Object?> body);
}

/// A [PeerSyncChannel] over a pinned, signed [LanSyncHttpClient].
final class HttpPeerSyncChannel implements PeerSyncChannel {
  /// A channel through [client].
  const new(this.client);

  /// The client bound to one paired peer.
  final LanSyncHttpClient client;

  @override
  String get peerDeviceId => client.peerDeviceId;

  @override
  Future<Map<String, Object?>> call(String route, Map<String, Object?> body) =>
      client.invoke('POST', route, body: body);
}

/// A cooperative cancellation signal for one sync task, checked between
/// batches: a batch in flight completes and commits, nothing after it
/// starts.
final class SyncCancellation {
  bool _cancelled = false;

  /// Whether [cancel] was called.
  bool get isCancelled => _cancelled;

  /// Asks the task to stop at the next batch boundary.
  void cancel() => _cancelled = true;
}
