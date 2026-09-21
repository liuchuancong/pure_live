import 'package:dio/dio.dart';
import 'package:pure_live/core/interface/live_input_recipe.dart';
import 'package:pure_live/core/site/bigo/bigo_api.dart';
import 'package:pure_live/core/site/bigo/bigo_input_recipe.dart';
import 'package:pure_live/core/site/niconico/niconico_api.dart';
import 'package:pure_live/core/site/niconico/niconico_input_recipe.dart';
import 'package:pure_live/core/site/niconico/niconico_watch.dart';

import 'bigo_hls_input.dart';
import 'niconico_hls_input.dart';
import 'owned_record_input.dart';
import 'recorder_proxy_routing.dart';

typedef LiveInputRecordingBinder = OwnedRecordSource Function(LiveInputRecipe recipe);
typedef NiconicoRecordInputOpener = Future<OwnedRecordInput> Function(
  NiconicoWatch watch, {
  required String? resolution,
  int? bandwidth,
  required bool recording,
  required String Function(Uri) findProxy,
  CancelToken? cancel,
});

OwnedRecordSource bindLiveInputForRecording(LiveInputRecipe recipe) => switch (recipe) {
  BigoInputRecipe() => bindBigoRecording(recipe),
  NiconicoInputRecipe() => bindNiconicoRecording(recipe),
  _ => throw UnsupportedError('No recording binding for this input recipe'),
};

OwnedRecordSource bindBigoRecording(
  BigoInputRecipe recipe, {
  BigoApi? api,
  String Function(Uri) findProxy = resolveRecorderProxyDirective,
}) => OwnedRecordSource(
  identity: recipe.identity,
  createInput: (cancel) =>
      BigoHlsInput.open(recipe.siteId, recording: true, api: api, findProxy: findProxy, cancel: cancel),
);

OwnedRecordSource bindNiconicoRecording(
  NiconicoInputRecipe recipe, {
  NiconicoApi? api,
  String Function(Uri) findProxy = resolveRecorderProxyDirective,
  NiconicoRecordInputOpener openInput = NiconicoHlsInput.open,
}) {
  final client = api ?? NiconicoApi();
  return OwnedRecordSource(
    identity: recipe.identity,
    createInput: (cancel) async {
      if (cancel.isCancelled) throw cancel.cancelError!;
      final watch = await client.room(recipe.programId, cancel: cancel);
      if (cancel.isCancelled) throw cancel.cancelError!;
      final input = await openInput(
        watch,
        resolution: recipe.resolution,
        bandwidth: recipe.bandwidth,
        recording: true,
        findProxy: findProxy,
        cancel: cancel,
      );
      // Ownership moves into the service even for a late result; the service's
      // cancellation fence joins close rather than abandoning the allocation.
      return input;
    },
  );
}
