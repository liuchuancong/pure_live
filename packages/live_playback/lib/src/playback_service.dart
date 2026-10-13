import 'dart:async';

import 'package:live_playback/src/background/background_playback_manager.dart';
import 'package:live_playback/src/config/playback_settings.dart';
import 'package:live_playback/src/config/window_preference_store.dart';
import 'package:live_playback/src/coordinator/playback_session_coordinator.dart';
import 'package:live_playback/src/feed/feed_playback_manager.dart';
import 'package:live_playback/src/model/content_type.dart';
import 'package:live_playback/src/model/playback_metadata.dart';
import 'package:live_playback/src/model/playback_system_state.dart';
import 'package:live_playback/src/multiview/multi_view_manager.dart';
import 'package:live_playback/src/notifications/playback_notifications.dart';
import 'package:live_playback/src/orchestration/playback_orchestrator.dart';
import 'package:live_playback/src/presentation/in_place_presentation_adapter.dart';
import 'package:live_playback/src/presentation/playback_presentation.dart';
import 'package:live_playback/src/presentation/window_geometry.dart';
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
/// - [PlaybackSettings] (optional): device profile and whether background
///   playback, PiP and the floating window are allowed — the viewer's settings,
///   not ours. Live: flip one while a video plays and the next decision obeys
///   the new answer;
/// - `PresentationAdapter` (optional, from `media_core_presentation` /
///   `media_core_pip` / `media_core_floating`): the platform mechanics behind
///   fullscreen, PiP and the floating window. Without one, the stack reports
///   fullscreen and window-fullscreen as available (they are host layout) and
///   PiP/floating as unsupported, so nothing asks for a window that would never
///   appear;
/// - [MediaSessionDriver] (optional, from `media_core_mediasession`): the app
///   attaches it to the kernel; when present, the notification names the room;
/// - [WindowPreferenceStore] (optional): where the viewer's window layout is
///   remembered across launches; `HiveWindowPreferenceStore` serves it from
///   `live_storage`.
final class PlaybackService {
  /// Creates the service.
  new({
    required PlayerKernel kernel,
    PresentationController? presentationController,
    PresentationAdapter? presentationAdapter,
    MediaSessionDriver? mediaSession,
    WindowPreferenceStore? windowStore,
    PlaybackSettings? settings,
  }) : settings = settings ?? PlaybackSettings(),
       notifications = PlaybackNotifications(driver: mediaSession) {
    coordinator = PlaybackSessionCoordinator(kernel: kernel, settings: this.settings);
    this.presentationController = presentationController ?? PresentationController();
    presentation = PlaybackPresentation(
      service: PresentationService(
        controller: this.presentationController,
        adapter: presentationAdapter ?? InPlacePresentationAdapter(),
      ),
      preferences: WindowPreferenceManager(store: windowStore ?? EphemeralWindowPreferenceStore()),
      settings: this.settings,
    );
    feed = FeedPlaybackManager(coordinator: coordinator);
    multiView = MultiViewManager(coordinator: coordinator);
    background = BackgroundPlaybackManager(
      coordinator: coordinator,
      presentation: presentation,
      settings: this.settings,
    );
    orchestrator = PlaybackOrchestrator(
      coordinator: coordinator,
      presentation: presentation,
      background: background,
      notifications: notifications,
    );

    _sessionSub = coordinator.sessionIds.listen((_) {
      _watchSessions();
      _publishState();
    });
    this.settings.addListener(_onSettingsChanged);
    _primarySub = coordinator.currentSessionIdStream.listen((_) => _publishState());
    _modeSub = presentation.modeChanges.listen((_) => _publishState());
    _backgroundSub = background.backgroundedChanges.listen((_) => _publishState());
  }

  /// What the viewer allows and what device this is.
  ///
  /// Live settings: replacing [PlaybackSettings.config] while a video plays is
  /// supported and republishes the state snapshot.
  final PlaybackSettings settings;

  /// The session registry: every open window, who owns the audio.
  late final PlaybackSessionCoordinator coordinator;

  /// Presentation policy and window geometry memory.
  late final PlaybackPresentation presentation;

  /// The presentation state machine this service drives.
  ///
  /// Exposed because the host often needs it directly: to observe the full
  /// state (target mode, generations, errors), or to feed it orientation and
  /// capability changes from its own platform layer.
  late final PresentationController presentationController;

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

  final BehaviorSubject<PlaybackSystemState> _state = BehaviorSubject<PlaybackSystemState>.seeded(
    PlaybackSystemState.idle,
  );

