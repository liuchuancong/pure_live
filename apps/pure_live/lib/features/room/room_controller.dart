import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show WatchRecordIdentity;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_playback/live_playback.dart' show EngineProgress, EngineReady, EngineStopped, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart'
    show
        EngineOptionOutcome,
        PlayerAdapterDurationChanged,
        PlayerAdapterEvent,
        PlayerAdapterPlaying,
        PlayerAdapterPositionChanged,
        PlayerAdapterRateChanged,
        PlayerAdapterVideoSizeChanged,
        PlayerAdapterVolumeChanged;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitPlayerAdapter;
import 'package:pure_live/app/engine/mpv_tuning.dart';
import 'package:pure_live/app/engine/playback_engine.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/room/room_providers.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

/// How the room is presented — the reference's `VideoMode`.
enum RoomPresentation {
  /// The bar, the video and the interaction pane are all on screen.
  normal,

  /// The video owns the window; every other surface is an overlay on it.
  fullscreen,

  /// A vertical source fills the window; the sheet has been dismissed off its
  /// foot and only the picture (over its ambient backdrop) remains.
  portraitFullscreen,
}

/// A sentinel so [RoomState.copyWith] can tell "leave it" from "clear it" on
/// the nullable fields — the state carries errors, and a copy that could not
/// clear one would pin a stale failure to the screen.
const Object _keep = Object();

/// The room page's snapshot: what the detail said, what the stream resolved
/// to, and how the page is presenting it.
final class RoomState {
  /// The initial snapshot: nothing loaded, the normal presentation.
  const new({
    this.room,
    this.detailError,
    this.loadingDetail = false,
    this.qualities = const [],
    this.quality,
    this.lines = const [],
    this.line,
    this.loadingLines = false,
    this.streamError,
    this.engineStopped = false,
    this.paused = false,
    this.presentation = RoomPresentation.normal,
    this.chromeVisible = true,
    this.sleepTimerActive = false,
    this.sleepMinutes = 60,
    this.sleepEndedTick = 0,
    this.barrageOn = true,
    this.volume = 1,
    this.muted = false,
    this.rate = 1,
    this.videoWidth,
    this.videoHeight,
  });

  /// The resolved room detail; null until [RoomController.load] lands.
  final LiveRoom? room;

  /// The room-detail failure — a malformed entry or a dead lookup.
  final Object? detailError;

  /// Whether the detail lookup is in flight.
  final bool loadingDetail;

  /// The qualities the platform offered for this room.
  final List<LivePlayQuality> qualities;

  /// The selected quality; the first offered until the user picks.
  final LivePlayQuality? quality;

  /// The lines the selected quality resolved to.
  final List<LivePlayLine> lines;

  /// The line the engine is playing; null before the first open.
  final LivePlayLine? line;

  /// Whether a quality/line resolve is in flight.
  final bool loadingLines;

  /// The stream-side failure: a resolve that failed, a lease that died.
  final Object? streamError;

  /// The engine reported a stop, so the surface offers a retry.
  final bool engineStopped;

  /// Whether playback is paused.
  final bool paused;

  /// The presentation the page renders.
  final RoomPresentation presentation;

  /// Whether the video's overlay chrome is up; the immersive presentations
  /// hide it after a few seconds and bring it back on a tap.
  final bool chromeVisible;

  /// Whether the sleep countdown is running right now — the reference's
  /// `ui.closeTimeFlag`.
  final bool sleepTimerActive;

  /// The timer's last committed duration, in minutes — the reference's
  /// `ui.closeTimes`. The dialog keeps its own draft; this is what the running
  /// countdown (or the next start) actually uses.
  final int sleepMinutes;

  /// Increments when the countdown fires, so a watcher can toast the finish.
  /// The timer pauses the room itself; this is only the announcement.
  final int sleepEndedTick;

  /// Whether the barrage draws over the video.
  final bool barrageOn;

  /// The player's volume, 0..1 — the app owns the number, the adapter only
  /// takes commands.
  final double volume;

  /// Whether the volume is silenced without losing its level.
  final bool muted;

  /// The playback rate; a live stream that cannot seek still accepts one.
  final double rate;

  /// The video track's width, as the engine last reported it.
  final int? videoWidth;

  /// The video track's height, as the engine last reported it.
  final int? videoHeight;

  /// Whether anything is playing.
  bool get playing => line != null;

