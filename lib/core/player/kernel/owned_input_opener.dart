import 'dart:async';

import 'package:dio/dio.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' as mk;
import 'package:pure_live/core/player/core/playback_input_lease.dart';

typedef OwnedInputRecipe = Future<PlaybackInputLease> Function(CancelToken cancel);

OwnedInputRecipe? asOwnedInputRecipe(Object? recipe) => recipe is OwnedInputRecipe ? recipe : null;

class _OwnedLeaseState {
  PlaybackInputLease? active;
  final Set<PlaybackInputLease> retiring = <PlaybackInputLease>{};
}

final Expando<_OwnedLeaseState> _ownedStates = Expando<_OwnedLeaseState>();

Future<void> openOwnedInputOnKernelPlayer(dynamic player, Object recipe) async {
  final owned = asOwnedInputRecipe(recipe);
  if (owned == null) {
    throw ArgumentError.value(recipe, 'recipe', 'Not an owned-input recipe');
  }
  final mkPlayer = player as mk.Player;
  final state = _ownedStates[mkPlayer] ??= _OwnedLeaseState();
  final previous = state.active;
  state.active = null;
  if (previous != null) {
    state.retiring.add(previous);
    unawaited(previous.close().whenComplete(() => state.retiring.remove(previous)));
  }

  final lease = await owned(CancelToken());
  state.active = lease;
  try {
    final platform = mkPlayer.platform as dynamic;
    await platform.setProperty('http-proxy', '');
    await mkPlayer.open(mk.Media(lease.uri.toString()), play: true);
  } catch (error) {
    if (identical(state.active, lease)) {
      state.active = null;
    }
    unawaited(lease.close());
    rethrow;
  }
}
