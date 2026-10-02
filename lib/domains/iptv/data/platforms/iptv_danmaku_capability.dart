import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';

/// IPTV 频道没有弹幕来源，连上只会提示"远程弹幕未接入"，因此显式不建立弹幕连接。
mixin IptvDanmakuCapability on LiveDanmakuCapabilityDefaults {
  @override
  bool get connectsDanmakuOnRoomEntry => false;
}
