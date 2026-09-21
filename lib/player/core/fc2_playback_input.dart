import 'package:dio/dio.dart';
import 'package:pure_live/core/site/fc2live/fc2_api.dart';
import 'package:pure_live/recorder/services/fc2_hls_input.dart';

import 'playback_proxy_policy.dart';
import 'playback_source.dart';
import 'playback_source_transport.dart';

typedef Fc2PlaybackInputOpener = Future<Fc2HlsInput> Function(
  String channelId, {
  required bool recording,
  Fc2Api? api,
  required String Function(Uri) findProxy,
  CancelToken? cancel,
});

final class Fc2PlaybackInput {
  Fc2PlaybackInput({required this.channelId, this.api, Fc2PlaybackInputOpener? openInput})
    : _openInput = openInput ?? Fc2HlsInput.open;

  final String channelId;
  final Fc2Api? api;
  final Fc2PlaybackInputOpener _openInput;

  late final OwnedPlaybackSource source = OwnedPlaybackSource(identity: 'fc2live:$channelId:auto', createInput: open);

  Future<PlaybackInputLease> open(CancelToken cancel) async {
    if (cancel.isCancelled) throw cancel.cancelError!;
    final directive = PlaybackProxyPolicy.currentDirective();
    try {
      final input = await _openInput(
        channelId,
        recording: false,
        api: api,
        findProxy: (_) => directive,
        cancel: cancel,
      );
      try {
        if (cancel.isCancelled) throw cancel.cancelError!;
        return PlaybackInputLease(input.inputUri, input.close, isUsable: () => !input.isClosed);
      } catch (_) {
        await input.close();
        rethrow;
      }
    } on Fc2Exception catch (error) {
      if (error.kind == Fc2Failure.cancelled && cancel.isCancelled) throw cancel.cancelError!;
      rethrow;
    }
  }
}
