import 'package:dio/dio.dart';

/// One recording attempt's private media transport. The FFmpeg service owns it
/// until native completion and joined cleanup, including late creation results.
abstract interface class OwnedRecordInput {
  Uri get inputUri;
  bool get isClosed;
  Duration get drainTimeout;
  bool get finishRequested;
  bool get inputTailDiscarded;
  set onCoverageIncomplete(void Function()? listener);
  List<String> replaceFirstInput(Iterable<String> arguments);
  Future<void> finish();
  Future<void> close();
}

typedef RecordArgumentsBuilder = List<String> Function(Uri input);

/// Public identity and recreation function only. No seat or short-lived URI is
/// opened until the native recording attempt owns a cancellation/cleanup fence.
final class OwnedRecordSource {
  OwnedRecordSource({required this.identity, required this.createInput}) {
    if (identity.trim().isEmpty) throw ArgumentError('Missing recording source identity');
  }
  final String identity;
  final Future<OwnedRecordInput> Function(CancelToken cancel) createInput;
}
