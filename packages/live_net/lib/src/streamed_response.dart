import 'dart:typed_data';

/// An HTTP response whose body is consumed incrementally.
///
/// Backs large downloads and media hand-offs. The [stream] is
/// single-subscription; [close] aborts it early — after a close, reading the
/// stream ends without an error.
abstract interface class LiveStreamedResponse {
  /// HTTP status code of the streaming response.
  int get statusCode;

  /// Response headers keyed by lower-case name.
  Map<String, String> get headers;

  /// The body chunks, single subscription.
  Stream<Uint8List> get stream;

  /// Aborts the transfer. Safe to call more than once.
  Future<void> close();
}
