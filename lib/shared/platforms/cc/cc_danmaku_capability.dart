import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';

/// 网易 CC 的分类/官方入口房间没有弹幕来源，连上只会提示"远程弹幕未接入"，
/// 因此显式不建立弹幕连接。
mixin CcDanmakuCapability on LiveDanmakuCapabilityDefaults {
  @override
  bool get connectsDanmakuOnRoomEntry => false;
}
