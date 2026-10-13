/// How much a `LiveGift` is worth (`giftTierOf`), as a hint for the gift line
/// and effects to come.
enum LiveGiftTier {
  /// Free, cheap, or of a value this app cannot place.
  normal,

  /// Worth a mark of its own.
  valuable,

  /// Worth the strongest mark.
  precious,
}
