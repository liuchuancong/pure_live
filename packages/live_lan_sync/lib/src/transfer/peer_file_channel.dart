import 'package:live_lan_sync/src/transport/lan_sync_http_client.dart' show LanSyncHttpClient;

/// The sender's view of one peer's file endpoints (spec §14.2):
/// `POST /files/init`, `PUT /files/{transferId}/chunks/{index}`,
/// `GET /files/{transferId}/status`, `DELETE /files/{transferId}`.
abstract interface class PeerFileChannel {
  /// The device receiving the files.
  String get peerDeviceId;

  /// Registers (or resumes) a transfer for the manifest in [body].
  Future<Map<String, Object?>> init(Map<String, Object?> body);

  /// Sends chunk [index] of [transferId].
  Future<Map<String, Object?>> putChunk(String transferId, int index, List<int> bytes);

  /// Where [transferId] stands on the receiver.
  Future<Map<String, Object?>> status(String transferId);

  /// Cancels [transferId]; the receiver discards what it has.
  Future<Map<String, Object?>> cancel(String transferId);
}

/// A [PeerFileChannel] over a pinned, signed [LanSyncHttpClient].
final class HttpPeerFileChannel implements PeerFileChannel {
  /// A channel through [client].
  const new(this.client);

  /// The client bound to one paired peer.
  final LanSyncHttpClient client;

  @override
  String get peerDeviceId => client.peerDeviceId;

  @override
  Future<Map<String, Object?>> init(Map<String, Object?> body) => client.invoke('POST', 'files/init', body: body);

  @override
  Future<Map<String, Object?>> putChunk(String transferId, int index, List<int> bytes) =>
      client.upload('PUT', 'files/${Uri.encodeComponent(transferId)}/chunks/$index', bytes);

  @override
  Future<Map<String, Object?>> status(String transferId) =>
      client.invoke('GET', 'files/${Uri.encodeComponent(transferId)}/status');

  @override
  Future<Map<String, Object?>> cancel(String transferId) =>
      client.invoke('DELETE', 'files/${Uri.encodeComponent(transferId)}');
}
