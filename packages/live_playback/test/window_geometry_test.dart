import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_playback/live_playback.dart';
import 'package:media_core/media_core.dart';

/// A geometry with a known video size.
VideoGeometry geometryOf(int width, int height) {
  final size = VideoSize(width: width, height: height);
  return VideoGeometry.derived(
    videoSize: size,
    displaySize: DisplaySize(width: width.toDouble(), height: height.toDouble()),
    rotation: const VideoRotationInfo.none(),
    pixelRatio: const PixelRatioValue.one(),
  );
}

void main() {
  const engine = WindowSizingEngine();

  group('naturalSize', () {
    test('a landscape video keeps its shape with the width as the long side', () {
      final size = engine.naturalSize(screen: const Size(1080, 1920), geometry: geometryOf(1920, 1080));

      expect(size.width / size.height, closeTo(16 / 9, 0.001));
      expect(size.width, greaterThan(size.height));
    });

    test('a portrait video gets a tall window', () {
      final size = engine.naturalSize(screen: const Size(1080, 1920), geometry: geometryOf(720, 1280));

      expect(size.height, greaterThan(size.width));
      expect(size.width / size.height, closeTo(720 / 1280, 0.001));
    });

    test('an unknown or square shape falls back to landscape', () {
      final size = engine.naturalSize(screen: const Size(1080, 1920), geometry: geometryOf(0, 0));

      expect(size.width, greaterThan(size.height));
    });

    test('a narrow portrait video never goes below the minimum width', () {
      // A 1:3 stream on a small screen: the proportional width would be a
      // sliver, so the policy's floor takes over.
      final size = engine.naturalSize(
        screen: const Size(360, 640),
        geometry: geometryOf(100, 300),
        policy: const WindowSizePolicy(scale: 0.5, minPortraitWidth: 140),
      );

      expect(size.width, greaterThanOrEqualTo(140));
    });
  });

  group('clampRect', () {
    const area = Size(400, 800);

    test('keeps a remembered rect inside the surface', () {
      final clamped = engine.clampRect(rect: const Rect.fromLTWH(900, 1200, 320, 180), area: area, aspectRatio: 16 / 9);

      expect(clamped.left + clamped.width, lessThanOrEqualTo(area.width));
      expect(clamped.top + clamped.height, lessThanOrEqualTo(area.height));
    });

    test('does not grow a rect the viewer made small', () {
      final clamped = engine.clampRect(rect: const Rect.fromLTWH(10, 10, 120, 67.5), area: area, aspectRatio: 16 / 9);

      expect(clamped.width, closeTo(120, 0.001));
    });

    test('preserves the aspect ratio while clamping', () {
      final clamped = engine.clampRect(rect: const Rect.fromLTWH(0, 0, 4000, 300), area: area, aspectRatio: 16 / 9);

      expect(clamped.width / clamped.height, closeTo(16 / 9, 0.001));
    });

    test('respects the surface clearance', () {
      final clamped = engine.clampRect(
        rect: const Rect.fromLTWH(0, 0, 300, 168.75),
        area: area,
        aspectRatio: 16 / 9,
        clearance: const WindowClearance(edge: 24, top: 60, bottom: 90),
      );

      expect(clamped.left, greaterThanOrEqualTo(24));
      expect(clamped.top, greaterThanOrEqualTo(60));
      expect(clamped.top + clamped.height, lessThanOrEqualTo(area.height - 90));
    });
  });

  group('defaultRect', () {
    test('parks the window in the bottom-right, inside the clearance', () {
      const area = Size(400, 800);
      final rect = engine.defaultRect(
        area: area,
        window: const Size(320, 180),
        clearance: const WindowClearance(bottom: 40),
      );

      expect(rect.right, closeTo(area.width - 16, 0.001));
      expect(rect.bottom, closeTo(area.height - 40, 0.001));
    });
  });

  group('layout strategy', () {
    test('a phone letterboxes a landscape video and immerses a portrait one', () {
      expect(
        LayoutStrategy.forProfile(DeviceProfile.mobile, VideoOrientation.landscape),
        LayoutStrategy.letterboxLandscape,
      );
      expect(
        LayoutStrategy.forProfile(DeviceProfile.mobile, VideoOrientation.portrait),
        LayoutStrategy.immersivePortrait,
      );
    });

    test('a tablet lays videos out responsively', () {
      expect(LayoutStrategy.forProfile(DeviceProfile.tablet, VideoOrientation.portrait), LayoutStrategy.responsive);
    });

    test('an overlay follows the video on every device', () {
      expect(
        LayoutStrategy.forProfile(DeviceProfile.desktop, VideoOrientation.landscape, isOverlay: true),
        LayoutStrategy.overlay,
      );
    });
  });
}
