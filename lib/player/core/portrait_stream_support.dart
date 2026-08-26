import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum VideoSourceOrientation { unknown, portrait, square, landscape }

enum PortraitOrientationOverride { automatic, portrait, landscape }

enum PortraitLayoutMode { balanced, immersive, compatibility }

enum PortraitFullscreenPolicy { followSource, followSystem, landscape }

enum PortraitDanmakuMode { followGlobal, upperQuarter, reduced, hidden }

@immutable
class VideoGeometrySnapshot {
  const VideoGeometrySnapshot({
    required this.width,
    required this.height,
    required this.aspectRatio,
    required this.orientation,
    required this.candidateOrientation,
    required this.stableSampleCount,
    required this.confidence,
    required this.observedAt,
  });

  const VideoGeometrySnapshot.unknown()
    : width = 0,
      height = 0,
      aspectRatio = 16 / 9,
      orientation = VideoSourceOrientation.unknown,
      candidateOrientation = VideoSourceOrientation.unknown,
      stableSampleCount = 0,
      confidence = 0,
      observedAt = null;

  final int width;
  final int height;
  final double aspectRatio;

  /// Last orientation that passed the stability gate.
  final VideoSourceOrientation orientation;

  /// Most recent raw candidate. It can differ briefly during a quality switch.
  final VideoSourceOrientation candidateOrientation;
  final int stableSampleCount;
  final double confidence;
  final DateTime? observedAt;

  bool get hasValidDimensions => width > 0 && height > 0 && aspectRatio.isFinite;
  bool get isStable => orientation != VideoSourceOrientation.unknown && orientation == candidateOrientation;

  VideoGeometrySnapshot copyWith({
    int? width,
    int? height,
    double? aspectRatio,
    VideoSourceOrientation? orientation,
    VideoSourceOrientation? candidateOrientation,
    int? stableSampleCount,
    double? confidence,
    DateTime? observedAt,
  }) {
    return VideoGeometrySnapshot(
      width: width ?? this.width,
      height: height ?? this.height,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      orientation: orientation ?? this.orientation,
      candidateOrientation: candidateOrientation ?? this.candidateOrientation,
      stableSampleCount: stableSampleCount ?? this.stableSampleCount,
      confidence: confidence ?? this.confidence,
      observedAt: observedAt ?? this.observedAt,
    );
  }
}

/// Event-driven video geometry classifier.
///
/// Decoder width and height often arrive as two independent events. A quality
/// or CDN switch can therefore expose one mixed pair for a few milliseconds.
/// This detector commits an orientation after three equal observations or a
/// 500 ms stable interval and uses a neutral band around 1:1 to avoid rotation
/// chatter for square and near-square sources.
class PortraitStreamDetector {
  PortraitStreamDetector({
    this.requiredSamples = 3,
    this.stabilityDelay = const Duration(milliseconds: 500),
    this.portraitThreshold = 0.90,
    this.landscapeThreshold = 1.10,
  });

  final int requiredSamples;
  final Duration stabilityDelay;
  final double portraitThreshold;
  final double landscapeThreshold;

  VideoGeometrySnapshot _snapshot = const VideoGeometrySnapshot.unknown();
  VideoSourceOrientation _pending = VideoSourceOrientation.unknown;
  DateTime? _pendingSince;
  int _pendingSamples = 0;

  VideoGeometrySnapshot get snapshot => _snapshot;
  DateTime? get pendingSince => _pendingSince;
  bool get hasPendingCandidate => _pending != VideoSourceOrientation.unknown;

  VideoGeometrySnapshot reset() {
    _pending = VideoSourceOrientation.unknown;
    _pendingSince = null;
    _pendingSamples = 0;
    _snapshot = const VideoGeometrySnapshot.unknown();
    return _snapshot;
  }

