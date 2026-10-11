import 'package:live_net/src/dio_http.dart' show DioLiveHttp;
import 'package:live_net/src/request.dart';
import 'package:live_net/src/response.dart';
import 'package:live_net/src/streamed_response.dart';

/// The HTTP contract every part of Pure Live codes against.
///
/// Implemented by [DioLiveHttp] in production and by replay/fake transports
/// in tests. The contract is the stable part — the dio transport underneath
/// is a replaceable detail.
abstract interface class LiveHttp {
  /// Sends the request and buffers the whole response.
  ///
  /// 4xx/5xx answers come back as ordinary [LiveResponse]s. Transport-level
  /// breakdowns throw a `TransportFailure` subtype.
  Future<LiveResponse> send(LiveRequest request);

  /// Opens the request without buffering, for incremental consumption.
  ///
  /// Same failure semantics as [send].
  Future<LiveStreamedResponse> open(LiveRequest request);

  /// Releases pooled transports. The instance is unusable afterwards.
  void close();
}
