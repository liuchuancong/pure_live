/// The kind of one danmaku message.
///
/// The kind decides the concrete type of `LiveMessage.payload` — the contract
/// is MODELS.md §5.
enum LiveMessageType {
  /// A chat message.
  chat,

  /// A gift; payload holds a LiveGift (a local gift holds a Map) and the
  /// text is the gift's plain text.
  gift,

  /// An audience update; payload holds a LiveAudienceUpdate (older engines
  /// may send a bare number).
  audienceUpdate,

  /// A super chat; payload stays null — super chats arrive through a
  /// dedicated list API, not the danmaku stream.
  superChat,

  /// Takes back messages shown earlier; payload holds a LiveRetraction.
  retraction,

  /// A platform notice shown as a line of its own; payload holds a
  /// LiveNoticeKind and the text is the notice.
  notice,

  /// A viewer entered the room.
  enter,

  /// A viewer left the room.
  leave,

  /// A viewer followed the streamer.
  follow,

  /// A viewer liked the stream.
  like,

  /// A viewer joined the fan club / membership tiers (bilibili guard,
  /// douyin fan club, douyu noble); distinct from gift because it changes
  /// an identity, not just a balance.
  membershipJoin,

  /// A system broadcast (stream start, mute, mic cut).
  system,
}
