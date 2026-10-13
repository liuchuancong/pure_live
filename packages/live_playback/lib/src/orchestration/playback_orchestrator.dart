import 'dart:async';

import 'package:live_playback/src/background/background_playback_manager.dart';
import 'package:live_playback/src/coordinator/playback_session_coordinator.dart';
import 'package:live_playback/src/model/content_type.dart';
import 'package:live_playback/src/model/playback_metadata.dart';
import 'package:live_playback/src/notifications/playback_notifications.dart';
import 'package:live_playback/src/presentation/playback_presentation.dart';
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
/// - **presentation side effects**: when the mode changes, the session's chat
///   rule and the media surface's metadata are updated in the same step, so a
///   PiP window never shows chat and never names the wrong room.
final class PlaybackOrchestrator {
  /// Creates the orchestrator.
  new({required this.coordinator, required this.presentation, required this.background, required this.notifications}) {
    _modeSub = presentation.modeChanges.listen(_onPresentationChanged);
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

  /// The room currently suspended, if any.
  String? get suspendedSessionId => _suspendedId;

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
    };
  }

  Future<void> _open(OpenContentIntent intent) async {
    final current = coordinator.currentSession;

    if (current != null && current.id != intent.id) {
      if (intent.contentType == ContentType.recorded && current.contentType == ContentType.live) {
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
    if (leaving != null && leaving.id != id) {
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

  Future<void> _changePresentation(PresentationMode mode) async {
    await presentation.requestMode(mode);
  }

  /// Runs when the presentation layer settles on a new mode.
  void _onPresentationChanged(PresentationMode mode) {
    final session = coordinator.currentSession;
    session?.applyPresentationMode(mode);
  }

  Future<void> _visibility(bool isVisible) async {
    await background.onVisibilityChanged(isVisible: isVisible);
  }

  Future<void> _close(String? id) async {
    if (id == null) {
      await coordinator.stopAll();
      notifications.clear();
      return;
    }

    await coordinator.stopSession(id);
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
