import 'package:live_sites/src/models/enums/live_stream_codec.dart';
import 'package:live_sites/src/models/play/live_play_quality/live_play_quality.dart';
import 'package:live_sites/src/models/play/live_playback_plan/live_playback_plan.dart';
import 'package:test/test.dart';

// The rule under test reads only the plan's quality facts; its lines belong
// to the playback read, not to the tier the room is shown.
LivePlaybackPlan _planOf({LivePlayQuality? applied, bool unconfirmed = false}) =>
    LivePlaybackPlan.of(appliedQuality: applied, qualityUnconfirmed: unconfirmed, lines: const []);

void main() {
  final list = [
    LivePlayQuality.of(label: '原画', qualityId: '10000'),
    LivePlayQuality.of(label: '高清', qualityId: '400'),
    LivePlayQuality.of(label: '标清', qualityId: '250'),
  ];
  final asked = list[0];

  group('resolveServedPlayQuality', () {
    test('the tier the platform names is returned as the entry the list holds', () {
      final served = resolveServedPlayQuality(
        plan: _planOf(
          applied: LivePlayQuality.of(label: '高清 720P', qualityId: '400'),
        ),
        qualities: list,
        requested: asked,
      );

      // Identity is the list's own entry: its label wins over the answer's
      // spelling, because the viewer knows the picker's words.
      expect(served, same(list[1]));
    });

    test('a tier the list never offered takes the asked entry place', () {
      final served = resolveServedPlayQuality(
        plan: _planOf(
          applied: LivePlayQuality.of(label: '60帧', qualityId: '20000'),
        ),
        qualities: list,
        requested: asked,
      );

      expect(served?.qualityId, '20000');
    });

    test('a tier equal to the ask changes nothing', () {
      expect(
        resolveServedPlayQuality(
          plan: _planOf(applied: asked),
          qualities: list,
          requested: asked,
        ),
        same(asked),
      );
    });

    test('an answer that does not name its tier is not guessed', () {
      expect(resolveServedPlayQuality(plan: _planOf(unconfirmed: true), qualities: list, requested: asked), isNull);
      expect(resolveServedPlayQuality(plan: _planOf(), qualities: list, requested: asked), isNull);
    });

    test('with no ids to compare, the label decides', () {
      expect(isSamePlayTier(LivePlayQuality.of(label: '高清'), LivePlayQuality.of(label: '高清')), isTrue);
      expect(
        isSamePlayTier(LivePlayQuality.of(label: '高清', codec: LiveStreamCodec.avc), LivePlayQuality.of(label: '流畅')),
        isFalse,
      );
    });
  });
}