  VideoGeometrySnapshot observe(int width, int height, {DateTime? now}) {
    if (width <= 0 || height <= 0) return _snapshot;
    final timestamp = now ?? DateTime.now();
    final ratio = width / height;
    if (!ratio.isFinite || ratio <= 0) return _snapshot;

    final candidate = _classify(ratio);
    if (candidate == _snapshot.orientation && candidate != VideoSourceOrientation.unknown) {
      _clearPending();
      _snapshot = _buildSnapshot(
        width: width,
        height: height,
        ratio: ratio,
        orientation: candidate,
        candidate: candidate,
        samples: requiredSamples,
        observedAt: timestamp,
      );
      return _snapshot;
    }

    if (_pending == candidate) {
      _pendingSamples++;
    } else {
      _pending = candidate;
      _pendingSince = timestamp;
      _pendingSamples = 1;
    }

    final stableFor = timestamp.difference(_pendingSince!);
    final shouldCommit = _pendingSamples >= requiredSamples || stableFor >= stabilityDelay;
    _snapshot = _buildSnapshot(
      width: width,
      height: height,
      ratio: ratio,
      orientation: shouldCommit ? candidate : _snapshot.orientation,
      candidate: candidate,
      samples: _pendingSamples,
      observedAt: timestamp,
    );
    if (shouldCommit) _clearPending();
    return _snapshot;
  }

  /// Commits the last unchanged candidate after [stabilityDelay] even if the
  /// decoder emits dimensions only once.
  VideoGeometrySnapshot commitPending({DateTime? now}) {
    final since = _pendingSince;
    if (since == null || _pending == VideoSourceOrientation.unknown) return _snapshot;
    final timestamp = now ?? DateTime.now();
    if (timestamp.difference(since) < stabilityDelay || !_snapshot.hasValidDimensions) return _snapshot;
    _snapshot = _snapshot.copyWith(
      orientation: _pending,
      candidateOrientation: _pending,
      stableSampleCount: math.max(_pendingSamples, 1),
      observedAt: timestamp,
    );
    _clearPending();
    return _snapshot;
  }

  VideoSourceOrientation _classify(double ratio) {
    // Hysteresis keeps an established orientation until it has crossed well
    // into the square band. This is especially useful for rotated metadata
    // during adaptive-quality transitions.
    if (_snapshot.orientation == VideoSourceOrientation.portrait && ratio < 0.96) {
      return VideoSourceOrientation.portrait;
    }
    if (_snapshot.orientation == VideoSourceOrientation.landscape && ratio > 1.04) {
      return VideoSourceOrientation.landscape;
    }
    if (ratio <= portraitThreshold) return VideoSourceOrientation.portrait;
    if (ratio >= landscapeThreshold) return VideoSourceOrientation.landscape;
    return VideoSourceOrientation.square;
  }

  VideoGeometrySnapshot _buildSnapshot({
    required int width,
    required int height,
    required double ratio,
    required VideoSourceOrientation orientation,
    required VideoSourceOrientation candidate,
    required int samples,
    required DateTime observedAt,
  }) {
    final distance = (ratio - 1).abs();
    final confidence = candidate == VideoSourceOrientation.square
        ? (1 - distance / 0.10).clamp(0.0, 1.0).toDouble()
        : (distance / 0.33).clamp(0.0, 1.0).toDouble();
    return VideoGeometrySnapshot(
      width: width,
      height: height,
      aspectRatio: ratio,
      orientation: orientation,
      candidateOrientation: candidate,
      stableSampleCount: samples,
      confidence: confidence,
      observedAt: observedAt,
    );
  }

  void _clearPending() {
    _pending = VideoSourceOrientation.unknown;
    _pendingSince = null;
    _pendingSamples = 0;
  }
}

@immutable
class PipAspectRatio {
  const PipAspectRatio(this.width, this.height);

  final int width;
  final int height;
  double get value => width / height;
}

class PortraitPresentationPolicy {
  const PortraitPresentationPolicy._();

  static const double androidPipMinimumAspectRatio = 1 / 2.39;
  static const double androidPipMaximumAspectRatio = 2.39;

