import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/player/core/portrait_stream_support.dart';
import 'package:pure_live/player/utils/fullscreen.dart';

void main() {
  group('PortraitStreamDetector', () {
    test('commits a portrait source after three equal samples', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);

      expect(detector.observe(1080, 1920, now: start).orientation, VideoSourceOrientation.unknown);
      expect(
        detector.observe(1080, 1920, now: start.add(const Duration(milliseconds: 80))).orientation,
        VideoSourceOrientation.unknown,
      );
      final stable = detector.observe(1080, 1920, now: start.add(const Duration(milliseconds: 160)));

      expect(stable.orientation, VideoSourceOrientation.portrait);
      expect(stable.isStable, isTrue);
      expect(stable.aspectRatio, closeTo(9 / 16, 0.001));
    });

    test('single decoder metadata event commits after the stability delay', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);
      detector.observe(720, 1280, now: start);

      expect(
        detector.commitPending(now: start.add(const Duration(milliseconds: 499))).orientation,
        VideoSourceOrientation.unknown,
      );
      expect(
        detector.commitPending(now: start.add(const Duration(milliseconds: 500))).orientation,
        VideoSourceOrientation.portrait,
      );
    });

    test('near-square metadata stays neutral and room reset removes stale state', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);
      detector.observe(1000, 1000, now: start);
      final square = detector.commitPending(now: start.add(const Duration(milliseconds: 500)));

      expect(square.orientation, VideoSourceOrientation.square);
      expect(detector.reset().orientation, VideoSourceOrientation.unknown);
      expect(detector.snapshot.hasValidDimensions, isFalse);
    });

    test('a transient quality-switch dimension does not flip stable orientation', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);
      detector.observe(1080, 1920, now: start);
      detector.commitPending(now: start.add(const Duration(milliseconds: 500)));

      final transient = detector.observe(1920, 1080, now: start.add(const Duration(milliseconds: 600)));
      expect(transient.orientation, VideoSourceOrientation.portrait);
      expect(transient.candidateOrientation, VideoSourceOrientation.landscape);
    });
  });

  group('PortraitPresentationPolicy', () {
    test('manual room override has priority over smart detection', () {
      final snapshot = VideoGeometrySnapshot(
        width: 1920,
        height: 1080,
        aspectRatio: 16 / 9,
        orientation: VideoSourceOrientation.landscape,
        candidateOrientation: VideoSourceOrientation.landscape,
        stableSampleCount: 3,
        confidence: 1,
        observedAt: DateTime(2026),
      );

      expect(
        PortraitPresentationPolicy.resolveOrientation(
          snapshot: snapshot,
          override: PortraitOrientationOverride.portrait,
          smartDetectionEnabled: true,
        ),
        VideoSourceOrientation.portrait,
      );
    });

    test('balanced room layout preserves at least 200 px for the danmaku list', () {
      final height = PortraitPresentationPolicy.resolveNormalVideoHeight(
        availableWidth: 390,
        availableHeight: 780,
        isPortraitSource: true,
        sourceAspectRatio: 9 / 16,
        adaptiveHeightEnabled: true,
        mode: PortraitLayoutMode.balanced,
      );

      expect(height, greaterThan(390 / (16 / 9)));
      expect(height + 45 + 200, lessThanOrEqualTo(780));
      expect(height, lessThanOrEqualTo(780 * 0.60));
    });

    test('PiP ratio clamps extreme video metadata to Android bounds', () {
      final tall = PortraitPresentationPolicy.resolveAndroidPipAspectRatio(
        width: 100,
        height: 1000,
        portraitFallback: true,
      );
      final wide = PortraitPresentationPolicy.resolveAndroidPipAspectRatio(
        width: 3000,
        height: 100,
        portraitFallback: false,
      );

      expect(tall.value, greaterThanOrEqualTo(1 / 2.39));
      expect(wide.value, lessThanOrEqualTo(2.39));
    });

    test('landscape compact windows stay on the legacy 16:9 contract', () {
      final malformedWide = VideoGeometrySnapshot(
        width: 6000,
        height: 1000,
        aspectRatio: 6,
        orientation: VideoSourceOrientation.landscape,
        candidateOrientation: VideoSourceOrientation.landscape,
        stableSampleCount: 3,
        confidence: 1,
        observedAt: DateTime(2026),
      );

      expect(
        PortraitPresentationPolicy.resolveCompactWindowAspectRatio(
          snapshot: malformedWide,
          effectiveOrientation: VideoSourceOrientation.landscape,
          followStablePortraitSource: true,
        ),
        closeTo(16 / 9, 0.0001),
      );
    });

    test('only a stable plausible portrait source changes compact-window ratio', () {
      final portrait = VideoGeometrySnapshot(
        width: 720,
        height: 1080,
        aspectRatio: 2 / 3,
        orientation: VideoSourceOrientation.portrait,
        candidateOrientation: VideoSourceOrientation.portrait,
        stableSampleCount: 3,
        confidence: 1,
        observedAt: DateTime(2026),
      );

      expect(
        PortraitPresentationPolicy.resolveCompactWindowAspectRatio(
          snapshot: portrait,
          effectiveOrientation: VideoSourceOrientation.portrait,
          followStablePortraitSource: true,
        ),
        closeTo(2 / 3, 0.0001),
      );
      expect(
        PortraitPresentationPolicy.resolveCompactWindowAspectRatio(
          snapshot: portrait,
          effectiveOrientation: VideoSourceOrientation.portrait,
          followStablePortraitSource: false,
        ),
        closeTo(9 / 16, 0.0001),
      );
    });

    test('one trusted ratio rejects malformed or orientation-conflicting metadata', () {
      final malformedPortrait = VideoGeometrySnapshot(
        width: 360,
        height: 1920,
        aspectRatio: 360 / 1920,
        orientation: VideoSourceOrientation.portrait,
        candidateOrientation: VideoSourceOrientation.portrait,
        stableSampleCount: 3,
        confidence: 1,
        observedAt: DateTime(2026),
      );
      final landscapeMetadata = VideoGeometrySnapshot(
        width: 1920,
        height: 1080,
        aspectRatio: 16 / 9,
        orientation: VideoSourceOrientation.landscape,
        candidateOrientation: VideoSourceOrientation.landscape,
        stableSampleCount: 3,
        confidence: 1,
        observedAt: DateTime(2026),
      );

      expect(
        PortraitPresentationPolicy.resolveVideoDisplayAspectRatio(
          snapshot: malformedPortrait,
          effectiveOrientation: VideoSourceOrientation.portrait,
        ),
        closeTo(9 / 16, 0.0001),
      );
      expect(
        PortraitPresentationPolicy.resolveVideoDisplayAspectRatio(
          snapshot: landscapeMetadata,
          effectiveOrientation: VideoSourceOrientation.portrait,
        ),
        closeTo(9 / 16, 0.0001),
      );
      expect(
        PortraitPresentationPolicy.resolveVideoDisplayAspectRatio(
          snapshot: landscapeMetadata,
          effectiveOrientation: VideoSourceOrientation.landscape,
        ),
        closeTo(16 / 9, 0.0001),
      );
    });
  });

  test('orientation locking is reserved for compact displays', () {
    expect(supportsOrientationLockForLogicalDisplay(const Size(390, 844)), isTrue);
    expect(supportsOrientationLockForLogicalDisplay(const Size(800, 1280)), isFalse);
  });
}
