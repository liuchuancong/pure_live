import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/modules/live_play/local_interaction_controller.dart';

void main() {
  group('local interaction profile', () {
    test('normalizes nickname length and whitespace', () {
      expect(LocalInteractionController.normalizeUserName('  listener  '), 'listener');
      expect(LocalInteractionController.normalizeUserName('   '), isEmpty);
      expect(LocalInteractionController.normalizeUserName('12345678901234567890123'), '12345678901234567890');
    });

    test('calculates a stable local level', () {
      expect(LocalInteractionController.levelForExperience(-1), 1);
      expect(LocalInteractionController.levelForExperience(0), 1);
      expect(LocalInteractionController.levelForExperience(499), 1);
      expect(LocalInteractionController.levelForExperience(500), 2);
      expect(LocalInteractionController.levelForExperience(1500), 4);
    });

    test('selects a platform-specific gift and badge catalogue', () {
      final bilibili = LocalInteractionController.giftsForPlatform(Sites.bilibiliSite);
      final douyin = LocalInteractionController.giftsForPlatform(Sites.douyinSite);
      final twitch = LocalInteractionController.giftsForPlatform(Sites.twitchSite);

      expect(bilibili.map((gift) => gift.id), contains('bili_voyage'));
      expect(douyin.map((gift) => gift.id), contains('douyin_carnival'));
      expect(bilibili.map((gift) => gift.id).toSet(), isNot(douyin.map((gift) => gift.id).toSet()));
      expect(LocalInteractionController.platformBadgeKey(Sites.huyaSite), 'local_badge_huya');
      expect(twitch.map((gift) => gift.id), contains('twitch_hype_train'));
      expect(LocalInteractionController.platformBadgeKey(Sites.twitchSite), 'local_badge_twitch');
    });
  });
}
