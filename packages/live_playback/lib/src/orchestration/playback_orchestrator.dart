import 'dart:async';

import 'package:live_playback/src/background/background_playback_manager.dart';
import 'package:live_playback/src/coordinator/playback_session_coordinator.dart';
import 'package:live_playback/src/model/content_type.dart';
import 'package:live_playback/src/model/playback_metadata.dart';
import 'package:live_playback/src/notifications/playback_notifications.dart';
import 'package:live_playback/src/presentation/playback_presentation.dart';
import 'package:live_playback/src/presentation/window_geometry.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';

/// What the UI asks the playback system to do.
///
/// The app states intent ("show this room", "go fullscreen", "I am leaving")
/// and the orchestrator decides which coordinators have to move, in which
/// order. This is what keeps the transition rules — and not the widgets — the
/// place where "opening a recorded video pauses the live room" is written down.
sealed class PlaybackIntent {
  /// Base constructor for intents.
  const new();
}

/// Show different content in the primary window.
final class OpenContentIntent extends PlaybackIntent {
  /// Creates the intent.
  const new({
    required this.id,
    required this.source,
    this.candidateSources = const <PlayerSource>[],
    this.contentType = ContentType.live,
    this.metadata = PlaybackMetadata.none,
    this.danmaku,
  });

  /// Business id of the content (room id, video id).
  final String id;

  /// Resolved playback source.
  final PlayerSource source;

  /// Alternative lines/qualities for recovery.
  final List<PlayerSource> candidateSources;

  /// Live or recorded.
  final ContentType contentType;

  /// Room identity.
  final PlaybackMetadata metadata;

  /// Optional chat controller factory.
  final DanmakuController? danmaku;
}

/// Return to whatever [OpenContentIntent] suspended.
final class ReturnToSuspendedIntent extends PlaybackIntent {
  /// Creates the intent.
  const new();
}

/// Change how the picture is presented.
final class ChangePresentationIntent extends PlaybackIntent {
  /// Creates the intent.
  const new(this.mode);

  /// The desired mode.
  final PresentationMode mode;
}

/// The app became visible or invisible.
final class VisibilityChangeIntent extends PlaybackIntent {
  /// Creates the intent.
  const new({required this.isVisible});

  /// Whether the app is visible now.
  final bool isVisible;
}

/// Stops one window, or all of them.
final class CloseSessionIntent extends PlaybackIntent {
  /// Creates the intent.
  const new({this.id});

  /// The session to close; null means every session.
  final String? id;
}

/// Turns the sound on or off for the whole app.
final class SetMutedIntent extends PlaybackIntent {
  /// Creates the intent.
  const new({required this.muted});

  /// Whether everything should be silent.
  final bool muted;
}

/// Continues a session in an overlay window instead of on its page.
///
/// Called when a page goes away while its video is still playing: the session
/// keeps running, becomes the audible window and moves into PiP or the in-app
/// small window. The page is gone, the video is not.
final class HandOffToOverlayIntent extends PlaybackIntent {
  /// Creates the intent.
  const new({required this.surface, this.sessionId});

  /// Which overlay continues the video.
  final WindowSurface surface;

  /// The session to hand off; null means the current one.
  final String? sessionId;
}

/// Returns the picture from an overlay back to the page.
final class ExitOverlayIntent extends PlaybackIntent {
  /// Creates the intent.
  const new();
}

/// Turns chat on or off for every open window.
final class SetDanmakuIntent extends PlaybackIntent {
  /// Creates the intent.
  const new({required this.enabled});

  /// Whether chat should be visible.
  final bool enabled;
}

/// The business brain: turns [PlaybackIntent]s into coordinator calls.
///
/// It owns the two rules that span the whole system rather than any one
/// window:
///
/// - **content switching**: opening a recorded video *suspends* the live room
///   (paused, still open) instead of destroying it, so returning resumes the
///   room the viewer was in; opening another live room closes the old one,
///   because two live rooms in memory is a leak with no upside;
/// - **the overlay outlives the page**: a session handed to PiP or the small
///   window keeps playing when the page that owned it closes or opens other
///   content, and the page that comes back takes the sound with a claim — the
///   overlay is muted, not stopped. Everything else follows from one rule:
///   opening content only *stops* what is not in an overlay, and only *parks*
///   (pauses, keeps) a live room displaced by a recorded video;
/// - **presentation side effects**: when the mode changes, the session's chat
///   rule and the media surface's metadata are updated in the same step, so a
///   PiP window never shows chat and never names the wrong room.
final class PlaybackOrchestrator {
  /// Creates the orchestrator.
  new({required this.coordinator, required this.presentation, required this.background, required this.notifications}) {
    _modeSub = presentation.modeChanges.listen(applyPresentationMode);
  }

  /// The session registry.
  final PlaybackSessionCoordinator coordinator;

  /// Presentation policy.
  final PlaybackPresentation presentation;

  /// Visibility policy.
  final BackgroundPlaybackManager background;

  /// System media surface naming.
  final PlaybackNotifications notifications;

  StreamSubscription<PresentationMode>? _modeSub;

  /// The live room that was put aside to play something else.
  String? _suspendedId;

  /// The session showing in an overlay window, if any.
  String? _overlayId;

  /// The room currently suspended, if any.
  String? get suspendedSessionId => _suspendedId;

  /// The session currently in an overlay window, if any.
  String? get overlaySessionId => _overlayId;

