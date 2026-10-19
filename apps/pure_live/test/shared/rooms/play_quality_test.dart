import 'package:flutter_test/flutter_test.dart';
import 'package:live_sites/live_sites.dart' show LivePlayQuality, LiveStreamCodec;
import 'package:pure_live/shared/rooms/play_quality.dart';

LivePlayQuality _q(String label, {LiveStreamCodec? codec}) => LivePlayQuality(label: label, codec: codec);

void main() {
  group('defaultQualityIndex', () {
    test('the labelled quality wins when the platform names it', () {
      final qualities = [_q('原画'), _q('超清'), _q('流畅')];
      expect(defaultQualityIndex(qualities, '超清'), 1);
    });

    test('an unlabelled preference takes the same relative position', () {
      final qualities = [_q('HD'), _q('SD'), _q('LOW')];
      // 流畅 is the worst of the five names → the last of three.
      expect(defaultQualityIndex(qualities, '流畅'), 2);
      expect(defaultQualityIndex(qualities, '原画'), 0);
    });

    test('preferH264 passes an HEVC name match while other codecs are on offer', () {
      final qualities = [_q('原画', codec: LiveStreamCodec.hevc), _q('蓝光4M'), _q('流畅')];
      expect(defaultQualityIndex(qualities, '原画'), 0);
      expect(defaultQualityIndex(qualities, '原画', preferH264: true), 1);
    });

    test('preferH264 still lands on HEVC when nothing else exists', () {
      final qualities = [_q('原画', codec: LiveStreamCodec.hevc), _q('流畅', codec: LiveStreamCodec.hevc)];
      expect(defaultQualityIndex(qualities, '原画', preferH264: true), 0);
    });

    test('an empty list is index zero, not a throw', () {
      expect(defaultQualityIndex(const [], '原画'), 0);
    });
  });

  group('videoFits', () {
    test('the stored index round-trips through the menu helper', () {
      expect(videoFits, hasLength(6));
      for (final (index, fit) in videoFits.indexed) {
        expect(videoFitIndexOf(fit), index);
      }
    });
  });
}
