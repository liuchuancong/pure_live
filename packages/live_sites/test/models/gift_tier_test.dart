import 'package:live_sites/src/models/enums/live_gift_unit.dart';
import 'package:live_sites/src/models/gift/gift_tier.dart';
import 'package:test/test.dart';

void main() {
  group('gift tiers (the reference thresholds)', () {
    test('ten yuan is valuable, a hundred is precious', () {
      expect(giftTierOf(LiveGiftUnit.yuan, 9.99), LiveGiftTier.normal);
      expect(giftTierOf(LiveGiftUnit.yuan, 10), LiveGiftTier.valuable);
      expect(giftTierOf(LiveGiftUnit.yuan, 99.99), LiveGiftTier.valuable);
      expect(giftTierOf(LiveGiftUnit.yuan, 100), LiveGiftTier.precious);
    });

    test('each unit is ranked by its own rate', () {
      expect(giftTierOf(LiveGiftUnit.bits, 140), LiveGiftTier.valuable);
      expect(giftTierOf(LiveGiftUnit.goldSeed, 1000), LiveGiftTier.normal);
      expect(giftTierOf(LiveGiftUnit.goldSeed, 10000), LiveGiftTier.valuable);
      expect(giftTierOf(LiveGiftUnit.cheese, 1900), LiveGiftTier.valuable);
    });

    test('an unrated, free or worthless gift is never ranked', () {
      expect(giftTierOf(LiveGiftUnit.sixCoin, 100000), LiveGiftTier.normal);
      expect(giftTierOf(LiveGiftUnit.other, 100000), LiveGiftTier.normal);
      expect(giftTierOf(LiveGiftUnit.yuan, null), LiveGiftTier.normal);
      expect(giftTierOf(LiveGiftUnit.yuan, 0), LiveGiftTier.normal);
      expect(giftShownTier(LiveGiftUnit.free, 100000), LiveGiftTier.normal);
      expect(giftShownTier(LiveGiftUnit.silver, 100000), LiveGiftTier.normal);
      expect(giftShownTier(LiveGiftUnit.yuan, 100), LiveGiftTier.precious);
    });
  });
}
