import 'package:pure_live/core/interface/live_input_recipe.dart';

import 'playback_source.dart';

typedef LiveInputPlaybackBinder = OwnedPlaybackSource Function(LiveInputRecipe recipe);

/// Binds public resolution data to a playback recipe without opening a seat.
/// Every actual native open acquires independent resources inside the manager.
OwnedPlaybackSource bindLiveInputForPlayback(LiveInputRecipe recipe) => switch (recipe) {
  _ => throw UnsupportedError('No playback binding for this input recipe'),
};
