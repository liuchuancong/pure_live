/// The kind of a platform notice carried by a `LiveMessageType.notice`
/// message.
enum LiveNoticeKind {
  /// A general system notice.
  system,

  /// A subscription/anchor-related notice.
  subscription,

  /// A raid: a streamer sends their viewers to another room.
  raid,

  /// Viewers gifted subscriptions to each other.
  giftedSubscription,
}
