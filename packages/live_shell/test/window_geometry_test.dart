import 'package:live_shell/live_shell.dart';
import 'package:test/test.dart';

/// A 1080p display at the origin, and a second one to its right.
const DisplayFrame builtIn = DisplayFrame(
  id: 'eDP-1',
  bounds: PixelRect(0, 0, 1920, 1080),
  workArea: PixelRect(0, 0, 1920, 1040),
);

const DisplayFrame external = DisplayFrame(
  id: 'DP-2',
  bounds: PixelRect(1920, 0, 2560, 1440),
  workArea: PixelRect(1920, 60, 2560, 1330),
);

WindowGeometry at(int left, int top, {bool maximized = false, String? displayId}) =>
    WindowGeometry(frame: PixelRect(left, top, 1200, 700), maximized: maximized, displayId: displayId);

void main() {
  group('isOnSomeDisplay', () {
    test('a normal place on either display is reachable', () {
      expect(isOnSomeDisplay(at(100, 100), [builtIn, external]), isTrue);
      expect(isOnSomeDisplay(at(2400, 400, displayId: 'DP-2'), [builtIn, external]), isTrue);
    });

    test('a window parked past every display is not', () {
      expect(isOnSomeDisplay(at(9000, 100), [builtIn, external]), isFalse);
      expect(isOnSomeDisplay(at(-4000, 100), [builtIn]), isFalse);
    });

    test('only the grab strip has to be on screen, not the whole window', () {
      // A wide window dragged mostly off the right edge still has its title
      // bar reachable, which is all a viewer needs to bring it back.
      const mostlyOff = WindowGeometry(frame: PixelRect(1700, 200, 1200, 700), maximized: false);

      expect(isOnSomeDisplay(mostlyOff, [builtIn]), isTrue);
    });
  });

  group('keepOnScreen', () {
    test('leaves a reachable window alone', () {
      final geometry = at(100, 100);

      expect(keepOnScreen(geometry, [builtIn, external]), same(geometry));
    });

    test('slides an orphaned window onto its own display when that still exists', () {
      final geometry = at(3000, 900, displayId: 'DP-2');

      final kept = keepOnScreen(geometry, [builtIn, external]);

      expect(kept.displayId, 'DP-2');
      expect(isOnSomeDisplay(kept, [builtIn, external]), isTrue);
      expect(kept.frame.width, 1200, reason: 'the size the viewer chose is kept');
    });

    test('falls back to a surviving display when the remembered one is gone', () {
      final geometry = at(3000, 900, displayId: 'DP-2');

      final kept = keepOnScreen(geometry, [builtIn]);

      expect(kept.displayId, 'eDP-1');
      expect(kept.frame.top, 0);
      expect(isOnSomeDisplay(kept, [builtIn]), isTrue);
    });

    test('clamps a window larger than the work area instead of overflowing it', () {
      const huge = WindowGeometry(frame: PixelRect(4000, 4000, 5000, 3000), maximized: false);

      final kept = keepOnScreen(huge, [builtIn]);

      expect(kept.frame.width, 1920);
      expect(kept.frame.height, 1040);
    });

    test('an empty display list keeps the geometry rather than inventing one', () {
      final geometry = at(4000, 4000);

      expect(keepOnScreen(geometry, const []), same(geometry));
    });
  });

  group('maximiseTo', () {
    test('uses the work area, so the taskbar stays visible', () {
      final maximised = maximiseTo(builtIn.workArea);

      expect(maximised.height, 1040, reason: 'not the display height of 1080');
      expect(maximised.bottom, lessThanOrEqualTo(builtIn.workArea.bottom));
    });

    test('keeps a display that starts away from the origin where it is', () {
      final maximised = maximiseTo(external.workArea);

      expect(maximised.left, 1920);
      expect(maximised.top, 60);
    });
  });

  group('WindowGeometry', () {
    test('remembers the restore size separately from the maximised state', () {
      const geometry = WindowGeometry(frame: PixelRect(0, 0, 1920, 1040), maximized: true, displayId: 'eDP-1');

      final restored = geometry.copyWith(maximized: false);

      expect(restored.maximized, isFalse);
      expect(restored.frame, geometry.frame);
    });
  });
}
