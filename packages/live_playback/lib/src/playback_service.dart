import 'dart:async';

import 'package:live_playback/src/background/background_playback_manager.dart';
import 'package:live_playback/src/config/playback_config.dart';
import 'package:live_playback/src/config/window_preference_store.dart';
import 'package:live_playback/src/coordinator/playback_session_coordinator.dart';
import 'package:live_playback/src/feed/feed_playback_manager.dart';
import 'package:live_playback/src/model/content_type.dart';
import 'package:live_playback/src/model/playback_metadata.dart';
import 'package:live_playback/src/model/playback_system_state.dart';
import 'package:live_playback/src/multiview/multi_view_manager.dart';
import 'package:live_playback/src/notifications/playback_notifications.dart';
import 'package:live_playback/src/orchestration/playback_orchestrator.dart';
import 'package:live_playback/src/presentation/playback_presentation.dart';
import 'package:live_playback/src/presentation/window_preference_manager.dart';
import 'package:live_playback/src/session/playback_session.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:media_core_mediasession/media_core_mediasession.dart';
import 'package:rxdart/rxdart.dart';

/// The single entry point the app talks to.
///
/// It assembles the coordinators over the host's kernel and exposes two
/// things: **intents** in (what the viewer asked for) and **one state
/// snapshot** out (what the system is doing). A surface — a room page, a PiP
/// window, a debug overlay — subscribes to [stateStream] and renders from
/// [PlaybackSystemState] instead of holding a controller of its own.
///
/// What the host supplies, and why each is the host's call:
///
/// - the [PlayerKernel]: the app owns adapters and the audio driver;
/// - [PlaybackConfig]: device profile, whether background playback, PiP and
///   the floating window are allowed — the viewer's settings, not ours;
/// - `PresentationManager` (optional, from `media_core`): built by the app
///   with whatever platform drivers it has, so this package never imports a
///   window manager. Without one, a default manager tracks the mode and no
///   platform window is touched;
/// - [MediaSessionDriver] (optional, from `media_core_mediasession`): the app
///   attaches it to the kernel; when present, the notification names the room;
/// - [WindowPreferenceStore] (optional): where the viewer's window layout is
///   remembered across launches; `HiveWindowPreferenceStore` serves it from
///   `live_storage`.
final class PlaybackService {
  /// Creates the service.
  new({
    required PlayerKernel kernel,
    PresentationManager? presentationManager,
    MediaSessionDriver? mediaSession,
    WindowPreferenceStore? windowStore,
    this.config = PlaybackConfig.defaults,
  }) : coordinator = PlaybackSessionCoordinator(kernel: kernel, config: config),
       _ownPresentation = presentationManager == null,
       presentation = PlaybackPresentation(
         manager: presentationManager ?? PresentationManager(controller: PresentationController()),
         preferences: WindowPreferenceManager(store: windowStore ?? EphemeralWindowPreferenceStore()),
         config: config,
       ),
       notifications = PlaybackNotifications(driver: mediaSession) {
    feed = FeedPlaybackManager(coordinator: coordinator);
    multiView = MultiViewManager(coordinator: coordinator);
    background = BackgroundPlaybackManager(coordinator: coordinator, presentation: presentation, config: config);
    orchestrator = PlaybackOrchestrator(
      coordinator: coordinator,
      presentation: presentation,
      background: background,
      notifications: notifications,
    );

    _sessionSub = coordinator.sessionIds.listen((_) => _publishState());
    _modeSub = presentation.modeChanges.listen((_) => _publishState());
    _backgroundSub = background.backgroundedChanges.listen((_) => _publishState());
  }

  /// What the viewer allows and what device this is.
  final PlaybackConfig config;

  /// The session registry: every open window, who owns the audio.
  final PlaybackSessionCoordinator coordinator;

  /// Presentation policy and window geometry memory.
  final PlaybackPresentation presentation;

  /// Media surface naming.
  final PlaybackNotifications notifications;

  /// Vertical feed playback with preloading and anchors.
  late final FeedPlaybackManager feed;

  /// Multi-window playback with one audible tile.
  late final MultiViewManager multiView;

  /// Visibility policy.
  late final BackgroundPlaybackManager background;

  /// The intent-to-coordinator brain.
  late final PlaybackOrchestrator orchestrator;

  final bool _ownPresentation;

