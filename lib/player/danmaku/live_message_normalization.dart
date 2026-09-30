import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:pure_live/common/models/live_message.dart';

/// LiveMessage → media_core_danmaku 的 [DanmakuMessage] 归一化。
///
/// 渲染仍由 pure_live 的 flame_barrage 承担；传输层的去重/积压闸门/
/// 相似过滤/会话围栏统一走 media_core_danmaku。
DanmakuMessage normalizeLiveMessage(LiveMessage message) {
  return DanmakuMessage(
    type: switch (message.type) {
      LiveMessageType.chat => DanmakuMessageType.chat,
      LiveMessageType.gift => DanmakuMessageType.gift,
      _ => DanmakuMessageType.system,
    },
    userName: message.userName,
    text: message.message,
    color: DanmakuColor(message.color.r, message.color.g, message.color.b),
    userId: message.userId,
    userLevel: message.userLevel,
    fansLevel: message.fansLevel,
    fansName: message.fansName,
    isLocal: message.isLocal,
    messageId: message.messageId,
    sentAt: message.sentAt,
  );
}
