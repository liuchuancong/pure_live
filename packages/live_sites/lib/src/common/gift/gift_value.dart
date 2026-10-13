import 'package:live_sites/src/models/live_gift_tier/live_gift_tier.dart';
import 'package:live_sites/src/models/live_gift_unit/live_gift_unit.dart';

/// How many of each unit make about one yuan, for [giftTierOf]. The domestic
/// rates are fixed by the platforms; the overseas ones are rough and only rank
/// gifts, never convert a value shown. A unit missing here is never ranked above
/// [LiveGiftTier.normal].
const Map<LiveGiftUnit, double> giftUnitsPerYuan = {
  LiveGiftUnit.fen: 100,
  LiveGiftUnit.yuan: 1,
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

/// From this many yuan a gift is [LiveGiftTier.valuable].
const int giftValuableYuan = 10;

/// From this many yuan a gift is [LiveGiftTier.precious].
const int giftPreciousYuan = 100;

/// The tier of a gift worth [totalValue] in [unit]: [LiveGiftTier.normal] when
/// [free], without a value or in a unit [giftUnitsPerYuan] does not rate; else by
/// yuan, below [giftValuableYuan] normal, below [giftPreciousYuan] valuable, from
/// it precious.
LiveGiftTier giftTierOf(LiveGiftUnit unit, int? totalValue, {bool free = false}) {
  final rate = giftUnitsPerYuan[unit];
  if (free || rate == null || totalValue == null || totalValue <= 0) return LiveGiftTier.normal;
  final yuan = totalValue / rate;
  if (yuan >= giftPreciousYuan) return LiveGiftTier.precious;
  if (yuan >= giftValuableYuan) return LiveGiftTier.valuable;
  return LiveGiftTier.normal;
}
