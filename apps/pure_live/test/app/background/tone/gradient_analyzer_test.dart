import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/app/background/tone/analysis/background_gradient.dart';
import 'package:pure_live/app/background/tone/analysis/background_models.dart';

const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);

void main() {
  group('gradient direction', () {
    test('a 0° gradient runs from the bottom to the top', () {
      final result = backgroundAnalyzeGradient(
        colors: const [_black, _white],
        stops: const [0, 1],
        deg: 0,
        underlay: _black,
      );
      expect(result.source, BackgroundSampleSource.gradient);
      expect(result.regions[0].profile.p90, closeTo(1, 0.001));
      expect(result.regions[6].profile.p10, closeTo(0, 0.001));
      expect(result.regions[0].profile.mean, greaterThan(result.regions[6].profile.mean));
    });

    test('a 90° gradient runs from the left to the right', () {
      final result = backgroundAnalyzeGradient(
        colors: const [_black, _white],
        stops: const [0, 1],
        deg: 90,
        underlay: _black,
      );
      expect(result.regions[2].profile.mean, greaterThan(result.regions[0].profile.mean));
      expect(result.regions[2].profile.p90, closeTo(1, 0.001));
      expect(result.regions[6].profile.p10, closeTo(0, 0.001));
    });
  });

  group('stops and alpha', () {
    test('stops decide how much of the line each colour owns', () {
      final even = backgroundAnalyzeGradient(
        colors: const [_black, _white],
        stops: const [0, 1],
        deg: 0,
        underlay: _black,
      );
      final early = backgroundAnalyzeGradient(
        colors: const [_black, _white],
        stops: const [0, 0.2],
        deg: 0,
        underlay: _black,
      );
      expect(early.profile.mean, greaterThan(even.profile.mean));
    });

    test('a transparent stop is measured over the page colour', () {
      final result = backgroundAnalyzeGradient(
        colors: const [Color(0x00000000), Color(0xFFFF0000)],
        stops: const [0, 1],
        deg: 0,
        underlay: _white,
      );
      expect(result.regions[6].profile.p90, closeTo(1, 0.001));
      expect(result.regions[0].profile.mean, greaterThan(0.2126));
      expect(result.regions[6].profile.mean, greaterThan(result.regions[0].profile.mean));
    });

    test('a gradient with uneven stops is made non-decreasing', () {
      final result = backgroundAnalyzeGradient(
        colors: const [_black, _white, _black],
        stops: const [0, 0.4, 0.2],
        deg: 0,
        underlay: _black,
      );
      expect(result.regions[0].profile.mean, closeTo(0, 0.001));
    });
  });

  group('degenerate paints', () {
    test('a single colour fills every region', () {
      final result = backgroundAnalyzeGradient(colors: const [_white], stops: null, deg: 0, underlay: _black);
      expect(result.profile.mean, 1);
      expect(result.regions, hasLength(9));
      expect(result.regions.every((region) => region.profile.mean == 1), isTrue);
    });
  });
}
