import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:test/test.dart';

void main() {
  group('LivePlayQuality.displayLabel', () {
    test('a confirmed tier is named as it is', () {
      expect(LivePlayQuality.of(label: '蓝光', qualityId: '400').displayLabel, '蓝光');
    });

    test('a tier the platform did not confirm carries the mark', () {
      final quality = LivePlayQuality.of(label: '蓝光', qualityId: '400', isPlaybackUnconfirmed: true);

      // The mark is display only: the ask sends the id, and a name with a `?`
      // in it would match nothing in the list.
      expect(quality.displayLabel, '蓝光?');
      expect(quality.label, '蓝光');
      expect(quality.qualityId, '400');
    });
  });
}
