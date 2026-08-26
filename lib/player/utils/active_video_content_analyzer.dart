import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pure_live/player/core/portrait_stream_support.dart';

/// Detects the active programme rectangle inside a decoded frame.
///
/// Live platforms sometimes deliver a 9:16 programme inside a 16:9 encoded
/// canvas. Decoder dimensions alone describe the canvas, so the application
/// sees a landscape stream even though the visible programme is portrait. This
/// analyzer looks only for strong, symmetric, low-luma matte bars. It is
/// deliberately conservative and is intended to run on two small screenshots,
/// not continuously in the render loop.
class ActiveVideoContentAnalyzer {
  const ActiveVideoContentAnalyzer({this.darkLuma = 34});

  final int darkLuma;

  ActiveVideoContentObservation? analyzeRgba(Uint8List rgba, {required int width, required int height}) {
    if (width < 32 || height < 32 || rgba.lengthInBytes < width * height * 4) return null;

    final columnScores = List<double>.generate(
      width,
      (x) => _columnMatteScore(rgba, width: width, height: height, x: x),
      growable: false,
    );
    final rowScores = List<double>.generate(height, (y) => _rowMatteScore(rgba, width: width, y: y), growable: false);

    final horizontal = _resolveSymmetricBars(columnScores);
    final vertical = _resolveSymmetricBars(rowScores);
    final horizontalShare = horizontal == null ? 0.0 : (horizontal.leading + horizontal.trailing) / width;
    final verticalShare = vertical == null ? 0.0 : (vertical.leading + vertical.trailing) / height;

    if (horizontal == null && vertical == null) {
      final outerScore = _outerEdgeScore(columnScores, rowScores);
      // A bright/varied edge is strong evidence that the whole decoded canvas
      // is real content. Publishing an explicit full-frame observation lets a
      // later programme clear an earlier cached crop without guessing.
      if (outerScore < 0.48) {
        return const ActiveVideoContentObservation(insets: NormalizedVideoInsets.none, confidence: 0.90);
      }
      return null;
    }

    final useHorizontal = horizontalShare >= verticalShare;
    final bars = useHorizontal ? horizontal! : vertical!;
    final total = useHorizontal ? width : height;
    final leading = bars.leading / total;
    final trailing = bars.trailing / total;
    final retained = 1 - leading - trailing;
    if (retained < 0.20) return null;

    final insets = useHorizontal
        ? NormalizedVideoInsets(left: leading, right: trailing)
        : NormalizedVideoInsets(top: leading, bottom: trailing);
    final centerActivity = _centerActivity(rgba, width: width, height: height, insets: insets);
    if (centerActivity < 0.18) return null;

    final symmetry = 1 - ((leading - trailing).abs() / math.max(leading, trailing)).clamp(0.0, 1.0);
    final barShare = leading + trailing;
    final areaEvidence = (barShare / 0.42).clamp(0.0, 1.0).toDouble();
    final confidence = (bars.meanScore * 0.48 + symmetry * 0.24 + areaEvidence * 0.18 + centerActivity * 0.10)
        .clamp(0.0, 1.0)
        .toDouble();
    if (confidence < 0.86) return null;
    return ActiveVideoContentObservation(insets: insets, confidence: confidence);
  }

  double _columnMatteScore(Uint8List rgba, {required int width, required int height, required int x}) {
    final start = (height * 0.12).floor();
    final end = (height * 0.92).ceil();
    final step = math.max(1, (end - start) ~/ 80);
    return _lineMatteScore(rgba, start: start, end: end, step: step, indexOf: (p) => (p * width + x) * 4);
  }

  double _rowMatteScore(Uint8List rgba, {required int width, required int y}) {
    final start = (width * 0.10).floor();
    final end = (width * 0.90).ceil();
    final step = math.max(1, (end - start) ~/ 80);
    return _lineMatteScore(rgba, start: start, end: end, step: step, indexOf: (p) => (y * width + p) * 4);
  }

