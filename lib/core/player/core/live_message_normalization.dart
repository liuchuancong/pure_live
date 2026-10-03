import 'package:pure_live/core/models/live_message.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';

///

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