  /// Executes [intent].
  Future<void> execute(PlaybackIntent intent) {
    return switch (intent) {
      OpenContentIntent() => _open(intent),
      ReturnToSuspendedIntent() => _returnToSuspended(),
      ChangePresentationIntent() => _changePresentation(intent.mode),
      VisibilityChangeIntent() => _visibility(intent.isVisible),
      CloseSessionIntent() => _close(intent.id),
      SetMutedIntent() => _setMuted(intent.muted),
      SetDanmakuIntent() => coordinator.setAllDanmakuEnabled(enabled: intent.enabled),
      HandOffToOverlayIntent() => _handOff(intent),
      ExitOverlayIntent() => _exitOverlay(),
    };
  }

  Future<void> _open(OpenContentIntent intent) async {
    final current = coordinator.currentSession;

    if (current != null && current.id != intent.id) {
      if (current.id == _overlayId) {
        // The incoming content is the page's; the overlay is the viewer's own
        // window and keeps playing. The claim below mutes it — the page is what
        // they are looking at — but it must not be stopped or parked: closing
        // the small window is the small window's business.
        await current.setMute(muted: true);
      } else if (intent.contentType == ContentType.recorded && current.contentType == ContentType.live) {
        // Put the room aside: the viewer will come back to it, and a live room
        // that was closed has to re-resolve everything on return.
        _suspendedId = current.id;
        await current.pause();
      } else {
        await coordinator.stopSession(current.id);
        if (_suspendedId == current.id) {
          _suspendedId = null;
        }
      }
    }

    final session = await coordinator.startSession(
      id: intent.id,
      source: intent.source,
      candidateSources: intent.candidateSources,
      contentType: intent.contentType,
      metadata: intent.metadata,
      danmaku: intent.danmaku,
      autoPlay: false,
    );

    await coordinator.claimAudio(intent.id);
    await session.play();
    session.applyPresentationMode(presentation.mode);
    notifications.publishSession(session);
  }

  Future<void> _returnToSuspended() async {
    final id = _suspendedId;
    if (id == null) {
      return;
    }
    _suspendedId = null;

    final session = coordinator.sessionFor(id);
    final leaving = coordinator.currentSession;
    if (leaving != null && leaving.id != id && leaving.id != _overlayId) {
      await coordinator.stopSession(leaving.id);
    }

    if (session == null) {
      return;
    }

    await coordinator.claimAudio(id);
    // A live stream drifted while it was paused: reopening the same source
    // puts the picture back at the live edge instead of at the stale position.
    if (session.contentType == ContentType.live) {
      await session.refresh();
    }
    await session.play();
    session.applyPresentationMode(presentation.mode);
    notifications.publishSession(session);
  }

  Future<void> _exitOverlay() async {
    await presentation.exitOverlay();
    applyPresentationMode(presentation.mode);
  }

  Future<void> _changePresentation(PresentationMode mode) async {
    await presentation.requestMode(mode);
    applyPresentationMode(presentation.mode);
  }

  /// Applies the business effects of the settled presentation [mode].
  ///
  /// Called after every await of a transition, and again from the mode stream
  /// for changes that arrive from the platform (the viewer closing a PiP
  /// window, a permission being revoked). The explicit calls exist because
  /// stream delivery is not synchronous: without them, a caller that awaits
  /// [execute] could observe a mode that its session has not been told about
  /// yet, which is exactly the "PiP shows chat for one frame" bug.
  void applyPresentationMode(PresentationMode mode) {
    if (!mode.isOverlay) {
      // Back on a page: whoever was in the small window is a page again, and
      // nothing is protecting it from being closed with that page.
      _overlayId = null;
    }

    final session = coordinator.sessionFor(_overlayId ?? '') ?? coordinator.currentSession;
    session?.applyPresentationMode(mode);
  }

  /// Continues a session in an overlay window.
  ///
  /// Order matters: the audio claim first, so the session is unmuted and every
  /// other window quiet before the mode flips — a viewer who taps "play in a
  /// small window" should hear the video start, not a beat of silence while the
  /// window animates in.
  Future<void> _handOff(HandOffToOverlayIntent intent) async {
    final id = intent.sessionId ?? coordinator.currentSessionId;
    final session = id == null ? null : coordinator.sessionFor(id);
    if (id == null || session == null) {
      return;
    }

    await coordinator.claimAudio(id);
    final accepted = await presentation.requestMode(intent.surface.mode);
    if (!accepted) {
      return;
    }

    _overlayId = id;
    applyPresentationMode(presentation.mode);
    if (!session.isPlaying) {
      await session.play();
    }
  }

  Future<void> _visibility(bool isVisible) async {
    await background.onVisibilityChanged(isVisible: isVisible);

    // The background policy may have moved the picture into PiP; the session
    // has to hear about it before the caller reads the state back.
    applyPresentationMode(presentation.mode);
  }

  Future<void> _close(String? id) async {
    if (id == null) {
      await coordinator.stopAll();
      _overlayId = null;
      _suspendedId = null;
      notifications.clear();
      return;
    }

    await coordinator.stopSession(id);
    if (_overlayId == id) {
      _overlayId = null;
    }
    if (_suspendedId == id) {
      _suspendedId = null;
    }
    if (coordinator.sessions.isEmpty) {
      notifications.clear();
    }
  }

  Future<void> _setMuted(bool muted) async {
    if (muted) {
      await coordinator.muteAll();
    } else {
      await coordinator.unmuteAll();
    }
  }

  /// Releases the orchestrator's subscription.
  Future<void> dispose() => _modeSub?.cancel() ?? Future<void>.value();
}
