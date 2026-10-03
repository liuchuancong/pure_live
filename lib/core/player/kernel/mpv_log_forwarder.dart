import 'dart:async';
import 'dart:developer' as developer;

import 'package:media_core_media_kit/media_core_media_kit.dart' as mk;

final Expando<StreamSubscription<mk.PlayerLog>> _forwarders = Expando<StreamSubscription<mk.PlayerLog>>();

/// 把 mpv 自己的日志接到开发者日志上。
///
/// media_kit 只把 mpv 的**错误码**喂给 `stream.error`，`stream.log` 里的日志文本
/// 默认无人订阅，等于全部丢掉。可直播卡顿的一手证据恰恰在那里：清单重载失败、
/// 分片的 HTTP 状态、cache 为什么暂停。没有它，外面能看到的只有"位置不动了"，
/// 只能靠现象猜。
///
/// 产出多少由 [MediaKitLiveProperties.playerConfiguration] 的 logLevel 决定；
/// 每个引擎只订阅一次，订阅随引擎一起被回收。
void attachMpvLogForwarder(mk.Player player) {
  if (_forwarders[player] != null) return;
  _forwarders[player] = player.stream.log.listen((entry) {
    developer.log('${entry.prefix}/${entry.level}: ${entry.text}', name: 'mpv');
  });
}
