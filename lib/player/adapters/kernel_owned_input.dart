import 'dart:async';

import 'package:dio/dio.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:pure_live/player/core/playback_source_transport.dart';

/// Owned 私有源的 recipe：获取一个回环输入租约（cancel 可观察）。
typedef OwnedInputRecipe = Future<PlaybackInputLease> Function(CancelToken cancel);

OwnedInputRecipe? asOwnedInputRecipe(Object? recipe) => recipe is OwnedInputRecipe ? recipe : null;

class _OwnedLeaseState {
  PlaybackInputLease? active;
  final Set<PlaybackInputLease> retiring = <PlaybackInputLease>{};
}

final Expando<_OwnedLeaseState> _ownedStates = Expando<_OwnedLeaseState>();

/// media_core custom-input opener：在 kernel 的 media_kit 播放器上打开
/// owned 回环租约。旧租约立即退役（换源/恢复重开都会走到这里），本租约
/// 打开失败时自行关闭并把错误交还 RecoveryLadder。回环输入必须绕过原生
/// 代理，这里直接对 player 设 `http-proxy=''`。
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
