import 'package:pure_live/shared/platforms/live_input_recipe.dart';

import 'package:pure_live/core/player/core/playback_source.dart';

typedef LiveInputPlaybackBinder = OwnedPlaybackSource Function(LiveInputRecipe recipe);

LiveInputPlaybackBinder? _installed;

void configureLiveInputPlaybackBinder(LiveInputPlaybackBinder? binder) => _installed = binder;

/// Binds public resolution data to a playback recipe without opening a seat.
/// Every actual native open acquires independent resources inside the manager.
OwnedPlaybackSource bindLiveInputForPlayback(LiveInputRecipe recipe) {
  final binder = _installed;
  if (binder == null) {
    throw UnsupportedError('No playback binder installed for ${recipe.runtimeType}');
  }
  return binder(recipe);
}