  static VideoSourceOrientation resolveOrientation({
    required VideoGeometrySnapshot snapshot,
    required PortraitOrientationOverride override,
    required bool smartDetectionEnabled,
  }) {
    return switch (override) {
      PortraitOrientationOverride.portrait => VideoSourceOrientation.portrait,
      PortraitOrientationOverride.landscape => VideoSourceOrientation.landscape,
      PortraitOrientationOverride.automatic =>
        smartDetectionEnabled ? snapshot.orientation : VideoSourceOrientation.landscape,
    };
  }

  static double resolveNormalVideoHeight({
    required double availableWidth,
    required double availableHeight,
    required bool isPortraitSource,
    required double sourceAspectRatio,
    required bool adaptiveHeightEnabled,
    required PortraitLayoutMode mode,
    double resolutionHeight = 45,
    double minimumDanmakuHeight = 200,
  }) {
    if (!availableWidth.isFinite || availableWidth <= 0 || !availableHeight.isFinite || availableHeight <= 0) {
      return 0;
    }
    final legacyHeight = math.min(availableHeight, availableWidth / (16 / 9));
    if (!isPortraitSource || !adaptiveHeightEnabled || mode == PortraitLayoutMode.compatibility) {
      return legacyHeight;
    }

    final ratio = sourceAspectRatio.isFinite && sourceAspectRatio > 0 ? sourceAspectRatio : 9 / 16;
    final desiredHeight = availableWidth / ratio;
    final reservedDanmaku = mode == PortraitLayoutMode.immersive ? 120.0 : minimumDanmakuHeight;
    final fractionCap = availableHeight * (mode == PortraitLayoutMode.immersive ? 0.78 : 0.60);
    final panelCap = availableHeight - resolutionHeight - reservedDanmaku;
    final upperBound = math.max(legacyHeight, math.min(fractionCap, panelCap));
    return desiredHeight.clamp(legacyHeight, upperBound).toDouble();
  }

  /// Returns the ratio used by PiP and the application floating window.
  ///
  /// Portrait adaptation is an opt-in extension to the established 16:9
  /// landscape pipeline. Landscape, square, unknown and implausible metadata
  /// therefore keep the legacy ratio instead of allowing one decoder metadata
  /// anomaly to resize every presentation mode.
  static double resolveCompactWindowAspectRatio({
    required VideoGeometrySnapshot snapshot,
    required VideoSourceOrientation effectiveOrientation,
    required bool followStablePortraitSource,
  }) {
    if (effectiveOrientation != VideoSourceOrientation.portrait) return 16 / 9;
    if (!followStablePortraitSource || !snapshot.hasValidDimensions || !snapshot.isStable) return 9 / 16;
    final ratio = snapshot.aspectRatio;
    if (ratio < androidPipMinimumAspectRatio || ratio > 0.90) return 9 / 16;
    return ratio;
  }

  /// Android accepts PiP ratios only in the inclusive [1/2.39, 2.39] range.
  /// Invalid decoder dimensions fall back to the effective presentation ratio.
  static PipAspectRatio resolveAndroidPipAspectRatio({
    required int width,
    required int height,
    required bool portraitFallback,
  }) {
    double ratio = width > 0 && height > 0 ? width / height : (portraitFallback ? 9 / 16 : 16 / 9);
    ratio = ratio.clamp(androidPipMinimumAspectRatio, androidPipMaximumAspectRatio).toDouble();
    const denominator = 1000;
    final minimumNumerator = (androidPipMinimumAspectRatio * denominator).ceil();
    final maximumNumerator = (androidPipMaximumAspectRatio * denominator).floor();
    final numerator = (ratio * denominator).round().clamp(minimumNumerator, maximumNumerator);
    final divisor = _greatestCommonDivisor(numerator, denominator);
    return PipAspectRatio(numerator ~/ divisor, denominator ~/ divisor);
  }

  static int _greatestCommonDivisor(int a, int b) {
    var x = a.abs();
    var y = b.abs();
    while (y != 0) {
      final remainder = x % y;
      x = y;
      y = remainder;
    }
    return x == 0 ? 1 : x;
  }
}