  /// Whether the stream is switching — the selectors go inert while it is.
  bool get switching => loadingLines;

  /// The platform's own verdict is "not living" and nothing resolved.
  bool get explicitlyOffline => lines.isEmpty && (room?.broadcast.isExplicitlyOfflineNow ?? false);

  /// Whether the source is taller than wide, so the layouts can hand it the
  /// canvas rather than letterbox it. A stream that never reported its frame
  /// keeps the landscape assumption — the layouts then use the plain stack.
  bool get isVerticalSource =>
      videoWidth != null && videoHeight != null && videoWidth! > 0 && videoHeight! > videoWidth!;

  /// The frame the video area keeps: the source's own ratio once the engine
  /// reported a size, else the 16/9 the reference assumes.
  double get sourceAspectRatio => isVerticalSource ? videoWidth! / videoHeight! : 16 / 9;

  /// The same state with these fields replaced. The nullable fields that a
  /// page genuinely clears — an error that got resolved, a line that stopped
  /// existing — take the [_keep] sentinel for "leave it", so a copy that only
  /// moves a flag cannot pin a stale failure to the screen.
  RoomState copyWith({
    Object? room = _keep,
    Object? detailError = _keep,
    bool? loadingDetail,
    List<LivePlayQuality>? qualities,
    Object? quality = _keep,
    List<LivePlayLine>? lines,
    Object? line = _keep,
    bool? loadingLines,
    Object? streamError = _keep,
    bool? engineStopped,
    bool? paused,
    RoomPresentation? presentation,
    bool? chromeVisible,
    bool? sleepTimerActive,
    int? sleepMinutes,
    int? sleepEndedTick,
    bool? barrageOn,
    double? volume,
    bool? muted,
    double? rate,
    Object? videoWidth = _keep,
    Object? videoHeight = _keep,
  }) => RoomState(
    room: room == _keep ? this.room : room as LiveRoom?,
    detailError: detailError == _keep ? this.detailError : detailError,
    loadingDetail: loadingDetail ?? this.loadingDetail,
    qualities: qualities ?? this.qualities,
    quality: quality == _keep ? this.quality : quality as LivePlayQuality?,
    lines: lines ?? this.lines,
    line: line == _keep ? this.line : line as LivePlayLine?,
    loadingLines: loadingLines ?? this.loadingLines,
    streamError: streamError == _keep ? this.streamError : streamError,
    engineStopped: engineStopped ?? this.engineStopped,
    paused: paused ?? this.paused,
    presentation: presentation ?? this.presentation,
    chromeVisible: chromeVisible ?? this.chromeVisible,
    sleepTimerActive: sleepTimerActive ?? this.sleepTimerActive,
    sleepMinutes: sleepMinutes ?? this.sleepMinutes,
    sleepEndedTick: sleepEndedTick ?? this.sleepEndedTick,
    barrageOn: barrageOn ?? this.barrageOn,
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
    rate: rate ?? this.rate,
    videoWidth: videoWidth == _keep ? this.videoWidth : videoWidth as int?,
    videoHeight: videoHeight == _keep ? this.videoHeight : videoHeight as int?,
  );
}

/// The room page's logic: the detail lookup, the quality and line resolve, the
/// engine, the watch-progress writeback, the volume, the sleep timer and the
/// presentation.
///
/// This is the reference's `LivePlayController` and `PlayerController` pair
/// folded onto the workspace's Riverpod stack — the page widgets render this
/// state and call these methods, and none of them owns logic of its own.
final class RoomController extends Notifier<RoomState> {
  /// A controller for [identity].
  new(this.identity);

  /// The room this controller serves.
  final RoomIdentity identity;

  /// How long the immersive overlay chrome stays up after a tap — the
  /// reference's `_controllerHideDelay`.
  static const _chromeHold = Duration(seconds: 5);

  /// How often watch progress is written back while playback runs. Coarse on
  /// purpose: each write is a store save, and a resume point five seconds off
  /// is close enough.
  static const _progressWriteInterval = Duration(seconds: 5);

  /// A saved position closer than this to the start is not worth seeking to.
  static const _seekWorthwhile = Duration(seconds: 5);

  /// The sleep timer's ceiling, the reference's `AppSettingsController.maxSleepMinutes`.
  static const maxSleepMinutes = 525600;

