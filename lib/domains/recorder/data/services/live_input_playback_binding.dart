import 'package:dio/dio.dart';
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/core/player/core/playback_proxy_policy.dart';
import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_api.dart';
import 'package:pure_live/shared/platforms/bigo/bigo_input_recipe.dart';
import 'package:pure_live/shared/platforms/fc2live/fc2_api.dart';
import 'package:pure_live/shared/platforms/fc2live/fc2_input_recipe.dart';
import 'package:pure_live/shared/platforms/live_input_recipe.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_api.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_input_recipe.dart';
import 'package:pure_live/shared/platforms/niconico/niconico_watch.dart';

import 'bigo_hls_input.dart';
import 'fc2_hls_input.dart';
import 'niconico_hls_input.dart';

typedef BigoPlaybackInputOpener = Future<BigoHlsInput> Function(
  String siteId, {
  required bool recording,
  BigoApi? api,
  required String Function(Uri) findProxy,
  CancelToken? cancel,
});

typedef Fc2PlaybackInputOpener = Future<Fc2HlsInput> Function(
  String channelId, {
  required bool recording,
  Fc2Api? api,
  required String Function(Uri) findProxy,
  CancelToken? cancel,
});

typedef NiconicoPlaybackInputOpener = Future<NiconicoHlsInput> Function(
  NiconicoWatch watch, {
  required String? resolution,
  int? bandwidth,
  required bool recording,
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
      return _lease(input.inputUri, input.close, () => !input.isClosed, cancel);
    } on BigoException catch (error) {
      if (error.kind == BigoFailure.cancelled && cancel.isCancelled) throw cancel.cancelError!;
      rethrow;
    }
  }
}

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
      return _lease(input.inputUri, input.close, () => !input.isClosed, cancel);
    } on Fc2Exception catch (error) {
      if (error.kind == Fc2Failure.cancelled && cancel.isCancelled) throw cancel.cancelError!;
      rethrow;
    }
  }
}

final class NiconicoPlaybackInput {
  NiconicoPlaybackInput({
    required String programId,
    required this.resolution,
    this.bandwidth,
    NiconicoApi? api,
    String Function(Uri)? findProxy,
    NiconicoPlaybackInputOpener? openInput,
  }) : programId = NiconicoWatch.validateProgramId(programId),
       _api = api ?? NiconicoApi(),
       _openInput = openInput ?? NiconicoHlsInput.open {
    _findProxy = findProxy;
    if (bandwidth != null && (resolution == null || bandwidth! <= 0)) {
      throw ArgumentError('A positive bandwidth selector requires an explicit resolution');
    }
  }

  final String programId;
  final String? resolution;
  final int? bandwidth;
  final NiconicoApi _api;
  String Function(Uri)? _findProxy;
  final NiconicoPlaybackInputOpener _openInput;

  late final OwnedPlaybackSource source = OwnedPlaybackSource(
    identity: 'niconico:$programId:${resolution ?? 'auto'}:${bandwidth ?? 'auto'}',
    createInput: open,
  );

  Future<PlaybackInputLease> open(CancelToken cancel) async {
    if (cancel.isCancelled) throw cancel.cancelError!;
    final findProxy = _findProxy ?? ((_) => PlaybackProxyPolicy.currentDirective());
    try {
      final watch = await _api.room(programId, cancel: cancel);
      if (cancel.isCancelled) throw cancel.cancelError!;
      final input = await _openInput(
        watch,
        resolution: resolution,
        bandwidth: bandwidth,
        recording: false,
        findProxy: findProxy,
        cancel: cancel,
      );
      return _lease(input.inputUri, input.close, () => !input.isClosed, cancel);
    } on NiconicoException catch (error) {
      if (error.kind == NiconicoFailure.cancelled && cancel.isCancelled) throw cancel.cancelError!;
      rethrow;
    }
  }
}

PlaybackInputLease _lease(Uri uri, Future<void> Function() close, bool Function() isUsable, CancelToken cancel) {
  if (cancel.isCancelled) throw cancel.cancelError!;
  return PlaybackInputLease(uri, close, isUsable: isUsable);
}

OwnedPlaybackSource bindSiteInputForPlayback(LiveInputRecipe recipe) => switch (recipe) {
  BigoInputRecipe() => BigoPlaybackInput(siteId: recipe.siteId).source,
  Fc2InputRecipe() => Fc2PlaybackInput(channelId: recipe.channelId).source,
  NiconicoInputRecipe() => NiconicoPlaybackInput(
    programId: recipe.programId,
    resolution: recipe.resolution,
    bandwidth: recipe.bandwidth,
  ).source,
  _ => throw UnsupportedError('No playback binding for ${recipe.runtimeType}'),
};
