import 'package:pure_live/shared/platforms/live_danmaku_capability.dart';

mixin IptvDanmakuCapability on LiveDanmakuCapabilityDefaults {
  @override
  bool get connectsDanmakuOnRoomEntry => false;
}
