/// The unit a gift's price is denominated in.
///
/// [free] means the gift has no value at all: `unitPrice`/`totalValue` carry
/// no meaning for it (the deleted `free` boolean was a second state for the
/// same fact, MODELS.md §3.16).
enum LiveGiftUnit {
  /// A platform's free currency (bilibili melon seeds, huya free beans).
  silver,

  /// A platform's paid currency (batteries, huya coins, douyin coins).
  gold,

  /// Chinese yuan.
  rmb,

  /// Points / intimacy score.
  point,

  /// No value.
  free,

  /// Anything else.
  other,
}
