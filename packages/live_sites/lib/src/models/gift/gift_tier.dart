import 'package:live_sites/src/models/enums/live_gift_unit.dart';

/// How much a gift is worth, as a hint for the gift line and for the chat
/// list's 只显示值钱的礼物 (the reference's `LiveGiftTier`, V03.5 §6.1, A08.12).
enum LiveGiftTier {
  /// Free, cheap, or of a value this app cannot place (an unknown rate).
  normal,

  /// Worth a mark of its own.
  valuable,

  /// Worth the strongest mark.
  precious,
}

/// How many of each unit make about one yuan, for [giftTierOf] (V03.5 §6.1,
/// §6.5). The domestic rates are fixed by the platforms; the overseas ones
/// are rough (100 Bits or 100 Kicks about a US dollar, cheese one won, a
/// star balloon or a PandaTV heart about 110 won, a niconico point about a
/// yen) and only rank gifts, never convert a value shown.
///
/// A unit missing here (red beans, six coins, LOOK's notes, silver seeds,
/// bananas, [LiveGiftUnit.gold], [LiveGiftUnit.other]) is never ranked above
/// [LiveGiftTier.normal].
const Map<LiveGiftUnit, double> giftUnitsPerYuan = {
  LiveGiftUnit.fen: 100,
  LiveGiftUnit.yuan: 1,
  LiveGiftUnit.rmb: 1,
  LiveGiftUnit.goldSeed: 1000,
  LiveGiftUnit.diamond: 10,
  LiveGiftUnit.douyinCoin: 10,
  LiveGiftUnit.acCoin: 10,
  LiveGiftUnit.starCoin: 100,
  LiveGiftUnit.bits: 14,
  LiveGiftUnit.kicks: 14,
  LiveGiftUnit.cheese: 190,
  LiveGiftUnit.starBalloon: 1.7,
  LiveGiftUnit.heart: 1.7,
  LiveGiftUnit.point: 21,
};

/// From this many yuan a gift is [LiveGiftTier.valuable] (V03.5 §6.1).
const double giftValuableYuan = 10;

/// From this many yuan a gift is [LiveGiftTier.precious] (V03.5 §6.1).
const double giftPreciousYuan = 100;

/// The tier of a gift worth [totalValue] in [unit]: [LiveGiftTier.normal]
/// when free ([unit] is `free` or `silver`/`banana`), without a value, or in
/// a unit [giftUnitsPerYuan] does not rate; else by yuan, below
/// [giftValuableYuan] normal, below [giftPreciousYuan] valuable, from it
/// precious.
LiveGiftTier giftTierOf(LiveGiftUnit unit, double? totalValue) {
  final rate = giftUnitsPerYuan[unit];
  if (rate == null || totalValue == null || totalValue <= 0) {
    return LiveGiftTier.normal;
  }
  final yuan = totalValue / rate;
  if (yuan >= giftPreciousYuan) {
    return LiveGiftTier.precious;
  }
  if (yuan >= giftValuableYuan) {
    return LiveGiftTier.valuable;
  }
  return LiveGiftTier.normal;
}

/// Whether a gift's [unit] counts as free: the free sentinel, or one of the
/// platforms' own free currencies ([LiveGiftUnit.silver], [LiveGiftUnit.banana]).
bool giftUnitIsFree(LiveGiftUnit unit) =>
    unit == LiveGiftUnit.free || unit == LiveGiftUnit.silver || unit == LiveGiftUnit.banana;

/// The tier of [totalValue] in [unit] as a gift line shows it, treating the
/// free units as [LiveGiftTier.normal] whatever the numbers say.
LiveGiftTier giftShownTier(LiveGiftUnit unit, double? totalValue) =>
    giftTierOf(unit, giftUnitIsFree(unit) ? null : totalValue);