  // The engine is built with the room, and its mpv tuning is read at every
  // open — a settings edit between two streams lands on the next one without
  // the app restarting, the reference's own nextOpen semantics.
  late final MediaCorePlaybackEngine _engine = MediaCorePlaybackEngine(
    mpvOptions: () => MpvTuning.nativeOptions(
      ref.read(appPreferencesProvider),
      platform: defaultTargetPlatform,
      isDesktop: _isDesktop,
    ),
  );
  StreamSubscription<PlaybackEngineEvent>? _engineSub;
  StreamSubscription<PlayerAdapterEvent>? _adapterSub;
  Timer? _chromeTimer;
  Timer? _progressTimer;
  Timer? _sleepTimer;
  Duration? _lastWrittenPosition;
  Duration? _pendingResumePosition;
  bool _resumeApplied = false;

  /// The surface the video renders. The surface widget reads it after a state
  /// change (the engine coming ready is what triggers the rebuild).
  MediaKitPlayerAdapter? get adapter => _engine.surfaceAdapter;

  @override
  RoomState build() {
    _engineSub = _engine.events.listen(_onEngineEvent);
    _progressTimer = Timer.periodic(_progressWriteInterval, (_) => writeProgress());
    ref.onDispose(() {
      _progressTimer?.cancel();
      _chromeTimer?.cancel();
      _sleepTimer?.cancel();
      unawaited(_adapterSub?.cancel());
      // The final write goes first: it reads the adapter that _engine.dispose
      // is about to tear down.
      writeProgress(force: true);
      unawaited(_engineSub?.cancel());
      unawaited(_engine.dispose());
    });
    // A tuning edit while a room is open: the live-capable subset lands on
    // the running player immediately; vo/ao/hwdec wait for the next open and
    // the page says so.
    ref.listen(appPreferencesProvider, (previous, next) {
      if (previous == null || MpvTuning.nextOpenOnlyChanged(previous, next)) {
        return;
      }
      unawaited(
        _engine.surfaceAdapter
            ?.applyEngineOptions(MpvTuning.liveOptions(next, isDesktop: _isDesktop))
            .catchError((_) => const <EngineOptionOutcome>[]),
      );
    });
    // The room kicks its own load off the build, not inside it: the first
    // thing `load` does is read and write `state`, and touching the state of
    // a provider still building is a circular dependency by riverpod's rule.
    // The microtask runs once this build has returned.
    unawaited(Future<void>.microtask(load));
    // The room opens dressed by the settings: a viewer who turned the barrage off
    // globally does not want it back for every room; the volume is the level the
    // reference's volume dialog stores per device class — a phone and a desktop
    // window keep separate answers, and the global mute outranks both.
    final preferences = ref.read(appPreferencesProvider);
    final level = isMobile ? preferences.defaultMobileVolume : preferences.defaultDesktopVolume;
    return RoomState(barrageOn: preferences.danmakuVisible, volume: level, muted: preferences.volumeMuted);
  }

  /// The form factor the app booted as — a fact, not a width. The layouts
  /// choose their structure from the live width; this only picks up the TV
  /// variant and tells a touch device from a windowed one.
  FormFactor get formFactor => ref.read(environmentProvider).runtime.formFactor;

  LiveSite? get _site => _entryValid ? ref.read(sitesProvider).registry.getById(identity.siteId) : null;

  /// Both ids must be present and the site must exist. The route carries them
  /// as path segments, so a blank or unknown one is a malformed entry, not a
  /// network failure — its error state says so.
  bool get _entryValid => identity.siteId.trim().isNotEmpty && identity.roomId.trim().isNotEmpty;

  void _onEngineEvent(PlaybackEngineEvent event) {
    switch (event) {
      case EngineReady():
        state = state.copyWith(engineStopped: false, streamError: null, paused: false);
        // The engine's own level is whatever the last handle left; the room's is
        // the stored answer, so it is re-asserted on every open.
        unawaited(_engine.surfaceAdapter?.setVolume(state.muted ? 0 : state.volume).catchError((_) {}));
      case EngineStopped():
        state = state.copyWith(engineStopped: true);
      case EngineProgress():
        break;
    }
  }

