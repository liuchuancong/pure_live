import 'package:live_sites/src/common/quality_label.dart';
import 'package:test/test.dart';

void main() {
  group('LiveQualityLabel.normalize', () {
    test("a platform's own Chinese word is kept", () {
      expect(LiveQualityLabel.normalize(platform: 'douyu', rawLabel: '超清  2M'), '超清 2M');
    });

    test('an English token becomes the tier name the app already uses', () {
      // TwitCasting names its tiers high / medium / low; the picker used to
      // show `HLS high` beside 超清/蓝光 everywhere else.
      expect(LiveQualityLabel.normalize(platform: 'twitcasting', rawLabel: 'high'), '高清');
      expect(LiveQualityLabel.normalize(platform: 'twitcasting', rawLabel: 'medium'), '标清');
      expect(LiveQualityLabel.normalize(platform: 'twitcasting', rawLabel: 'low'), '流畅');
    });

    test('a source tier is named 原画, an unnamed one 默认', () {
      expect(LiveQualityLabel.normalize(platform: 'douyin', rawLabel: 'source'), '原画');
      expect(LiveQualityLabel.normalize(platform: 'douyu', rawLabel: 'default'), '默认');
    });

    test('bilibili codes are read as codes', () {
      expect(LiveQualityLabel.normalize(platform: 'bilibili', rawLabel: '', id: 20000), '4K');
      expect(LiveQualityLabel.normalize(platform: 'bilibili', rawLabel: '', id: 30000), '杜比');
      expect(LiveQualityLabel.normalize(platform: 'bilibili', rawLabel: '', id: 400), '蓝光');

      // A code no table names still says what it is, but never as a bare
      // number a viewer cannot tell from a bitrate or an id.
      expect(LiveQualityLabel.normalize(platform: 'bilibili', rawLabel: '', id: 6000), '清晰度 6000');
    });

    test('a resolution is named by its short side', () {
      expect(LiveQualityLabel.normalize(platform: 'niconico', rawLabel: '', resolution: '1280x720'), '720P 清晰');
      expect(LiveQualityLabel.normalize(platform: 'niconico', rawLabel: '', resolution: '3840x2160'), '4K');
    });

    test('the last resort is the bitrate, then the id, then 默认', () {
      expect(LiveQualityLabel.normalize(platform: 'kick', rawLabel: '', bitrate: 4500000), '4.5 Mbps');
      expect(LiveQualityLabel.normalize(platform: 'kick', rawLabel: '', id: 't1016'), '清晰度 t1016');
      expect(LiveQualityLabel.normalize(platform: 'kick', rawLabel: ''), '默认');
    });

    test('an unnamed tier never answers with nothing', () {
      // Douyu's `multirates` row without a `name` used to reach the picker as
      // an empty string - a blank row beside the named ones.
      expect(LiveQualityLabel.normalize(platform: 'douyu', rawLabel: '', id: 2000), isNotEmpty);
    });
  });
}
