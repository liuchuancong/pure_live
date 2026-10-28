import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart' show AppLifecycleState, WidgetsBinding, WidgetsBindingObserver;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_core/media_core.dart' show PlayerHandle, PlayerHandleLifecycle, PlayerKernel, PresentationMode;
import 'package:pure_live/app/providers/player/player_backend_providers.dart' show PlayerKernelBackend;
import 'package:pure_live/app/providers/player/player_providers.dart' show playerKernelProvider;
import 'package:pure_live/app/providers/window/presentation_providers.dart' show roomPresentationProvider;
import 'package:pure_live/app/providers/window/system_pip.dart' show exitSystemPip;

/// The system picture-in-picture window's two lifecycle rules on iOS.
///
/// 1. Leaving the foreground must not pause the picture. `PlayerKernel`
///    deactivates every playing handle when the app goes away — the right
///    rule everywhere except here: an open system window is the app still
///    watching, and the layer it shows belongs to the handle that pause would
///    stop. iOS therefore builds its kernel without that pause
///    (`KernelOptions.pauseWhenBackgrounded` off) and applies the same rule
///    here, exempting the window. The rule stays the kernel's own: every
///    playing handle is deactivated, not just the visible one, and nothing is
///    resumed on the way back — audio starting by itself after an app switch
///    reads as a bug.
///
///    One engine is exempt even without an open window: BetterPlayer's iOS
///    view is an AVPlayerLayer and it arms the system's automatic window
///    itself, so leaving the app floats that picture by design. Pausing it
///    here would freeze the window iOS just opened.
/// 2. Coming back into the app takes the picture back. iOS keeps the window
///    open over another app; returning to this one means the page's own
///    picture is on screen again, so the window goes.
final class SystemPipLifecycle with WidgetsBindingObserver {
  /// Starts watching the app lifecycle for [kernel].
  SystemPipLifecycle({required this.kernel, required this.pipOpen}) {
    WidgetsBinding.instance.addObserver(this);
  }

  /// The window's players.
  final PlayerKernel kernel;

  /// Whether the system's picture-in-picture window holds the picture.
  final bool Function() pipOpen;

  /// The engine whose iOS player view floats itself into the system window;
  /// see the class comment.
  static final String _selfFloatingEngine = PlayerKernelBackend.betterPlayer.id;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        if (pipOpen()) return;
        for (final handle in players) {
          if (handle.disposed ||
              handle.backendId == _selfFloatingEngine ||
              !(handle.config.pauseWhenBackgrounded ?? true) ||
              !handle.playbackStream.value.isPlaying) {
            continue;
          }
          unawaited(handle.deactivate());
        }
      case AppLifecycleState.resumed:
        if (pipOpen()) unawaited(exitSystemPip());
        for (final handle in players) {
          if (!handle.disposed) handle.activate();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // Transient on the way to paused, or the process is going away: no
        // player action, and no surprise pause when a dialog steals focus.
        break;
    }
  }

  /// Stops observing; the kernel outlives this guard.
  void dispose() => WidgetsBinding.instance.removeObserver(this);

  /// The players as they are right now — a transition never acts on the list
  /// a previous build saw.
  List<PlayerHandle> get players => kernel.handles;
}

/// The window's picture-in-picture lifecycle guard.
///
/// Every page that can go fullscreen publishes its mode through the room
/// presentation controller, so this is the one answer regardless of which
/// page owns the player.
final Provider<SystemPipLifecycle> systemPipLifecycleProvider = Provider<SystemPipLifecycle>(createSystemPipLifecycle);

/// Builds the iOS lifecycle guard for one window.
SystemPipLifecycle createSystemPipLifecycle(Ref ref) {
  final guard = SystemPipLifecycle(
    kernel: ref.watch(playerKernelProvider),
    pipOpen: () {
      try {
        return ref.read(roomPresentationProvider) == PresentationMode.pip;
      } on Object {
        // The scope is gone with the window: nothing is playing any more.
        return false;
      }
    },
  );
  ref.onDispose(guard.dispose);
  return guard;
}