  /// Adapter events arm the resume seek and carry the source's own shape, the
  /// volume and the rate the overlay reads back. The writeback ticks on its own
  /// timer and reads the adapter directly.
  void onAdapterEvent(PlayerAdapterEvent event) {
    switch (event) {
      case PlayerAdapterDurationChanged() || PlayerAdapterPositionChanged() || PlayerAdapterPlaying():
        _maybeResumeSeek();
      case PlayerAdapterVideoSizeChanged(:final width, :final height):
        if (width != state.videoWidth || height != state.videoHeight) {
          state = state.copyWith(videoWidth: width, videoHeight: height);
        }
      case PlayerAdapterVolumeChanged(:final volume):
        state = state.copyWith(volume: volume.clamp(0.0, 1.0));
      case PlayerAdapterRateChanged(:final rate):
        state = state.copyWith(rate: rate);
      default:
        break;
    }
  }

  /// Applies the saved resume position, once per visit, when the adapter
  /// reports a real duration — the sign the source is a replay or a VOD rather
  /// than a live stream. The seek waits for that report instead of racing the
  /// open: a seek handed to mpv before the media loaded is accepted but easy
  /// to lose, so every position, duration and playing event re-runs this.
  void _maybeResumeSeek() {
    final target = _pendingResumePosition;
    if (target == null || _resumeApplied) {
      return;
    }
    final adapter = _engine.surfaceAdapter;
    final duration = adapter?.duration;
    if (adapter == null || duration == null || duration <= Duration.zero) {
      return;
    }
    _resumeApplied = true;
    if (target <= _seekWorthwhile || target >= duration) {
      // At the start there is nothing to resume; at the end a seek would
      // complete the source the moment it plays.
      return;
    }
    unawaited(adapter.seek(target).catchError((_) {}));
  }

  /// Writes the watched fraction to the history — the resume point the history
  /// cards draw.
  ///
  /// Only a source with a real duration (a replay or VOD) has progress; a live
  /// stream reports none and its entry keeps the visit snapshot [load] upserted.
  /// A tick whose position has not moved is skipped; [force] writes regardless,
  /// for the pause and the room-exit flush.
  void writeProgress({bool force = false}) {
    if (!_entryValid) {
      return;
    }
    final adapter = _engine.surfaceAdapter;
    final duration = adapter?.duration;
    if (adapter == null || duration == null || duration <= Duration.zero) {
      return;
    }
    final position = adapter.position;
    if (position <= Duration.zero) {
      return;
    }
    if (!force && position == _lastWrittenPosition) {
      return;
    }
    _lastWrittenPosition = position;
    unawaited(
      ref
          .read(historyRepositoryProvider)
          .updateProgress(
            siteId: identity.siteId,
            roomId: identity.roomId,
            progress: position.inMilliseconds / duration.inMilliseconds,
            position: position,
          ),
    );
  }

  bool _loadingDetail = false;

  /// Resolves the room detail, enters the watch history, and opens the
  /// qualities. Idempotent while a load is in flight; the in-flight flag is
  /// its own, not the state field, because a retried load can be called from
  /// the page while this one is still resolving.
  Future<void> load() async {
    if (_loadingDetail) {
      return;
    }
    _loadingDetail = true;
    state = state.copyWith(loadingDetail: true, detailError: null);
    try {
      final site = _site;
      if (site == null) {
        state = state.copyWith(detailError: StateError('unknown site "${identity.siteId}"'));
        return;
      }
      final roomCapability = site.capability<LiveRoomProvider>();
      if (roomCapability != null) {
        final detail = await roomCapability.getRoom(identity.roomId);
        state = state.copyWith(
          detailError: detail.fold((error) => error, (_) => null),
          room: detail.fold((_) => null, (room) => room),
        );
      }
      final known = state.room;
      final repository = ref.read(historyRepositoryProvider);
      // `record` rewrites the entry without watch progress, so the saved resume
      // point is read off the previous entry first and re-asserted after the
      // upsert — a visit whose playback never starts keeps its progress
      // instead of silently resetting it.
      final previous = repository.records
          .where(
            (record) =>
                record.identity == LiveRoom.normalized(platform: identity.siteId, roomId: identity.roomId).identityKey,
          )
          .firstOrNull;
      final savedProgress = previous?.progress;
      final savedPosition = previous?.position;
      await repository.record(known ?? LiveRoom.normalized(platform: identity.siteId, roomId: identity.roomId));
      if (previous != null && (savedProgress != null || savedPosition != null)) {
        _pendingResumePosition = savedPosition;
        await repository.updateProgress(
          siteId: identity.siteId,
          roomId: identity.roomId,
          progress: savedProgress ?? 0.0,
          position: savedPosition,
        );
      }
      await _loadQualities();
    } finally {
      _loadingDetail = false;
      // A load that outlived its room page must not write into a disposed
      // provider; the last watcher leaving already tore the controller down.
      if (ref.mounted) {
        state = state.copyWith(loadingDetail: false);
      }
    }
  }

