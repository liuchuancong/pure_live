/// 站点标识常量。
///
/// Core 需要按平台标识做判断（应用级偏好的真实在线平台清单、观众数能力表），
/// 但不应该认识任何平台适配器实现。适配器注册表
/// `domains/live/data/platforms/sites.dart` 复用同一批常量，避免两处字面量各自
/// 漂移。
abstract final class PlatformIds {
  static const String douyin = 'douyin';
  static const String kuaishou = 'kuaishou';
  static const String cc = 'cc';
  static const String twitch = 'twitch';
  static const String soop = 'soop';
  static const String acfun = 'acfun';
  static const String picarto = 'picarto';
  static const String twitcasting = 'twitcasting';
  static const String bilibili = 'bilibili';
  static const String douyu = 'douyu';
  static const String huya = 'huya';
  static const String iptv = 'iptv';
  static const String yy = 'yy';
}
