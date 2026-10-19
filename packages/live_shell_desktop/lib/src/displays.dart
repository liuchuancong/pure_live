import 'dart:ui' show Offset, Rect, Size;

import 'package:live_shell/live_shell.dart';
import 'package:screen_retriever/screen_retriever.dart';

/// Reads the displays a window may be placed on.
///
/// A seam rather than the concrete reader below: the shell resolves a frame to a
/// display id on every geometry read, and a test that exercises that has no
/// display server to ask.
typedef DisplayReader = Future<List<DisplayFrame>> Function();

/// One display's geometry, reduced to what the shell can act on.
///
/// The plugin hands back an FFI-backed `Display` whose handles belong to the
/// native side, so the conversion below takes this plain record instead: the
/// reader flattens the plugin object once, and the mapping the tests argue
/// about is reachable without a display server.
typedef DisplayGeometry = ({int id, Offset position, Size size, Rect workArea, double scaleFactor});

/// Reads the displays the shell may place a window on.
///
/// The mapping is documented field by field because the shell's [DisplayFrame]
/// and the display API do not use the same vocabulary:
///
/// * `size`/`position` are the display's full extent and its origin — 0.3 of the
///   display API reports the origin too, which is what `bounds` is now assembled
///   from. The 0.2 bridge only reported the *visible* origin, so `bounds`
///   understated a frame by the width of the bars on its near edge; that
///   compromise is gone.
/// * `workArea` is the area left after the menu bar, taskbar and any reserved
///   edges, which is what maximising must clamp to.
/// * Sizes are in **logical pixels**, the unit this whole shell standardises on.
final class ScreenRetrieverDisplays {
  /// A reader over the shared display manager.
  const new();

  /// Every display currently attached.
  Future<List<DisplayFrame>> read() async {
    final displays = DisplayManager.instance.getAll();
    return [for (final display in displays) toDisplayFrame(geometryOf(display))];
  }

  /// Flattens one plugin display into [DisplayGeometry].
  DisplayGeometry geometryOf(Display display) => (
    id: display.id,
    position: display.position.toOffset(),
    size: display.size.toSize(),
    workArea: display.workArea.toRect(),
    scaleFactor: display.scaleFactor,
  );

  /// Converts one [DisplayGeometry] into the shell's value.
  DisplayFrame toDisplayFrame(DisplayGeometry display) {
    final position = display.position;
    final size = display.size;
    final bounds = PixelRect(position.dx.round(), position.dy.round(), size.width.round(), size.height.round());
    final work = display.workArea;
    return DisplayFrame(
      // The plugin's id is an int now; the shell keeps it as an opaque string, so
      // a geometry saved by an older build simply stops matching and the restore
      // falls back to the first display (§ window_geometry.restoreWindow).
      id: display.id.toString(),
      bounds: bounds,
      workArea: PixelRect(work.left.round(), work.top.round(), work.width.round(), work.height.round()),
      scaleFactor: display.scaleFactor,
    );
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

/// Where a window of [size] should open, in the plugin's coordinate space, or
/// null when no display can be read.
typedef WindowOriginReader = Future<Offset?> Function(Size size);

/// The work-area-centred origin the window plugin would have computed for
/// itself, computed here instead.
///
/// `window_frame_kit` 0.3 moved its own centering onto the display API's FFI
/// handles (`WindowOptions.center` and `center()` both call
/// `calcWindowPosition`, which reads `DisplayManager` directly), so a caller that
/// wants the placement to be observable — or testable without a display server —
/// has to do the arithmetic and hand the plugin a position. The selection order
/// is the plugin's: the display under the cursor, else the primary, else the
/// first; the centring is inside `workArea`, not the full extent, so a remembered
/// taskbar never ends up under the window.
Future<Offset?> centerOnWorkArea(Size size) async {
  const manager = DisplayManager.instance;
  final displays = manager.getAll();
  if (displays.isEmpty) {
    return null;
  }
  final cursor = manager.getCursorPosition().toOffset();
  final area =
      displays.where((display) => display.workArea.toRect().contains(cursor)).firstOrNull ??
      displays.firstWhere((display) => display.isPrimary, orElse: () => displays.first);
  final work = area.workArea.toRect();
  // The plugin's own arithmetic: the free space is measured inside the work
  // area and split evenly, so a window taller than the work area lands at its
  // top rather than hanging over the taskbar.
  return Offset(work.left + (work.width - size.width) / 2, work.top + (work.height - size.height) / 2);
}

/// The logical-pixel rectangle the window plugin reports, converted.
PixelRect rectToFrame(Rect rect) =>
    PixelRect(rect.left.round(), rect.top.round(), rect.width.round(), rect.height.round());

/// The shell's frame, converted back for the window plugin.
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
