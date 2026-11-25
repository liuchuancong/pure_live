import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart' show Clipboard, ClipboardData, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_device/live_device.dart'
    show PlatformScreenBrightnessService, ScreenBrightnessScope, ScreenBrightnessService;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/page/chat_splitter.dart' show ChatSplitter;
import 'package:pure_live/modules/vod/controller/vod_app_login.dart' show vodAppClientProvider;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_library.dart'
    show VodSeasonProgress, VodSeasonProgressController, vodSeasonProgressProvider;
import 'package:pure_live/modules/vod/controller/vod_pgc.dart';
import 'package:pure_live/modules/vod/controller/vod_playback_settings.dart'
    show VodApiType, VodFinishAction, VodSpeedChoice, vodPlaybackSettingsProvider;
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show vodQualityProvider;
import 'package:pure_live/modules/vod/controller/vod_social.dart' show vodWriteReadyProvider;
import 'package:pure_live/modules/vod/widgets/vod_jump_dialog.dart' show showVodJumpDialog;
import 'package:pure_live/modules/vod/widgets/vod_media_source.dart'
    show vodDashSourceOf, vodDashVideoOf, vodQualityLabel;
import 'package:pure_live/modules/vod/widgets/vod_picture_gestures.dart' show VodPictureGestures, VodTapSide;
import 'package:pure_live/modules/vod/widgets/vod_player_chrome.dart'
    show VodGestureKind, VodGestureTip, VodPictureNotice, VodSeekBar;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodFoldedText, VodRailDoor, vodDurationText;
import 'package:pure_live/shared/player/on_video_colors.dart';
import 'package:pure_live/shared/player/playback_layout.dart' show kPlaybackWideBreakpoint;
import 'package:pure_live/shared/player/player_bar_choice.dart' show PlayerBarChoice;
import 'package:pure_live/shared/player/player_bar_tier.dart' show PlayerBarButton, PlayerBarTier;
import 'package:pure_live/shared/player/player_control_bar.dart' show PlayerBarRows, PlayerControlBar;
import 'package:pure_live/shared/player/player_overlay.dart'
    show PlayerGlassPill, PlayerOverlayPanel, PlayerPanelHost, PlayerPanelOption;
import 'package:pure_live/shared/player/player_seek_layer.dart' show PlayerSeekLayer;
import 'package:pure_live/shared/shared.dart'
    show
        AudienceFormat,
        BackgroundPlaybackGate,
        CoverFallback,
        DetailHeroBackdrop,
        FloatingVideoHandoff,
        FloatingVideoWindow,
        HeroPlayDisc,
        LiveWindow,
        PlaybackLayout,
        PlayerCapsuleHead,
        PlayerIdleProgress,
        PlayerMoreHues,
        PlayerMoreRow,
        PlayerMoreTile,
        PlayerMoreTiles,
        PlayerPipChrome,
        PlayerPipVerb,
        PlayerStatsOverlay,
        RoomCoverChip,
        SectionHeader,
        cachedImage,
        capturePlayerFrame,
        kPlaybackCompactBreakpoint,
        kRoomCoverScrim,
        playerBarLine,
        playerStatsVisibleProvider,
        showPlayerMoreContainer,
        silencePlayer;
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

/// One cinema title's page: the player over media_core, the season's blurb,
/// and its episodes — the reference's PgcFeatureScreen, with the station's own
/// player chrome.
///
/// The first episode opens with the page; picking another switches the same
/// handle to it. Episodes are addressed by `ep_id` through the signed PGC
/// play endpoint, which is what the login-gated renditions need.
/// The exact episode essence the page has successfully opened.
typedef _SeasonMediaIdentity = ({int seasonId, int episodeId, int? cid, int? aid});

/// The newest episode request; a newer pick replaces an older pending one.
typedef _SeasonOpenIntent = ({VodEpisode episode, int? qn, Duration? resumeFrom});

final class VodSeasonPage extends ConsumerStatefulWidget {
  /// The season behind [seasonId].
  const VodSeasonPage({required this.seasonId, super.key});

  /// The season's id (`ss` number).
  final int seasonId;

  @override
  ConsumerState<VodSeasonPage> createState() => _VodSeasonPageState();
}

final class _VodSeasonPageState extends ConsumerState<VodSeasonPage> with RouteAware, WidgetsBindingObserver {
  /// The cinema player's default qn (1080P); the source may serve lower.
  static const int _defaultQn = 80;

  VodEpisode? _episode;
  VodPlayInfo? _play;
  _SeasonMediaIdentity? _openedIdentity;
  _SeasonOpenIntent? _pendingEpisode;
  PlayerHandle? _attemptHandle;
  int _openGeneration = 0;
  int _openedGeneration = 0;
  int _qn = _defaultQn;

  /// The definition actually opened. The request names the whole ladder and
  /// this number says which rung of it the episode is playing on, so the menu
  /// checks what is on the screen rather than what was asked for.
  int _openedQn = _defaultQn;
  String? _openedLabel;

  /// The quality picker's box; the bar's panel language hangs from it.
  final GlobalKey _qualityAnchor = GlobalKey();
  final GlobalKey _speedAnchor = GlobalKey();

  /// The bar's box; the panel host measures its card against it.
  final GlobalKey _barAnchor = GlobalKey();

  /// The episodes catalogue's chip: the cluster's list button, whose panel
  /// hangs centred above the pill.
  final GlobalKey _episodesAnchor = GlobalKey();

  /// The bar panel standing now; a tap anywhere else puts it away.
  String? _openPanel;

  /// The watching lock, the room's own rule: locked, the strip, the bar and
  /// the picture's gestures all stand down, and the unlock pill on the
  /// picture's right edge is the only thing left to press.
  bool _locked = false;

  /// The pointer's answers: the chip a gesture left on the picture, the sound
  /// and the rate a drag or a hold is setting, and the bar's own patience. The
  /// archive page keeps the same shapes, so the same finger means the same
  /// thing in both halves of the station.
  VodGestureKind? _gestureKind;
  String? _gestureValue;
  String? _gestureNote;
  Timer? _gestureTimer;
  Timer? _hideTimer;
  bool _controlsVisible = true;
  double _volume = 1;
  double _speed = 1;
  double _dragVolume = 1;
  bool _speedHeld = false;
  double _speedBeforeHold = 1;

  /// The screen's brightness the left half of the picture adjusts, where the
  /// display will take the write.
  final ScreenBrightnessService _screenBrightness = const PlatformScreenBrightnessService();
  bool? _brightnessWritable;
  ScreenBrightnessScope _brightnessScope = ScreenBrightnessScope.application;
  double _brightness = 100;
  double _dragBrightness = 100;
  bool _dragIsBrightness = false;

  /// The horizontal drag: where it started, how far it has walked, and where
  /// that stands, so the release seeks once rather than on every frame.
  Duration? _scrubFrom;
  double _scrubWalked = 0;
  double? _scrubSeconds;

  /// The keyboard's step, which grows while the key keeps coming.
  double _seekStep = 5;
  DateTime? _lastSeekKey;

  /// What a double tap on either side of the picture steps over.
  static const double _doubleTapStep = 10;

  /// The countdown before the episode after this one opens, so the step
  /// forward can be stopped while it is still a plan.
  int _countdown = 0;
  Timer? _countdownTimer;

  /// Whether the end of the episode has already been acted on.
  bool _finished = false;
  PlayerHandle? _handle;
  StreamSubscription<PlayerTransportState>? _transportSub;
  StreamSubscription<PlayerAdapterEvent>? _eventSub;
  StreamSubscription<void>? _geometrySub;

  /// The last moment the continue checkpoint's seconds were written; the
  /// picture's ticks arrive far faster than a preference write should.
  DateTime _lastPositionSave = DateTime(0);

  /// The picture's own shape, followed from the engine's geometry: the
  /// stage sizes itself to the episode, not to a hardcoded 16:9 that
  /// letterboxes a vertical episode wrong on a portrait phone.
  double _aspectRatio = 16 / 9;
  PlayerTransportState? _transport;
  String? _error;
  bool _opening = false;
  bool _silent = false;
  bool _muted = false;
  bool _globalMute = false;
  bool _disposed = false;
  bool _autoOpened = false;
  double? _dragSeconds;

  /// The picture's background rule, the video page's own gate: whether
  /// leaving the app keeps the episode playing, and how it comes back.
  BackgroundPlaybackGate? _backgroundGate;
  PlayerId? _backgroundPausedHandle;

  /// The window's observer, kept for `dispose` where the provider scope may
  /// already be gone.
  RouteObserver<ModalRoute<void>>? _routeObserver;

  // Captured while the page is alive; `ref` is refused by the time dispose
  // runs, and the leaving page must still exit its presentation mode and
  // release its handle.
  late final RoomPresentationController _presentationNotifier;
  late final PlayerKernel _kernel;

  /// The continue checkpoint's writer, captured for the same reason: the
  /// leaving page's last position lands after `ref` has stopped answering.
  late final VodSeasonProgressController _progressNotifier;

  /// The season detail as plain data, followed through a manual listener:
  /// `_savePosition` names its episode ladder by it, also on the way out.
  VodSeasonDetail? _seasonDetail;

  /// The presentation mode, followed through a manual listener for the same
  /// reason: the leaving page reads its own field, not `ref`.
  PresentationMode _presentationMode = PresentationMode.normal;

  bool get _immersive => ref.read(roomPresentationProvider.notifier).modeOwnsWindow(ref.read(roomPresentationProvider));
  bool get _effectivelyMuted => _muted || _globalMute;

  _SeasonMediaIdentity _identityOf(VodEpisode episode) =>
      (seasonId: widget.seasonId, episodeId: episode.id, cid: episode.cid, aid: episode.aid);

  VodEpisode? _episodeOf(_SeasonMediaIdentity? identity) {
    if (identity == null) return null;
    for (final episode in _seasonDetail?.episodes ?? const <VodEpisode>[]) {
      if (_identityOf(episode) == identity) return episode;
    }
    return null;
  }

  /// Only a successfully opened source may answer transport controls. The
  /// handle being switched is deliberately absent from this path.
  PlayerHandle? get _playableHandle {
    final handle = _handle;
    if (!mounted || _disposed || _opening || _openedIdentity == null || _openedGeneration != _openGeneration) {
      return null;
    }
    return handle;
  }

  bool _isCurrentGeneration(int generation) => mounted && !_disposed && generation == _openGeneration;

  void _clearTransportSubscriptions() {
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _transportSub = null;
    _eventSub = null;
    _geometrySub = null;
  }

  void _releaseHandle(PlayerHandle handle) {
    silencePlayer(handle);
    unawaited(_kernel.release(handle.id));
  }

