import 'package:pure_live/core/sites.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';

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

    test('normalizes rich local danmaku style values', () {
      final style = LocalInteractionController.buildDanmakuStyle(
        fontSize: 60,
        speed: 20,
        fontWeight: 1200,
        showStroke: false,
        strokeWidth: 9,
      );

      expect(style.fontSize, 32);
      expect(style.baseSpeed, 60);
      expect(style.fontWeight, 900);
      expect(style.showStroke, isFalse);
      expect(style.strokeWidth, 0);
      expect(LocalInteractionController.danmakuPresets.map((preset) => preset.id), [
        'clean',
        'highlight',
        'neon',
        'minimal',
      ]);
    });

    test('selects a platform-specific gift and badge catalogue', () {
      final bilibili = LocalInteractionController.giftsForPlatform(Sites.bilibiliSite);
      final douyin = LocalInteractionController.giftsForPlatform(Sites.douyinSite);
      final twitch = LocalInteractionController.giftsForPlatform(Sites.twitchSite);
      final soop = LocalInteractionController.giftsForPlatform(Sites.soopSite);

      expect(bilibili.map((gift) => gift.id), contains('bili_voyage'));
      expect(douyin.map((gift) => gift.id), contains('douyin_carnival'));
      expect(bilibili.map((gift) => gift.id).toSet(), isNot(douyin.map((gift) => gift.id).toSet()));
      expect(LocalInteractionController.platformBadgeKey(Sites.huyaSite), 'local_badge_huya');
      expect(twitch.map((gift) => gift.id), contains('twitch_hype_train'));
      expect(LocalInteractionController.platformBadgeKey(Sites.twitchSite), 'local_badge_twitch');
      expect(soop.map((gift) => gift.id), contains('soop_signature_balloon'));
      expect(LocalInteractionController.platformBadgeKey(Sites.soopSite), 'local_badge_soop');
    });
  });
}
