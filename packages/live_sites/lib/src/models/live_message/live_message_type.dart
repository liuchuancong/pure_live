/// Kind of a danmaku message.
enum LiveMessageType {
  /// Chat.
  chat,

  /// A gift, membership, gifted subscription or tip; the message's `data` holds
  /// it as a `LiveGift` (a platform's subclass), the text is the gift's
  /// `plainText`. Local gifts hold the local interaction's map.
  gift,

  /// Audience update; the message's `data` holds a `LiveAudienceUpdate`.
  online,

  /// Super chat.
  superChat,

  /// Takes back messages shown earlier (a moderator deleted one, or cleared a
  /// user's or the whole chat); the message's `data` holds a `LiveRetraction`.
  retraction,

  /// A platform notice shown as a line of its own; the message's `data` holds
  /// its `LiveNoticeKind`, the message text the notice.
  notice,
}
