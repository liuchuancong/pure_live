/// The unit a gift's price is denominated in.
///
/// [free] means the gift has no value at all: `unitPrice`/`totalValue` carry
/// no meaning for it (the deleted `free` boolean was a second state for the
/// same fact, MODELS.md §3.16).
///
/// The fine units (everything after [other]) are the platforms' own
/// currencies, kept as the platform counts them; how many make a yuan is
/// `giftUnitsPerYuan`'s business, not the unit's. [gold] stays for a paid
/// currency whose rate in yuan is unknown, so it is never ranked.
enum LiveGiftUnit {
  /// A platform's free currency (bilibili melon seeds, huya free beans).
  silver,

  /// A platform's paid currency whose rate in yuan is unknown, so it is
  /// never ranked.
  gold,

  /// Chinese yuan.
  rmb,

  /// Points / intimacy score.
  point,

  /// No value.
  free,

  /// Anything else.
  other,

  /// Fen, a hundredth of a yuan (Douyu's gift-table prices).
  fen,

  /// Whole yuan (a super chat's or a guard card's price).
  yuan,

  /// Bilibili gold seeds (金瓜子).
  goldSeed,

  /// Missevan diamonds (钻石).
  diamond,

  /// KilaKila red beans (红豆).
  redBean,

  /// Twitch Bits.
  bits,

  /// Kick's Kicks.
  kicks,

  /// CHZZK cheese (치즈).
  cheese,

  /// SOOP star balloons (별풍선).
  starBalloon,

  /// Douyin coins (抖币).
  douyinCoin,

  /// Six Rooms coins (六币); the rate is not checked, so never ranked.
  sixCoin,

  /// AcFun's AC coins (AC币), ten to a yuan.
  acCoin,

  /// AcFun's bananas (香蕉), the platform's free currency.
  banana,

  /// Kugou Live's star coins (星币), a hundred to a yuan.
  starCoin,

  /// PandaTV's hearts (하트).
  heart,

  /// LOOK's notes (音符); the rate is not checked, so never ranked.
  note,
}
