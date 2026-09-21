import 'package:dio/dio.dart';
import 'package:pure_live/core/site/bigo/bigo_api.dart';
import 'package:pure_live/recorder/services/bigo_hls_input.dart';

import 'playback_proxy_policy.dart';
import 'playback_source.dart';
import 'playback_source_transport.dart';

typedef BigoPlaybackInputOpener = Future<BigoHlsInput> Function(
  String siteId, {
  required bool recording,
  BigoApi? api,
  required String Function(Uri) findProxy,
  CancelToken? cancel,
});

final class BigoPlaybackInput {
  BigoPlaybackInput({required String siteId, this.api, BigoPlaybackInputOpener? openInput})
    : siteId = BigoApi.validateSiteId(siteId),
      _openInput = openInput ?? BigoHlsInput.open;

  final String siteId;
  final BigoApi? api;
  final BigoPlaybackInputOpener _openInput;

  late final OwnedPlaybackSource source = OwnedPlaybackSource(identity: 'bigo:$siteId:live', createInput: open);

  Future<PlaybackInputLease> open(CancelToken cancel) async {
    if (cancel.isCancelled) throw cancel.cancelError!;
    final directive = PlaybackProxyPolicy.currentDirective();
    try {
      final input = await _openInput(siteId, recording: false, api: api, findProxy: (_) => directive, cancel: cancel);
      try {
        if (cancel.isCancelled) throw cancel.cancelError!;
        return PlaybackInputLease(input.inputUri, input.close, isUsable: () => !input.isClosed);
      } catch (_) {
        await input.close();
        rethrow;
      }
    } on BigoException catch (error) {
      if (error.kind == BigoFailure.cancelled && cancel.isCancelled) throw cancel.cancelError!;
      rethrow;
    }
  }
}
