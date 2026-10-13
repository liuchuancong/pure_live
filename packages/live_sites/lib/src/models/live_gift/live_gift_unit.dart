/// The unit of a `LiveGift`'s unit price and total value: each platform's own
/// currency, kept as the platform counts it. How many make a yuan is only in
/// `giftUnitsPerYuan`.
enum LiveGiftUnit {
  /// Fen, a hundredth of a yuan (Douyu's gift table prices).
  fen,

  /// Whole yuan: the super chats of Bilibili, Douyu and Huya, and a Bilibili
  /// guard's card.
  yuan,

  /// Bilibili gold seeds (金瓜子).
  goldSeed,

  /// Bilibili silver seeds (银瓜子), which free gifts cost.
  silverSeed,

  /// Missevan diamonds (钻石).
  diamond,

  /// KilaKila red beans (红豆).
  redBean,

  /// Points: niconico, 17LIVE, FC2.
  point,

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

  /// Six Rooms coins (六币).
  sixCoin,

  /// AcFun's AC coins (AC币), ten to a yuan.
  acCoin,

  /// AcFun's bananas (香蕉), the platform's free currency.
  banana,

  /// Kugou Live's star coins (星币), a hundred to a yuan.
  starCoin,

  /// PandaTV's hearts (하트).
  heart,

  /// LOOK's notes (音符).
  note,

  /// A unit the platform does not document, or no value at all.
  other,
}
