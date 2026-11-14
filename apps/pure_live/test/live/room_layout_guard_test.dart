import 'package:flutter_test/flutter_test.dart';

import 'package:pure_live/shared/player/playback_layout.dart';

/// The playback layout machine's guard: the window class and the
/// sideways-immersive flag are the axes every playback branch reads, so the
/// breakpoints themselves are pinned here — a drift in one constant shows up
/// as a red test before it shows up as a regressed layout.
void main() {
  group('PlaybackLayout.resolve — the window class axis', () {
    test('wide from the 840 breakpoint', () {
      expect(PlaybackLayout.resolve(width: 1280, height: 800).windowClass, PlaybackWindowClass.wide);
      expect(PlaybackLayout.resolve(width: 840, height: 800).windowClass, PlaybackWindowClass.wide);
    });

    test('regular between 600 and 839', () {
      expect(PlaybackLayout.resolve(width: 839, height: 800).windowClass, PlaybackWindowClass.regular);
      expect(PlaybackLayout.resolve(width: 600, height: 700).windowClass, PlaybackWindowClass.regular);
    });

    test('compact under 600', () {
      expect(PlaybackLayout.resolve(width: 599, height: 900).windowClass, PlaybackWindowClass.compact);
    });

    test('a portrait window is compact, never landscape by width alone', () {
      final layout = PlaybackLayout.resolve(width: 400, height: 800);
      expect(layout.windowClass, PlaybackWindowClass.compact);
      expect(layout.landscapeImmersive, isFalse);
    });
  });

  group('PlaybackLayout.resolve — the sideways-immersive flag', () {
    test('a window held sideways in a short height is landscape before width is asked', () {
      expect(PlaybackLayout.resolve(width: 900, height: 400).landscapeImmersive, isTrue);
    });

    test('the sideways flag answers to the shape, never the platform', () {
      // The judgement is the window's own: a desktop window held short takes
      // the landscape arrangement exactly as a phone does.
      expect(PlaybackLayout.resolve(width: 900, height: 400).windowClass, PlaybackWindowClass.wide);
    });

    test('the landscape gate answers to the height, not the width alone', () {
      // The same window at a taller height is not the sideways arrangement.
      expect(PlaybackLayout.resolve(width: 900, height: 500).landscapeImmersive, isFalse);
    });
  });
}
