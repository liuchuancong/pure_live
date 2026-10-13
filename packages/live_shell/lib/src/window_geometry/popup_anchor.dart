import 'package:live_shell/src/window_geometry/window_geometry.dart';

/// Where a corner popup — update progress, "this channel went live" — lands.
///
/// A pure function of the work area rather than a call into the display API, so
/// the two platform conventions that differ here can be pinned in a test:
/// notifications dock at the **top** on macOS, under the menu bar where the
/// system's own banners appear, and at the **bottom** on Windows and Linux,
/// above the taskbar where the system's own toasts appear. Getting this wrong is
/// not fatal but it is unmistakable: a stack of app popups sitting over the Mac
/// menu bar looks wrong to anyone who uses the machine daily.
///
/// A 16-pixel inset keeps the popup off the very edge, which is where the resize
/// grab-bands and the rounded corners are; flush to the edge it also collides
/// with a taskbar set to auto-hide. The side is fixed to the far right because
/// that is where both platforms put a toast; a left variant would be a switch
/// with nothing to switch it from.
PixelRect anchorToCorner({
  required PixelRect workArea,
  required int width,
  required int height,
  required bool topEdge,
}) {
  const inset = 16;
  final left = workArea.right - inset - width;
  final top = topEdge ? workArea.top + inset : workArea.bottom - inset - height;
  return PixelRect(left, top, width, height);
}
