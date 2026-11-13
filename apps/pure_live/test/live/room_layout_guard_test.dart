import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/modules/live/room/layout/room_layout.dart';

/// The room layout machine's guard: the window class and the sideways-phone
/// flag are the axes every room branch reads, so the breakpoints themselves
/// are pinned here — a drift in one constant shows up as a red test before
/// it shows up as a regressed layout.
void main() {
  group('RoomLayout.resolve — the window class axis', () {
    test('wide from the 840 breakpoint', () {
      expect(RoomLayout.resolve(width: 1280, height: 800, phoneLike: false).windowClass, RoomWindowClass.wide);
      expect(RoomLayout.resolve(width: 840, height: 800, phoneLike: false).windowClass, RoomWindowClass.wide);
    });

    test('regular between 600 and 839', () {
      expect(RoomLayout.resolve(width: 839, height: 800, phoneLike: false).windowClass, RoomWindowClass.regular);
      expect(RoomLayout.resolve(width: 600, height: 700, phoneLike: false).windowClass, RoomWindowClass.regular);
    });

    test('compact under 600', () {
      expect(RoomLayout.resolve(width: 599, height: 900, phoneLike: false).windowClass, RoomWindowClass.compact);
    });

    test('a portrait phone is compact, never landscape by width alone', () {
      final layout = RoomLayout.resolve(width: 400, height: 800, phoneLike: true);
      expect(layout.windowClass, RoomWindowClass.compact);
      expect(layout.landscapePhone, isFalse);
    });
  });

  group('RoomLayout.resolve — the sideways-phone flag', () {
    test('a phone held sideways in a short window is landscape before width is asked', () {
      final layout = RoomLayout.resolve(width: 900, height: 400, phoneLike: true);
      expect(layout.landscapePhone, isTrue);
    });

    test('a desktop window as short keeps the class its width gives it', () {
      final layout = RoomLayout.resolve(width: 900, height: 400, phoneLike: false);
      expect(layout.landscapePhone, isFalse);
      expect(layout.windowClass, RoomWindowClass.wide);
    });

    test('the landscape gate answers to the height, not the width alone', () {
      // The same phone at a taller window is not the sideways arrangement.
      expect(RoomLayout.resolve(width: 900, height: 500, phoneLike: true).landscapePhone, isFalse);
    });
  });
}