  final BehaviorSubject<PlaybackSystemState> _state = BehaviorSubject<PlaybackSystemState>.seeded(
    PlaybackSystemState.idle,
  );

  StreamSubscription<List<String>>? _sessionSub;
  StreamSubscription<PresentationMode>? _modeSub;
  StreamSubscription<bool>? _backgroundSub;

  /// The current state snapshot.
  PlaybackSystemState get state => _state.value;

  /// The state snapshot stream. The UI observes this.
  ValueStream<PlaybackSystemState> get stateStream => _state.stream;

  /// Runs an intent.
  ///
  /// Every intent publishes a fresh snapshot before returning, so a caller
  /// that awaits it can read [state] immediately.
  Future<void> execute(PlaybackIntent intent) async {
    await orchestrator.execute(intent);
    _publishState();
  }

  /// Opens a live room.
  Future<PlaybackSession> openLive({
    required String id,
    required PlayerSource source,
    List<PlayerSource> candidateSources = const <PlayerSource>[],
    PlaybackMetadata metadata = PlaybackMetadata.none,
    DanmakuController? danmaku,
  }) async {
    await execute(
      OpenContentIntent(
        id: id,
        source: source,
        candidateSources: candidateSources,
        metadata: metadata,
        danmaku: danmaku,
      ),
    );
    return coordinator.sessionFor(id)!;
  }

  /// Opens a recorded video, suspending whatever live room was playing.
  Future<PlaybackSession> openRecorded({
    required String id,
    required PlayerSource source,
    List<PlayerSource> candidateSources = const <PlayerSource>[],
    PlaybackMetadata metadata = PlaybackMetadata.none,
  }) async {
    await execute(
      OpenContentIntent(
        id: id,
        source: source,
        candidateSources: candidateSources,
        contentType: ContentType.recorded,
        metadata: metadata,
      ),
    );
    return coordinator.sessionFor(id)!;
  }

  /// Returns to the live room that [openRecorded] suspended, if any.
  Future<void> returnToSuspendedLive() => execute(const ReturnToSuspendedIntent());

  /// Tells the system the app became visible or invisible.
  Future<void> setVisible({required bool isVisible}) => execute(VisibilityChangeIntent(isVisible: isVisible));

  /// Closes one window, or all of them when [id] is null.
  Future<void> close({String? id}) => execute(CloseSessionIntent(id: id));

  /// Silences or unsilences the whole app.
  Future<void> setMuted({required bool muted}) => execute(SetMutedIntent(muted: muted));

  /// Turns chat on or off for every open window.
  Future<void> setDanmakuEnabled({required bool enabled}) => execute(SetDanmakuIntent(enabled: enabled));

  /// Replaces one room's chat blocklist.
  void updateDanmakuPolicy(String id, DanmakuFilterPolicy policy) {
    coordinator.sessionFor(id)?.updateDanmakuPolicy(policy);
  }

  /// Switches presentation mode (fullscreen, PiP, floating, normal).
  Future<void> setPresentationMode(PresentationMode mode) => execute(ChangePresentationIntent(mode));

  /// Tells the layout layer the video turned, so the strategy follows it.
  void updateVideoOrientation(VideoOrientation orientation) => presentation.updateOrientation(orientation);

  void _publishState() {
    final sessions = <String, PlaybackSessionSnapshot>{
      for (final entry in coordinator.sessions.entries)
        entry.key: entry.value.toSnapshot(isPrimary: entry.key == coordinator.currentSessionId),
    };

    _state.add(
      PlaybackSystemState(
        sessions: sessions,
        primarySessionId: coordinator.currentSessionId,
        presentationMode: presentation.mode,
        presentationTransitioning: presentation.isTransitioning,
        deviceProfile: config.deviceProfile,
        isBackgrounded: background.isBackgrounded,
        allMuted: sessions.isNotEmpty && sessions.values.every((session) => session.muted),
        allDanmakuDisabled: !coordinator.danmakuEnabled,
      ),
    );
  }

  /// Releases every coordinator, session and stream.
  Future<void> dispose() async {
    await _sessionSub?.cancel();
    await _modeSub?.cancel();
    await _backgroundSub?.cancel();
    await feed.dispose();
    await multiView.dispose();
    await background.dispose();
    await orchestrator.dispose();
    await coordinator.dispose();
    await _state.close();
    if (_ownPresentation) {
      await presentation.manager.dispose();
    }
    await presentation.dispose();
  }
}
