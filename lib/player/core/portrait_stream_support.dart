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
enum VideoGeometryEvidence { unknown, cache, platformMetadata, decoderMetadata, activeContent }

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
    this.activeContentCanvasAspectRatio = 0,
    this.sourceHintAspectRatio = 0,
    this.sourceHintConfidence = 0,
    this.sourceHintSource = '',
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
      activeContentCanvasAspectRatio = 0,
      sourceHintAspectRatio = 0,
      sourceHintConfidence = 0,
      sourceHintSource = '',
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
  final double activeContentCanvasAspectRatio;
  final double sourceHintAspectRatio;
  final double sourceHintConfidence;
  final String sourceHintSource;
  final VideoGeometryEvidence evidence;
  final bool isProvisional;

  bool get hasValidDimensions => width > 0 && height > 0 && aspectRatio.isFinite;
  bool get isStable => orientation != VideoSourceOrientation.unknown && orientation == candidateOrientation;
  bool get hasTrustedSourceHint =>
      sourceHintAspectRatio.isFinite &&
      sourceHintAspectRatio > 0 &&
      sourceHintConfidence.isFinite &&
      sourceHintConfidence >= 0.90;

  bool get hasActiveContentCrop {
    if (!activeContentInsets.hasCrop || activeContentConfidence < 0.86) return false;
    final basis = activeContentCanvasAspectRatio;
    return basis <= 0 || _relativeRatioDifference(basis, aspectRatio) <= 0.08;
  }

  bool get sourceHintOverridesDecoder =>
      hasTrustedSourceHint && _sourceHintShouldOverrideDecoder(aspectRatio, sourceHintAspectRatio);

  double get effectiveAspectRatio {
    if (hasActiveContentCrop) return activeContentInsets.applyToAspectRatio(aspectRatio);
    if (sourceHintOverridesDecoder) return sourceHintAspectRatio;
    return aspectRatio;
  }

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
    double? activeContentCanvasAspectRatio,
    double? sourceHintAspectRatio,
    double? sourceHintConfidence,
    String? sourceHintSource,
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
      activeContentCanvasAspectRatio: activeContentCanvasAspectRatio ?? this.activeContentCanvasAspectRatio,
      sourceHintAspectRatio: sourceHintAspectRatio ?? this.sourceHintAspectRatio,
      sourceHintConfidence: sourceHintConfidence ?? this.sourceHintConfidence,
      sourceHintSource: sourceHintSource ?? this.sourceHintSource,
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
  bool _contentEvidenceSettled = false;

  VideoGeometrySnapshot get snapshot => _snapshot;
  DateTime? get pendingSince => _pendingSince;
  bool get hasPendingCandidate => _pending != VideoSourceOrientation.unknown;
  bool get contentEvidenceSettled => _contentEvidenceSettled;

  VideoGeometrySnapshot reset() {
    _pending = VideoSourceOrientation.unknown;
    _pendingSince = null;
    _pendingSamples = 0;
    _pendingContent = null;
    _pendingContentSamples = 0;
    _contentEvidenceSettled = false;
    _snapshot = const VideoGeometrySnapshot.unknown();
    return _snapshot;
  }

  void resetPendingEvidence() {
    _clearPending();
    _pendingContent = null;
    _pendingContentSamples = 0;
    _contentEvidenceSettled = false;
  }

  /// Seeds the next decoder session from a recent stable room snapshot. It is
  /// explicitly provisional: fresh decoder/content observations replace it,
  /// while the UI avoids a visible 16:9 -> portrait jump during reconnects.
  VideoGeometrySnapshot seed(VideoGeometrySnapshot cached) {
    if (!cached.isStable || !cached.hasValidDimensions) return reset();
    resetPendingEvidence();
    final ratio = cached.effectiveAspectRatio;
    const basis = 10000;
    _snapshot = VideoGeometrySnapshot(
      width: (ratio * basis).round(),
      height: basis,
      aspectRatio: ratio,
      orientation: cached.orientation,
      candidateOrientation: cached.orientation,
      stableSampleCount: requiredSamples,
      confidence: cached.confidence,
      observedAt: cached.observedAt,
      sourceHintAspectRatio: cached.sourceHintAspectRatio,
      sourceHintConfidence: cached.sourceHintConfidence,
      sourceHintSource: cached.sourceHintSource,
      evidence: VideoGeometryEvidence.cache,
      isProvisional: true,
    );
    return _snapshot;
  }

  /// Starts a new URL/quality/CDN generation without carrying a crop measured
  /// on the previous decoded canvas. The last effective ratio remains as a
  /// provisional frame until platform or decoder metadata for the new source
  /// arrives, preventing both a visible jump and stale double-cropping.
  VideoGeometrySnapshot beginSourceTransition() {
    if (!_snapshot.isStable || !_snapshot.hasValidDimensions) return reset();
    return seed(_snapshot);
  }

  /// Commits strong platform stream metadata immediately. Decoder dimensions
  /// still replace the encoded-canvas fields later, while this declared content
  /// ratio remains available to repair malformed sample-aspect metadata and to
  /// identify a portrait programme carried in a landscape canvas.
  VideoGeometrySnapshot observeSourceMetadata(
    int width,
    int height, {
    required double confidence,
    required String source,
    DateTime? now,
  }) {
    if (width <= 0 || height <= 0 || !confidence.isFinite || confidence <= 0) return _snapshot;
    final ratio = width / height;
    if (!ratio.isFinite || ratio <= 0) return _snapshot;
    final orientation = _classifyWithoutHysteresis(ratio);
    _clearPending();
    _pendingContent = null;
    _pendingContentSamples = 0;
    _contentEvidenceSettled = false;
    _snapshot = VideoGeometrySnapshot(
      width: width,
      height: height,
      aspectRatio: ratio,
      orientation: orientation,
      candidateOrientation: orientation,
      stableSampleCount: requiredSamples,
      confidence: confidence.clamp(0.0, 1.0).toDouble(),
      observedAt: now ?? DateTime.now(),
      sourceHintAspectRatio: ratio,
      sourceHintConfidence: confidence.clamp(0.0, 1.0).toDouble(),
      sourceHintSource: source,
      evidence: VideoGeometryEvidence.platformMetadata,
      isProvisional: true,
    );
    return _snapshot;
  }

  VideoGeometrySnapshot observe(int width, int height, {DateTime? now}) {
    if (width <= 0 || height <= 0) return _snapshot;
    final timestamp = now ?? DateTime.now();
    final encodedRatio = width / height;
    if (!encodedRatio.isFinite || encodedRatio <= 0) return _snapshot;
    if (_snapshot.hasActiveContentCrop &&
        _relativeRatioDifference(
              _snapshot.activeContentCanvasAspectRatio > 0
                  ? _snapshot.activeContentCanvasAspectRatio
                  : _snapshot.aspectRatio,
              encodedRatio,
            ) >
            0.08) {
      _snapshot = _snapshot.copyWith(
        activeContentInsets: NormalizedVideoInsets.none,
        activeContentConfidence: 0,
        activeContentCanvasAspectRatio: 0,
        evidence: _snapshot.hasTrustedSourceHint
            ? VideoGeometryEvidence.platformMetadata
            : VideoGeometryEvidence.decoderMetadata,
      );
      _pendingContent = null;
      _pendingContentSamples = 0;
      _contentEvidenceSettled = false;
    }
    final ratio = _snapshot.hasActiveContentCrop
        ? _snapshot.activeContentInsets.applyToAspectRatio(encodedRatio)
        : _snapshot.hasTrustedSourceHint &&
              _sourceHintShouldOverrideDecoder(encodedRatio, _snapshot.sourceHintAspectRatio)
        ? _snapshot.sourceHintAspectRatio
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
    final encodedRatio = _snapshot.aspectRatio;
    if (observation.insets.hasCrop && !_isPlausibleActiveContentCrop(encodedRatio, observation.insets)) {
      _pendingContent = null;
      _pendingContentSamples = 0;
      return _snapshot;
    }
    final observedRatio = observation.insets.applyToAspectRatio(encodedRatio);
    if (observation.insets.hasCrop &&
        _snapshot.hasTrustedSourceHint &&
        _relativeRatioDifference(observedRatio, _snapshot.sourceHintAspectRatio) > 0.16) {
      _pendingContent = null;
      _pendingContentSamples = 0;
      return _snapshot;
    }
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
    _contentEvidenceSettled = true;
    final effectiveRatio = accepted.insets.applyToAspectRatio(_snapshot.aspectRatio);
    final orientation = _classifyWithoutHysteresis(effectiveRatio);
    final clearContradictedHint = !accepted.insets.hasCrop && _snapshot.sourceHintOverridesDecoder;
    _clearPending();
    _snapshot = _snapshot.copyWith(
      orientation: orientation,
      candidateOrientation: orientation,
      stableSampleCount: requiredSamples,
      confidence: math.max(_snapshot.confidence, accepted.confidence),
      observedAt: now ?? DateTime.now(),
      activeContentInsets: accepted.insets,
      activeContentConfidence: accepted.confidence,
      activeContentCanvasAspectRatio: _snapshot.aspectRatio,
      sourceHintAspectRatio: clearContradictedHint ? 0 : _snapshot.sourceHintAspectRatio,
      sourceHintConfidence: clearContradictedHint ? 0 : _snapshot.sourceHintConfidence,
      sourceHintSource: clearContradictedHint ? '' : _snapshot.sourceHintSource,
      evidence: accepted.insets.hasCrop
          ? VideoGeometryEvidence.activeContent
          : _snapshot.hasTrustedSourceHint && !clearContradictedHint
          ? VideoGeometryEvidence.platformMetadata
          : VideoGeometryEvidence.decoderMetadata,
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
      activeContentCanvasAspectRatio: _snapshot.activeContentCanvasAspectRatio,
      sourceHintAspectRatio: _snapshot.sourceHintAspectRatio,
      sourceHintConfidence: _snapshot.sourceHintConfidence,
      sourceHintSource: _snapshot.sourceHintSource,
      evidence: _snapshot.hasActiveContentCrop
          ? VideoGeometryEvidence.activeContent
          : _snapshot.hasTrustedSourceHint &&
                _sourceHintShouldOverrideDecoder(encodedRatio, _snapshot.sourceHintAspectRatio)
          ? VideoGeometryEvidence.platformMetadata
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

double _relativeRatioDifference(double left, double right) {
  if (!left.isFinite || !right.isFinite || left <= 0 || right <= 0) return double.infinity;
  return (left - right).abs() / math.max(left, right);
}

VideoSourceOrientation _orientationForAspect(double ratio) {
  if (ratio <= 0.90) return VideoSourceOrientation.portrait;
  if (ratio >= 1.10) return VideoSourceOrientation.landscape;
  return VideoSourceOrientation.square;
}

bool _sourceHintShouldOverrideDecoder(double encodedRatio, double sourceHintRatio) {
  if (!encodedRatio.isFinite || encodedRatio <= 0 || !sourceHintRatio.isFinite || sourceHintRatio <= 0) return false;
  final encodedOrientation = _orientationForAspect(encodedRatio);
  final hintedOrientation = _orientationForAspect(sourceHintRatio);
  if (encodedOrientation != hintedOrientation) return true;
  return switch (hintedOrientation) {
    VideoSourceOrientation.portrait => encodedRatio < PortraitPresentationPolicy.androidPipMinimumAspectRatio,
    VideoSourceOrientation.landscape => encodedRatio > PortraitPresentationPolicy.androidPipMaximumAspectRatio,
    VideoSourceOrientation.square => false,
    VideoSourceOrientation.unknown => false,
  };
}

bool _isPlausibleActiveContentCrop(double encodedRatio, NormalizedVideoInsets insets) {
  if (!insets.hasCrop || !insets.isValid || !encodedRatio.isFinite || encodedRatio <= 0) return !insets.hasCrop;
  final horizontalShare = insets.left + insets.right;
  final verticalShare = insets.top + insets.bottom;
  final effectiveRatio = insets.applyToAspectRatio(encodedRatio);
  if (!effectiveRatio.isFinite ||
      effectiveRatio < PortraitPresentationPolicy.androidPipMinimumAspectRatio ||
      effectiveRatio > PortraitPresentationPolicy.androidPipMaximumAspectRatio) {
    return false;
  }
  if (horizontalShare >= verticalShare) {
    // Side bars only establish a portrait programme when the decoded canvas is
    // landscape. Applying them to an already portrait frame creates the narrow
    // strip regression this gate is designed to prevent.
    return encodedRatio >= 1.10;
  }
  return encodedRatio <= 0.90;
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

  /// Resolves the crop that is valid for the final presentation ratio.
  ///
  /// A measured crop is accepted only when applying it to the current decoder
  /// canvas produces that same ratio. Strong platform metadata may also infer
  /// symmetric pillar bars when a portrait programme is carried in a landscape
  /// canvas, covering engines that do not expose screenshot capture.
  static NormalizedVideoInsets resolveVideoContentInsets({
    required VideoGeometrySnapshot snapshot,
    required double presentationAspectRatio,
  }) {
    final measured = resolveConsistentVideoContentInsets(
      encodedAspectRatio: snapshot.aspectRatio,
      presentationAspectRatio: presentationAspectRatio,
      contentInsets: snapshot.hasActiveContentCrop ? snapshot.activeContentInsets : NormalizedVideoInsets.none,
    );
    if (measured.hasCrop) return measured;

    if (!snapshot.sourceHintOverridesDecoder ||
        _relativeRatioDifference(snapshot.sourceHintAspectRatio, presentationAspectRatio) > 0.08) {
      return NormalizedVideoInsets.none;
    }
    final encodedRatio = snapshot.aspectRatio;
    final hintedRatio = snapshot.sourceHintAspectRatio;
    if (encodedRatio < 1.10 || hintedRatio > 0.90 || encodedRatio <= hintedRatio) {
      return NormalizedVideoInsets.none;
    }
    final retainedWidth = hintedRatio / encodedRatio;
    if (retainedWidth < 0.20 || retainedWidth > 0.88) return NormalizedVideoInsets.none;
    final side = (1 - retainedWidth) / 2;
    return resolveConsistentVideoContentInsets(
      encodedAspectRatio: encodedRatio,
      presentationAspectRatio: presentationAspectRatio,
      contentInsets: NormalizedVideoInsets(left: side, right: side),
    );
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

/// Enforces the geometry contract at the renderer boundary. A stale or
/// malformed crop is ignored when its resulting viewport disagrees with the
/// already resolved presentation ratio.
NormalizedVideoInsets resolveConsistentVideoContentInsets({
  required double encodedAspectRatio,
  required double presentationAspectRatio,
  required NormalizedVideoInsets contentInsets,
}) {
  if (!contentInsets.hasCrop ||
      !contentInsets.isValid ||
      !encodedAspectRatio.isFinite ||
      encodedAspectRatio <= 0 ||
      !presentationAspectRatio.isFinite ||
      presentationAspectRatio <= 0) {
    return NormalizedVideoInsets.none;
  }
  final croppedRatio = contentInsets.applyToAspectRatio(encodedAspectRatio);
  if (_relativeRatioDifference(croppedRatio, presentationAspectRatio) > 0.08) {
    return NormalizedVideoInsets.none;
  }
  return contentInsets;
}
