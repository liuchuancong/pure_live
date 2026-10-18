import 'package:live_platform/live_platform.dart' show FormFactor;

/// The room page's shapes. Each one is drawn by its own layout file — there is
/// no single adaptive tree that guesses at all of them, because a phone in
/// landscape, a tablet, a resizable desktop window and a TV 10-foot view want
/// different surfaces on screen, not the same tree with different numbers.
enum RoomShell {
  /// A touch phone held upright: the video keeps the top of the column and the
  /// pane takes the rest, or rides a sheet over a vertical source.
  phonePortrait,

  /// A touch phone turned sideways: the video fills the window and the pane
  /// collapses to an overlay strip, because the height cannot spare a column.
  phoneLandscape,

  /// A touch tablet or a mid-size window: the split, with the pane as a fixed
  /// rail beside the video.
  tabletSplit,

  /// A desktop window: the split again, but hover-driven chrome, keyboard
  /// bindings and a title bar that has to coexist with the room header.
  desktopSplit,

  /// A TV: no app bar, no hover, focus-traversal only, larger type, the pane
  /// held to one side of a full-bleed video.
  tvFocus,
}

/// The width at and below which the pane goes under the video instead of
/// beside it — the reference's `resolveLivePlayNormalLayout` threshold.
const double roomSplitThreshold = 680;

/// Resolves the shape from the live box, not from a boot-time fact.
///
/// [width] and [height] are the body's constraints so the answer flips when
/// the window is dragged or the phone is turned; [formFactor] only separates a
/// touch device from a windowed one and picks up the TV.
RoomShell resolveRoomShell({
  required double width,
  required double height,
  required FormFactor formFactor,
  required bool isTouch,
}) {
  if (formFactor == FormFactor.tv) {
    return RoomShell.tvFocus;
  }
  // A phone on its side never has the height for a stacked column, whatever
  // its width reads — that is the one case where the width threshold lies.
  if (isTouch && formFactor == FormFactor.phone && width > height) {
    return RoomShell.phoneLandscape;
  }
  if (width <= roomSplitThreshold) {
    return RoomShell.phonePortrait;
  }
  return formFactor == FormFactor.desktop ? RoomShell.desktopSplit : RoomShell.tabletSplit;
}
