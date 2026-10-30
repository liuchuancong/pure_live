import 'dart:typed_data' show Uint8List;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/app/background/tone/analysis/background_luminance.dart';
import 'package:pure_live/app/background/tone/analysis/background_pixels.dart';

/// Straight-alpha RGBA bytes in row-major order.
Uint8List _rgba(List<List<int>> pixels) {
  final bytes = Uint8List(pixels.length * 4);
  for (var index = 0; index < pixels.length; index++) {
    bytes.setRange(index * 4, index * 4 + 4, pixels[index]);
  }
  return bytes;
}

void main() {
  group('luminance profile', () {
    test('a black surface is all dark and lives in the first bin', () {
      final profile = backgroundProfileOf(const [0, 0, 0, 0]);
      expect(profile.mean, 0);
      expect(profile.median, 0);
      expect(profile.darkRatio, 1);
      expect(profile.brightRatio, 0);
      expect(profile.histogram.first, 1);
      expect(profile.histogram.skip(1), everyElement(0));
    });

    test('two hands split the profile evenly', () {
      final profile = backgroundProfileOf(const [0, 1]);
      expect(profile.mean, 0.5);
      expect(profile.median, 0.5);
      expect(profile.p10, closeTo(0.1, 1e-9));
      expect(profile.p90, closeTo(0.9, 1e-9));
      expect(profile.darkRatio, 0.5);
      expect(profile.brightRatio, 0.5);
      expect(profile.histogram.first, 0.5);
      expect(profile.histogram.last, 0.5);
    });

    test('out-of-range values are clamped before measuring', () {
      final profile = backgroundProfileOf(const [-1, 2]);
      expect(profile.mean, 0.5);
      expect(profile.p10, closeTo(0.1, 1e-9));
      expect(profile.p90, closeTo(0.9, 1e-9));
    });

    test('an empty sample has a zeroed profile', () {
      final profile = backgroundProfileOf(const <double>[]);
      expect(profile.mean, 0);
      expect(profile.histogram, everyElement(0));
    });
  });

  group('RGBA analysis', () {
    test('a transparent pixel is measured over the page, not as its own colour', () {
      final result = backgroundAnalyzeRgba(
        rgba: _rgba([
          [255, 0, 0, 0],
          [255, 255, 255, 255],
        ]),
        width: 2,
        height: 1,
        underlay: const Color(0xFFFFFFFF),
      );
      expect(result.profile.mean, 1);
      expect(result.regions, hasLength(9));
    });

    test('straight alpha is composited before the mean is taken', () {
      final result = backgroundAnalyzeRgba(
        rgba: _rgba([
          [0, 0, 0, 255],
          [255, 255, 255, 255],
        ]),
        width: 2,
        height: 1,
        underlay: const Color(0xFFFFFFFF),
      );
      expect(result.profile.mean, 0.5);
      expect(result.representative.a, 1);
      expect(result.representative.r, closeTo(0.5, 0.01));
    });

    test('a malformed buffer falls back to the page colour', () {
      final result = backgroundAnalyzeRgba(rgba: Uint8List(0), width: 2, height: 2, underlay: const Color(0xFF123456));
      expect(result.profile.mean, relativeLuminanceOf(const Color(0xFF123456)));
      expect(result.regions, hasLength(9));
    });
  });
}
