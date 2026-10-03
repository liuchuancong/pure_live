import 'package:pure_live/shared/platforms/live_input_recipe.dart';

import 'package:pure_live/core/player/core/playback_source.dart';

typedef LiveInputPlaybackBinder = OwnedPlaybackSource Function(LiveInputRecipe recipe);

LiveInputPlaybackBinder? _installed;

/// 装配点：app 启动时安装实现（本仓在录制域的数据层，`bindSiteInputForPlayback`）。
/// domain 只认这个函数形状，不认识任何站点的席位获取。
void configureLiveInputPlaybackBinder(LiveInputPlaybackBinder? binder) => _installed = binder;

/// Binds public resolution data to a playback recipe without opening a seat.
/// Every actual native open acquires independent resources inside the manager.
///
/// 未装配时绑定任何配方都抛：那正是"接线断了"的样子。静默退回直连会把一个
/// 只能靠自有输入播放的站点（niconico/bigo/fc2）变成"拿到 URL 也播不了"，
/// 而抛异常至少让日志说出真话。
OwnedPlaybackSource bindLiveInputForPlayback(LiveInputRecipe recipe) {
  final binder = _installed;
  if (binder == null) {
    throw UnsupportedError('No playback binder installed for ${recipe.runtimeType}');
  }
  return binder(recipe);
}
