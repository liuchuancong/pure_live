import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

/// What a remote control can ask the application to do.
///
/// A semantic set, not a key set: which physical key produces which action is
/// decided once, in [LiveRemoteKeys], so a page handles "the user wants the
/// next item" instead of `LogicalKeyboardKey.mediaTrackNext` — and a TV whose
/// remote sends a different code is fixed in one place rather than in every
/// page.
enum LiveRemoteAction {
  /// Confirm: enter, select or the centre of the d-pad.
  select,

  /// Go back: the back key, Escape or the remote's return button.
  back,

  /// Open the contextual menu of what is focused.
  menu,

  /// Play or pause.
  playPause,

  /// Seek forward by the player's step.
  seekForward,

  /// Seek backward by the player's step.
  seekBackward,

  /// Jump to the next item (channel, room, track).
  next,

  /// Jump to the previous item.
  previous,

  /// Show information about what is focused.
  info,
}

/// Which physical keys [LiveRemoteAction]s map to.
///
/// The mapping follows what Android TV, tvOS, Windows and the Flutter engine
/// agree on, and includes the game-controller buttons for remotes that
/// present as gamepads (`gameButtonA` for select, `gameButtonB` for back).
/// Arrow keys are deliberately *not* in here: on a TV the arrows move focus,
/// so a page that needs them for seeking opts in through
/// `LiveRemoteInput(arrowsSeek: true)`.
abstract final class LiveRemoteKeys {
  /// The keys that mean [action].
  static List<LogicalKeyboardKey> of(LiveRemoteAction action) => switch (action) {
    LiveRemoteAction.select => const [
      LogicalKeyboardKey.select,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.gameButtonA,
    ],
    LiveRemoteAction.back => const [
      LogicalKeyboardKey.escape,
      LogicalKeyboardKey.goBack,
      LogicalKeyboardKey.browserBack,
      LogicalKeyboardKey.gameButtonB,
    ],
    LiveRemoteAction.menu => const [
      LogicalKeyboardKey.contextMenu,
      LogicalKeyboardKey.f10,
      LogicalKeyboardKey.gameButtonStart,
    ],
    LiveRemoteAction.playPause => const [
      LogicalKeyboardKey.mediaPlayPause,
      LogicalKeyboardKey.mediaPlay,
      LogicalKeyboardKey.mediaPause,
      LogicalKeyboardKey.gameButtonX,
    ],
    LiveRemoteAction.seekForward => const [LogicalKeyboardKey.mediaFastForward, LogicalKeyboardKey.mediaTrackNext],
    LiveRemoteAction.seekBackward => const [LogicalKeyboardKey.mediaRewind, LogicalKeyboardKey.mediaTrackPrevious],
    LiveRemoteAction.next => const [LogicalKeyboardKey.channelUp, LogicalKeyboardKey.pageDown],
    LiveRemoteAction.previous => const [LogicalKeyboardKey.channelDown, LogicalKeyboardKey.pageUp],
    LiveRemoteAction.info => const [LogicalKeyboardKey.info, LogicalKeyboardKey.f1],
  };

  /// The keys that seek while arrows are claimed by the player.
  static const List<LogicalKeyboardKey> arrowBackward = [LogicalKeyboardKey.arrowLeft];

  /// The keys that seek forward while arrows are claimed by the player.
  static const List<LogicalKeyboardKey> arrowForward = [LogicalKeyboardKey.arrowRight];
}

/// A page's answer to a [LiveRemoteAction].
///
/// Returning `true` means the action was handled and the input layer stops;
/// `false` lets it fall through (to another handler above, or to the default
/// behaviour, such as the back key popping the route).
typedef LiveRemoteActionHandler = bool Function(BuildContext context);

/// An intent for [LiveRemoteAction.select], for pages that prefer the
/// intent/action machinery over callbacks.
class LiveSelectIntent extends Intent {
  /// A select intent.
  const new();
}

/// An intent for [LiveRemoteAction.back].
class LiveBackIntent extends Intent {
  /// A back intent.
  const new();
}

/// An intent for [LiveRemoteAction.menu].
class LiveMenuIntent extends Intent {
  /// A menu intent.
  const new();
}

/// An intent for [LiveRemoteAction.playPause].
class LivePlayPauseIntent extends Intent {
  /// A play/pause intent.
  const new();
}

/// An intent for seeking, with [seconds] positive forward and negative
/// backward.
class LiveSeekIntent extends Intent {
  /// A seek intent of [seconds].
  const new(this.seconds);

  /// How far to seek; negative seeks backward.
  final int seconds;

  /// Whether the seek goes forward.
  bool get forward => seconds > 0;
}

/// An intent for [LiveRemoteAction.next].
class LiveNextIntent extends Intent {
  /// A next intent.
  const new();
}

/// An intent for [LiveRemoteAction.previous].
class LivePreviousIntent extends Intent {
  /// A previous intent.
  const new();
}

/// An intent for [LiveRemoteAction.info].
class LiveInfoIntent extends Intent {
  /// An info intent.
  const new();
}
