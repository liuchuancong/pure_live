import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/background_playback_policy.dart';

void main() {
  group('BackgroundPlaybackPolicy', () {
    test('ordinary video pauses when every background option is off', () {
      expect(
        BackgroundPlaybackPolicy.shouldContinue(
          backgroundPlaybackEnabled: false,
          sleepSessionActive: false,
          audioOnlySessionActive: false,
        ),
        isFalse,
      );
    });

    test('manual audio-only session keeps playing without global toggle', () {
      expect(
        BackgroundPlaybackPolicy.shouldContinue(
          backgroundPlaybackEnabled: false,
          sleepSessionActive: false,
          audioOnlySessionActive: true,
        ),
        isTrue,
      );
    });

    test('global background playback or sleep session keeps playing', () {
      expect(
        BackgroundPlaybackPolicy.shouldContinue(
          backgroundPlaybackEnabled: true,
          sleepSessionActive: false,
          audioOnlySessionActive: false,
        ),
        isTrue,
      );
      expect(
        BackgroundPlaybackPolicy.shouldContinue(
          backgroundPlaybackEnabled: false,
          sleepSessionActive: true,
          audioOnlySessionActive: false,
        ),
        isTrue,
      );
    });
  });
}
