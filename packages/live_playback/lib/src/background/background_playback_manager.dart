import 'dart:async';

import 'package:live_playback/src/config/playback_settings.dart';
import 'package:live_playback/src/coordinator/playback_session_coordinator.dart';
import 'package:live_playback/src/presentation/playback_presentation.dart';
import 'package:rxdart/rxdart.dart';

/// What happens to playback when the app stops being visible.
///
/// The policy is the viewer's, read live from [PlaybackSettings], and the order
/// is deliberate:
///
/// 1. **PiP, when allowed** — the viewer asked to keep *watching*, and the
///    platform can float the picture. This wins over audio-only because it is
///    strictly more of what they asked for.
/// 2. **Background audio, when allowed** — nothing floats, but the sound keeps
///    going and the system media surface offers play/pause/stop. This is the
///    music-app behaviour, and it is what a live room wants when the screen
///    turns off.
/// 3. **Pause** — neither is allowed, so the app keeps quiet instead of
///    playing to nobody.
///
/// When the app comes back, a PiP window that this manager opened is closed
/// again: the picture belongs on the page it was taken from. A PiP window the
/// *viewer* opened is left alone.
final class BackgroundPlaybackManager {
  /// Creates the manager.
  new({required this.coordinator, required this.presentation, PlaybackSettings? settings})
    : settings = settings ?? PlaybackSettings();

  /// The session registry.
  final PlaybackSessionCoordinator coordinator;

  /// The presentation policy (mode transitions, PiP support).
  final PlaybackPresentation presentation;

  /// What the viewer allows, read at the moment of the decision.
  ///
  /// Read here rather than captured at construction because these are settings
  /// the viewer flips while a video is playing, and the next backgrounding has
  /// to obey the new answer.
  final PlaybackSettings settings;

  final BehaviorSubject<bool> _backgrounded = BehaviorSubject<bool>.seeded(false);

  bool _openedPip = false;

  /// Whether the app is currently backgrounded, as far as this manager knows.
  bool get isBackgrounded => _backgrounded.value;

  /// Stream of background/foreground transitions.
  ValueStream<bool> get backgroundedChanges => _backgrounded.stream;

  /// Applies the policy for a visibility change.
  ///
  /// Wire this to the app's lifecycle observer; the manager is idempotent, so
  /// a lifecycle that reports the same state twice does nothing the second
  /// time.
  Future<void> onVisibilityChanged({required bool isVisible}) {
    if (isVisible) {
      return onForegrounded();
    }
    return onBackgrounded();
  }

  /// Applies the background policy.
  Future<void> onBackgrounded() async {
    if (_backgrounded.value) {
      return;
    }
    _backgrounded.add(true);

    final session = coordinator.currentSession;
    if (session == null) {
      return;
    }

    if (settings.allowPictureInPicture && presentation.canEnterPip) {
      _openedPip = await presentation.enterPip();
      if (_openedPip) {
        return;
      }
    }

    if (!settings.allowBackgroundPlayback) {
      await session.pause();
      return;
    }

    // Audio-only background: the picture can stop rendering, the sound and the
    // system media controls must not.
    if (!session.isPlaying) {
      await session.play();
    }
  }

  /// Applies the foreground policy.
  Future<void> onForegrounded() async {
    if (!_backgrounded.value) {
      return;
    }
    _backgrounded.add(false);

    if (_openedPip) {
      _openedPip = false;
      if (presentation.isPip) {
        await presentation.exitOverlay();
      }
    }

    final session = coordinator.currentSession;
    if (session == null) {
      return;
    }

    if (!session.isPlaying && !settings.allowBackgroundPlayback) {
      // Nothing automatic: the viewer paused by leaving, so coming back does
      // not start playback behind their back.
      return;
    }

    if (!session.isPlaying) {
      await session.play();
    }
  }

  /// Releases the manager's streams.
  Future<void> dispose() => _backgrounded.close();
}
