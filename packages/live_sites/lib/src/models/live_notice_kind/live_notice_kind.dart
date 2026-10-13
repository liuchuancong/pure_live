/// Kind of a platform notice shown as its own line.
enum LiveNoticeKind {
  /// A message from the platform or the room (rules, announcements).
  system,

  /// A viewer subscribed, renewed or gifted subscriptions or memberships (Twitch
  /// subscriptions, YouTube memberships, CHZZK, Kick and Picarto subscriptions):
  /// the purchase itself, once.
  subscription,

  /// Another channel brought its viewers over.
  raid,

  /// A viewer received one of the subscriptions or memberships another gifted to
  /// the community (Twitch's `subgift` of a community gift, YouTube's gift
  /// redemption): the giver's own `subscription` notice counts the gift, so this
  /// one is never a super chat card.
  giftedSubscription,
}
