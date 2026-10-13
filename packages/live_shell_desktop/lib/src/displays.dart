import 'dart:ui' show Offset, Rect, Size;

import 'package:live_shell/live_shell.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// Reads the displays a window may be placed on.
///
/// A seam rather than the concrete reader below: the shell resolves a frame to a
/// display id on every geometry read, and a test that exercises that has no
/// display server to ask.
typedef DisplayReader = Future<List<DisplayFrame>> Function();

/// Reads the displays the shell may place a window on.
///
/// The mapping is documented field by field because `screen_retriever` reports
/// less than the shell's [DisplayFrame] asks for, and pretending otherwise is
/// how a window ends up under the taskbar:
///
/// * `size` is the display's full extent, `visiblePosition`/`visibleSize` are
///   the area left after the menu bar, taskbar and any reserved edges — the work
///   area, which is exactly what maximising must clamp to.
/// * **The full frame's origin is not reported.** Only the visible area's origin
///   is, so [DisplayFrame.bounds] is assembled as the visible origin with the
///   full size added at the far end. That understates the frame by the width of
///   the bars on the near edge and cannot be helped from Dart. Nothing in the
///   shell decides on `bounds`: placement, clamping and visibility tests all read
///   `workArea`, so the approximation stays inert. If a future need makes it
///   live, the fix is a native read of the monitor info, not a change here.
/// * Sizes come back in **logical pixels**, which is the unit this whole shell
///   standardises on.
final class ScreenRetrieverDisplays {
  /// A reader over the shared screen_retriever instance.
  const new();

  /// Every display currently attached.
  Future<List<DisplayFrame>> read() async {
    final displays = await ScreenRetriever.instance.getAllDisplays();
    return [for (final display in displays) toDisplayFrame(display)];
  }

  /// Converts one plugin display into the shell's value.
  DisplayFrame toDisplayFrame(Display display) {
    final visiblePosition = display.visiblePosition ?? Offset.zero;
    final visibleSize = display.visibleSize ?? display.size;
    final scaleFactor = display.scaleFactor?.toDouble() ?? 1;
    final workArea = PixelRect(
      visiblePosition.dx.round(),
      visiblePosition.dy.round(),
      visibleSize.width.round(),
      visibleSize.height.round(),
    );
    final bounds = PixelRect(workArea.left, workArea.top, display.size.width.round(), display.size.height.round());
    return DisplayFrame(id: display.id, bounds: bounds, workArea: workArea, scaleFactor: scaleFactor);
  }

  /// Which display a frame is mostly on, null when it is on none of them.
  ///
  /// Used to record [WindowGeometry.displayId] after a drag: the window manager
  /// knows where the window is but not which screen it belongs to, and the
  /// difference matters only once a screen disappears — that is when the
  /// remembered id decides where the window comes back.
  String? displayHosting(PixelRect frame, List<DisplayFrame> displays) {
    String? best;
    var bestArea = 0;
    for (final display in displays) {
      final overlap = frame.intersect(display.workArea);
      if (overlap == null) {
        continue;
      }
      final area = overlap.width * overlap.height;
      if (area > bestArea) {
        bestArea = area;
        best = display.id;
      }
    }
    return best;
  }
}

/// The logical-pixel rectangle `window_manager` reports, converted.
PixelRect rectToFrame(Rect rect) =>
    PixelRect(rect.left.round(), rect.top.round(), rect.width.round(), rect.height.round());

/// The shell's frame, converted back for `window_manager`.
Rect frameToRect(PixelRect frame) =>
    Rect.fromLTWH(frame.left.toDouble(), frame.top.toDouble(), frame.width.toDouble(), frame.height.toDouble());

/// The size a window starts with when nothing has been remembered yet.
///
/// A constant with **one** home, because the same number used to be written twice
/// with two different answers (here and `configureMainWindow`'s default
/// parameter), and an unused "default" is not a default — the window came up at
/// whichever one its caller happened to read.
///
/// It is deliberately not clamped to the display. On a machine whose work area is
/// smaller than this the window manager applies its own placement, and an app
/// that needs a guaranteed fit should compute a size from
/// [ScreenRetrieverDisplays] and pass it in; silently shrinking a window the
/// caller asked for is its own surprise.
const Size defaultWindowSize = Size(1280, 800);
