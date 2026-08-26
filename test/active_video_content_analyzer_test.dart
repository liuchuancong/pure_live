import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/utils/active_video_content_analyzer.dart';

void main() {
  const analyzer = ActiveVideoContentAnalyzer();

  test('finds a portrait programme embedded inside a landscape canvas', () {
    const width = 160;
    const height = 90;
    final pixels = _frame(width, height, (x, y) {
      if (x < 55 || x >= 105) {
        // Sparse bright overlay text in a matte bar must not hide the bar.
        if (y == 20 && x % 13 == 0) return (255, 255, 255);
        return (0, 0, 0);
      }
      return ((x * 5) % 255, (y * 9) % 255, ((x + y) * 3) % 255);
    });

    final result = analyzer.analyzeRgba(pixels, width: width, height: height);

    expect(result, isNotNull);
    expect(result!.insets.left, closeTo(55 / width, 0.04));
    expect(result.insets.right, closeTo(55 / width, 0.04));
    expect(result.insets.top, 0);
    expect(result.insets.applyToAspectRatio(width / height), closeTo(50 / 90, 0.12));
    expect(result.confidence, greaterThanOrEqualTo(0.86));
  });

  test('keeps an ordinary full-frame landscape source untouched', () {
    const width = 160;
    const height = 90;
    final pixels = _frame(width, height, (x, y) => (40 + (x * 3) % 180, 35 + (y * 5) % 180, 45 + ((x + y) * 2) % 180));

    final result = analyzer.analyzeRgba(pixels, width: width, height: height);

    expect(result, isNotNull);
    expect(result!.insets.hasCrop, isFalse);
    expect(result.confidence, greaterThanOrEqualTo(0.86));
  });

  test('does not treat a uniformly dark scene as letterbox evidence', () {
    const width = 160;
    const height = 90;
    final pixels = _frame(width, height, (x, y) => (7 + x % 3, 8 + y % 3, 9));

    final result = analyzer.analyzeRgba(pixels, width: width, height: height);

    expect(result, isNull);
  });
}

Uint8List _frame(int width, int height, (int, int, int) Function(int x, int y) pixel) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final (r, g, b) = pixel(x, y);
      final offset = (y * width + x) * 4;
      bytes[offset] = r;
      bytes[offset + 1] = g;
      bytes[offset + 2] = b;
      bytes[offset + 3] = 255;
    }
  }
  return bytes;
}
