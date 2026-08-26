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

    test('two active-content observations identify portrait video inside a landscape canvas', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);
      detector.observe(1920, 1080, now: start);
      detector.commitPending(now: start.add(const Duration(milliseconds: 500)));
      const observation = ActiveVideoContentObservation(
        insets: NormalizedVideoInsets(left: 0.3418, right: 0.3418),
        confidence: 0.96,
        canvasAspectRatio: 16 / 9,
      );

      expect(detector.observeActiveContent(observation).orientation, VideoSourceOrientation.landscape);
      final active = detector.observeActiveContent(observation);

      expect(active.orientation, VideoSourceOrientation.portrait);
      expect(active.evidence, VideoGeometryEvidence.activeContent);
      expect(active.effectiveAspectRatio, closeTo(9 / 16, 0.02));
      expect(active.aspectRatio, closeTo(16 / 9, 0.001));
    });

    test('side-bar evidence is rejected for an already portrait decoder canvas', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);
      detector.observe(1080, 1920, now: start);
      detector.commitPending(now: start.add(const Duration(milliseconds: 500)));
      const invalid = ActiveVideoContentObservation(
        insets: NormalizedVideoInsets(left: 0.3418, right: 0.3418),
        confidence: 0.98,
      );

      detector.observeActiveContent(invalid);
      final snapshot = detector.observeActiveContent(invalid);

      expect(snapshot.hasActiveContentCrop, isFalse);
      expect(snapshot.effectiveAspectRatio, closeTo(9 / 16, 0.001));
    });

    test('a new source generation invalidates crop measured on an earlier quality', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);
      detector.observe(1920, 1080, now: start);
      detector.commitPending(now: start.add(const Duration(milliseconds: 500)));
      const bars = ActiveVideoContentObservation(
        insets: NormalizedVideoInsets(left: 0.3418, right: 0.3418),
        confidence: 0.96,
      );
      detector.observeActiveContent(bars);
      expect(detector.observeActiveContent(bars).hasActiveContentCrop, isTrue);

      detector.beginSourceTransition();
      final switched = detector.observe(1080, 1920, now: start.add(const Duration(seconds: 1)));

      expect(switched.hasActiveContentCrop, isFalse);
      expect(switched.aspectRatio, closeTo(9 / 16, 0.001));
      expect(switched.candidateOrientation, VideoSourceOrientation.portrait);
    });

    test('platform metadata repairs malformed decoder sample aspect without a crop', () {
      final detector = PortraitStreamDetector();
      detector.observeSourceMetadata(1080, 1920, confidence: 0.99, source: 'douyin.extra');

      final snapshot = detector.observe(360, 1920);

      expect(snapshot.sourceHintOverridesDecoder, isTrue);
      expect(snapshot.effectiveAspectRatio, closeTo(9 / 16, 0.001));
      expect(snapshot.orientation, VideoSourceOrientation.portrait);
      expect(snapshot.hasActiveContentCrop, isFalse);
    });

    test('selected-stream portrait metadata classifies but never invents a crop', () {
      final detector = PortraitStreamDetector();
      detector.observeSourceMetadata(1080, 1920, confidence: 0.995, source: 'douyin.selected_sdk_params');

      final snapshot = detector.observe(1920, 1080);
      final insets = PortraitPresentationPolicy.resolveVideoContentInsets(
        snapshot: snapshot,
        presentationAspectRatio: 9 / 16,
      );

      expect(snapshot.effectiveAspectRatio, closeTo(16 / 9, 0.002));
      expect(snapshot.candidateOrientation, VideoSourceOrientation.landscape);
      expect(insets.hasCrop, isFalse);
    });

    test('selected landscape metadata never invents a crop for a portrait decoder canvas', () {
      final detector = PortraitStreamDetector();
      detector.observeSourceMetadata(1920, 1080, confidence: 0.995, source: 'douyin.selected_sdk_params');

      final snapshot = detector.observe(1080, 1920);

      expect(
        PortraitPresentationPolicy.resolveVideoContentInsets(
          snapshot: snapshot,
          presentationAspectRatio: 16 / 9,
        ).hasCrop,
        isFalse,
      );
    });

    test('two full-frame probes can disprove a conflicting platform hint', () {
      final detector = PortraitStreamDetector();
      detector.observeSourceMetadata(1080, 1920, confidence: 0.99, source: 'douyin.extra');
      detector.observe(1920, 1080);
      const fullFrame = ActiveVideoContentObservation(insets: NormalizedVideoInsets.none, confidence: 0.94);

      detector.observeActiveContent(fullFrame);
      final snapshot = detector.observeActiveContent(fullFrame);

      expect(snapshot.orientation, VideoSourceOrientation.landscape);
      expect(snapshot.hasTrustedSourceHint, isFalse);
      expect(snapshot.effectiveAspectRatio, closeTo(16 / 9, 0.001));
      expect(snapshot.evidence, VideoGeometryEvidence.activeContent);
    });

    test('screenshot canvas corrects decoder metadata before applying measured bars', () {
      final detector = PortraitStreamDetector();
      detector.observeSourceMetadata(1080, 1920, confidence: 0.99, source: 'douyin.extra');
      detector.observe(360, 1920);
      const bars = ActiveVideoContentObservation(
        insets: NormalizedVideoInsets(left: 0.3418, right: 0.3418),
        confidence: 0.97,
        canvasAspectRatio: 16 / 9,
      );

      detector.observeActiveContent(bars);
      final snapshot = detector.observeActiveContent(bars);

      expect(snapshot.orientation, VideoSourceOrientation.portrait);
      expect(snapshot.aspectRatio, closeTo(360 / 1920, 0.001));
      expect(snapshot.renderCanvasAspectRatio, closeTo(16 / 9, 0.001));
      expect(snapshot.effectiveAspectRatio, closeTo(9 / 16, 0.02));
      expect(snapshot.hasActiveContentCrop, isTrue);
    });

    test('two direct portrait frame probes replace a malformed landscape decoder canvas', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);
      detector.observe(1920, 1080, now: start);
      detector.commitPending(now: start.add(const Duration(milliseconds: 500)));
      const portraitFrame = ActiveVideoContentObservation(
        insets: NormalizedVideoInsets.none,
        confidence: 0.95,
        canvasAspectRatio: 9 / 16,
      );

      detector.observeActiveContent(portraitFrame);
      final snapshot = detector.observeActiveContent(portraitFrame);

      expect(snapshot.orientation, VideoSourceOrientation.portrait);
      expect(snapshot.effectiveAspectRatio, closeTo(9 / 16, 0.001));
      expect(snapshot.renderCanvasAspectRatio, closeTo(9 / 16, 0.001));
    });

    test('source transition retains effective ratio but drops the previous canvas crop', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);
      detector.observe(1920, 1080, now: start);
      detector.commitPending(now: start.add(const Duration(milliseconds: 500)));
      const bars = ActiveVideoContentObservation(
        insets: NormalizedVideoInsets(left: 0.3418, right: 0.3418),
        confidence: 0.96,
      );
      detector.observeActiveContent(bars);
      final portrait = detector.observeActiveContent(bars);

      final transition = detector.beginSourceTransition();

      expect(portrait.hasActiveContentCrop, isTrue);
      expect(transition.hasActiveContentCrop, isFalse);
      expect(transition.hasTrustedSourceHint, isFalse);
      expect(transition.isProvisional, isTrue);
      expect(transition.aspectRatio, closeTo(9 / 16, 0.02));
    });

    test('source transition drops the previous URL geometry authority', () {
      final detector = PortraitStreamDetector();
      final start = DateTime(2026, 1, 1);
      detector.observeSourceMetadata(1080, 1920, confidence: 0.995, source: 'douyin.selected_sdk_params');
      detector.observe(1920, 1080, now: start);
      final selected = detector.commitPending(now: start.add(const Duration(milliseconds: 500)));

      final transition = detector.beginSourceTransition();

      expect(selected.orientation, VideoSourceOrientation.landscape);
      expect(transition.effectiveAspectRatio, closeTo(16 / 9, 0.001));
      expect(transition.hasTrustedSourceHint, isFalse);
    });

    test('a cached room geometry is provisional until fresh decoder evidence arrives', () {
      final detector = PortraitStreamDetector();
      final cached = VideoGeometrySnapshot(
        width: 1080,
        height: 1920,
        aspectRatio: 9 / 16,
        orientation: VideoSourceOrientation.portrait,
        candidateOrientation: VideoSourceOrientation.portrait,
        stableSampleCount: 3,
        confidence: 1,
        observedAt: DateTime(2026),
      );

      expect(detector.seed(cached).isProvisional, isTrue);
      expect(detector.observe(720, 1280).isProvisional, isFalse);
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

    test('generic platform metadata does not invent crop coordinates for a landscape canvas', () {
      final snapshot = VideoGeometrySnapshot(
        width: 1920,
        height: 1080,
        aspectRatio: 16 / 9,
        orientation: VideoSourceOrientation.portrait,
        candidateOrientation: VideoSourceOrientation.portrait,
        stableSampleCount: 3,
        confidence: 0.99,
        observedAt: DateTime(2026),
        sourceHintAspectRatio: 9 / 16,
        sourceHintConfidence: 0.99,
        sourceHintSource: 'douyin.extra',
        evidence: VideoGeometryEvidence.platformMetadata,
      );

      final insets = PortraitPresentationPolicy.resolveVideoContentInsets(
        snapshot: snapshot,
        presentationAspectRatio: 9 / 16,
      );

      expect(insets.hasCrop, isFalse);
      expect(snapshot.renderCanvasAspectRatio, closeTo(16 / 9, 0.001));
    });

    test('settled full-frame evidence clears a conflicting selected-stream hint', () {
      final detector = PortraitStreamDetector();
      detector.observeSourceMetadata(1080, 1920, confidence: 0.995, source: 'douyin.selected_sdk_params');
      detector.observe(1920, 1080);
      const fullFrame = ActiveVideoContentObservation(
        insets: NormalizedVideoInsets.none,
        confidence: 0.96,
        canvasAspectRatio: 16 / 9,
      );

      detector.observeActiveContent(fullFrame);
      final settled = detector.observeActiveContent(fullFrame);

      expect(settled.hasTrustedSourceHint, isFalse);
      expect(
        PortraitPresentationPolicy.resolveVideoContentInsets(
          snapshot: settled,
          presentationAspectRatio: 16 / 9,
        ).hasCrop,
        isFalse,
      );
    });
  });

  test('orientation locking is reserved for compact displays', () {
    expect(supportsOrientationLockForLogicalDisplay(const Size(390, 844)), isTrue);
    expect(supportsOrientationLockForLogicalDisplay(const Size(800, 1280)), isFalse);
  });
}
