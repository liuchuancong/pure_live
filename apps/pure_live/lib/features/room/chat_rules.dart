import 'package:live_sites/live_sites.dart';
import 'package:pure_live/features/room/gift_value.dart' show giftLineVisible;

/// The chat list's rules (the reference's chat-list switches), kept out of
/// the widget so they can be read without a session.
///
/// A gift is a chat line only while its own switch is on — the flying gifts
/// have a separate answer; the quiet types (entries, likes) never take a line.
/// A membership keeps its line and, when asked, also gets a super-chat card.
bool chatLineVisible(LiveMessage message, {required bool showGifts, bool valuableGiftsOnly = false}) =>
    switch (message.type) {
      LiveMessageType.gift =>
        showGifts &&
            giftLineVisible(switch (message.giftOrNull) {
              final LiveGift value => value,
              _ => null,
            }, valuableOnly: valuableGiftsOnly),
      LiveMessageType.chat ||
      LiveMessageType.notice ||
      LiveMessageType.enter ||
      LiveMessageType.leave ||
      LiveMessageType.follow ||
      LiveMessageType.like ||
      LiveMessageType.membershipJoin ||
      LiveMessageType.system => true,
      LiveMessageType.superChat || LiveMessageType.audienceUpdate || LiveMessageType.retraction => false,
    };

/// The super-chat card a membership join also gets, or null when the viewer
/// did not ask for memberships among the super chats or the message names
/// nobody.
LiveSuperChatMessage? membershipCard(LiveMessage message, {required bool include}) {
  if (!include || message.type != LiveMessageType.membershipJoin || message.text.isEmpty) {
    return null;
  }
  final sender = message.effectiveSender;
  return LiveSuperChatMessage(
    messageId: message.messageId,
    userName: sender.userName,
    faceUrl: sender.avatarUrl ?? '',
    text: message.text,
    startTime: message.sentAt,
  );
}