  StreamSubscription<List<String>>? _sessionSub;
  StreamSubscription<String?>? _primarySub;
  StreamSubscription<PresentationMode>? _modeSub;
  StreamSubscription<bool>? _backgroundSub;

  /// Per-session subscriptions that keep the snapshot honest, keyed by session.
  ///
  /// The snapshot is a value, so anything that changes what it says has to
  /// publish a new one — including changes nobody asked the service for, like
  /// the feed muting a tile or another window claiming the audio channel.
  final Map<String, List<StreamSubscription<Object?>>> _watched = <String, List<StreamSubscription<Object?>>>{};

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

  /// Continues a playing session in an overlay window.
  ///
  /// The one call a page makes when it is being popped while its video should
  /// keep going: the session keeps playing, becomes the audible window and
  /// moves into [surface]. It survives the page — opening other content or
  /// leaving the list stops the *page's* video, not this one — until the
  /// overlay is exited or the session is closed.
  Future<void> handOffToOverlay({String? id, WindowSurface surface = WindowSurface.floating}) =>
      execute(HandOffToOverlayIntent(surface: surface, sessionId: id));

  /// Returns the picture from an overlay to the page.
  Future<void> exitOverlay() => execute(const ExitOverlayIntent());

  /// The session currently in an overlay window, if any.
  String? get overlaySessionId => orchestrator.overlaySessionId;

  /// The session a recorded video displaced, if any.
  String? get suspendedSessionId => orchestrator.suspendedSessionId;

  /// Tells the layout layer the video turned, so the strategy follows it.
  void updateVideoOrientation(VideoOrientation orientation) => presentation.updateOrientation(orientation);

  /// Subscribes to the open sessions' state, dropping the ones that closed.
  ///
  /// The transport subscription is filtered to the coarse states — playing,
  /// paused, buffering — because a snapshot per position tick would rebuild the
  /// whole map sixty times a second for numbers the UI reads from the player
  /// widget anyway.
  void _watchSessions() {
    final live = coordinator.sessions.keys.toSet();

    for (final id in _watched.keys.toSet()) {
      if (live.contains(id)) {
        continue;
      }
      for (final subscription in _watched.remove(id)!) {
        unawaited(subscription.cancel());
      }
    }

    for (final id in live) {
      if (_watched.containsKey(id)) {
        continue;
      }

      final session = coordinator.sessionFor(id);
      if (session == null) {
        continue;
      }

      _watched[id] = <StreamSubscription<Object?>>[
        session.state.listen((_) => _publishState()),
        session.mutedChanges.listen((_) => _publishState()),
        session.danmakuEnabledChanges.listen((_) => _publishState()),
        session.transportState
            .map((state) => (state.isPlaying, state.buffering, state.command))
            .distinct()
            .listen((_) => _publishState()),
      ];
    }
  }

  /// Republishes when the viewer changes a setting.
  ///
  /// A settings change does not have to touch the picture — turning PiP off
  /// while a video plays changes the *next* decision — but the snapshot the UI
  /// renders includes the settings, so it has to move with them.
  void _onSettingsChanged() => _publishState();

  void _publishState() {
    final sessions = <String, PlaybackSessionSnapshot>{
      for (final entry in coordinator.sessions.entries)
        entry.key: entry.value.toSnapshot(isPrimary: entry.key == coordinator.currentSessionId),
    };

    _state.add(
      PlaybackSystemState(
        sessions: sessions,
        primarySessionId: coordinator.currentSessionId,
        overlaySessionId: orchestrator.overlaySessionId,
        presentationMode: presentation.mode,
        presentationTransitioning: presentation.isTransitioning,
        deviceProfile: settings.deviceProfile,
        isBackgrounded: background.isBackgrounded,
        allMuted: sessions.isNotEmpty && sessions.values.every((session) => session.muted),
        allDanmakuDisabled: !coordinator.danmakuEnabled,
      ),
    );
  }

  /// Releases every coordinator, session and stream.
  Future<void> dispose() async {
    await _sessionSub?.cancel();
    settings.removeListener(_onSettingsChanged);
    await _primarySub?.cancel();
    await _modeSub?.cancel();
    await _backgroundSub?.cancel();
    for (final subscriptions in _watched.values) {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    }
    _watched.clear();
    await feed.dispose();
    await multiView.dispose();
    await background.dispose();
    await orchestrator.dispose();
    await coordinator.dispose();
    await _state.close();
    await presentation.dispose();
    await presentation.service.dispose();
  }
}
