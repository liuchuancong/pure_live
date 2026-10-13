/// What a `LiveGift` is.
enum LiveGiftKind {
  /// A gift sent to the broadcaster (or a guest).
  gift,

  /// A paid membership bought or renewed: Bilibili's guard (`GUARD_BUY`:
  /// 舰长, 提督, 总督), YouTube or Twitch memberships. The gift's `count` is the
  /// number of months.
  membership,

  /// Subscriptions gifted to other viewers (Twitch `subgift`, Kick's gifted
  /// subscriptions). The gift's `count` is how many were given.
  subscription,

  /// Money given without a gift item (Twitch Bits, SOOP's balloons, FC2 tips).
  /// The gift's `name` names the currency.
  tip,
}
