import 'package:pure_live/core/models/live_area.dart';

/// 「官方分类入口」判定。
///
/// 网易 CC 的部分分类并不对应应用内的房间列表，而是指向官方页面；这类分类要
/// 交给系统浏览器打开。判定规则与可重建的目标地址属于直播域（CCCatalog），
/// App 装配层绑定到这个 Core 端口，导航工具因此不反向 import 业务域。
///
/// 未绑定实现时按「普通分类」处理：落回应用内的分类房间路由。
abstract final class OfficialCategoryPolicy {
  static bool Function(LiveArea area)? isOfficialCategory;
  static Uri? Function(LiveArea area)? officialCategoryUri;

  static bool isOfficial(LiveArea area) => isOfficialCategory?.call(area) ?? false;

  static Uri? uriFor(LiveArea area) => officialCategoryUri?.call(area);
}
