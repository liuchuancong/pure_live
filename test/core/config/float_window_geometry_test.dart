import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/config/float_window_geometry.dart';

void main() {
  group('FloatWindowGeometry', () {
    test('landscape and portrait keep separate windows', () {
      final geometry = const FloatWindowGeometry.empty()
          .withRect(isPortrait: false, rect: Rect.fromLTWH(10, 20, 300, 170))
          .withRect(isPortrait: true, rect: Rect.fromLTWH(40, 50, 180, 320));

      expect(geometry.forPortrait(false), Rect.fromLTWH(10, 20, 300, 170));
      expect(geometry.forPortrait(true), Rect.fromLTWH(40, 50, 180, 320));
    });

    test('a saved rect replaces only its own orientation', () {
      final landscape = const FloatWindowGeometry.empty().withRect(
        isPortrait: false,
        rect: Rect.fromLTWH(1, 2, 3, 4),
      );
      final overwritten = landscape.withRect(isPortrait: false, rect: Rect.fromLTWH(5, 6, 7, 8));

      expect(overwritten.forPortrait(false), Rect.fromLTWH(5, 6, 7, 8));
      expect(overwritten.forPortrait(true), isNull);
    });

    test('an orientation with nothing saved falls back to the anchor', () {
      final geometry = FloatWindowGeometry.decode(const FloatWindowGeometry.empty().encode());

      expect(geometry.forPortrait(false), isNull);
      expect(geometry.forPortrait(true), isNull);
    });

    test('round-trips through the stored string', () {
      final geometry = const FloatWindowGeometry.empty().withRect(
        isPortrait: true,
        rect: Rect.fromLTWH(12.5, 300, 214, 380),
      );

      expect(FloatWindowGeometry.decode(geometry.encode()).forPortrait(true), Rect.fromLTWH(12.5, 300, 214, 380));
    });

    // The stored value survives backups and file edits, so a broken payload is
    // an absent memory rather than a window that cannot open.
    test('an unreadable payload decodes to no memory', () {
      for (final raw in const <String>['', '   ', 'null', '[1,2,3]', '{"landscape":"x"}', '{"landscape":[0,0,10]}']) {
        expect(FloatWindowGeometry.decode(raw).forPortrait(false), isNull, reason: raw);
      }
    });

    test('a broken rect in the payload is not remembered', () {
      final emptyHeight = FloatWindowGeometry.decode('{"landscape":[0,0,10,0]}');
      final notANumber = FloatWindowGeometry.decode('{"landscape":[0,0,10,"x"]}');

      expect(emptyHeight.forPortrait(false), isNull);
      expect(notANumber.forPortrait(false), isNull);
    });

    group('surface orientation', () {
      test('a surface taller than it is wide is portrait', () {
        expect(FloatWindowGeometry.isPortraitSurface(const Size(400, 800)), isTrue);
        expect(FloatWindowGeometry.isPortraitSurface(const Size(800, 400)), isFalse);
      });

      test('a square surface counts as landscape', () {
        expect(FloatWindowGeometry.isPortraitSurface(const Size(600, 600)), isFalse);
      });

      test('an unknown or degenerate size counts as landscape', () {
        expect(FloatWindowGeometry.isPortraitSurface(Size.zero), isFalse);
        expect(FloatWindowGeometry.isPortraitSurface(const Size(400, 0)), isFalse);
        expect(FloatWindowGeometry.isPortraitSurface(const Size(double.infinity, 800)), isFalse);
      });

      test('the two orientations keep their own window', () {
        final geometry = const FloatWindowGeometry.empty()
            .withRect(isPortrait: FloatWindowGeometry.isPortraitSurface(const Size(800, 400)), rect: Rect.fromLTWH(1, 2, 3, 4))
            .withRect(isPortrait: FloatWindowGeometry.isPortraitSurface(const Size(400, 800)), rect: Rect.fromLTWH(5, 6, 7, 8));

        expect(geometry.forPortrait(false), Rect.fromLTWH(1, 2, 3, 4));
        expect(geometry.forPortrait(true), Rect.fromLTWH(5, 6, 7, 8));
      });
    });
  });
}
