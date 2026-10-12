/// Network kernel for Pure Live.
///
/// Business modules use `LiveHttp` instead of depending directly on Dio:
/// build clients through `DioFactory` (a `ClientProfile` picks caching and
/// retry defaults), describe calls as `LiveRequest`, and pattern match on
/// `TransportFailure` when the transport itself fails. Error statuses
/// (4xx/5xx) are ordinary `LiveResponse`s, not exceptions — only the
/// convenience callers in `LiveHttpCalls` promote bad statuses to
/// `HttpStatusFailure`.
///
/// `MediaProbe` sits on the same contract and answers a different question:
/// not "did the server reply" but "is there a stream behind this address",
/// by reading the head of the body and matching the container signature.
library;

export 'src/calls.dart';
export 'src/client_profile.dart';
export 'src/dio_factory.dart';
export 'src/live_http.dart';
export 'src/media_probe.dart';
export 'src/proxy.dart';
export 'src/request.dart';
export 'src/response.dart';
export 'src/streamed_response.dart';
export 'src/transport_failure.dart';
