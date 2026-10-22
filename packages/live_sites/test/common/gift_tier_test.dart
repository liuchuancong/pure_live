import 'package:live_sites/live_sites.dart';
import 'package:test/test.dart';

/// The yuan table behind "礼物价值换算成元" and the tier behind "只显示值钱的
/// 礼物": what ranks, what never does, and where the two thresholds sit.
void main() {
  test('the thresholds: under 10 yuan normal, 10 valuable, 100 precious', () {
    expect(giftTierOf(LiveGiftUnit.yuan, 9.99), LiveGiftTier.normal);
    expect(giftTierOf(LiveGiftUnit.yuan, 10), LiveGiftTier.valuable);
    expect(giftTierOf(LiveGiftUnit.yuan, 99.99), LiveGiftTier.valuable);
    expect(giftTierOf(LiveGiftUnit.yuan, 100), LiveGiftTier.precious);
  });

  test('a platform currency is ranked through its own rate', () {
    // 1000 gold seeds = 1 yuan; 10000 seeds = 10 yuan.
    expect(giftTierOf(LiveGiftUnit.goldSeed, 10000), LiveGiftTier.valuable);
    // 100 fen = 1 yuan; 100000 fen = 1000 yuan.
    expect(giftTierOf(LiveGiftUnit.fen, 100000), LiveGiftTier.precious);
    // 10 douyin coins = 1 yuan.
    expect(giftTierOf(LiveGiftUnit.douyinCoin, 100), LiveGiftTier.valuable);
    // 14 bits ≈ 1 yuan.
    expect(giftTierOf(LiveGiftUnit.bits, 140), LiveGiftTier.valuable);
    // 100 star coins = 1 yuan.
    expect(giftTierOf(LiveGiftUnit.starCoin, 1000), LiveGiftTier.valuable);
  });

  test('an unrated unit and a missing value stay normal', () {
    for (final unit in [
      LiveGiftUnit.gold,
      LiveGiftUnit.other,
      LiveGiftUnit.redBean,
      LiveGiftUnit.sixCoin,
      LiveGiftUnit.note,
      LiveGiftUnit.silver,
      LiveGiftUnit.banana,
    ]) {
      expect(giftTierOf(unit, 1000000), LiveGiftTier.normal, reason: unit.name);
    }
    expect(giftTierOf(LiveGiftUnit.yuan, null), LiveGiftTier.normal);
    expect(giftTierOf(LiveGiftUnit.yuan, 0), LiveGiftTier.normal);
    expect(giftTierOf(LiveGiftUnit.yuan, -5), LiveGiftTier.normal);
  });

  test('the free units report free, whatever their numbers say', () {
    expect(giftUnitIsFree(LiveGiftUnit.free), isTrue);
    expect(giftUnitIsFree(LiveGiftUnit.silver), isTrue);
    expect(giftUnitIsFree(LiveGiftUnit.banana), isTrue);
    expect(giftUnitIsFree(LiveGiftUnit.goldSeed), isFalse);
    expect(giftShownTier(LiveGiftUnit.silver, 1000000), LiveGiftTier.normal);
  });
}
