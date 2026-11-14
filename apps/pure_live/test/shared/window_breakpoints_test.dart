import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:pure_live/shared/layout/window_breakpoints.dart';

void main() {
  group('isTabletSized', () {
    test('a tablet reads its shortest side, in either orientation', () {
      expect(isTabletSized(const Size(800, 1280)), isTrue, reason: 'portrait tablet');
      expect(isTabletSized(const Size(1280, 800)), isTrue, reason: 'landscape tablet');
    });

    test('the floor itself is a tablet; a dp under it is not', () {
      expect(isTabletSized(const Size(600, 960)), isTrue);
      expect(isTabletSized(const Size(599, 960)), isFalse);
    });

    test('a phone and a desktop window never reach the floor', () {
      expect(isTabletSized(const Size(360, 800)), isFalse, reason: 'phone portrait');
      expect(isTabletSized(const Size(800, 360)), isFalse, reason: 'phone landscape');
      expect(isTabletSized(const Size(700, 500)), isFalse, reason: 'short desktop window');
    });

    test('a square-ish desktop window can cross the floor', () {
      expect(isTabletSized(const Size(700, 760)), isTrue);
    });
  });
}
