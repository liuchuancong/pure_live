import 'dart:math' as math;

import 'package:flutter/foundation.dart';

enum VideoSourceOrientation { unknown, portrait, square, landscape }

enum PortraitOrientationOverride { automatic, portrait, landscape }

enum PortraitLayoutMode { balanced, immersive, compatibility }

enum PortraitFullscreenPolicy { followSource, followSystem, landscape }

enum PortraitDanmakuMode { followGlobal, upperQuarter, reduced, hidden }

/// Evidence currently driving the effective video geometry.
///
/// Decoder metadata is the fast default. A cached value may be shown while a
/// room reconnects, and a high-confidence active-content probe may refine a
/// landscape canvas that actually contains a portrait programme with pillar
/// bars. Manual room overrides remain a presentation policy and are therefore
/// intentionally kept outside this enum.
enum VideoGeometryEvidence { unknown, cache, decoderMetadata, activeContent }

@immutable
class NormalizedVideoInsets {
  const NormalizedVideoInsets({this.left = 0, this.top = 0, this.right = 0, this.bottom = 0});

  static const none = NormalizedVideoInsets();

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get widthFraction => (1 - left - right).clamp(0.0, 1.0).toDouble();
  double get heightFraction => (1 - top - bottom).clamp(0.0, 1.0).toDouble();
  bool get hasCrop => left > 0.001 || top > 0.001 || right > 0.001 || bottom > 0.001;

  bool get isValid =>
      left.isFinite &&
      top.isFinite &&
      right.isFinite &&
      bottom.isFinite &&
      left >= 0 &&
      top >= 0 &&
      right >= 0 &&
      bottom >= 0 &&
      widthFraction > 0.10 &&
      heightFraction > 0.10;

  double applyToAspectRatio(double encodedAspectRatio) {
    if (!isValid || !encodedAspectRatio.isFinite || encodedAspectRatio <= 0) return encodedAspectRatio;
    return encodedAspectRatio * widthFraction / heightFraction;
  }

  bool isNear(NormalizedVideoInsets other, {double tolerance = 0.035}) {
    return (left - other.left).abs() <= tolerance &&
        (top - other.top).abs() <= tolerance &&
        (right - other.right).abs() <= tolerance &&
        (bottom - other.bottom).abs() <= tolerance;
  }
}

@immutable
class ActiveVideoContentObservation {
  const ActiveVideoContentObservation({required this.insets, required this.confidence});

  final NormalizedVideoInsets insets;
  final double confidence;

