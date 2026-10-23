import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart';
import 'package:live_shell_desktop/live_shell_desktop.dart';

/// One display's geometry, without the plugin's FFI handle.
DisplayGeometry geometry({
  required int id,
  required Size size,
  required Rect workArea,
  Offset position = Offset.zero,
  double scaleFactor = 1,
}) => (id: id, position: position, size: size, workArea: workArea, scaleFactor: scaleFactor);

void main() {
  group('rect ↔ PixelRect', () {
    test('an integer frame survives the round trip', () {
      const frame = PixelRect(120, 80, 1200, 700);

      expect(rectToFrame(frameToRect(frame)), frame);
    });

    test('a fractional bounds rectangle from a scaled display is rounded, not truncated', () {
      // At 125% scaling the plugin reports positions like 120.5; a truncation
      // would move the window by half a pixel every save-and-restore cycle,
      // which over a few sessions walks a remembered window off the screen.
      final frame = rectToFrame(const Rect.fromLTWH(120.6, 80.2, 1200.4, 700.9));

      expect(frame.left, 121);
      expect(frame.top, 80);
      expect(frame.width, 1200);
      expect(frame.height, 701);
    });

    test('a monitor to the left of the primary one keeps its negative origin', () {
      // Windows puts secondary monitors at negative x when they sit left of the
      // primary; clamping that to zero moves the window onto the wrong screen
      // before any policy has been consulted.
      final frame = rectToFrame(const Rect.fromLTWH(-1920, 0, 1200, 700));

      expect(frame.left, -1920);
      expect(frameToRect(frame).left, -1920);
    });
  });

  group('toDisplayFrame', () {
    test('the work area is the work area and the full extent is the bounds', () {
      final display = geometry(id: 1, size: const Size(1920, 1080), workArea: const Rect.fromLTWH(0, 0, 1920, 1010));

      final frame = const ScreenRetrieverDisplays().toDisplayFrame(display);

      expect(frame.id, '1');
      expect(frame.workArea.height, 1010, reason: 'maximising must leave the taskbar visible');
      expect(frame.bounds.height, 1080);
    });

    test('a display left of the primary one keeps its own origin in bounds', () {
      // The 0.2 bridge could not report a full frame's origin at all, so a
      // secondary monitor's coordinates were lost here; the display API answers
      // that directly now.
      final display = geometry(
        id: 2,
        position: const Offset(-2560, 0),
        size: const Size(2560, 1440),
        workArea: const Rect.fromLTWH(-2560, 0, 2560, 1400),
      );

      final frame = const ScreenRetrieverDisplays().toDisplayFrame(display);

      expect(frame.bounds.left, -2560);
      expect(frame.workArea.left, -2560);
    });

    test('the plugin id reaches the shell as the string the geometry stores', () {
      final display = geometry(id: 7, size: const Size(1920, 1080), workArea: const Rect.fromLTWH(0, 0, 1920, 1080));

      expect(const ScreenRetrieverDisplays().toDisplayFrame(display).id, '7');
    });

    test('a scale factor is carried through', () {
      final display = geometry(
        id: 3,
        size: const Size(1920, 1080),
        workArea: const Rect.fromLTWH(0, 0, 1920, 1080),
        scaleFactor: 1.5,
      );

      expect(const ScreenRetrieverDisplays().toDisplayFrame(display).scaleFactor, 1.5);
    });
  });

  group('displayHosting', () {
    const left = DisplayFrame(
      id: 'left',
      bounds: PixelRect(-1920, 0, 1920, 1080),
      workArea: PixelRect(-1920, 0, 1920, 1040),
    );
    const right = DisplayFrame(id: 'right', bounds: PixelRect(0, 0, 1920, 1080), workArea: PixelRect(0, 0, 1920, 1040));
    const reader = ScreenRetrieverDisplays();

    test('a window mostly on one screen is reported as belonging to it', () {
      const straddling = PixelRect(-400, 100, 1200, 700);

      // 400 wide on the left screen, 800 on the right.
      expect(reader.displayHosting(straddling, [left, right]), 'right');
    });

    test('a window dragged fully off every display has no host', () {
      expect(reader.displayHosting(const PixelRect(9000, 0, 800, 600), [left, right]), isNull);
    });

    test('no displays means no host rather than a guess', () {
      expect(reader.displayHosting(const PixelRect(0, 0, 800, 600), const []), isNull);
    });
  });

  group('supportsTray', () {
    test('the desktops have a notification area and the phones do not', () {
      expect(supportsTray(PlatformKind.windows), isTrue);
      expect(supportsTray(PlatformKind.linux), isTrue);
      expect(supportsTray(PlatformKind.macos), isTrue);
      expect(supportsTray(PlatformKind.android), isFalse);
      expect(supportsTray(PlatformKind.ios), isFalse);
    });
  });

  group('primaryChromePlan', () {
    test('windows 10 and 11 alike draw their own strip, and the resize is theirs', () {
      final plan = primaryChromePlan(PlatformKind.windows);

      expect(plan.mode, ChromeMode.selfDrawn);
      expect(plan.ownsResize, isTrue);
      expect(plan.ownsSnap, isFalse);
    });

    test('Linux draws its own strip and therefore owns what that costs', () {
      final plan = primaryChromePlan(PlatformKind.linux);

      expect(plan.mode, ChromeMode.selfDrawn);
      expect(plan.ownsSnap, isTrue);
      expect(plan.workAreaClampNeeded, isTrue);
    });
  });
}
