import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType, Offset, Rect, Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:pure_live/shared/layout/window_class.dart';

void main() {
  group('WindowClass', () {
    test('the width classes follow the page measures', () {
      expect(WindowClass.of(const Size(500, 800)).width, WindowWidthClass.compact);
      expect(WindowClass.of(const Size(600, 800)).width, WindowWidthClass.medium);
      expect(WindowClass.of(const Size(960, 800)).width, WindowWidthClass.expanded);
    });

    test('the height classes follow the compact measures', () {
      expect(WindowClass.of(const Size(1200, 420)).isShort, isTrue);
      expect(WindowClass.of(const Size(1200, 480)).isShort, isFalse);
      expect(WindowClass.of(const Size(1200, 900)).height, WindowHeightClass.expanded);
    });

    test('a short wide area is a phone held sideways; a short narrow one is not', () {
      expect(WindowClass.of(const Size(800, 420)).isPhoneLandscape, isTrue);
      expect(WindowClass.of(const Size(400, 420)).isPhoneLandscape, isFalse);
      expect(WindowClass.of(const Size(800, 800)).isPhoneLandscape, isFalse);
    });

    test('the same classes are equal however they were built', () {
      expect(
        WindowClass.of(const Size(700, 700)),
        WindowClass(width: WindowWidthClass.medium, height: WindowHeightClass.medium),
      );
    });
  });

  group('DisplayHinge', () {
    test('a half-opened fold splits; a flat fold and a cutout do not', () {
      // dart:ui draws a fold as a line: zero width or zero height.
      final fold = DisplayFeature(
        type: DisplayFeatureType.fold,
        bounds: const Rect.fromLTWH(399, 0, 0, 800),
        state: DisplayFeatureState.postureHalfOpened,
      );
      final flat = DisplayFeature(
        type: DisplayFeatureType.fold,
        bounds: const Rect.fromLTWH(399, 0, 0, 800),
        state: DisplayFeatureState.unknown,
      );
      final cutout = DisplayFeature(
        type: DisplayFeatureType.cutout,
        bounds: const Rect.fromLTWH(399, 0, 2, 800),
        state: DisplayFeatureState.unknown,
      );
      expect(DisplayHinge.find([fold], const Size(800, 800))?.bounds, fold.bounds);
      expect(DisplayHinge.find([flat], const Size(800, 800)), isNull);
      expect(DisplayHinge.find([cutout], const Size(800, 800)), isNull);
    });

    test('a vertical hinge splits a row into two panes with the hinge as the gap', () {
      final hinge = DisplayHinge(const Rect.fromLTWH(398, 0, 4, 800));
      final split = hinge.splitRow(left: 0, width: 800);
      expect(split, isNotNull);
      expect(split!.start, 398);
      expect(split.gap, 4);
      expect(hinge.splitRow(left: 0, width: 500, minPane: 320), isNull);
      expect(hinge.splitRow(left: 100, width: 300, minPane: 320), isNull);
    });

    test('a hinge down the middle sends each side to its own half', () {
      final hinge = DisplayHinge(const Rect.fromLTWH(0, 398, 800, 4));
      expect(hinge.vertical, isFalse);
      final top = hinge.sideOf(const Offset(400, 200), const Size(800, 800));
      expect(top.bottom, 398);
      final bottom = hinge.sideOf(const Offset(400, 600), const Size(800, 800));
      expect(bottom.top, 402);
    });
  });
}