  Future<void> _loadQualities() async {
    final capability = _site?.capability<LivePlaybackProvider>();
    if (capability == null) {
      // No playback capability: the surface shows what the detail says
      // (offline or live) with no selectors to offer.
      return;
    }
    final result = await capability.getQualities(roomId: identity.roomId);
    state = result.fold(
      (error) => state.copyWith(streamError: error),
      (qualities) => state.copyWith(qualities: qualities, quality: qualities.firstOrNull),
    );
    await openLines();
  }

  /// Resolves the lines for [quality] (the current one when omitted) and opens
  /// the first — a quality switch lands here too.
  Future<void> openLines({LivePlayQuality? quality}) async {
    final capability = _site?.capability<LivePlaybackProvider>();
    if (capability == null) {
      return;
    }
    final chosen = quality ?? state.quality;
    state = state.copyWith(loadingLines: true, engineStopped: false, streamError: null, quality: chosen);
    final result = await capability.getLines(roomId: identity.roomId, quality: chosen);
    final lines = result.fold((error) {
      state = state.copyWith(streamError: error);
      return const <LivePlayLine>[];
    }, (value) => value);
    state = state.copyWith(lines: lines, loadingLines: false);
    if (lines.isNotEmpty) {
      await play(lines.first);
    }
  }

  /// Opens [line] on the engine, then follows the new adapter for the duration
  /// report that arms the resume seek — a switch swaps the adapter underneath.
  Future<void> play(LivePlayLine line) async {
    state = state.copyWith(line: line, engineStopped: false, paused: false);
    await _engine.open(line);
    unawaited(_adapterSub?.cancel());
    _adapterSub = _engine.surfaceAdapter?.events.listen(onAdapterEvent);
    _maybeResumeSeek();
  }

  /// A retry re-resolves the current quality's lines: a lease-expired or
  /// single-use URL never plays again by re-opening it.
  Future<void> retry() => openLines(quality: state.quality);

  /// Pauses or resumes, flushing the pause position past the write throttle.
  void togglePause() {
    final paused = !state.paused;
    state = state.copyWith(paused: paused);
    if (paused) {
      writeProgress(force: true);
      unawaited(_engine.pause());
    } else {
      unawaited(_engine.resume());
    }
  }

  /// Sets the player volume, 0..1, and unmutes it — the overlay's slider owns
  /// the number and the adapter only ever takes the command.
  void setVolume(double volume) {
    final value = volume.clamp(0.0, 1.0);
    state = state.copyWith(volume: value, muted: value == 0);
    unawaited(_engine.surfaceAdapter?.setVolume(value).catchError((_) {}));
  }

  /// Silences without losing the level, so the slider comes back where it was.
  void toggleMute() {
    final muted = !state.muted;
    state = state.copyWith(muted: muted);
    unawaited(_engine.surfaceAdapter?.setVolume(muted ? 0 : state.volume).catchError((_) {}));
  }

  /// Steps the playback rate; a live stream that cannot seek still takes one.
  void setRate(double rate) {
    final value = rate.clamp(0.5, 3.0);
    state = state.copyWith(rate: value);
    unawaited(_engine.surfaceAdapter?.setRate(value).catchError((_) {}));
  }

  /// Takes the presentation. On a desktop the OS window follows; on touch the
  /// same mode is an in-app presentation, so the chrome can float over it.
  void setPresentation(RoomPresentation mode) {
    if (mode == RoomPresentation.normal && state.presentation != RoomPresentation.normal) {
      _chromeTimer?.cancel();
      state = state.copyWith(presentation: mode);
      if (_isDesktop) {
        unawaited(windowManager.setFullScreen(false));
      }
      return;
    }
    state = state.copyWith(presentation: mode, chromeVisible: true);
    if (_isDesktop) {
      unawaited(windowManager.setFullScreen(mode != RoomPresentation.normal));
    }
    scheduleChromeHide();
  }

