import 'package:pure_live/core/interface/live_input_recipe.dart';
import 'package:pure_live/core/site/bigo/bigo_input_recipe.dart';
import 'package:pure_live/core/site/niconico/niconico_input_recipe.dart';

import 'bigo_playback_input.dart';
import 'niconico_playback_input.dart';
import 'playback_source.dart';

typedef LiveInputPlaybackBinder = OwnedPlaybackSource Function(LiveInputRecipe recipe);

/// Binds public resolution data to a playback recipe without opening a seat.
/// Every actual native open acquires independent resources inside the manager.
OwnedPlaybackSource bindLiveInputForPlayback(LiveInputRecipe recipe) => switch (recipe) {
  BigoInputRecipe() => BigoPlaybackInput(siteId: recipe.siteId).source,
  NiconicoInputRecipe() => NiconicoPlaybackInput(
    programId: recipe.programId,
    resolution: recipe.resolution,
    bandwidth: recipe.bandwidth,
  ).source,
  _ => throw UnsupportedError('No playback binding for this input recipe'),
};
