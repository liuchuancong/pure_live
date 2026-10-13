import 'package:freezed_annotation/freezed_annotation.dart';

part 'live_stream.freezed.dart';

/// The transport a resolved stream uses.
enum LiveStreamProtocol {
  /// HTTP Live Streaming.
  hls,

  /// HTTP progressive FLV.
  httpFlv,

  /// Dynamic Adaptive Streaming over HTTP.
  dash,

  /// Real-Time Messaging Protocol.
  rtmp,

  /// WebRTC.
  webrtc,

  /// A plain HTTP file or progressive source.
  http,

  /// The protocol is not known.
  unknown,
}

/// A resolved playable source: the URL, the protocol and the headers and
/// expiry needed to fetch it. Short-lived URLs are never persisted as room
/// metadata; they live only in this resolution. [headers] may carry cookies,
/// so the application's security policy governs how they are handled.
// ignore_for_file: unnecessary_type_name_in_constructor -- Freezed
// factories cannot use the `new` shorthand.
@freezed
abstract class LiveStream with _$LiveStream {
  /// Creates a stream at [uri] with its [protocol], [quality], [lineId],
  /// request [headers], optional [expiresAt] and source [metadata].
  const factory LiveStream({
    required Uri uri,
    @Default(LiveStreamProtocol.unknown) LiveStreamProtocol protocol,
    String? quality,
    String? lineId,
    @Default({}) Map<String, String> headers,
    DateTime? expiresAt,
    bool? audioOnlyAvailable,
    @Default({}) Map<String, Object?> metadata,
  }) = _LiveStream;
}