  @override
  void initState() {
    super.initState();
    _presentationNotifier = ref.read(roomPresentationProvider.notifier);
    _kernel = ref.read(playerKernelProvider);
    _progressNotifier = ref.read(vodSeasonProgressProvider.notifier);
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    ref.listenManual(
      vodSeasonDetailProvider(widget.seasonId),
      (_, next) => _seasonDetail = next.value,
      fireImmediately: true,
    );
    // The station's opening quality, with the cinema's own floor: 720P is the
    // progressive endpoint's ceiling, not a PGC rendition's.
    final setting = ref.read(vodQualityProvider).qn;
    _qn = setting < _defaultQn ? _defaultQn : setting;
    // The sound and rate the picture starts with, and whether this display
    // will take a brightness write at all.
    _volume = ref.read(modulePlaybackSettingsProvider(PlayerModule.vod)).volume;
    _speed = ref.read(vodPlaybackSettingsProvider).speed.value;
    _globalMute = ref.read(playbackSettingsProvider).globalMute;
    // The background rule the video page plays by: the gate decides whether
    // leaving the app pauses this picture, and what resumes it.
    WidgetsBinding.instance.addObserver(this);
    _backgroundGate = BackgroundPlaybackGate(
      backgroundEnabled: () => ref.read(playbackSettingsProvider).backgroundPlay,
      shouldPause: () {
        final presentation = _presentationMode;
        return (_transport?.isPlaying ?? false) &&
            presentation != PresentationMode.pip &&
            presentation != PresentationMode.floating;
      },
      pause: () async {
        _backgroundPausedHandle = _playableHandle?.id;
        await _playableHandle?.pause();
      },
      canResume: () =>
          _backgroundPausedHandle != null &&
          _playableHandle?.id == _backgroundPausedHandle &&
          !(_transport?.isPlaying ?? false),
      resume: () async {
        _backgroundPausedHandle = null;
        await _playableHandle?.play();
      },
    );
    unawaited(_syncBrightness());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgroundGate?.handleLifecycle(state);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      // The field is not promoted by flow analysis, so name the type.
      // ignore: omit_local_variable_types
      final RouteObserver<ModalRoute<void>> observer = _routeObserver ?? ref.read(routeObserverProvider);
      _routeObserver = observer;
      observer.subscribe(this, route);
    }
  }

  /// Another page covers this one (a related title, a menu route): the picture
  /// pauses rather than playing under it — the archive page's own rule.
  @override
  void didPushNext() {
    final handle = _playableHandle;
    if (handle != null && (_transport?.isPlaying ?? false)) {
      unawaited(handle.pause().catchError((Object _) {}));
    }
  }

  /// The page's hold on the app's sound: playing an episode hushes a live
  /// window or the music the viewer left running.
  void _holdSound() {
    unawaited(
      ref
          .read(audioArbiterProvider.notifier)
          .claim(
            AudioOwner(AudioOwnerKind.vod, 'vod-season:${widget.seasonId}'),
            () => Future<void>.value(_playableHandle?.pause()),
          ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    ref.read(audioArbiterProvider.notifier).release(AudioOwner(AudioOwnerKind.vod, 'vod-season:${widget.seasonId}'));
    // The page's last position lands through the captured writer and
    // ladder; no `ref` read below this line.
    _savePosition(force: true);
    // The player goes quiet before anything else: the route's leave animation
    // runs while the release's queue drains, and the episode must not be heard
    // over the page the viewer returned to. Everything the leaving page needs
    // was captured while it was alive: a `ref` read here throws, and a page
    // that throws on its way out never releases the handle — the picture keeps
    // sounding with nothing left on screen to stop it.
    final handle = _handle ?? _attemptHandle;
    _handle = null;
    _attemptHandle = null;
    if (handle != null) {
      if (_presentationNotifier.modeOwnsWindow(_presentationMode)) {
        unawaited(_presentationNotifier.exit(handle.id));
      }
      silencePlayer(handle);
      unawaited(_kernel.release(handle.id));
    }
    _routeObserver?.unsubscribe(this);
    _routeObserver = null;
    WidgetsBinding.instance.removeObserver(this);
    _backgroundGate?.dispose();
    _backgroundGate = null;
    _gestureTimer?.cancel();
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    _clearTransportSubscriptions();
    super.dispose();
  }

  Future<void> _openEpisode(VodEpisode episode, {int? qn, Duration? resumeFrom}) async {
    if (!mounted || _disposed) return;
    // A pick made while another source is opening is intent, not noise: keep
    // only the newest one and drain it after the current attempt settles.
    _pendingEpisode = (episode: episode, qn: qn, resumeFrom: resumeFrom);
    if (_opening) return;
    await _drainEpisodeOpens();
  }

  Future<void> _drainEpisodeOpens() async {
    while (mounted && !_disposed && _pendingEpisode != null) {
      final intent = _pendingEpisode!;
      _pendingEpisode = null;
      final episode = intent.episode;
      final generation = ++_openGeneration;
      final fallback = _episodeOf(_openedIdentity) ?? _episode;
      // Checkpoint the source that actually reported a transport before its
      // identity is cleared; the requested episode has not opened yet.
      _savePosition(force: true);
      final detail = ref.read(vodSeasonDetailProvider(widget.seasonId)).value;
      final index = detail?.episodes.indexOf(episode) ?? -1;
      VodSeasonProgress? checkpoint;
      for (final entry in ref.read(vodSeasonProgressProvider)) {
        if (entry.seasonId == '${widget.seasonId}') {
          checkpoint = entry;
          break;
        }
      }
      final Duration? from;
      if (intent.resumeFrom != null) {
        from = intent.resumeFrom;
      } else if (checkpoint != null && checkpoint.episodeIndex == index && (checkpoint.positionSeconds ?? 0) > 5) {
        from = Duration(seconds: checkpoint.positionSeconds!.round());
      } else {
        from = null;
      }
      final want = intent.qn ?? _qn;
      _qn = want;
      final previous = _handle;
      _handle = null;
      _attemptHandle = null;
      _openedIdentity = null;
      _openedGeneration = 0;
      _backgroundPausedHandle = null;
      _clearTransportSubscriptions();
      // Retire the old source before any network wait. Reusing it here leaves
      // the previous episode audible when the next source fails to open.
      if (previous != null) _releaseHandle(previous);
      _resetScrub();
      _cancelCountdown();
      _gestureTimer?.cancel();
      setState(() {
        _opening = true;
        _episode = episode;
        _play = null;
        _silent = false;
        _transport = null;
        _dragSeconds = null;
        _error = null;
        _finished = false;
        _openedQn = want;
        _openedLabel = null;
        _aspectRatio = 16 / 9;
        _openPanel = null;
        _gestureKind = null;
        _gestureValue = null;
        _gestureNote = null;
        _speedHeld = false;
        _speedBeforeHold = _speed;
      });
      if (!_isCurrentGeneration(generation)) return;
      try {
        final appClient = ref.read(vodAppClientProvider);
        VodPlayInfo info;
        if (ref.read(vodPlaybackSettingsProvider).apiType == VodApiType.app && appClient != null) {
          try {
            info = await appClient.playPgc(epid: episode.id, cid: episode.cid);
          } on Object {
            info = await ref.read(vodClientProvider).pgcPlay(episodeId: episode.id, cid: episode.cid, aid: episode.aid);
          }
        } else {
          info = await ref.read(vodClientProvider).pgcPlay(episodeId: episode.id, cid: episode.cid, aid: episode.aid);
        }
        if (!_isCurrentGeneration(generation)) return;
        final handle = await _kernel.create(
          config: const PlayerConfig(name: 'vod-pgc'),
          preferredBackend: ref.read(playerKernelBackendProvider).id,
        );
        if (!_isCurrentGeneration(generation)) {
          _releaseHandle(handle);
          return;
        }
        _attemptHandle = handle;
        _handle = handle;
        _bind(handle, generation);
        _holdSound();
        FloatingVideoWindow.dismiss();
        await handle.setMute(muted: _effectivelyMuted);
        final picture = vodDashVideoOf(info, maxQuality: want);
        _openedQn = picture?.quality ?? info.servedQuality ?? want;
        _openedLabel = vodQualityLabel(info, _openedQn) ?? info.quality;
        final dash = vodDashSourceOf(info, maxQuality: want);
        _holdSound();
        await handle.setMute(muted: _effectivelyMuted);
        if (!_isCurrentGeneration(generation)) return;
        if (dash != null) {
          try {
            await handle.openMedia(dash, autoPlay: true);
            // media_core signals "this engine cannot join two essences" as an
            // UnsupportedError; the muxed request below is its handler.
            // ignore: avoid_catching_errors
          } on UnsupportedError {
            info = await ref
                .read(vodClientProvider)
                .pgcPlay(episodeId: episode.id, cid: episode.cid, aid: episode.aid, dash: false);
            if (!_isCurrentGeneration(generation)) return;
            _openedQn = info.servedQuality ?? _openedQn;
            _openedLabel = info.quality;
            _holdSound();
            await handle.setMute(muted: _effectivelyMuted);
            await handle.open(_episodeSource(info, episode), autoPlay: true);
          }
        } else {
          await handle.open(_episodeSource(info, episode), autoPlay: true);
        }
        if (!_isCurrentGeneration(generation)) return;
        await handle.setVolume(_volume);
        await handle.setMute(muted: _effectivelyMuted);
        await handle.setRate(_speed);
        if (from != null && from.inMilliseconds > 5000) {
          await handle.seek(from);
        }
        if (!_isCurrentGeneration(generation)) return;
        // The identity is published only after the source and its opening
        // options succeeded. Every control and checkpoint reads this identity.
        _openedIdentity = _identityOf(episode);
        _openedGeneration = generation;
        _attemptHandle = null;
        setState(() {
          _play = info;
          _silent = info.silent;
          _opening = false;
        });
        if (detail != null && index >= 0) {
          unawaited(
            ref
                .read(vodSeasonProgressProvider.notifier)
                .save(
                  seasonId: '${widget.seasonId}',
                  title: detail.title,
                  cover: detail.coverUrl,
                  episodeIndex: index,
                  total: detail.episodes.length,
                  positionSeconds: from == null ? null : from.inMilliseconds / 1000,
                ),
          );
        }
        _wake();
      } on Object catch (failure) {
        final stale = _attemptHandle ?? _handle;
        _handle = null;
        _attemptHandle = null;
        _openedIdentity = null;
        _openedGeneration = 0;
        _clearTransportSubscriptions();
        if (stale != null) _releaseHandle(stale);
        if (!mounted || _disposed) return;
        setState(() {
          _episode = fallback;
          _opening = false;
          _play = null;
          _silent = false;
          _transport = null;
          _dragSeconds = null;
          _openedLabel = null;
          _error = failure is VodFailure ? failure.message : '$failure';
        });
      }
    }
  }

  /// The continue checkpoint's seconds: written at most once every few
  /// seconds while the picture plays, and once more on the way out. The
  /// open-time write names the ladder's position; this one adds the
  /// where within the episode.
  void _savePosition({bool force = false, Duration? positionOverride, bool markDone = false}) {
    final episode = _episodeOf(_openedIdentity);
    final transport = _transport;
    if (episode == null || transport == null || _openedGeneration != _openGeneration) return;
    final total = transport.duration.inMilliseconds;
    // The floating mini window hands its last second over on the way out;
    // this page's own transport stopped at the handoff, so the override
    // is the only record of what the window played since.
    final position = positionOverride?.inMilliseconds ?? transport.position.inMilliseconds;
    if (total <= 0 || position <= 0) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastPositionSave) < const Duration(seconds: 5)) return;
    _lastPositionSave = now;
    final detail = _seasonDetail;
    final index = detail?.episodes.indexOf(episode) ?? -1;
    if (detail == null || index < 0) return;
    unawaited(
      _progressNotifier.save(
        seasonId: '${widget.seasonId}',
        title: detail.title,
        cover: detail.coverUrl,
        episodeIndex: index,
        total: detail.episodes.length,
        positionSeconds: position / 1000,
        completed: markDone,
      ),
    );
  }

  /// The share of the range one arrow key or wheel step takes, the figure the
  /// 画质与音频 setting owns.
  double get _volumeStep => ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;

  void _nudgeUp() => _nudge(_volumeStep);

  void _nudgeDown() => _nudge(-_volumeStep);

  void _nudge(double delta) {
    final next = (_volume + delta).clamp(0.0, 1.0);
    _wake();
    _showGesture(VodGestureKind.volume, '${(next * 100).round()}%');
    unawaited(_setVolume(next));
  }

  /// One step along the station's own rate ladder, the keyboard's way through
  /// it: the choices the archive page's panel lists, walked in [direction].
  Future<void> _stepSpeed(int direction) async {
    const choices = VodSpeedChoice.values;
    final current = choices.indexOf(VodSpeedChoice.nearest(_speed));
    final next = (current + (direction > 0 ? 1 : -1)).clamp(0, choices.length - 1);
    if (choices[next] == choices[current]) return;
    _showGesture(VodGestureKind.speed, choices[next].label);
    await _setSpeed(choices[next].value);
  }

  /// The quality button's own name: the word for the control, plus the
  /// definition the episode is actually playing on. An icon-only button says
  /// which thing it tunes; without this it never says what it is set to.
  String _qualityMenuLabel(Translations t) {
    final label = _openedLabel;
    if (label == null || label.isEmpty) return t.player.quality;
    return '${t.player.quality} · $label';
  }

  /// The pointer's vocabulary over the picture, and the episode steps it
  /// names. These are the archive page's shapes on purpose: the same finger
  /// should mean the same thing in both halves of the station, and a page that
  /// invents its own gestures teaches the viewer twice.

  /// Brings the chrome back and starts it settling away again.
  void _wake() {
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _wake();
    }
  }

  /// The watching lock: taking it puts the panels away first, and locked the
  /// strip, the bar and the gestures stand down until the unlock pill says
  /// otherwise — the room's and the channel's own rule.
  void _toggleLock() {
    if (!_locked && _openPanel != null) setState(() => _openPanel = null);
    setState(() => _locked = !_locked);
    if (_locked) {
      _hideTimer?.cancel();
      return;
    }
    _wake();
  }

  /// A playing episode lets its bars down after a moment's rest; a paused one
  /// keeps them, because a stopped picture has nothing else to read.
  /// Whether this display is the TV form factor: its chrome never hides on
  /// idle, the room's keepControls rule — the remote's focus walk is the
  /// only way through the bar, and a bar that folds under a focused button
  /// strands the walk.
  bool get _isTv => ref.read(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;

  void _scheduleHide() {
    // The tracker still walks the regions a leaving page owned: its exit
    // lands here after dispose, and a dead state reads no store.
    if (!mounted) return;
    _hideTimer?.cancel();
    // The TV's chrome never hides on idle (see _isTv).
    if (_isTv) return;
    if (!(_transport?.isPlaying ?? false)) return;
    // The viewer's own rest length, the setting every surface reads — its
    // zero is 常显, the bar never hides on idle while the video plays.
    final seconds = ref.read(modulePlaybackSettingsProvider(PlayerModule.vod)).controlsAutoHideSeconds;
    if (seconds <= 0) return;
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && (_transport?.isPlaying ?? false)) setState(() => _controlsVisible = false);
    });
  }

  void _showGesture(VodGestureKind kind, String value, {String? note}) {
    _gestureTimer?.cancel();
    setState(() {
      _gestureKind = kind;
      _gestureValue = value;
      _gestureNote = note;
    });
    _gestureTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _gestureKind = null);
    });
  }

  /// Asks the display what it will take; a display that will not write has no
  /// brightness half, so that half stays the volume.
  Future<void> _syncBrightness() async {
    try {
      final capabilities = await _screenBrightness.getCapabilities();
      final scope = capabilities.supportsScope(ScreenBrightnessScope.application)
          ? ScreenBrightnessScope.application
          : ScreenBrightnessScope.system;
      final value = capabilities.canRead ? await _screenBrightness.getBrightness(scope: scope) : null;
      if (!mounted) return;
      setState(() {
        _brightnessWritable = capabilities.canOfferBrightnessControl;
        _brightnessScope = scope;
        if (value != null) _brightness = value.toDouble().clamp(0.0, 100.0);
      });
    } on Object {
      if (mounted) setState(() => _brightnessWritable = false);
    }
  }

  void _beginPictureDrag(double xFraction) {
    if (_brightnessWritable == true && xFraction < 0.5) {
      _dragIsBrightness = true;
      _dragBrightness = _brightness;
      _showGesture(VodGestureKind.brightness, '${_brightness.round()}%');
      return;
    }
    _dragIsBrightness = false;
    _dragVolume = _volume;
    _showGesture(VodGestureKind.volume, '${(_volume * 100).round()}%');
  }

  void _dragPictureBy(double delta) {
    if (_dragIsBrightness) {
      final next = (_dragBrightness - delta / 2.2).clamp(0.0, 100.0);
      _dragBrightness = next;
      _showGesture(VodGestureKind.brightness, '${next.round()}%');
      if (next.round() != _brightness.round()) {
        _brightness = next.round().toDouble();
        unawaited(
          _screenBrightness
              .setBrightness(_brightness.round(), scope: _brightnessScope)
              .catchError((Object _) => _brightness.round()),
        );
      }
      return;
    }
    final next = (_dragVolume - delta / 220).clamp(0.0, 1.0);
    _dragVolume = next;
    _showGesture(VodGestureKind.volume, '${(next * 100).round()}%');
    unawaited(_setVolume(next));
  }

  void _wheelVolume(double delta) {
    if (_playableHandle == null) return;
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (_volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showGesture(VodGestureKind.volume, '${(next * 100).round()}%');
    unawaited(_setVolume(next));
  }

  Future<void> _setVolume(double value) async {
    final handle = _playableHandle;
    if (handle == null) return;
    setState(() => _volume = value);
    // The module remembers it: the next episode opens here.
    unawaited(ref.read(modulePlaybackSettingsProvider(PlayerModule.vod).notifier).setVolume(value));
    try {
      await handle.setVolume(value);
    } on Object {
      // A refused volume is not a playback failure.
    }
  }

  Future<void> _setMuted({required bool muted}) async {
    final handle = _playableHandle;
    if (!muted && _globalMute) {
      _globalMute = false;
      unawaited(ref.read(playbackSettingsProvider.notifier).setGlobalMute(value: false));
    }
    if (mounted) setState(() => _muted = muted);
    if (handle == null) return;
    try {
      await handle.setMute(muted: _effectivelyMuted);
    } on Object {
      // A refused mute is not a playback failure.
    }
  }

  Future<void> _toggleMute() => _setMuted(muted: !_effectivelyMuted);

  Future<void> _setSpeed(double rate) async {
    final handle = _playableHandle;
    if (handle == null) return;
    setState(() => _speed = rate);
    try {
      await handle.setRate(rate);
    } on Object {
      // Same as volume.
    }
  }

  /// Steps the episode by [seconds] and says where it landed.
  Future<void> _stepSeek(double seconds) async {
    final transport = _transport;
    final handle = _playableHandle;
    if (transport == null || handle == null) return;
    final total = transport.duration.inMilliseconds / 1000;
    var target = transport.position.inMilliseconds / 1000 + seconds;
    if (target < 0) target = 0;
    if (total > 0 && target > total) target = total;
    _showGesture(
      seconds < 0 ? VodGestureKind.seekBack : VodGestureKind.seekForward,
      vodDurationText(Duration(seconds: target.round())),
      note: '${seconds < 0 ? '-' : '+'}${seconds.abs().round()}',
    );
    await _seekTo(target);
  }

  /// The keyboard's step, which grows while the key keeps coming.
  void _keySeek(double sign) {
    final now = DateTime.now();
    final chained = _lastSeekKey != null && now.difference(_lastSeekKey!) < const Duration(milliseconds: 900);
    final step = chained ? (_seekStep * 2).clamp(5.0, 30.0) : 5.0;
    _seekStep = step;
    _lastSeekKey = now;
    unawaited(_stepSeek(step * sign));
  }

  void _doubleTapAt(VodTapSide side) {
    _wake();
    switch (side) {
      case VodTapSide.left:
        unawaited(_stepSeek(-_doubleTapStep));
      case VodTapSide.right:
        unawaited(_stepSeek(_doubleTapStep));
      case VodTapSide.middle:
        unawaited(_togglePlay());
    }
  }

  void _scrubBy(double delta, double width) {
    if (_playableHandle == null) return;
    final transport = _transport;
    if (transport == null || width <= 0) return;
    final total = transport.duration.inMilliseconds / 1000;
    if (total <= 0) return;
    _scrubFrom ??= transport.position;
    _scrubWalked += delta / width * total;
    var target = _scrubFrom!.inMilliseconds / 1000 + _scrubWalked;
    if (target < 0) target = 0;
    if (target > total) target = total;
    _scrubSeconds = target;
    _showGesture(
      VodGestureKind.seek,
      vodDurationText(Duration(seconds: target.round())),
      note: '${_scrubWalked < 0 ? '-' : '+'}${_scrubWalked.abs().round()}',
    );
  }

  Future<void> _endScrub(bool committed) async {
    final target = committed ? _scrubSeconds : null;
    _resetScrub();
    if (target == null) return;
    await _seekTo(target);
  }

  void _resetScrub() {
    _scrubFrom = null;
    _scrubWalked = 0;
    _scrubSeconds = null;
  }

  void _speedHold(bool held) => unawaited(held ? _beginSpeedHold() : _endSpeedHold());

  Future<void> _beginSpeedHold() async {
    final handle = _playableHandle;
    if (handle == null || _speedHeld) return;
    _speedHeld = true;
    _speedBeforeHold = _speed;
    final boosted = ref.read(vodPlaybackSettingsProvider).longPressSpeed;
    final note = context.t.vod.gestureSpeedHold;
    setState(() => _speed = boosted.value);
    try {
      await handle.setRate(boosted.value);
    } on Object {
      // A rate the engine refused is not a reason to fail the hold.
    }
    _showGesture(VodGestureKind.speed, boosted.label, note: note);
  }

  Future<void> _endSpeedHold() async {
    if (!_speedHeld) return;
    _speedHeld = false;
    _gestureTimer?.cancel();
    setState(() {
      _speed = _speedBeforeHold;
      _gestureKind = null;
    });
    final handle = _playableHandle;
    if (handle == null) return;
    try {
      await handle.setRate(_speedBeforeHold);
    } on Object {
      // Same as the hold itself.
    }
  }

  /// The episode [direction] steps from the one playing, or null at either end
  /// of the season's list.
  VodEpisode? _episodeStepped(int direction) {
    if (_playableHandle == null) return null;
    final episodes = ref.read(vodSeasonDetailProvider(widget.seasonId)).value?.episodes ?? const <VodEpisode>[];
    final index = episodes.indexWhere((candidate) => _identityOf(candidate) == _openedIdentity) + direction;
    if (index < 0 || index >= episodes.length) return null;
    return episodes[index];
  }

  bool get _hasNextEpisode => _episodeStepped(1) != null;

  bool get _hasPreviousEpisode => _episodeStepped(-1) != null;

  void _openSteppedEpisode(int direction) {
    final target = _episodeStepped(direction);
    if (target == null) return;
    unawaited(_openEpisode(target));
  }

  /// What the end of an episode leads to: the station's own finish action,
  /// counted down first when it names the next one rather than a stop.
  Future<void> _handleFinished() async {
    if (_finished || _playableHandle == null) return;
    _finished = true;
    // The checkpoint says the season was played to its end: for a ladder
    // the last-episode rule already reads it done, and a single-episode
    // season (a film) needs this mark to leave the continue card.
    _savePosition(force: true, markDone: true);
    final next = _episodeStepped(1);
    switch (ref.read(vodPlaybackSettingsProvider).finish) {
      case VodFinishAction.pause:
        break;
      case VodFinishAction.nextPart:
        if (next != null) _startCountdown(next);
      case VodFinishAction.exit:
        if (mounted) context.pop();
      case VodFinishAction.playRelated:
        if (next == null) return;
        unawaited(_openEpisode(next));
    }
  }

  void _startCountdown(VodEpisode next) {
    _countdownTimer?.cancel();
    setState(() => _countdown = 5);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final left = _countdown - 1;
      if (left <= 0) {
        timer.cancel();
        setState(() => _countdown = 0);
        unawaited(_openEpisode(next));
        return;
      }
      setState(() => _countdown = left);
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() => _countdown = 0);
  }

  /// The flat source of a muxed answer: the shape a single-URL engine opens,
  /// and the fallback when the DASH pair is unsupported.
  PlayerSource _episodeSource(VodPlayInfo info, VodEpisode episode) {
    final uri = Uri.parse(info.url);
    return PlayerSource.of(
      id: SourceId('vod:pgc:${episode.id}:${DateTime.now().microsecondsSinceEpoch}'),
      uri: uri,
      type: SourceType.remote,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: SourceFormat.fromUri(uri),
      headers: info.headers.isEmpty ? null : SourceHeaders(info.headers),
      title: episode.title,
    );
  }

  void _bind(PlayerHandle handle, int generation) {
    _clearTransportSubscriptions();
    _geometrySub = handle.geometryController.state.listen((state) {
      if (!_isCurrentGeneration(generation)) return;
      final size = state.geometry.videoSize;
      if (size.width <= 0 || size.height <= 0) return;
      final ratio = size.width / size.height;
      if (!ratio.isFinite || (_aspectRatio - ratio).abs() < 0.01) return;
      setState(() => _aspectRatio = ratio.clamp(0.5, 2.4));
    });
    _transportSub = handle.playbackStream.listen((state) {
      if (!_isCurrentGeneration(generation)) return;
      setState(() {
        _transport = state;
        if (state.isPlaying) _error = null;
      });
      if (state.isPlaying) _scheduleHide();
      if (_openedGeneration == generation && _openedIdentity != null) _savePosition();
    });
    // The station's own events, not positions the page guesses at: the end
    // of an episode is what the finish action waits for, and a failed one
    // says so on the picture instead of spinning forever.
    _eventSub = handle.adapterEvents.listen((event) {
      if (!_isCurrentGeneration(generation)) return;
      switch (event) {
        case final PlayerAdapterErrorEvent error:
          setState(() => _error = error.message);
        case PlayerAdapterCompleted():
          if (_openedGeneration == generation && _openedIdentity != null) unawaited(_handleFinished());
        default:
          break;
      }
    });
  }

  /// The episode's live download row, projected to the fields the picture's
  /// pill reads: a record compares structurally, so a tick from some other
  /// task in the queue does not rebuild this page.
  ({VodDownloadPhase phase, double? progress, String id})? _episodeDownload(VodEpisode? episode) {
    final episodeId = episode?.id ?? 0;
    final cid = episode?.cid ?? 0;
    return ref.watch(
      vodDownloadsProvider.select((items) {
        final item = vodDownloadOf(items, 'ep$episodeId', cid);
        if (item == null) return null;
        return (phase: item.phase, progress: item.progress, id: item.id);
      }),
    );
  }

  /// Hands the current episode to the app-wide download queue; the queue
  /// resolves its own muxed address when the task's turn comes, and the
  /// 下载管理 page (the station's sidebar, or Settings → 视频) takes over
  /// from there.
  Future<void> _startDownload() async {
    final t = context.t;
    final episode = _episode;
    final cid = episode?.cid ?? 0;
    if (episode == null || cid <= 0) return;
    final season = ref.read(vodSeasonDetailProvider(widget.seasonId)).value;
    final episodes = season?.episodes ?? const <VodEpisode>[];
    final position = episodes.indexWhere((entry) => entry.id == episode.id);
    final result = await ref
        .read(vodDownloadsProvider.notifier)
        .download(
          epId: episode.id,
          cid: cid,
          title: season?.title ?? episode.title,
          part: episode.title,
          index: position >= 0 ? position + 1 : 1,
          parts: episodes.isEmpty ? 1 : episodes.length,
          qn: ref.read(vodDownloadQualityProvider).qn,
          cover: episode.coverUrl?.toString() ?? season?.coverUrl?.toString() ?? '',
        );
    if (!mounted) return;
    switch (result.outcome) {
      case VodDownloadEnqueue.queued:
        showDsToast(context: context, title: t.settings.downloadQueuedNotice, status: DsStatus.success);
      case VodDownloadEnqueue.duplicate:
        showDsToast(context: context, title: t.player.downloadDuplicate);
      case VodDownloadEnqueue.failed:
        showDsToast(
          context: context,
          title: t.settings.downloadStatusFailed,
          description: result.error,
          status: DsStatus.danger,
        );
    }
  }

  Future<void> _togglePlay() async {
    final handle = _playableHandle;
    if (handle == null) return;
    try {
      final playing = _transport?.isPlaying ?? false;
      if (playing) {
        await handle.pause();
      } else {
        _holdSound();
        await handle.play();
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _seekTo(double seconds) async {
    final handle = _playableHandle;
    if (handle == null) return;
    try {
      await handle.seek(Duration(milliseconds: (seconds * 1000).round()));
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  void _toggleFullscreen() {
    final handle = _playableHandle;
    if (handle == null) return;
    unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id));
  }

  /// The page's own way out: a mode that took the window gives it back, and
  /// the viewer lands on the page underneath; with none standing, the page
  /// itself is left. Escape has always followed this rule, and the small
  /// window's close lands on it when the window is the page's own — the main
  /// window cannot close without taking the app with it, so "done watching"
  /// there means the episode stops and the window hands the page back.
  void _leave() {
    final handle = _handle;
    if (handle != null && _immersive) {
      unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
      return;
    }
    context.pop();
  }

  /// Keeps the frame the episode is showing in the viewer's screenshot
  /// folder, the way every player's picture verbs do.
  Future<void> _screenshot() async {
    final handle = _playableHandle;
    if (handle == null) return;
    final file = await capturePlayerFrame(handle, ref.read(appPathsProvider).screenshots, prefix: 'season');
    if (!mounted) return;
    final t = context.t;
    showDsToast(
      context: context,
      title: file == null ? t.player.screenshotFailed : t.player.screenshotSaved(name: file.uri.pathSegments.last),
      status: file == null ? DsStatus.danger : DsStatus.success,
    );
  }

  /// The desktop's compact window (the phone's system window on iOS); a host
  /// that refuses has to be told, or the button reads as broken.
  Future<void> _togglePip() async {
    final handle = _playableHandle;
    if (handle == null) return;
    final accepted = await ref.read(roomPresentationProvider.notifier).togglePip(handle.id);
    if (accepted || !mounted) return;
    showDsToast(context: context, title: context.t.common.pipUnavailable);
  }

  /// Whether the picture verbs may show: the frame copy needs an engine that
  /// can hand a frame back; the small windows need a source to work on and
  /// no window-owning mode standing (the picture-in-picture small window
  /// already is a small window).
  bool get _pictureVerbsReady {
    // The 小窗 overlay belongs to the primary window: its root navigator
    // is the only one registered as the app's, so a secondary's handoff
    // would land its picture on the primary's overlay. Secondary windows
    // keep their own picture instead.
    if (!ref.read(isPrimaryWindowProvider)) return false;
    final handle = _playableHandle;
    return handle != null &&
        handle.source != null &&
        _presentationMode == PresentationMode.normal &&
        !FloatingVideoWindow.isShowing;
  }

  /// Hands the episode to the floating mini window and leaves: the window
  /// opens its own handle from this one's source, resuming where it stopped,
  /// while the page pops back; the expand button re-opens this route (the
  /// season restarts its walk — this page keeps no progress record).
  Future<void> _enterMiniWindow() async {
    final handle = _playableHandle;
    final source = handle?.source;
    if (handle == null || source == null) return;
    final episode = _episodeOf(_openedIdentity);
    final t = context.t;
    final backend = ref.read(playerKernelBackendProvider).id;
    // The window's close path runs after this page is gone: the
    // checkpoint's writer and the ladder it names are captured now.
    final progress = ref.read(vodSeasonProgressProvider.notifier);
    final detail = ref.read(vodSeasonDetailProvider(widget.seasonId)).value;
    final index = episode == null || detail == null ? -1 : detail.episodes.indexOf(episode);
    final title = detail?.title ?? t.vod.opening;
    final ok = await FloatingVideoWindow.show(
      FloatingVideoHandoff(
        title: title,
        resume: handle.position,
        rate: handle.rate,
        muted: handle.muted,
        open: (kernel) async {
          final fresh = await kernel.create(
            config: const PlayerConfig(name: 'floating-video'),
            preferredBackend: backend,
          );
          await fresh.open(source, autoPlay: true);
          return fresh;
        },
        onClose: (position, {required reopen}) {
          // The window's last second lands where a return to the season
          // resumes from.
          if (detail != null && index >= 0 && position.inMilliseconds > 0) {
            unawaited(
              progress.save(
                seasonId: '${widget.seasonId}',
                title: detail.title,
                cover: detail.coverUrl,
                episodeIndex: index,
                total: detail.episodes.length,
                positionSeconds: position.inMilliseconds / 1000,
              ),
            );
          }
          if (reopen) {
            final root = rootNavigatorKey.currentContext;
            if (root != null && root.mounted) {
              unawaited(root.push('/vod/season/${widget.seasonId}'));
            }
          }
        },
      ),
    );
    if (!ok || !mounted || _disposed) return;
    // The window now carries the sound: this page goes quiet before it pops.
    silencePlayer(handle);
    if (mounted && context.mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  /// The sideways window has no episode column: the strip's jump verb is
  /// the way through the ladder there, the section's own dialog reused —
  /// a number is an episode number first, a ladder position second.
  Future<void> _jumpEpisode() async {
    final detail = _seasonDetail;
    if (detail == null || detail.episodes.isEmpty) return;
    final episodes = detail.episodes;
    int? parse(String typed) {
      final number = int.tryParse(typed.trim());
      if (number == null) return null;
      final byIndex = episodes.where((entry) => int.tryParse(entry.index) == number);
      if (byIndex.isNotEmpty) return episodes.indexOf(byIndex.first);
      return number >= 1 && number <= episodes.length ? number - 1 : null;
    }

    final position = await showVodJumpDialog(
      context,
      title: context.t.vod.episodesJump,
      count: episodes.length,
      parse: parse,
    );
    if (position == null || position < 0 || position >= episodes.length || !mounted) return;
    unawaited(_openEpisode(episodes[position]));
  }

  /// The picture verbs over the picture: the two small windows, then the
  /// more door — one pill, on every stage size this page draws. The compact
  /// window leads the cluster, the room's own order: where the picture goes
  /// comes before what is done to it. The desktop's small window is the one
  /// stage that draws none of this — its chrome is the shared one's, and the
  /// way back to this page rides that. The frame copy lives on the picture's
  /// right edge with the lock; the episode's download lives in the more
  /// container now. The catalogues — the episodes among them — live on the
  /// bar's middle row, where every player keeps them; the strip carries only
  /// the window verbs.
  List<Widget> _pictureVerbs(Translations t) => [
    if (_playableHandle != null && ref.read(roomPresentationProvider.notifier).pipAvailable)
      PlayerBarButton(
        // The frame with the way in while the page holds the picture, and
        // the frame with the way out once the phone's system window does —
        // the page keeps its layout under that window, so the verb it shows
        // has to say which way it goes now.
        icon: _presentationMode == PresentationMode.pip ? DsIcons.pictureInPicture2 : DsIcons.pictureInPicture,
        label: _presentationMode == PresentationMode.pip ? t.player.pipOff : t.player.pipOn,
        selected: _presentationMode == PresentationMode.pip,
        onPressed: () {
          _wake();
          unawaited(_togglePip());
        },
      ),
    if (_pictureVerbsReady && ref.watch(playbackSettingsProvider.select((settings) => settings.floatWindow)))
      PlayerBarButton(
        icon: DsIcons.appWindow,
        label: t.common.miniWindow,
        onPressed: () {
          _wake();
          unawaited(_enterMiniWindow());
        },
      ),
    PlayerBarButton(
      icon: DsIcons.ellipsisVertical,
      label: t.common.more,
      onPressed: () {
        _wake();
        unawaited(
          showPlayerMoreContainer(context, content: (context, {required labeled}) => _seasonMoreContent(context.t)),
        );
      },
    ),
  ];

  /// The more container's content, the room's own shape: what the panel does
  /// as a round tile over one list of settings — the episode's download, the
  /// home it took when the lock claimed the edge, and the stream's own
  /// numbers. The StatefulBuilder is the panel's own redraw, so a download's
  /// percent and the switch read fresh on every pick.
  Widget _seasonMoreContent(Translations t) {
    final handle = _handle;
    return StatefulBuilder(
      builder: (context, setPanel) {
        final download = _episodeDownload(_episode);
        final running =
            download != null &&
            (download.phase == VodDownloadPhase.running || download.phase == VodDownloadPhase.queued);
        final stats = ref.read(playerStatsVisibleProvider);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s12,
          children: [
            PlayerMoreTiles(
              tiles: [
                PlayerMoreTile(
                  color: PlayerMoreHues.download,
                  icon: DsIcons.download,
                  // A download under way says its own percent under the circle.
                  label: switch (download) {
                    final task? when running =>
                      task.progress == null
                          ? t.settings.downloadPercentUnknown
                          : t.settings.downloadPercent(percent: '${(task.progress! * 100).round()}'),
                    _ => t.player.download,
                  },
                  onTap: (_episode?.cid ?? 0) <= 0
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          _wake();
                          unawaited(_startDownload());
                        },
                ),
              ],
            ),
            DsListSection(
              children: [
                // Read fresh on the panel's own redraw: the pick flips the
                // provider under the row, and this switch is the first thing
                // the redraw reads.
                PlayerMoreRow(
                  label: t.player.statsToggle,
                  leading: DsIcons.activity,
                  value: null,
                  onTap: handle == null
                      ? null
                      : () {
                          ref.read(playerStatsVisibleProvider.notifier).toggle();
                          setPanel(() {});
                        },
                  trailing: DsSwitch(
                    value: stats,
                    onChanged: (_) {
                      ref.read(playerStatsVisibleProvider.notifier).toggle();
                      setPanel(() {});
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: DsSpace.s12),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final immersive = _immersive;
    ref.listen(playbackSettingsProvider.select((settings) => settings.globalMute), (previous, next) {
      if (previous == next) return;
      if (mounted) setState(() => _globalMute = next);
      final handle = _handle ?? _attemptHandle;
      if (handle != null) {
        unawaited(handle.setMute(muted: _effectivelyMuted).catchError((Object _) {}));
      }
    });
    // A sideways window (shorter than 480 tall, wider than tall, 600 or
    // more across) takes the stage alone: the page's episode column has no
    // room beside a 16:9 picture that short, and the strip's verbs stay
    // over the picture — the same judgement every other player makes
    // (与直播间同一台排版机，与平台无关).
    final windowSize = MediaQuery.sizeOf(context);
    final sizeStage = PlaybackLayout.resolve(width: windowSize.width, height: windowSize.height).landscapeImmersive;
    // This episode's queue rows announce themselves: a finished episode
    // says where it landed, a failed one says so — however the page was left.
    ref.listen(vodDownloadsProvider, (previous, next) {
      final episode = _episode;
      if (episode == null) return;
      final prefix = 'ep${episode.id}:';
      final before = {for (final item in previous ?? const <VodDownloadItem>[]) item.id: item.phase};
      for (final item in next) {
        if (!item.id.startsWith(prefix) || before[item.id] == item.phase) continue;
        if (!mounted) return;
        final t = context.t;
        if (item.phase == VodDownloadPhase.done) {
          showDsToast(
            context: context,
            title: t.player.downloadDone(name: item.fileName),
            status: DsStatus.success,
          );
        } else if (item.phase == VodDownloadPhase.failed) {
          showDsToast(context: context, title: t.settings.downloadStatusFailed, status: DsStatus.danger);
        }
      }
    });
    final detail = ref.watch(vodSeasonDetailProvider(widget.seasonId));
    final season = detail.value;
    if (season != null && !_autoOpened && season.episodes.isNotEmpty) {
      _autoOpened = true;
      // The continue checkpoint names the ladder's position: the episode
      // the card promised is the one that opens, not episode one again.
      VodSeasonProgress? checkpoint;
      for (final entry in ref.read(vodSeasonProgressProvider)) {
        if (entry.seasonId == '${widget.seasonId}') {
          checkpoint = entry;
          break;
        }
      }
      final index = checkpoint == null ? 0 : checkpoint.episodeIndex.clamp(0, season.episodes.length - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openEpisode(season.episodes[index]));
      });
    }
    final Widget body;
    if (season == null && detail.hasError) {
      body = Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.common.loadFailed),
          description: Text('${detail.error}'),
          actions: [
            DsButton(
              onPressed: () => ref.invalidate(vodSeasonDetailProvider(widget.seasonId)),
              child: Text(t.vod.retry),
            ),
          ],
        ),
      );
    } else if (season == null) {
      body = _SeasonSkeleton(posterWidth: LiveWindow.isCompact(windowSize.width) ? 110 : 216);
    } else if (immersive) {
      body = _player(immersive: true);
    } else if (sizeStage) {
      // The sideways window plays over black: the letterbox a shorter-than-
      // 16:9 stage leaves is part of the picture, not of the page.
      body = ColoredBox(
        color: OnVideoColors.ground,
        child: Center(child: _player(immersive: false, stageOnly: true)),
      );
    } else {
      body = _page(season);
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.f11): _toggleFullscreen,
        // The stream's own figures: the key every player answers to.
        const SingleActivator(LogicalKeyboardKey.keyI): () => ref.read(playerStatsVisibleProvider.notifier).toggle(),
        // The same keys the archive page answers with: the arrows step the
        // episode and the sound, the comma and the period walk the rate,
        // and a held arrow keeps growing the step so a long skip is one key.
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          _wake();
          _keySeek(-1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          _wake();
          _keySeek(1);
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): _nudgeUp,
        const SingleActivator(LogicalKeyboardKey.arrowDown): _nudgeDown,
        const SingleActivator(LogicalKeyboardKey.comma): () => unawaited(_stepSpeed(-1)),
        const SingleActivator(LogicalKeyboardKey.period): () => unawaited(_stepSpeed(1)),
        const SingleActivator(LogicalKeyboardKey.escape): _leave,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: colors.canvas,
          // The immersive body keeps the whole surface; the page body wears
          // no pane header any more — the strip over the picture carries the
          // way back and the season's name, as the archive page's strip does.
          body: SafeArea(bottom: false, child: body),
        ),
      ),
    );
  }

  Widget _page(VodSeasonDetail detail) {
    final t = context.t;
    final window = MediaQuery.sizeOf(context).width;
    final inset = LiveWindow.pageInset(window);
    final showDetails = ref.watch(vodPlaybackSettingsProvider).showDetails;
    final episode = _episode;
    final episodes = detail.episodes;
    // The stage: the picture and the season's head. The ladder's shelf
    // travels beside it on a wide window and under it otherwise.
    Widget stage() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s20,
      children: [
        _player(immersive: false),
        _SeasonHead(
          season: detail,
          episode: episode,
          showDetails: showDetails,
          // The head's poster keeps the mockup's two sizes: the wall
          // card's measure beside the words on a desk, a phone's
          // narrower tile where the column cannot spare the room.
          posterWidth: LiveWindow.isCompact(window) ? 110 : 216,
          canPlay: episodes.isNotEmpty,
          onPlay: _playNow,
          canDownload: (episode?.cid ?? 0) > 0,
          onDownload: () => unawaited(_startDownload()),
          onShare: () => unawaited(_share()),
          canWrite: ref.watch(vodWriteReadyProvider),
          onSetFollow: (follow) => unawaited(_setSeasonFollow(follow)),
        ),
        const DsDivider(),
      ],
    );
    Widget shelf() => _EpisodesSection(
      episodes: episodes,
      current: episode,
      onOpen: (candidate) => unawaited(_openEpisode(candidate)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // A season without episodes is one column at any width. A wide one
        // with them splits like the video page: the stage beside a
        // draggable, foldable episodes rail — the same seam — and a folded
        // rail leaves its door at the stage's end edge.
        if (episodes.isEmpty || constraints.maxWidth < kPlaybackWideBreakpoint) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s20,
                  children: [stage(), if (episodes.isNotEmpty) shelf()],
                ),
              ),
            ),
          );
        }
        final railMax = (constraints.maxWidth - _railStageFloor).clamp(_railMin, _railMax);
        final railWidth = _railWidth.clamp(_railMin, railMax);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                    child: Center(
                      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1100), child: stage()),
                    ),
                  ),
                  if (!_railOpen) VodRailDoor(label: t.vod.episodes, onOpen: () => setState(() => _railOpen = true)),
                ],
              ),
            ),
            if (_railOpen) ...[
              ChatSplitter(
                width: railWidth,
                minWidth: _railMin,
                maxWidth: railMax,
                onResize: (value) => setState(() => _railWidth = value),
                onResizeEnd: (value) => setState(() => _railWidth = value),
                onReset: () => setState(() => _railWidth = _railDefaultWidth),
                label: t.vod.episodes,
              ),
              SizedBox(
                width: railWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s8, 0),
                      child: Row(
                        children: [
                          const Spacer(),
                          DsButton.icon(
                            variant: DsButtonVariant.ghost,
                            size: DsSize.sm,
                            onPressed: () => setState(() => _railOpen = false),
                            icon: const DsIcon(DsIcons.panelRightClose),
                            semanticLabel: t.common.previewCollapseList,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s24),
                        child: shelf(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // The wide window's episodes rail: open or folded to its door, and the
  // width the seam's drag left it at — the video page's rail, pointed at
  // the ladder.
  bool _railOpen = true;
  double _railWidth = _railDefaultWidth;
  static const double _railMin = 280;
  static const double _railMax = 520;
  static const double _railDefaultWidth = 340;

  /// The least width the stage keeps beside the rail.
  static const double _railStageFloor = 420;

  /// Puts a picture on: the episode already on the player resumes, and before
  /// one has opened, the season's first does — the head's 立即播放 verb.
  /// Flips the season's follow: the write lands, the detail reads again,
  /// and the toast says which way it went.
  Future<void> _setSeasonFollow(bool follow) async {
    final t = context.t;
    try {
      await ref.read(vodClientProvider).setSeasonFollow(seasonId: widget.seasonId, follow: follow);
      if (!mounted) return;
      ref.invalidate(vodSeasonDetailProvider(widget.seasonId));
      showDsToast(
        context: context,
        title: follow ? t.vod.seasonFollowOn : t.vod.seasonFollowOff,
        status: DsStatus.success,
      );
    } on Object {
      if (!mounted) return;
      showDsToast(context: context, title: t.vod.seasonFollowFailed, status: DsStatus.danger);
    }
  }

  void _playNow() {
    final handle = _playableHandle;
    if (handle != null) {
      _holdSound();
      unawaited(handle.play());
      return;
    }
    final episodes = ref.read(vodSeasonDetailProvider(widget.seasonId)).value?.episodes ?? const <VodEpisode>[];
    if (episodes.isEmpty) return;
    final opened = _episodeOf(_openedIdentity);
    final checkpoint = ref
        .read(vodSeasonProgressProvider)
        .where((entry) => entry.seasonId == '${widget.seasonId}')
        .firstOrNull;
    final saved = checkpoint == null ? null : episodes.elementAtOrNull(checkpoint.episodeIndex);
    final episode = _episode ?? opened ?? saved ?? episodes.first;
    unawaited(_openEpisode(episode));
  }

  /// Sends the season's web address through the system share sheet where the
  /// platform has one, else copies the link — the live room's share, pointed
  /// at a title rather than a room.
  Future<void> _share() async {
    final season = ref.read(vodSeasonDetailProvider(widget.seasonId)).value;
    final title = season?.title.trim() ?? '';
    final link = 'https://www.bilibili.com/bangumi/play/ss${widget.seasonId}';
    final platform = defaultTargetPlatform;
    final sheet =
        !kIsWeb &&
        (platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS ||
            platform == TargetPlatform.macOS ||
            platform == TargetPlatform.windows);
    if (sheet) {
      try {
        final text = title.isEmpty ? link : '$title\n$link';
        await SharePlus.instance.share(ShareParams(text: text, subject: title.isEmpty ? null : title));
        return;
      } on Object {
        // A platform without a usable sheet falls through to the clipboard.
      }
    }
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) showDsToast(context: context, title: context.t.vod.linkCopied);
  }

  /// The picture and its controls; [immersive] drops the page's chrome and
  /// puts the way out over the picture, since the app bar is gone there.
  Widget _player({required bool immersive, bool stageOnly = false}) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final handle = _handle;
    final transport = _transport;
    final episode = _episode;
    final playing = transport?.isPlaying ?? false;
    // The bar follows the pointer: a tap on the picture puts it away while the
    // episode plays, and a stopped one keeps it, because a paused picture has nothing
    // else to read. Locked, nothing rides the picture: the unlock pill on the
    // right edge is the whole chrome, the room's own rule.
    final showBar = !_locked && (_controlsVisible || !playing);
    final qualities = _play?.qualities ?? const <VodQuality>[];
    // The desktop's small window wears the shared chrome alone: no strip, no
    // corner pills and no bar of catalogues — the way back and the season's
    // name, the close, the transport, the sound, the seek line and the pin —
    // the picture keeping its gestures. The mode takes the window, so it only
    // ever stands on the immersive branch.
    final smallWindow = immersive && _presentationMode == PresentationMode.pip && _presentationNotifier.pipOwnsWindow;
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive || stageOnly ? 0 : theme.radii.overlay),
      child: ColoredBox(
        color: colors.overlay,
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (handle != null)
                MediaPlayerView(handle: handle, backgroundColor: colors.overlay)
              else
                const ColoredBox(color: OnVideoColors.ground),
              // The pointer's vocabulary over the picture: a tap raises or puts
              // away the bar, a drag along it scrubs, a drag down it takes the
              // sound or the screen's brightness, a double tap on either side steps
              // ten seconds and on the middle plays or pauses, and a hold runs the
              // episode faster until the finger lifts. The same shapes the archive
              // page answers with, from the same widget.
              VodPictureGestures(
                enabled: _playableHandle != null && !_locked,
                onTap: _toggleControls,
                onDoubleTap: _doubleTapAt,
                onScrub: _scrubBy,
                onScrubEnd: _endScrub,
                onAdjustStart: _beginPictureDrag,
                onAdjust: _dragPictureBy,
                onHold: _speedHold,
                onWheel: _wheelVolume,
                // A pointer over the picture keeps the bar; leaving it lets
                // the episode settle it away, the archive page's rule.
                child: MouseRegion(
                  onHover: (_) => _wake(),
                  onExit: (_) => _scheduleHide(),
                  child: const SizedBox.expand(),
                ),
              ),
              if (_gestureKind case final kind?)
                Positioned.fill(
                  child: VodGestureTip(kind: kind, value: _gestureValue ?? '', note: _gestureNote),
                ),
              // The stream's own numbers, on the same session switch the
              // room, the archive and every other player answer to — the
              // switch the more panel's row and the `I` key both flip.
              if (handle case final player? when ref.watch(playerStatsVisibleProvider))
                Positioned.fill(
                  child: IgnorePointer(child: PlayerStatsOverlay(handle: player)),
                ),
              if (_opening || (transport?.isBuffering ?? false))
                const Center(child: DsSpinner(style: DsSpinnerStyle(size: 40))),
              // The way out of the two fullscreens, the system's and the
              // window's: the pill is the shape's own way out — it names the
              // shape it sits in and leaves that one, never falling into the
              // other on the way, the way the bar's pair never does. The small
              // window draws no pill here: its top-left is the shared chrome's
              // way back to the page.
              if (immersive && !smallWindow)
                PositionedDirectional(
                  top: DsSpace.s8,
                  start: DsSpace.s8,
                  child: SafeArea(
                    child: PlayerGlassPill(
                      child: PlayerBarButton(
                        icon: switch (_presentationMode) {
                          PresentationMode.windowFullscreen => DsIcons.squareShrinkUpLeftDownRight,
                          _ => DsIcons.minimize,
                        },
                        label: switch (_presentationMode) {
                          PresentationMode.windowFullscreen => t.player.windowFullscreenOff,
                          _ => t.player.fullscreenOff,
                        },
                        onPressed: () {
                          _wake();
                          _leave();
                        },
                      ),
                    ),
                  ),
                ),
              // Immersive keeps the picture verbs too: the way out sits at
              // the top-left, the verbs at the top-right, over both stage
              // shapes this page draws. The sideways stage-only body does
              // the same, its top-left pill being the way back instead. The
              // small window's corners are the shared chrome's, so the cluster
              // stands down there: its compact-window button would otherwise
              // show the way in while being the way out.
              if ((immersive || stageOnly) && !smallWindow && handle != null)
                PositionedDirectional(
                  top: DsSpace.s8,
                  end: DsSpace.s8,
                  child: SafeArea(
                    child: PlayerGlassPill(
                      child: KeyedSubtree(
                        key: _episodesAnchor,
                        child: Row(mainAxisSize: MainAxisSize.min, children: _pictureVerbs(t)),
                      ),
                    ),
                  ),
                ),
              if (stageOnly)
                PositionedDirectional(
                  top: DsSpace.s8,
                  start: DsSpace.s8,
                  child: SafeArea(
                    child: PlayerGlassPill(
                      child: PlayerBarButton(
                        icon: DsIcons.arrowLeft,
                        label: t.common.back,
                        onPressed: () {
                          _wake();
                          if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                ),
              // The picture's right edge, the room column's shape: the
              // frame's copy above the lock — take the shot, then hand the
              // picture over to the lock. Locked, the unlock pill is the
              // only thing drawn, whatever the page does next; the download
              // lives in the more container now. The small window's corners
              // belong to the shared chrome, so the column stands down there
              // — save as that unlock pill: a locked picture with no unlock
              // on it is a door bricked from inside.
              if (handle != null && (_locked || (!smallWindow && (immersive || stageOnly || showBar))))
                PositionedDirectional(
                  end: DsSpace.s12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: DsSpace.s8,
                      children: [
                        if (!_locked && !smallWindow && handle.canCaptureScreenshot)
                          PlayerGlassPill(
                            child: PlayerBarButton(
                              icon: DsIcons.camera,
                              label: t.player.screenshot,
                              onPressed: () {
                                _wake();
                                unawaited(_screenshot());
                              },
                            ),
                          ),
                        PlayerGlassPill(
                          child: PlayerBarButton(
                            icon: _locked ? DsIcons.unlock : DsIcons.lock,
                            label: _locked ? t.room.unlockControls : t.room.lockControls,
                            onPressed: _toggleLock,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // The page's head, over the picture: the way back and the
              // season's name, riding the same shade the archive strip wears.
              // The sideways stage-only body leads with its own pill, and
              // the title would only fight it for the corner.
              if (showBar && !immersive && !stageOnly)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
                    decoration: BoxDecoration(gradient: OnVideoColors.shade(edge: VerticalDirection.up)),
                    child: Row(
                      spacing: DsSpace.s8,
                      children: [
                        PlayerCapsuleHead(
                          title: ref.watch(vodSeasonDetailProvider(widget.seasonId)).value?.title ?? t.vod.opening,
                          onBack: () {
                            _wake();
                            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                          },
                        ),
                        const Spacer(),
                        // The picture verbs at the row's far end — the
                        // same cluster every player carries, sized for
                        // the stage that shows it.
                        if (handle != null)
                          PlayerGlassPill(
                            child: Row(mainAxisSize: MainAxisSize.min, children: _pictureVerbs(t)),
                          ),
                      ],
                    ),
                  ),
                ),
              // The silent-source badge sits in the corner the small window's
              // close takes, and that corner is the shared chrome's.
              if (_silent && !smallWindow)
                PositionedDirectional(
                  top: DsSpace.s8,
                  end: DsSpace.s8,
                  child: DsBadge(label: Text(t.vod.pictureOnly), icon: const DsIcon(DsIcons.volumeOff)),
                ),
              // The bar away, the picture keeps one line at its foot: how far
              // the episode ran, and the strip that brings the bar back.
              // Locked, the line stands down too — nothing reads as chrome
              // but the unlock pill. The small window's chrome draws its own.
              if (!smallWindow && !showBar && playing && handle != null && !_locked)
                PositionedDirectional(
                  bottom: 0,
                  start: 0,
                  end: 0,
                  child: PlayerIdleProgress(
                    position: transport?.position,
                    duration: transport?.duration,
                    onWake: _wake,
                  ),
                ),
              if (!smallWindow && showBar)
                PositionedDirectional(
                  bottom: 0,
                  start: 0,
                  end: 0,
                  // The archive bar's own chrome, not this page's: one
                  // shade, one inset, and the archive's own buttons inside
                  // it, so the two detail pages answer alike.
                  child: PlayerControlBar(
                    key: _barAnchor,
                    padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, 0, DsSpace.s12, DsSpace.s8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: DsSpace.s4,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The step to the next episode is announced and counted,
                        // so a viewer who is not done with this one can stop it.
                        if (_countdown > 0)
                          Align(alignment: AlignmentDirectional.centerEnd, child: _countdownNotice(t)),
                        // The episode's download under way, then the line the
                        // episode is read by: the rows the page's bar and the
                        // small window's shade both carry, so neither goes
                        // unsaid because the window got small.
                        ?_downloadRow(t, theme, episode),
                        _seekLine(t),
                        // The bar's spacing and its buttons are the shared
                        // player's, so the season answers like the archive: one
                        // control line under the seek line — the transport
                        // leading it, the catalogues beside it and the way out
                        // at the line's end — and a line that cannot carry the
                        // catalogues gives them the one above, so play stays
                        // the first control of the bottom line whatever the
                        // width. The session verbs (the download, the frame
                        // copy) live in the picture's top pill and the rows
                        // over this one, not on it.
                        LayoutBuilder(
                          builder: (context, barConstraints) {
                            final barWidth = barConstraints.maxWidth;
                            final tv = PlayerBarTier.tvOf(context);
                            final gap = tv ? DsSpace.s8 : DsSpace.s4;
                            final control = PlayerBarTier.controlFootprint(context);
                            final pip = _presentationMode == PresentationMode.pip;
                            final previous = _hasPreviousEpisode;
                            final next = _hasNextEpisode;
                            // The bar's own width is the volume ladder's ruler:
                            // 96 px when it is roomy, 72 when it bends, and gone
                            // under 480, where the mute and the wheel still speak.
                            final volumeWidth = barWidth >= 720 ? 96.0 : (barWidth >= 480 ? 72.0 : null);
                            // The catalogues' three answers, as their chips
                            // draw them.
                            final qualityLabel = _qualityMenuLabel(t);
                            final speedLabel = VodSpeedChoice.nearest(_speed).label;
                            final episodeLabel = episode == null
                                ? t.vod.episodes
                                : t.vod.episodeNo(index: episode.index);
                            final hasEpisodes = _seasonDetail != null && _seasonDetail!.episodes.length > 1;
                            // The line is read before it is laid out, by the
                            // shared rule and off the bar's own width: the
                            // words go first, then the line gives way to the
                            // one above.
                            final line = playerBarLine(
                              barWidth: barWidth,
                              gap: gap,
                              fixed: [
                                if (previous) control,
                                control,
                                if (next) control,
                                control,
                                ?volumeWidth,
                                if (_desktop && !pip) control,
                                if (!pip) control,
                              ],
                              worded: [
                                if (qualities.isNotEmpty)
                                  PlayerBarChoice.extentOf(context, qualityLabel, compact: false),
                                PlayerBarChoice.extentOf(context, speedLabel, compact: false),
                                if (hasEpisodes) PlayerBarChoice.extentOf(context, episodeLabel, compact: false),
                              ],
                              glyphs: [
                                if (qualities.isNotEmpty)
                                  PlayerBarChoice.extentOf(context, qualityLabel, compact: true),
                                PlayerBarChoice.extentOf(context, speedLabel, compact: true),
                                if (hasEpisodes) PlayerBarChoice.extentOf(context, episodeLabel, compact: true),
                              ],
                            );
                            final compact = !line.words;
                            return PlayerBarRows(
                              // The shared reading decides: one line while the
                              // width carries all three groups, the catalogues
                              // on the line above when it does not — never a
                              // threshold of this page's own.
                              foldWidth: line.inline ? 0 : double.infinity,
                              foldAbove: true,
                              gap: gap,
                              start: Row(
                                spacing: gap,
                                children: [
                                  // The steps between episodes lead, the way
                                  // every serial's bar carries them: the
                                  // episode before, play, the episode after —
                                  // where the thumb starts, at every width. A
                                  // season is watched in both directions, and
                                  // the catalogue keeps the jump to any one.
                                  if (previous)
                                    PlayerBarButton(
                                      icon: DsIcons.skipBack,
                                      label: t.vod.previousPart,
                                      onPressed: () {
                                        _wake();
                                        _openSteppedEpisode(-1);
                                      },
                                    ),
                                  PlayerBarButton(
                                    icon: playing ? DsIcons.pause : DsIcons.play,
                                    label: playing ? t.player.pause : t.player.play,
                                    onPressed: handle == null
                                        ? null
                                        : () {
                                            _wake();
                                            unawaited(_togglePlay());
                                          },
                                  ),
                                  if (next)
                                    PlayerBarButton(
                                      icon: DsIcons.skipForward,
                                      label: t.vod.nextPart,
                                      onPressed: () {
                                        _wake();
                                        _openSteppedEpisode(1);
                                      },
                                    ),
                                  // The volume the archive bar carries: the
                                  // pair, then the slider, exactly where the
                                  // archive keeps them.
                                  PlayerBarButton(
                                    icon: (handle?.muted ?? false) ? DsIcons.volumeX : DsIcons.volume2,
                                    label: (handle?.muted ?? false) ? t.player.unmute : t.player.mute,
                                    onPressed: handle == null
                                        ? null
                                        : () {
                                            _wake();
                                            unawaited(_toggleMute());
                                          },
                                  ),
                                  if (volumeWidth case final width?) _volumeSlider(t, width),
                                ],
                              ),
                              // The net under the reading: a catalogue the
                              // measure said fits and the type draws a hair
                              // wider scrolls here rather than painting past
                              // the bar.
                              middle: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  spacing: gap,
                                  children: [
                                    if (qualities.isNotEmpty)
                                      PlayerBarChoice(
                                        anchorKey: _qualityAnchor,
                                        label: t.player.quality,
                                        value: qualityLabel,
                                        icon: DsIcons.gauge,
                                        selected: _openPanel == 'quality',
                                        compact: compact,
                                        onPressed: () =>
                                            setState(() => _openPanel = _openPanel == 'quality' ? null : 'quality'),
                                      ),
                                    // The pace, the button the keyboard's comma
                                    // and period have always walked: the same
                                    // ladder the vod page lists, now with a
                                    // door of its own.
                                    PlayerBarChoice(
                                      anchorKey: _speedAnchor,
                                      label: t.player.speed,
                                      value: speedLabel,
                                      icon: DsIcons.timer,
                                      selected: _openPanel == 'speed',
                                      compact: compact,
                                      onPressed: () =>
                                          setState(() => _openPanel = _openPanel == 'speed' ? null : 'speed'),
                                    ),
                                    // The episodes catalogue, where the archive
                                    // keeps its parts. It rides the bar, so it
                                    // shows and hides with it.
                                    if (hasEpisodes)
                                      PlayerBarChoice(
                                        anchorKey: _episodesAnchor,
                                        label: t.vod.episodes,
                                        value: episodeLabel,
                                        icon: DsIcons.listVideo,
                                        selected: _openPanel == 'episodes',
                                        compact: compact,
                                        onPressed: () =>
                                            setState(() => _openPanel = _openPanel == 'episodes' ? null : 'episodes'),
                                      ),
                                  ],
                                ),
                              ),
                              end: Row(
                                spacing: gap,
                                children: [
                                  // The window's own shape with the arrows that say
                                  // which way it goes — the desktop verb, present in
                                  // the immersive shell too, its pair beside it.
                                  if (_desktop && !pip)
                                    PlayerBarButton(
                                      icon: _presentationMode == PresentationMode.windowFullscreen
                                          ? DsIcons.squareShrinkUpLeftDownRight
                                          : DsIcons.squareExpandUpRightDownLeft,
                                      label: _presentationMode == PresentationMode.windowFullscreen
                                          ? t.player.windowFullscreenOff
                                          : t.player.windowFullscreenOn,
                                      selected: _presentationMode == PresentationMode.windowFullscreen,
                                      onPressed: handle == null
                                          ? null
                                          : () {
                                              _wake();
                                              unawaited(_presentationNotifier.toggleWindowFullscreen(handle.id));
                                            },
                                    ),
                                  // The system fullscreen, the phone's way
                                  // and the F key's. It reads as the way in
                                  // from the window's own fullscreen too: the
                                  // two variants answer to their own buttons,
                                  // and neither is the other's exit.
                                  if (!pip)
                                    PlayerBarButton(
                                      icon: _presentationMode == PresentationMode.fullscreen
                                          ? DsIcons.minimize
                                          : DsIcons.maximize,
                                      label: _presentationMode == PresentationMode.fullscreen
                                          ? t.player.fullscreenOff
                                          : t.player.fullscreen,
                                      selected: _presentationMode == PresentationMode.fullscreen,
                                      onPressed: handle == null
                                          ? null
                                          : () {
                                              _wake();
                                              _toggleFullscreen();
                                            },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (_error case final error?) _barError(theme, error),
                      ],
                    ),
                  ),
                ),
              // The bar's pickers hang their cards over the picture: a tap
              // anywhere else closes whichever one stands. The small window
              // has no bar to hang a card from and no room for one — its
              // chrome is the shared one's — so a catalogue left open before
              // the window shrank waits there for the page to come back.
              if (!smallWindow && _openPanel != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _openPanel = null),
                    child: const SizedBox.expand(),
                  ),
                ),
              if (!smallWindow && showBar && _openPanel == 'quality' && qualities.isNotEmpty)
                PlayerPanelHost(
                  anchorKey: _qualityAnchor,
                  barKey: _barAnchor,
                  width: 220,
                  child: PlayerOverlayPanel(
                    title: t.player.quality,
                    children: [
                      for (final quality in qualities)
                        PlayerPanelOption(
                          label: quality.label,
                          selected: quality.qn == _openedQn,
                          onPressed: () {
                            setState(() => _openPanel = null);
                            final current = _episodeOf(_openedIdentity);
                            if (current != null) {
                              unawaited(_openEpisode(current, qn: quality.qn, resumeFrom: _transport?.position));
                            }
                          },
                        ),
                    ],
                  ),
                ),
              if (!smallWindow && showBar && _openPanel == 'speed')
                PlayerPanelHost(
                  anchorKey: _speedAnchor,
                  barKey: _barAnchor,
                  width: 180,
                  child: PlayerOverlayPanel(
                    title: t.player.speed,
                    children: [
                      for (final choice in VodSpeedChoice.values)
                        PlayerPanelOption(
                          label: choice.label,
                          selected: choice.value == _speed,
                          onPressed: () {
                            setState(() => _openPanel = null);
                            unawaited(_setSpeed(choice.value));
                          },
                        ),
                    ],
                  ),
                ),
              // The episodes catalogue: the bar's list chip hangs it over
              // the picture — one row per episode, the one playing lit, the
              // number jump kept as the catalogue's own first row.
              if (!smallWindow && showBar && _openPanel == 'episodes')
                PlayerPanelHost(
                  anchorKey: _episodesAnchor,
                  barKey: _barAnchor,
                  width: 280,
                  child: Builder(
                    builder: (context) {
                      final episodes = _seasonDetail?.episodes ?? const <VodEpisode>[];
                      final current = _episode;
                      return PlayerOverlayPanel(
                        title: t.vod.episodes,
                        children: [
                          if (episodes.length > 1)
                            PlayerPanelOption(
                              label: t.vod.episodesJump,
                              selected: false,
                              onPressed: () {
                                setState(() => _openPanel = null);
                                unawaited(_jumpEpisode());
                              },
                            ),
                          for (final episode in episodes)
                            PlayerPanelOption(
                              label: episode.title.isEmpty ? t.vod.episodeNo(index: episode.index) : episode.title,
                              detail: episode.title.isEmpty ? null : t.vod.episodeNo(index: episode.index),
                              selected: current != null && episode.id == current.id,
                              onPressed: () {
                                setState(() => _openPanel = null);
                                unawaited(_openEpisode(episode));
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ),
              // The desktop's small window, its last layers: the band that
              // moves the window — the top 44 px, under the chrome, a double
              // press on it handing the page back — then the shared chrome
              // over the picture, and the countdown to the next episode as
              // its pill over the two. The bar carries that offer above its
              // seek line; stacked into a shade this short it would push the
              // bar up over the corners, and over the close with them.
              if (smallWindow) ...[
                PositionedDirectional(
                  start: 0,
                  end: 0,
                  top: 0,
                  height: 44,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (_) {
                      final window = ref.read(windowsPipWindowProvider);
                      if (window != null) unawaited(window.startDragging());
                    },
                    onDoubleTap: () {
                      _wake();
                      unawaited(_togglePip());
                    },
                  ),
                ),
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) =>
                        _smallWindowChrome(context, constraints.maxWidth, visible: showBar),
                  ),
                ),
                if (showBar && _countdown > 0) Positioned.fill(child: Center(child: _countdownNotice(t))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// How long the episode on the picture runs: the engine's own reading of
  /// it, else the figure the ladder named for the episode.
  Duration get _episodeDuration => _transport?.duration ?? _episodeOf(_openedIdentity)?.duration ?? Duration.zero;

  /// Where the episode stands: the second a drag is holding the line on,
  /// else the engine's.
  Duration get _episodePosition => _dragSeconds != null
      ? Duration(milliseconds: (_dragSeconds! * 1000).round())
      : _transport?.position ?? Duration.zero;

  /// The season's own seek line: the clocks come from the shared layer, and
  /// the line — the preview, the cover thumb — rides the slot the layer
  /// leaves for it. The page's bar and the small window's shade draw the
  /// same one, so a drag speaks the same two callbacks wherever it starts.
  Widget _seekLine(Translations t) => PlayerSeekLayer.replay(
    position: _episodePosition,
    duration: _episodeDuration,
    buffered: _transport?.buffer.ranges ?? const [],
    seekBar: VodSeekBar(
      position: _episodePosition,
      duration: _episodeDuration,
      semanticLabel: t.player.progress,
      buffered: _transport?.buffer.ranges ?? const [],
      coverUrl: ref.read(vodSeasonDetailProvider(widget.seasonId)).value?.coverUrl,
      showPreview: ref.watch(vodPlaybackSettingsProvider).seekPreview,
      onScrub: (seconds) => setState(() => _dragSeconds = seconds),
      onSeek: (seconds) {
        setState(() => _dragSeconds = null);
        unawaited(_seekTo(seconds));
      },
    ),
  );

  /// The sound's level on the bar, [width] wide: the one slider the page's
  /// bar and the small window's shade trim the volume with.
  Widget _volumeSlider(Translations t, double width) => SizedBox(
    width: width,
    child: DsSlider(
      value: ((_playableHandle?.volume ?? _volume) * 100).clamp(0.0, 100.0),
      max: 100,
      style: const DsSliderStyle(
        height: 24,
        trackHeight: 4,
        trackColor: OnVideoColors.track,
        fillColor: OnVideoColors.foreground,
        thumbColor: OnVideoColors.foreground,
        thumbSize: 12,
      ),
      onChanged: _playableHandle == null
          ? null
          : (value) {
              _wake();
              unawaited(_setVolume(value / 100));
            },
      semanticLabel: t.player.volume,
    ),
  );

  /// The offer the end of an episode makes: the next one opening when the
  /// countdown runs out, and the word that stops it. A pill over what it
  /// stands on — a one-time offer that leaves when taken, not a watching
  /// verb — so the bar sets it at its line's end and the small window
  /// floats it over the picture.
  Widget _countdownNotice(Translations t) => VodPictureNotice(
    icon: DsIcons.listVideo,
    text: t.vod.nextPartIn(seconds: _countdown),
    actionLabel: t.common.cancel,
    onAction: _cancelCountdown,
  );

  /// The episode's download under way, the row the bar keeps above its seek
  /// line: how far the file is, and the pause that holds it there. Null
  /// when nothing of this episode is in the queue's hands.
  Widget? _downloadRow(Translations t, DsThemeData theme, VodEpisode? episode) {
    if (_episodeDownload(episode) case final download?
        when download.phase == VodDownloadPhase.running || download.phase == VodDownloadPhase.queued) {
      return Row(
        spacing: DsSpace.s8,
        children: [
          const DsSpinner(style: DsSpinnerStyle(size: 12)),
          Expanded(
            child: Text(
              switch (download.progress) {
                final progress? => t.settings.downloadPercent(percent: '${(progress * 100).round()}'),
                null => t.settings.downloadPercentUnknown,
              },
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.caption.copyWith(color: OnVideoColors.foreground),
            ),
          ),
          DsButton.icon(
            variant: DsButtonVariant.ghost,
            size: DsSize.sm,
            semanticLabel: t.player.downloadPause,
            onPressed: () => unawaited(ref.read(vodDownloadsProvider.notifier).pause(download.id)),
            icon: const DsIcon(DsIcons.pause),
          ),
        ],
      );
    }
    return null;
  }

  /// What the picture has to report — a source that would not open, a seek
  /// the engine refused — [message] on one line under the transport, in the
  /// theme's danger ink. It rides the bar rather than covering the picture:
  /// a refused seek is not the end of the episode.
  Widget _barError(DsThemeData theme, String message) => Padding(
    padding: const EdgeInsetsDirectional.only(top: DsSpace.s4),
    child: Text(
      message,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.typography.caption.copyWith(color: theme.colors.danger.text),
    ),
  );

  /// The desktop's small window: the shared chrome over the episode's
  /// picture. The season's name beside the way back, the transport leading
  /// the bar, the sound after it, the season's own seek line running along
  /// the bottom edge above them, and the pin at the bar's end; what the
  /// page's bar says around that line — a download under way, a failure —
  /// rides the same slot. The picture underneath keeps every gesture it has
  /// on the page.
  Widget _smallWindowChrome(BuildContext context, double width, {required bool visible}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final handle = _playableHandle;
    final playing = _transport?.isPlaying ?? false;
    final muted = handle?.muted ?? false;
    final control = PlayerBarTier.controlFootprint(context);
    // The name's room: what the two corner pills and the window's insets
    // leave of the window.
    final nameMax = (width - 2 * control - 56).clamp(0, double.infinity).toDouble();
    // Play and pause: the bar's first control on a desktop's window, the
    // middle of the picture on a phone's.
    Widget transportButton({double? size, double? glyph}) => PlayerBarButton(
      icon: playing ? DsIcons.pause : DsIcons.play,
      label: playing ? t.player.pause : t.player.play,
      size: size,
      iconSize: glyph,
      onPressed: handle == null
          ? null
          : () {
              _wake();
              unawaited(_togglePlay());
            },
    );
    return PlayerPipChrome(
      visible: visible,
      width: width,
      control: control,
      onRestore: () {
        _wake();
        unawaited(_togglePip());
      },
      onClose: () {
        _wake();
        unawaited(_playableHandle?.pause());
        final close = ref.read(roomLeaveProvider);
        if (close != null) {
          unawaited(close());
          return;
        }
        // The page's own window cannot close itself: the episode stops and
        // the small window hands the page back.
        _leave();
      },
      onWake: _wake,
      identity: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: nameMax),
        child: Text(
          // The word the page's own head prints over the picture.
          ref.watch(vodSeasonDetailProvider(widget.seasonId)).value?.title ?? t.vod.opening,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.labelStrong.copyWith(color: OnVideoColors.foreground),
        ),
      ),
      leading: transportButton(),
      playPause: PlayerGlassPill(
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.s8),
          child: transportButton(size: theme.sizes.lg, glyph: DsSpace.s24),
        ),
      ),
      verbs: [
        PlayerPipVerb(
          child: PlayerBarButton(
            icon: muted ? DsIcons.volumeX : DsIcons.volume2,
            label: muted ? t.player.unmute : t.player.mute,
            onPressed: handle == null
                ? null
                : () {
                    _wake();
                    unawaited(_toggleMute());
                  },
          ),
        ),
        // The level where the window is wide enough to trim it; under that
        // the mute pill alone names the sound.
        if (width >= 480) PlayerPipVerb(extent: 88, child: _volumeSlider(t, 88)),
      ],
      progress: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: DsSpace.s4,
        children: [
          ?_downloadRow(t, theme, _episode),
          _seekLine(t),
          if (_error case final error?) _barError(theme, error),
        ],
      ),
      onTogglePin: () {
        final next = !ref.read(playbackSettingsProvider).windowsPipAlwaysOnTop;
        unawaited(ref.read(playbackSettingsProvider.notifier).setWindowsPipAlwaysOnTop(value: next));
        unawaited(ref.read(desktopWindowHostProvider).setAlwaysOnTop(value: next));
      },
      pinned: ref.watch(playbackSettingsProvider.select((settings) => settings.windowsPipAlwaysOnTop)),
    );
  }
}

/// Whether this host offers the desktop-only window-fullscreen button — the
/// room bar's own rule: the picture filling the app window while the window
/// stays a window is a desktop shell's verb.
bool get _desktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux);

/// One cinema season as the page opens with it: the mockup's poster head —
/// the front at its own 3:4 with the score on its corner, and beside it the
/// name, the tags, the figures, the episode on the picture, the actions row
/// (立即播放, download, share) and the blurb folded to two lines.
final class _SeasonHead extends StatelessWidget {
  const _SeasonHead({
    required this.season,
    required this.episode,
    required this.showDetails,
    required this.posterWidth,
    required this.canPlay,
    required this.onPlay,
    required this.canDownload,
    required this.onDownload,
    required this.onShare,
    required this.canWrite,
    required this.onSetFollow,
  });

  /// The season shown.
  final VodSeasonDetail season;

  /// The episode the page is playing, when one is.
  final VodEpisode? episode;

  /// Whether the score, the counts and the blurb appear — the station's own
  /// switch, the same one the video page's details answer to.
  final bool showDetails;

  /// The poster's width: the wide head's 216, the phone's 110.
  final double posterWidth;

  /// Whether 立即播放 has an episode to open.
  final bool canPlay;

  /// Puts a picture on.
  final VoidCallback onPlay;

  /// Whether the episode on the picture can enter the download queue.
  final bool canDownload;

  /// Hands the episode to the queue.
  final VoidCallback onDownload;

  /// Shares the season's web address.
  final VoidCallback onShare;

  /// Whether the cookie can speak the follow write; a guest keeps the
  /// badge instead of the button.
  final bool canWrite;

  /// Flips the season's follow; null leaves the button inert.
  final ValueChanged<bool>? onSetFollow;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final rating = showDetails ? season.rating : '';
    // A film's state line is its release day (`2023年03月31日上映`), which
    // already says the year; only a series' line (`更新至第1278话`) leaves
    // the year for the tags to say.
    final stateNamesYear = season.subtitle.contains(RegExp(r'\d{4}'));
    final published = season.publishedAt;
    final area = season.area;
    // The tags row leads with where and when — the mockup's `2026 · 日本` —
    // then the source's own subject tags, then the score in its accent
    // stamp. A film whose state line already says the year does not say it
    // twice.
    final String? lead;
    if (area.isNotEmpty) {
      lead = published != null && !stateNamesYear ? '${published.year} · $area' : area;
    } else {
      lead = published != null && !stateNamesYear ? '${published.year}' : null;
    }
    final chips = <({String text, bool score})>[
      if (lead != null) (text: lead, score: false),
      for (final style in season.styles) (text: style, score: false),
      if (rating.isNotEmpty) (text: rating, score: true),
    ];
    final plays = season.viewCount;
    final danmaku = season.danmakuCount;
    final facts = [
      if (showDetails && plays != null && plays > 0) '${AudienceFormat.format(plays)} ${t.vod.views}',
      if (showDetails && danmaku != null && danmaku > 0) '${AudienceFormat.format(danmaku)} ${t.vod.danmaku}',
      if (season.subtitle.isNotEmpty) season.subtitle,
    ];
    final current = episode;
    final fallback = CoverFallback(title: season.title, padding: const EdgeInsets.all(DsSpace.s8));
    final cover = season.coverUrl;
    // The cover leads the head the way the music module's record does:
    // frosted behind the block, the poster carrying its shadow in front.
    return DetailHeroBackdrop(
      coverImage: cover == null || cover.isEmpty ? null : cachedImage(cover, policy: ImageCachePolicies.videoCover),
      child: Padding(
        padding: const EdgeInsets.all(DsSpace.s20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DsSpace.s16,
          children: [
            SizedBox(
              width: posterWidth,
              child: DecoratedBox(
                decoration: DsBoxDecoration(
                  borderRadius: BorderRadius.circular(theme.radii.card),
                  shadows: [DsShadow(color: colors.overlay, blur: DsSpace.s24, offset: const Offset(0, DsSpace.s8))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(theme.radii.card),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (cover == null || cover.isEmpty)
                          fallback
                        else
                          DsImage(
                            image: cachedImage(cover, policy: ImageCachePolicies.videoCover),
                            aspectRatio: 3 / 4,
                            semanticLabel: season.title,
                            fallback: fallback,
                          ),
                        // The poster is 3:4, not the covers' 16:9: a fade that
                        // rises from the foot by its own height, not a cover scrim
                        // stretched over a taller shape.
                        PositionedDirectional(
                          bottom: 0,
                          start: 0,
                          end: 0,
                          height: 96,
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: OnVideoColors.shade(
                                  edge: VerticalDirection.down,
                                  strong: OnVideoColors.coverMark,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // The score on the poster's corner, the mockup's accent
                        // stamp: the one figure worth reading before the words.
                        if (rating.isNotEmpty)
                          PositionedDirectional(top: DsSpace.s6, end: DsSpace.s6, child: _scoreBadge(context, rating)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s8,
                children: [
                  Row(
                    spacing: DsSpace.s8,
                    children: [
                      Expanded(
                        child: Text(
                          season.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.title.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                        ),
                      ),
                      if (!canWrite && season.followed) DsBadge(label: Text(t.vod.following), dot: false),
                    ],
                  ),
                  if (chips.isNotEmpty)
                    Wrap(
                      spacing: DsSpace.s6,
                      runSpacing: DsSpace.s6,
                      children: [
                        // The score stays on the poster's corner — the accent
                        // stamp says it once, not twice on one screen.
                        for (final chip in chips)
                          if (!chip.score) DsBadge(label: Text(chip.text), dot: false),
                      ],
                    ),
                  if (facts.isNotEmpty)
                    Text(
                      facts.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.caption.copyWith(color: colors.textMuted),
                    ),
                  if (current != null)
                    Row(
                      spacing: DsSpace.s6,
                      children: [
                        Flexible(
                          child: DsBadge(label: Text(t.vod.episodeNo(index: current.index)), dot: false),
                        ),
                        Expanded(
                          child: Text(
                            current.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.body.copyWith(color: colors.text),
                          ),
                        ),
                      ],
                    ),
                  Wrap(
                    spacing: DsSpace.s8,
                    runSpacing: DsSpace.s8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // The head's anchor: the play disc carries the verb's
                      // weight the music module's records do.
                      HeroPlayDisc(onPressed: canPlay ? onPlay : null, semanticLabel: t.vod.playNow),
                      // The follow verb, where the head's keep-verbs stand:
                      // 追番 asks, 已追 answers — the badge's word, now the
                      // button's own state.
                      if (canWrite)
                        DsButton(
                          variant: season.followed ? DsButtonVariant.secondary : DsButtonVariant.primary,
                          size: DsSize.sm,
                          onPressed: onSetFollow == null ? null : () => onSetFollow!(!season.followed),
                          child: Text(season.followed ? t.vod.following : t.vod.seasonFollow),
                        ),
                      DsButton(
                        variant: DsButtonVariant.secondary,
                        size: DsSize.sm,
                        leading: const DsIcon(DsIcons.download, size: 14),
                        onPressed: canDownload ? onDownload : null,
                        child: Text(t.player.download),
                      ),
                      DsButton.icon(
                        variant: DsButtonVariant.ghost,
                        size: DsSize.sm,
                        semanticLabel: t.vod.share,
                        onPressed: onShare,
                        icon: const DsIcon(DsIcons.share),
                      ),
                    ],
                  ),
                  if (showDetails && season.evaluate.isNotEmpty) VodFoldedText(text: season.evaluate, maxLines: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The score in the mockup's accent stamp: white digits on the accent
  /// fill, the poster corner and the tags row saying the same figure once
  /// each in their own place.
  Widget _scoreBadge(BuildContext context, String text) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    return DsBadge(
      label: Text(text),
      dot: false,
      style: DsBadgeStyle(
        background: colors.accent,
        foreground: colors.onAccent,
        borderRadius: BorderRadius.circular(theme.radii.control(18)),
        textStyle: theme.typography.numeric(
          theme.typography.caption.copyWith(color: colors.onAccent, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

/// A season's episodes, [kVodEpisodeGroup] at a time with a pager and a jump
/// box when they run past one group — the episode shelf's pattern shared with
/// the video page's parts, for the seasons that run to hundreds of episodes.
const int kVodEpisodeGroup = 20;

/// The information line under an episode card's cover: one caption line held
/// at a fixed height, so a row's cards all end at the same line whatever the
/// column width — the season card's own measure, at an episode's size.
const double kVodEpisodeInfoExtent = 46;

/// The widest an episode card gets before the shelf takes another column, and
/// the bounds it keeps whatever the window says: four across on a desktop,
/// two on a phone — the mockup's own two counts.
const double kVodEpisodeMaxExtent = 280;
const int kVodEpisodeMaxColumns = 4;
const int kVodEpisodeMinColumns = 2;

/// The columns a shelf [content] pixels wide takes: as many as keep a card at
/// or under [kVodEpisodeMaxExtent], within the mockup's two-to-four bounds.
/// [crossSpacing] is the viewer's own column spacing, so the count always
/// leaves room for the gaps it will really draw.
int episodeColumnsForWidth(double content, {required double crossSpacing}) {
  if (content <= 0) return kVodEpisodeMinColumns;
  double width(int columns) => (content - crossSpacing * (columns - 1)) / columns;
  var columns = 1;
  while (columns < kVodEpisodeMaxColumns && width(columns) > kVodEpisodeMaxExtent) {
    columns++;
  }
  if (columns < kVodEpisodeMinColumns) return kVodEpisodeMinColumns;
  return columns;
}

final class _EpisodesSection extends ConsumerStatefulWidget {
  const _EpisodesSection({required this.episodes, required this.current, required this.onOpen});

  final List<VodEpisode> episodes;

  /// The episode the page is playing, when one is.
  final VodEpisode? current;

  /// Runs when the viewer picks another episode.
  final void Function(VodEpisode episode) onOpen;

  @override
  ConsumerState<_EpisodesSection> createState() => _EpisodesSectionState();
}

final class _EpisodesSectionState extends ConsumerState<_EpisodesSection> {
  int _group = 0;

  @override
  void initState() {
    super.initState();
    _group = _groupOf(widget.current);
  }

  @override
  void didUpdateWidget(_EpisodesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching the playing episode turns the shelf to the page it sits on.
    if (oldWidget.current?.id != widget.current?.id) {
      setState(() => _group = _groupOf(widget.current));
    }
  }

  /// The group [episode] sits in, by its place in the season's list.
  int _groupOf(VodEpisode? episode) {
    if (episode == null) return 0;
    final position = widget.episodes.indexWhere((candidate) => candidate.id == episode.id);
    return position < 0 ? 0 : position ~/ kVodEpisodeGroup;
  }

  /// Asks for an episode number and opens it; an empty or unknown answer
  /// leaves the shelf where it was.
  Future<void> _jump() async {
    final episodes = widget.episodes;
    if (episodes.isEmpty) return;
    int? parse(String typed) {
      final number = int.tryParse(typed.trim());
      if (number == null) return null;
      final byIndex = episodes.where((episode) => int.tryParse(episode.index) == number);
      if (byIndex.isNotEmpty) return episodes.indexOf(byIndex.first);
      return number >= 1 && number <= episodes.length ? number - 1 : null;
    }

    final position = await showVodJumpDialog(
      context,
      title: context.t.vod.episodesJump,
      count: episodes.length,
      parse: parse,
    );
    if (position == null || position < 0 || position >= episodes.length || !mounted) return;
    widget.onOpen(episodes[position]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    // The gaps between the cards are the viewer's browsing spacing, the same
    // measure every feed on the station pages by.
    final browse = ref.watch(browseSettingsProvider);
    final crossSpacing = browse.crossSpacing;
    final mainSpacing = browse.mainSpacing;
    final episodes = widget.episodes;
    final groups = (episodes.length + kVodEpisodeGroup - 1) ~/ kVodEpisodeGroup;
    final group = _group.clamp(0, groups - 1);
    final first = group * kVodEpisodeGroup;
    final shown = episodes.skip(first).take(kVodEpisodeGroup).toList();
    final last = first + shown.length;
    // A phone's width cannot carry five controls in one row: the
    // paging arrows fold away there, the range text and the jump stay.
    final narrow = MediaQuery.sizeOf(context).width < kPlaybackCompactBreakpoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        SectionHeader(
          title: t.vod.episodes,
          count: episodes.length,
          hint: groups > 1 ? '$first–$last / ${episodes.length}' : null,
          trailing: [
            if (groups > 1 && !narrow) ...[
              DsButton.icon(
                icon: const DsIcon(DsIcons.chevronLeft),
                semanticLabel: t.vod.episodesPrevious,
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: group > 0 ? () => setState(() => _group = group - 1) : null,
              ),
              DsButton.icon(
                icon: const DsIcon(DsIcons.chevronRight),
                semanticLabel: t.vod.episodesNext,
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: group < groups - 1 ? () => setState(() => _group = group + 1) : null,
              ),
            ],
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.listOrdered, size: 16),
              onPressed: () => unawaited(_jump()),
              child: Text(t.vod.episodesJump),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final content = constraints.maxWidth;
            // A column with nothing to divide cannot size a tile; the page's
            // own layout never hands one in, but a guard keeps the delegate
            // honest.
            if (content <= 0) return const SizedBox.shrink();
            final columns = episodeColumnsForWidth(content, crossSpacing: crossSpacing);
            final tileWidth = (content - crossSpacing * (columns - 1)) / columns;
            return GridView.builder(
              shrinkWrap: true,
              // The page's own scroll carries the shelf; the grid never
              // competes with it.
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: crossSpacing,
                mainAxisSpacing: mainSpacing,
                mainAxisExtent: tileWidth * 9 / 16 + kVodEpisodeInfoExtent,
              ),
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final candidate = shown[index];
                final playing = candidate.id == widget.current?.id;
                return DsCard(
                  onPressed: () => widget.onOpen(candidate),
                  semanticLabel: '${t.vod.episodeNo(index: candidate.index)} ${candidate.title}',
                  style: DsCardStyle(
                    padding: EdgeInsets.zero,
                    hovered: DsCardStyle(background: colors.hover),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _episodeCover(candidate, context),
                            const Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
                              ),
                            ),
                            // The episode's number on the cover's corner;
                            // the one on the picture wears the accent, so
                            // the shelf always answers 观看到第几话.
                            PositionedDirectional(
                              top: DsSpace.s6,
                              start: DsSpace.s6,
                              child: playing
                                  ? DsBadge(
                                      label: Text(t.vod.episodeNo(index: candidate.index)),
                                      dot: false,
                                      style: DsBadgeStyle(
                                        background: colors.accent,
                                        foreground: colors.onAccent,
                                        borderRadius: BorderRadius.circular(theme.radii.control(18)),
                                        textStyle: theme.typography.numeric(
                                          theme.typography.caption.copyWith(
                                            color: colors.onAccent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    )
                                  : RoomCoverChip(
                                      compact: true,
                                      text: t.vod.episodeNo(index: candidate.index),
                                      style: theme.typography.numeric(theme.typography.caption),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: kVodEpisodeInfoExtent,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(DsSpace.s6, DsSpace.s4, DsSpace.s6, DsSpace.s4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            spacing: DsSpace.s3,
                            children: [
                              Text(
                                candidate.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(
                                  color: playing ? colors.accent : colors.text,
                                  fontWeight: playing ? FontWeight.w600 : null,
                                ),
                              ),
                              if (candidate.duration != null)
                                Text(
                                  vodDurationText(candidate.duration!),
                                  style: theme.typography.numeric(
                                    theme.typography.caption.copyWith(color: colors.textMuted),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// An episode's cover, or the theme's stand-in.
  static Widget _episodeCover(VodEpisode episode, BuildContext context) {
    final fallback = CoverFallback(title: episode.title, padding: const EdgeInsets.all(DsSpace.s8));
    final url = episode.coverUrl;
    if (url == null || url.isEmpty) return fallback;
    return DsImage(
      image: cachedImage(url, policy: ImageCachePolicies.videoCover),
      aspectRatio: 16 / 9,
      semanticLabel: episode.title,
      fallback: fallback,
    );
  }
}

/// The season's loading shape: the poster's own 3:4, the title and its
/// chips as bars, the episode wall as a block — the page opens shaped like
/// itself instead of a spinner on an empty canvas.
final class _SeasonSkeleton extends StatelessWidget {
  const _SeasonSkeleton({required this.posterWidth});

  /// The poster's width, the same two measures the head itself draws at.
  final double posterWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = LiveWindow.pageInset(width);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s20,
            children: [
              const AspectRatio(
                aspectRatio: 16 / 9,
                child: ColoredBox(color: OnVideoColors.ground),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s16,
                children: [
                  SizedBox(
                    width: posterWidth,
                    child: const AspectRatio(
                      aspectRatio: 3 / 4,
                      child: DsSkeleton.block(width: double.infinity),
                    ),
                  ),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: DsSpace.s12,
                      children: [
                        DsSkeleton(width: double.infinity, height: 22, strong: true),
                        DsSkeleton(width: 200, height: 12),
                        Row(
                          spacing: DsSpace.s6,
                          children: [
                            DsSkeleton(width: 56, height: 22),
                            DsSkeleton(width: 72, height: 22),
                            DsSkeleton(width: 64, height: 22),
                          ],
                        ),
                        Row(
                          spacing: DsSpace.s8,
                          children: [
                            DsSkeleton(width: 96, height: 30),
                            DsSkeleton(width: 88, height: 30),
                            DsSkeleton.circle(size: 30),
                          ],
                        ),
                        DsSkeleton.block(width: double.infinity, height: 48),
                      ],
                    ),
                  ),
                ],
              ),
              const DsSkeleton.block(width: double.infinity, height: 160),
              const Align(
                alignment: AlignmentDirectional.center,
                child: DsSpinner(style: DsSpinnerStyle(size: 24)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
