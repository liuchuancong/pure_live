import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'package:live_uikit/src/input/live_remote_actions.dart';

/// Turns remote-control and keyboard presses into [LiveRemoteAction]s for
/// the subtree below it.
///
/// One widget per screen (usually the player page, or the app shell) installs
/// the whole mapping, so no page ever compares key codes. Handlers are
/// optional and each is consulted only for its own action; an action with no
/// handler falls through to whatever is above — which is how "the back key
/// pops the route" keeps working for pages that do not handle back.
///
/// The arrows stay with the focus system unless [arrowsSeek] is true, because
/// hijacking them globally would make focus navigation impossible on a
/// remote: [arrowsSeek] is for the player, where the picture has focus and
/// the user expects left/right to scrub.
class LiveRemoteInput extends StatelessWidget {
  /// A remote-input scope for [child].
  const new({
    required this.child,
    this.onSelect,
    this.onBack,
    this.onMenu,
    this.onPlayPause,
    this.onSeek,
    this.onNext,
    this.onPrevious,
    this.onInfo,
    this.arrowsSeek = false,
    this.seekStep = const Duration(seconds: 10),
    super.key,
  });

  /// The subtree that receives the actions.
  final Widget child;

  /// Handles confirm.
  final LiveRemoteActionHandler? onSelect;

  /// Handles back.
  final LiveRemoteActionHandler? onBack;

  /// Handles the context menu.
  final LiveRemoteActionHandler? onMenu;

  /// Handles play/pause.
  final LiveRemoteActionHandler? onPlayPause;

  /// Handles a seek of [seekStep] in the given direction; positive seconds
  /// seek forward.
  final bool Function(BuildContext context, Duration offset)? onSeek;

  /// Handles "next item".
  final LiveRemoteActionHandler? onNext;

  /// Handles "previous item".
  final LiveRemoteActionHandler? onPrevious;

  /// Handles the info key.
  final LiveRemoteActionHandler? onInfo;

  /// Whether the arrow keys seek instead of moving focus; the player sets
  /// this while its controls are hidden.
  final bool arrowsSeek;

  /// How far one seek key press moves.
  final Duration seekStep;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _shortcuts(),
      child: Actions(
        actions: {
          LiveSelectIntent: _handler(context, onSelect),
          LiveBackIntent: _handler(context, onBack),
          LiveMenuIntent: _handler(context, onMenu),
          LivePlayPauseIntent: _handler(context, onPlayPause),
          LiveNextIntent: _handler(context, onNext),
          LivePreviousIntent: _handler(context, onPrevious),
          LiveInfoIntent: _handler(context, onInfo),
          LiveSeekIntent: CallbackAction<LiveSeekIntent>(
            onInvoke: (intent) => onSeek?.call(context, Duration(seconds: intent.seconds)) ?? false,
          ),
        },
        child: child,
      ),
    );
  }

  Map<ShortcutActivator, Intent> _shortcuts() {
    final bindings = <ShortcutActivator, Intent>{};
    void bind(List<LogicalKeyboardKey> keys, Intent intent) {
      for (final key in keys) {
        bindings[SingleActivator(key)] = intent;
      }
    }

    bind(LiveRemoteKeys.of(LiveRemoteAction.select), const LiveSelectIntent());
    bind(LiveRemoteKeys.of(LiveRemoteAction.back), const LiveBackIntent());
    bind(LiveRemoteKeys.of(LiveRemoteAction.menu), const LiveMenuIntent());
    bind(LiveRemoteKeys.of(LiveRemoteAction.playPause), const LivePlayPauseIntent());
    bind(LiveRemoteKeys.of(LiveRemoteAction.next), const LiveNextIntent());
    bind(LiveRemoteKeys.of(LiveRemoteAction.previous), const LivePreviousIntent());
    bind(LiveRemoteKeys.of(LiveRemoteAction.info), const LiveInfoIntent());
    bind(LiveRemoteKeys.of(LiveRemoteAction.seekForward), LiveSeekIntent(seekStep.inSeconds));
    bind(LiveRemoteKeys.of(LiveRemoteAction.seekBackward), LiveSeekIntent(-seekStep.inSeconds));
    if (arrowsSeek) {
      bind(LiveRemoteKeys.arrowForward, LiveSeekIntent(seekStep.inSeconds));
      bind(LiveRemoteKeys.arrowBackward, LiveSeekIntent(-seekStep.inSeconds));
    }
    return bindings;
  }

  /// An action that calls [handler], falling through when it declines.
  ///
  /// `CallbackAction.onInvoke` is the only place in the Actions API that can
  /// report "not handled", and reporting it is what lets a page handle menu
  /// while the same key still reaches a widget that does not.
  CallbackAction<T> _handler<T extends Intent>(BuildContext context, LiveRemoteActionHandler? handler) =>
      CallbackAction<T>(onInvoke: (intent) => handler?.call(context) ?? false);
}