  bool get _isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
    _ => false,
  };

  /// Whether this device answers to the mobile volume default — the reference
  /// dialog's own platform split.
  bool get isMobile => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.fuchsia || TargetPlatform.iOS => true,
    _ => false,
  };

  /// Brings the overlay chrome up, or flips it when the surface was tapped.
  void revealChrome({bool toggle = false}) {
    // toggle=true flips it, toggle=false raises it.
    state = state.copyWith(chromeVisible: !toggle || !state.chromeVisible);
    scheduleChromeHide();
  }

  /// Drops the overlay chrome now instead of waiting for its timer.
  void hideChrome() {
    _chromeTimer?.cancel();
    state = state.copyWith(chromeVisible: false);
  }

  /// Arms the auto-hide. The normal presentation keeps its chrome permanently,
  /// and a chrome that is already down has nothing left to hide.
  void scheduleChromeHide() {
    _chromeTimer?.cancel();
    if (state.presentation == RoomPresentation.normal || !state.chromeVisible) {
      return;
    }
    _chromeTimer = Timer(_chromeHold, () => state = state.copyWith(chromeVisible: false));
  }

  /// Holds the chrome while a pointer sits over the control bars — the
  /// reference's hover lease. A bar that hides under the cursor is worse than
  /// one that never hides.
  void keepChromeWhileHovering({required bool hovering}) {
    _chromeTimer?.cancel();
    if (hovering) {
      state = state.copyWith(chromeVisible: true);
    } else {
      scheduleChromeHide();
    }
  }

  /// Commits the reference's volume dialog as one transaction: the mute and the
  /// two per-device levels are persisted, and the mute plus this device
  /// class's level are applied to the live player. A room whose engine has
  /// nothing to drive throws — the dialog keeps the draft and says why, the
  /// same contract the reference's `trySetVolume` failure path implements.
  Future<void> commitRoomVolumeDefaults({required bool muted, required double mobile, required double desktop}) async {
    final store = ref.read(appPreferencesStoreProvider);
    final target = muted ? 0.0 : (isMobile ? mobile : desktop);
    final adapter = _engine.surfaceAdapter;
    if (adapter == null) {
      throw StateError('The active room did not accept the volume update');
    }
    await adapter.setVolume(target);
    state = state.copyWith(volume: isMobile ? mobile : desktop, muted: muted);
    await store.update(
      (preferences) =>
          preferences.copyWith(volumeMuted: muted, defaultMobileVolume: mobile, defaultDesktopVolume: desktop),
    );
  }

  /// Starts, re-arms or cancels the sleep countdown — the reference's
  /// `applyRoomPlaybackTimer`: duration and flag land as one transaction, and
  /// cancelling never touches playback itself.
  void applySleepTimer({required bool enabled, required int minutes}) {
    final normalized = minutes.clamp(1, maxSleepMinutes);
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (!enabled) {
      state = state.copyWith(sleepTimerActive: false);
      return;
    }
    state = state.copyWith(sleepTimerActive: true, sleepMinutes: normalized);
    _sleepTimer = Timer(Duration(minutes: normalized), _onSleepTimerEnded);
  }

  /// The countdown's end: the flag falls, playback pauses, the finish ticks
  /// once so the page can toast it — the reference pauses the player and toasts
  /// rather than closing anything.
  void _onSleepTimerEnded() {
    _sleepTimer = null;
    state = state.copyWith(sleepTimerActive: false, sleepEndedTick: state.sleepEndedTick + 1);
    if (state.paused) {
      return;
    }
    state = state.copyWith(paused: true);
    writeProgress(force: true);
    unawaited(_engine.pause());
  }

  /// Turns the barrage over the video on or off — and remembers it. The
  /// reference's toggle is the `hideDanmaku` setting itself: the pane and every
  /// later room read the same answer, not a per-visit flag.
  void setBarrage({required bool on}) {
    state = state.copyWith(barrageOn: on);
    unawaited(
      ref.read(appPreferencesProvider.notifier).update((preferences) => preferences.copyWith(danmakuVisible: on)),
    );
  }
}

/// The room page's state — one controller per room identity. Re-entering the
/// same room reuses it; the last watcher leaving disposes the engine.
// riverpod's family type (ProviderFamily) is not exported by
// flutter_riverpod, so the variable annotation the lint asks for cannot be
// written.
// ignore: specify_nonobvious_property_types
final roomControllerProvider = NotifierProvider.autoDispose.family<RoomController, RoomState, RoomIdentity>(
  RoomController.new,
);