  bool get isReliable => insets.isValid && confidence.isFinite && confidence >= 0.86;
}

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
    this.activeContentInsets = NormalizedVideoInsets.none,
    this.activeContentConfidence = 0,
    this.evidence = VideoGeometryEvidence.decoderMetadata,
    this.isProvisional = false,
  });

  const VideoGeometrySnapshot.unknown()
    : width = 0,
      height = 0,
      aspectRatio = 16 / 9,
      orientation = VideoSourceOrientation.unknown,
      candidateOrientation = VideoSourceOrientation.unknown,
      stableSampleCount = 0,
      confidence = 0,
      observedAt = null,
      activeContentInsets = NormalizedVideoInsets.none,
      activeContentConfidence = 0,
      evidence = VideoGeometryEvidence.unknown,
      isProvisional = false;

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
  final NormalizedVideoInsets activeContentInsets;
  final double activeContentConfidence;
  final VideoGeometryEvidence evidence;
  final bool isProvisional;

  bool get hasValidDimensions => width > 0 && height > 0 && aspectRatio.isFinite;
  bool get isStable => orientation != VideoSourceOrientation.unknown && orientation == candidateOrientation;
  bool get hasActiveContentCrop => activeContentInsets.hasCrop && activeContentConfidence >= 0.86;
  double get effectiveAspectRatio =>
      hasActiveContentCrop ? activeContentInsets.applyToAspectRatio(aspectRatio) : aspectRatio;

  VideoGeometrySnapshot copyWith({
    int? width,
    int? height,
    double? aspectRatio,
    VideoSourceOrientation? orientation,
    VideoSourceOrientation? candidateOrientation,
    int? stableSampleCount,
    double? confidence,
    DateTime? observedAt,
    NormalizedVideoInsets? activeContentInsets,
    double? activeContentConfidence,
    VideoGeometryEvidence? evidence,
    bool? isProvisional,
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
      activeContentInsets: activeContentInsets ?? this.activeContentInsets,
      activeContentConfidence: activeContentConfidence ?? this.activeContentConfidence,
      evidence: evidence ?? this.evidence,
      isProvisional: isProvisional ?? this.isProvisional,
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
  ActiveVideoContentObservation? _pendingContent;
  int _pendingContentSamples = 0;

  VideoGeometrySnapshot get snapshot => _snapshot;
  DateTime? get pendingSince => _pendingSince;
  bool get hasPendingCandidate => _pending != VideoSourceOrientation.unknown;

  VideoGeometrySnapshot reset() {
    _pending = VideoSourceOrientation.unknown;
    _pendingSince = null;
    _pendingSamples = 0;
    _pendingContent = null;
    _pendingContentSamples = 0;
    _snapshot = const VideoGeometrySnapshot.unknown();
    return _snapshot;
  }

  void resetPendingEvidence() {
    _clearPending();
    _pendingContent = null;
    _pendingContentSamples = 0;
  }

  /// Seeds the next decoder session from a recent stable room snapshot. It is
  /// explicitly provisional: fresh decoder/content observations replace it,
  /// while the UI avoids a visible 16:9 -> portrait jump during reconnects.
  VideoGeometrySnapshot seed(VideoGeometrySnapshot cached) {
    if (!cached.isStable || !cached.hasValidDimensions) return reset();
    resetPendingEvidence();
    _snapshot = cached.copyWith(evidence: VideoGeometryEvidence.cache, isProvisional: true);
    return _snapshot;
  }

  VideoGeometrySnapshot observe(int width, int height, {DateTime? now}) {
    if (width <= 0 || height <= 0) return _snapshot;
    final timestamp = now ?? DateTime.now();
    final encodedRatio = width / height;
    if (!encodedRatio.isFinite || encodedRatio <= 0) return _snapshot;
    final ratio = _snapshot.hasActiveContentCrop
        ? _snapshot.activeContentInsets.applyToAspectRatio(encodedRatio)
        : encodedRatio;

    final candidate = _classify(ratio);
    if (candidate == _snapshot.orientation && candidate != VideoSourceOrientation.unknown) {
      _clearPending();
      _snapshot = _buildSnapshot(
        width: width,
        height: height,
        ratio: ratio,
        encodedRatio: encodedRatio,
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
      encodedRatio: encodedRatio,
      orientation: shouldCommit ? candidate : _snapshot.orientation,
      candidate: candidate,
      samples: _pendingSamples,
      observedAt: timestamp,
    );
    if (shouldCommit) _clearPending();
    return _snapshot;
  }

  /// Fuses an off-path, low-resolution frame probe with decoder metadata.
  /// Two mutually consistent observations are required. This prevents a dark
  /// scene, transition frame or danmaku overlay from resizing all player modes.
  VideoGeometrySnapshot observeActiveContent(ActiveVideoContentObservation observation, {DateTime? now}) {
    if (!_snapshot.hasValidDimensions || !observation.isReliable) return _snapshot;
    if (_pendingContent?.insets.isNear(observation.insets) ?? false) {
      _pendingContentSamples++;
      if (observation.confidence > _pendingContent!.confidence) _pendingContent = observation;
    } else {
      _pendingContent = observation;
      _pendingContentSamples = 1;
    }
    if (_pendingContentSamples < 2) return _snapshot;

    final accepted = _pendingContent!;
    _pendingContent = null;
    _pendingContentSamples = 0;
    final effectiveRatio = accepted.insets.applyToAspectRatio(_snapshot.aspectRatio);
    final orientation = _classifyWithoutHysteresis(effectiveRatio);
    _clearPending();
    _snapshot = _snapshot.copyWith(
      orientation: orientation,
      candidateOrientation: orientation,
      stableSampleCount: requiredSamples,
      confidence: math.max(_snapshot.confidence, accepted.confidence),
      observedAt: now ?? DateTime.now(),
      activeContentInsets: accepted.insets,
      activeContentConfidence: accepted.confidence,
      evidence: accepted.insets.hasCrop ? VideoGeometryEvidence.activeContent : VideoGeometryEvidence.decoderMetadata,
      isProvisional: false,
    );
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

  VideoSourceOrientation _classifyWithoutHysteresis(double ratio) {
    if (ratio <= portraitThreshold) return VideoSourceOrientation.portrait;
    if (ratio >= landscapeThreshold) return VideoSourceOrientation.landscape;
    return VideoSourceOrientation.square;
  }

  VideoGeometrySnapshot _buildSnapshot({
    required int width,
    required int height,
    required double ratio,
    required double encodedRatio,
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
      aspectRatio: encodedRatio,
      orientation: orientation,
      candidateOrientation: candidate,
      stableSampleCount: samples,
      confidence: confidence,
      observedAt: observedAt,
      activeContentInsets: _snapshot.activeContentInsets,
      activeContentConfidence: _snapshot.activeContentConfidence,
      evidence: _snapshot.hasActiveContentCrop
          ? VideoGeometryEvidence.activeContent
          : VideoGeometryEvidence.decoderMetadata,
      isProvisional: false,
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

  /// Resolves the one aspect ratio used to present a native video texture.
  ///
  /// Some live CDNs expose a decoded buffer size whose sample-aspect metadata
  /// is temporarily malformed. Letting that raw ratio drive a texture directly
  /// can turn a regular 9:16 stream into a very narrow strip. The established
  /// orientation (including a room override) is therefore the authority:
  /// plausible ratios in the same orientation are preserved, while conflicting
  /// or out-of-range metadata falls back to the conventional live ratio.
  static double resolveVideoDisplayAspectRatio({
    required VideoGeometrySnapshot snapshot,
    required VideoSourceOrientation effectiveOrientation,
  }) {
    final ratio = snapshot.effectiveAspectRatio;
    final valid = snapshot.hasValidDimensions && ratio > 0;
    return switch (effectiveOrientation) {
      VideoSourceOrientation.portrait =>
        valid && ratio >= androidPipMinimumAspectRatio && ratio < 0.90 ? ratio : 9 / 16,
      VideoSourceOrientation.landscape =>
        valid && ratio > 1.10 && ratio <= androidPipMaximumAspectRatio ? ratio : 16 / 9,
      VideoSourceOrientation.square => valid && ratio >= 0.90 && ratio <= 1.10 ? ratio : 1.0,
      VideoSourceOrientation.unknown => 16 / 9,
    };
  }

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
    if (!snapshot.isStable || !followStablePortraitSource) return 9 / 16;
    return resolveVideoDisplayAspectRatio(snapshot: snapshot, effectiveOrientation: effectiveOrientation);
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