  double _lineMatteScore(
    Uint8List rgba, {
    required int start,
    required int end,
    required int step,
    required int Function(int position) indexOf,
  }) {
    var samples = 0;
    var dark = 0;
    var sum = 0.0;
    var sumSquares = 0.0;
    for (var position = start; position < end; position += step) {
      final index = indexOf(position);
      final r = rgba[index];
      final g = rgba[index + 1];
      final b = rgba[index + 2];
      final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
      if (luma <= darkLuma) dark++;
      sum += luma;
      sumSquares += luma * luma;
      samples++;
    }
    if (samples == 0) return 0;
    final mean = sum / samples;
    final variance = math.max(0, sumSquares / samples - mean * mean);
    final darkFraction = dark / samples;
    final darkness = (1 - mean / 58).clamp(0.0, 1.0).toDouble();
    final uniformity = (1 - math.sqrt(variance) / 58).clamp(0.0, 1.0).toDouble();
    return (darkFraction * 0.58 + darkness * 0.27 + uniformity * 0.15).clamp(0.0, 1.0).toDouble();
  }

  _SymmetricBars? _resolveSymmetricBars(List<double> scores) {
    final maxScan = (scores.length * 0.44).floor();
    final leading = _scanMattePrefix(scores, maxScan: maxScan);
    final trailing = _scanMattePrefix(scores.reversed.toList(growable: false), maxScan: maxScan);
    final minimum = math.max(3, (scores.length * 0.055).round());
    if (leading < minimum || trailing < minimum) return null;
    final larger = math.max(leading, trailing);
    if ((leading - trailing).abs() / larger > 0.36) return null;
    final retained = scores.length - leading - trailing;
    if (retained < scores.length * 0.20) return null;
    final barScores = <double>[...scores.take(leading), ...scores.skip(scores.length - trailing)];
    final meanScore = barScores.reduce((a, b) => a + b) / barScores.length;
    if (meanScore < 0.78) return null;
    return _SymmetricBars(leading: leading, trailing: trailing, meanScore: meanScore);
  }

  int _scanMattePrefix(List<double> scores, {required int maxScan}) {
    var lastReliable = 0;
    var weakRun = 0;
    final weakTolerance = math.max(2, (scores.length * 0.012).ceil());
    for (var index = 0; index < maxScan; index++) {
      final from = math.max(0, index - 2);
      final to = math.min(scores.length, index + 3);
      final local = scores.sublist(from, to).reduce((a, b) => a + b) / (to - from);
      if (local >= 0.70) {
        lastReliable = index + 1;
        weakRun = 0;
      } else {
        weakRun++;
        if (weakRun > weakTolerance) break;
      }
    }
    return lastReliable;
  }

  double _outerEdgeScore(List<double> columns, List<double> rows) {
    final columnBand = math.max(2, (columns.length * 0.04).round());
    final rowBand = math.max(2, (rows.length * 0.04).round());
    final values = <double>[
      ...columns.take(columnBand),
      ...columns.skip(columns.length - columnBand),
      ...rows.take(rowBand),
      ...rows.skip(rows.length - rowBand),
    ];
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _centerActivity(
    Uint8List rgba, {
    required int width,
    required int height,
    required NormalizedVideoInsets insets,
  }) {
    final left = (width * insets.left).ceil();
    final right = (width * (1 - insets.right)).floor();
    final top = (height * insets.top).ceil();
    final bottom = (height * (1 - insets.bottom)).floor();
    final stepX = math.max(1, (right - left) ~/ 40);
    final stepY = math.max(1, (bottom - top) ~/ 40);
    var samples = 0;
    var sum = 0.0;
    var sumSquares = 0.0;
    for (var y = top; y < bottom; y += stepY) {
      for (var x = left; x < right; x += stepX) {
        final index = (y * width + x) * 4;
        final luma = 0.2126 * rgba[index] + 0.7152 * rgba[index + 1] + 0.0722 * rgba[index + 2];
        sum += luma;
        sumSquares += luma * luma;
        samples++;
      }
    }
    if (samples == 0) return 0;
    final mean = sum / samples;
    final variance = math.max(0, sumSquares / samples - mean * mean);
    final brightness = (mean / 72).clamp(0.0, 1.0).toDouble();
    final variation = (math.sqrt(variance) / 48).clamp(0.0, 1.0).toDouble();
    return math.max(brightness, variation);
  }
}

class _SymmetricBars {
  const _SymmetricBars({required this.leading, required this.trailing, required this.meanScore});

  final int leading;
  final int trailing;
  final double meanScore;
}
