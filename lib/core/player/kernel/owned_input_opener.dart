import 'dart:async';

import 'package:dio/dio.dart';
import 'package:media_core_media_kit/media_core_media_kit.dart' as mk;
import 'package:pure_live/core/player/core/playback_input_lease.dart';
import 'package:pure_live/core/player/core/playback_source.dart';

typedef OwnedInputRecipe = Future<PlaybackInputLease> Function(CancelToken cancel);

OwnedInputRecipe? asOwnedInputRecipe(Object? recipe) => recipe is OwnedInputRecipe ? recipe : null;

/// 放进 `kMediaKitCustomInputKey` 的东西：**打开输入的函数**，不是 source 本身。
///
/// 这是 [asOwnedInputRecipe] 的另一半——两端必须对齐，而对齐失败不是编译错误
/// （元数据是 `Map<String, Object?>`），是运行时 `Invalid argument (recipe):
/// Not an owned-input recipe`，房间直接打不开。FC2 就死在这里：facade 塞了整个
/// [OwnedPlaybackSource]，而多画面那条路一直塞的是 `createInput`。
Object customInputMetadataOf(OwnedPlaybackSource source) => source.createInput;

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
    // 代理与容器格式由 beforeOpen 钩子按源统一决定（自有输入的 `owned:` 协议属于
    // 本机输入，那里会把 http-proxy 清空），这里不再重复一次判定。
    await mkPlayer.open(mk.Media(lease.uri.toString()), play: true);
  } catch (error) {
    if (identical(state.active, lease)) {
      state.active = null;
    }
    unawaited(lease.close());
    rethrow;
  }
}
