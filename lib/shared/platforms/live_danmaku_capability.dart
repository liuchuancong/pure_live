import 'package:pure_live/shared/platforms/danmaku_emoji.dart';

/// 站点的弹幕细节。
///
/// 通用弹幕代码只问站点能力，不再维护平台名单或 `case Sites.xSite:` 分支：站点
/// 用 [LiveDanmakuCapabilityDefaults] 拿到全部默认值，只覆写自己真正不同的部分。
abstract interface class LiveDanmakuCapability {
  /// 进入房间时是否建立弹幕连接。
  ///
  /// 没有弹幕来源的房间连上只会提示"远程弹幕未接入"，这类站点显式不连。
  bool get connectsDanmakuOnRoomEntry;

  /// 站点专有的昵称提示，返回本地化 key；没有则为 null。
  String? danmakuUserNameNoticeKey(String userName);

  /// 站点专有的弹幕表情解析；不提供表情的站点返回 null。
  UnifiedEmojiModel? parseDanmakuEmoji(Map<String, dynamic> json, String fallbackKey);
}

/// [LiveDanmakuCapability] 的默认实现。
///
/// 站点这样用：`class XSite with LiveDanmakuCapabilityDefaults, XDanmakuCapability ...`，
/// 只在 `XDanmakuCapability` 里覆写与默认不同的成员。
mixin LiveDanmakuCapabilityDefaults implements LiveDanmakuCapability {
  @override
  bool get connectsDanmakuOnRoomEntry => true;

  @override
  String? danmakuUserNameNoticeKey(String userName) => null;

  @override
  UnifiedEmojiModel? parseDanmakuEmoji(Map<String, dynamic> json, String fallbackKey) => null;
}
