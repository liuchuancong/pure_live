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

/// The least width that puts the chat beside the video — the reference's
/// `roomWideMinWidth` (840; 3.x split from 680, which squeezed the video).
const double roomWideMinWidth = 840;

/// Heights below this make a sideways window a phone held landscape, whatever
/// its width — the reference's `windowCompactHeight`.
const double roomCompactMaxHeight = 480;

/// Resolves the shape from the live box, not from a boot-time fact.
///
/// [width] and [height] are the body's constraints so the answer flips when
/// the window is dragged or the phone is turned; [formFactor] only separates a
/// touch device from a windowed one and picks up the TV.
///
/// The rules are the reference's `roomPageLayout`: a short wide window is the
/// landscape shape on a touch device and keeps the split on a desktop (where
/// a short window is just a small window); the split starts at 840; below it
/// the upright phone layout carries the portrait panel when the stream is
/// vertical (the three-stop sheet lives inside [RoomShell.phonePortrait]).
RoomShell resolveRoomShell({
  required double width,
  required double height,
  required FormFactor formFactor,
  required bool isTouch,
}) {
  if (formFactor == FormFactor.tv) {
    return RoomShell.tvFocus;
  }
  // A phone held sideways (or a touch window too short for a column): the
  // video fills the height and the pane becomes a narrow side column.
  if (isTouch && height < roomCompactMaxHeight && width > height && width >= 600) {
    return RoomShell.phoneLandscape;
  }
  if (width >= roomWideMinWidth) {
    return formFactor == FormFactor.desktop ? RoomShell.desktopSplit : RoomShell.tabletSplit;
  }
  return RoomShell.phonePortrait;
}
