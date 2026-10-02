import 'package:dio/dio.dart';

/// Owns cancellation for a single request and the consumption of its body.
/// Dio 5.11.1's transformed response stream does not forward subscription
/// cancellation upstream. Ending this scope also stops that upstream source
/// and its receive timer, without cancelling a shared caller token or Dio.
Future<T> withRequestCancellation<T>(CancelToken? caller, Future<T> Function(CancelToken transport) consume) async {
  final transport = CancelToken();
  if (caller?.isCancelled == true) transport.cancel();
  final forwarding = caller?.whenCancel.asStream().listen((_) {
    if (!transport.isCancelled) transport.cancel();
  });
  try {
    return await consume(transport);
  } finally {
    await forwarding?.cancel();
    if (!transport.isCancelled) transport.cancel();
    await transport.whenCancel;
  }
}
