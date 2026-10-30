import 'dart:typed_data' show Uint8List;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/app/background/tone/analysis/background_luminance.dart';
import 'package:pure_live/app/background/tone/analysis/background_pixels.dart';
import 'package:pure_live/app/background/tone/analysis/background_regions.dart';

/// Straight-alpha RGBA bytes in row-major order.
Uint8List _rgba(List<List<int>> pixels) {
  final bytes = Uint8List(pixels.length * 4);
  for (var index = 0; index < pixels.length; index++) {
    bytes.setRange(index * 4, index * 4 + 4, pixels[index]);
  }
  return bytes;
}

const _black = [0, 0, 0, 255];
const _white = [255, 255, 255, 255];

void main() {
  group('region geometry', () {
    test('the nine cells tile the surface row-major', () {
      expect(kBackgroundRegionCount, 9);
      expect(backgroundRegionRect(0).topLeft, Offset.zero);
      expect(backgroundRegionRect(8).left, closeTo(2 / 3, 1e-9));
      expect(backgroundRegionRect(8).top, closeTo(2 / 3, 1e-9));
      expect(backgroundRegionRect(8).width, closeTo(1 / 3, 1e-9));
    });

    test('a result names its own row and column', () {
      final regions = backgroundRegionsOf(
        width: 3,
        height: 3,
        lumas: List<double>.filled(9, 0),
        colors: List<Color>.filled(9, const Color(0xFF000000)),
      );
      expect(regions[4].row, 1);
      expect(regions[4].column, 1);
      expect(regions[8].row, 2);
      expect(regions[8].column, 2);
    });
  });

  group('region measurement', () {
    test('each cell measures its own pixels', () {
      final pixels = [
        for (var index = 0; index < 9; index++)
          if (index == 4) _white else _black,
      ];
      final result = backgroundAnalyzeRgba(rgba: _rgba(pixels), width: 3, height: 3, underlay: const Color(0xFF000000));
      expect(result.regions, hasLength(9));
      expect(result.regions[4].profile.mean, 1);
      expect(result.regions[4].dark, isFalse);
      expect(result.regions[0].profile.mean, 0);
      expect(result.regions[0].dark, isTrue);
      expect(result.regions[0].ink, kBackgroundLightInk);
    });

    test('a bright top row and a dark bottom row stay separate', () {
      final pixels = [
        for (var row = 0; row < 3; row++)
          for (var column = 0; column < 6; column++)
            if (row == 0) _white else _black,
      ];
      final result = backgroundAnalyzeRgba(rgba: _rgba(pixels), width: 6, height: 3, underlay: const Color(0xFF000000));
      for (var column = 0; column < 3; column++) {
        expect(result.regions[column].profile.mean, 1);
        expect(result.regions[6 + column].profile.mean, 0);
      }
      expect(result.profile.mean, closeTo(1 / 3, 1e-9));
    });
  });
}
