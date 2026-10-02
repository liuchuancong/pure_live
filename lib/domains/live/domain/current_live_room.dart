import 'package:pure_live/core/models/live_room.dart';

/// 当前正在播放的房间。
///
/// 站点适配器（数据层）在取流失败时需要判断"失败的是不是正在播的那个房间"，
/// 以前它直接 `Get.find<PlayerController>()`，等于让数据源反向依赖页面控制器。
/// 这里把它换成一个域内可注入的只读入口：presentation 层负责注册 provider，
/// data 层只读值。
class CurrentLiveRoom {
  /// 由直播播放控制器在安装时挂载、销毁时清空。
  static LiveRoom? Function()? provider;

  static LiveRoom? get value => provider?.call();
}
