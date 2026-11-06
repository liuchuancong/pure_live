import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, FilteringTextInputFormatter, LogicalKeyboardKey, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_device/live_device.dart'
    show PlatformScreenBrightnessService, ScreenBrightnessScope, ScreenBrightnessService;
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_app_login.dart' show vodAppClientProvider;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_pgc.dart';
import 'package:pure_live/modules/vod/controller/vod_playback_settings.dart'
    show VodApiType, VodFinishAction, VodSpeedChoice, vodPlaybackSettingsProvider;
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show vodQualityProvider;
import 'package:pure_live/modules/vod/widgets/vod_media_source.dart'
    show vodDashSourceOf, vodDashVideoOf, vodQualityLabel;
import 'package:pure_live/modules/vod/widgets/vod_picture_gestures.dart' show VodPictureGestures, VodTapSide;
import 'package:pure_live/modules/vod/widgets/vod_player_chrome.dart'
    show VodGestureKind, VodGestureTip, VodPictureNotice, VodSeekBar;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show vodDurationText;
import 'package:pure_live/shared/shared.dart'
    show
        AudienceFormat,
        CoverFallback,
        LiveWindow,
        PlayerIdleProgress,
        RoomCoverChip,
        cachedImage,
        kRoomCoverScrim,
        silencePlayer;
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;

/// One cinema title's page: the player over media_core, the season's blurb,
/// and its episodes — the reference's PgcFeatureScreen, with the station's own
/// player chrome.
///
/// The first episode opens with the page; picking another switches the same
/// handle to it. Episodes are addressed by `ep_id` through the signed PGC
/// play endpoint, which is what the login-gated renditions need.
final class VodSeasonPage extends ConsumerStatefulWidget {
  /// The season behind [seasonId].
  const VodSeasonPage({required this.seasonId, super.key});

  /// The season's id (`ss` number).
  final int seasonId;

  @override
  ConsumerState<VodSeasonPage> createState() => _VodSeasonPageState();
}

final class _VodSeasonPageState extends ConsumerState<VodSeasonPage> with RouteAware {
  /// The cinema player's default qn (1080P); the source may serve lower.
  static const int _defaultQn = 80;

  VodEpisode? _episode;
  VodPlayInfo? _play;
  int _qn = _defaultQn;

  /// The definition actually opened. The request names the whole ladder and
  /// this number says which rung of it the episode is playing on, so the menu
  /// checks what is on the screen rather than what was asked for.
  int _openedQn = _defaultQn;
  String? _openedLabel;

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
  PlayerId? _boundPlayer;
  StreamSubscription<PlayerTransportState>? _transportSub;
  StreamSubscription<PlayerAdapterEvent>? _eventSub;
  PlayerTransportState? _transport;
  String? _error;
  bool _opening = false;
  bool _silent = false;
  bool _disposed = false;
  bool _autoOpened = false;
  double? _dragSeconds;

  /// The window's observer, kept for `dispose` where the provider scope may
  /// already be gone.
  RouteObserver<ModalRoute<void>>? _routeObserver;

  // Captured while the page is alive; `ref` is refused by the time dispose
  // runs, and the leaving page must still exit its presentation mode and
  // release its handle.
  late final RoomPresentationController _presentationNotifier;
  late final PlayerKernel _kernel;

  /// The presentation mode, followed through a manual listener for the same
  /// reason: the leaving page reads its own field, not `ref`.
  PresentationMode _presentationMode = PresentationMode.normal;

  bool get _immersive => ref.read(roomPresentationProvider.notifier).modeOwnsWindow(ref.read(roomPresentationProvider));

  @override
  void initState() {
    super.initState();
    _presentationNotifier = ref.read(roomPresentationProvider.notifier);
    _kernel = ref.read(playerKernelProvider);
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    // The station's opening quality, with the cinema's own floor: 720P is the
    // progressive endpoint's ceiling, not a PGC rendition's.
    final setting = ref.read(vodQualityProvider).qn;
    _qn = setting < _defaultQn ? _defaultQn : setting;
    // The sound and rate the picture starts with, and whether this display
    // will take a brightness write at all.
    _volume = ref.read(playbackSettingsProvider.notifier).volume;
    _speed = ref.read(vodPlaybackSettingsProvider).speed.value;
    unawaited(_syncBrightness());
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
    final handle = _handle;
    if (handle != null && (_transport?.isPlaying ?? false)) {
      unawaited(handle.pause().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // The player goes quiet before anything else: the route's leave animation
    // runs while the release's queue drains, and the episode must not be heard
    // over the page the viewer returned to. Everything the leaving page needs
    // was captured while it was alive: a `ref` read here throws, and a page
    // that throws on its way out never releases the handle — the picture keeps
    // sounding with nothing left on screen to stop it.
    final handle = _handle;
    if (handle != null) {
      if (_presentationNotifier.modeOwnsWindow(_presentationMode)) {
        unawaited(_presentationNotifier.exit(handle.id));
      }
      silencePlayer(handle);
      unawaited(_kernel.release(handle.id));
    }
    _routeObserver?.unsubscribe(this);
    _routeObserver = null;
    _gestureTimer?.cancel();
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _openEpisode(VodEpisode episode, {int? qn}) async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _episode = episode;
      _play = null;
      _silent = false;
      _transport = null;
      _dragSeconds = null;
      _error = null;
      _finished = false;
    });
    // The next episode has its own ladder, its own position and its own held
    // rate, so none of this one's gestures or countdown carries over.
    _resetScrub();
    _cancelCountdown();
    final previous = _handle;
    if (previous != null) {
      try {
        await previous.pause();
      } on Object {
        // The switch itself reports a player that will not answer.
      }
    }
    try {
      // The app interface's PGC service when the viewer chose it and signed
      // in; a refusal falls back to the web endpoint. Either is asked for the
      // whole ladder, and `want` picks the picture out of it — the same split
      // the archive page keeps, so a tier the account may have is never
      // hidden by the number the request carried.
      final appClient = ref.read(vodAppClientProvider);
      final want = qn ?? _qn;
      _qn = want;
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
      if (!mounted || _disposed) return;
      final kernel = ref.read(playerKernelProvider);
      final handle =
          previous ??
          await kernel.create(
            config: const PlayerConfig(name: 'vod-pgc'),
            preferredBackend: ref.read(playerKernelBackendProvider).id,
          );
      if (!mounted || _disposed) {
        if (previous == null) unawaited(kernel.release(handle.id));
        return;
      }
      _handle = handle;
      _bind(handle);
      final picture = vodDashVideoOf(info, maxQuality: want);
      _openedQn = picture?.quality ?? info.servedQuality ?? want;
      _openedLabel = vodQualityLabel(info, _openedQn) ?? info.quality;
      final dash = vodDashSourceOf(info, maxQuality: want);
      if (dash != null) {
        try {
          await handle.openMedia(dash, autoPlay: true);
          // media_core signals "this engine cannot join two essences" as an
          // UnsupportedError; the muxed request below is its handler.
          // ignore: avoid_catching_errors
        } on UnsupportedError {
          // A single-URL engine: ask the muxed answer, whose sound is inside
          // the file.
          info = await ref
              .read(vodClientProvider)
              .pgcPlay(episodeId: episode.id, cid: episode.cid, aid: episode.aid, dash: false);
          if (!mounted || _disposed) return;
          _openedQn = info.servedQuality ?? _openedQn;
          _openedLabel = info.quality;
          await handle.open(_episodeSource(info, episode), autoPlay: true);
        }
      } else {
        await handle.open(_episodeSource(info, episode), autoPlay: true);
      }
      if (!mounted || _disposed) return;
      // The sound and the rate the page already answers to belong to the new
      // episode too; an engine that kept the old handle remembers neither.
      await handle.setVolume(_volume);
      await handle.setRate(_speed);
      setState(() {
        _play = info;
        _silent = info.silent;
        _opening = false;
      });
      _wake();
    } on Object catch (failure) {
      if (!mounted || _disposed) return;
      setState(() {
        _opening = false;
        _transport = null;
        _error = failure is VodFailure ? failure.message : '$failure';
      });
    }
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
    if (label == null || label.isEmpty) return t.vod.quality;
    return '${t.vod.quality} · $label';
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

  /// A playing episode lets its bars down after a moment's rest; a paused one
  /// keeps them, because a stopped picture has nothing else to read.
  void _scheduleHide() {
    _hideTimer?.cancel();
    if (!(_transport?.isPlaying ?? false)) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
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
    final handle = _handle;
    if (handle == null) return;
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (_volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showGesture(VodGestureKind.volume, '${(next * 100).round()}%');
    unawaited(_setVolume(next));
  }

  Future<void> _setVolume(double value) async {
    final handle = _handle;
    if (handle == null) return;
    setState(() => _volume = value);
    try {
      await handle.setVolume(value);
    } on Object {
      // A refused volume is not a playback failure.
    }
  }

  Future<void> _setSpeed(double rate) async {
    final handle = _handle;
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
    final handle = _handle;
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
        _togglePlay();
    }
  }

  void _scrubBy(double delta, double width) {
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
    final handle = _handle;
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
    final handle = _handle;
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
    final episodes = ref.read(vodSeasonDetailProvider(widget.seasonId)).value?.episodes ?? const <VodEpisode>[];
    final index = episodes.indexWhere((candidate) => candidate.id == _episode?.id) + direction;
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
    if (_finished) return;
    _finished = true;
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

  void _bind(PlayerHandle handle) {
    if (_boundPlayer == handle.id) return;
    _boundPlayer = handle.id;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    _transportSub = handle.playbackStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _transport = state;
        if (state.isPlaying) _error = null;
      });
      if (state.isPlaying) _scheduleHide();
    });
    // The end of an episode is the station's own event, not a position the
    // page has to guess at: it is what the finish action waits for.
    _eventSub = handle.adapterEvents.listen((event) {
      if (event is PlayerAdapterCompleted) unawaited(_handleFinished());
    });
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
        showDsToast(context: context, title: t.vod.downloadQueued, status: DsStatus.success);
      case VodDownloadEnqueue.duplicate:
        showDsToast(context: context, title: t.vod.downloadDuplicate);
      case VodDownloadEnqueue.failed:
        showDsToast(context: context, title: t.vod.downloadFailed, description: result.error, status: DsStatus.danger);
    }
  }

  void _togglePlay() {
    final handle = _handle;
    if (handle == null) return;
    unawaited(_transport?.isPlaying ?? false ? handle.pause() : handle.play());
  }

  Future<void> _seekTo(double seconds) async {
    final handle = _handle;
    if (handle == null) return;
    await handle.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  void _toggleFullscreen() {
    final handle = _handle;
    if (handle == null) return;
    unawaited(ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final immersive = _immersive;
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
            title: t.vod.downloadDone(name: item.fileName),
            status: DsStatus.success,
          );
        } else if (item.phase == VodDownloadPhase.failed) {
          showDsToast(context: context, title: t.vod.downloadFailed, status: DsStatus.danger);
        }
      }
    });
    final detail = ref.watch(vodSeasonDetailProvider(widget.seasonId));
    final season = detail.value;
    if (season != null && !_autoOpened && season.episodes.isNotEmpty) {
      _autoOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openEpisode(season.episodes.first));
      });
    }
    final Widget body;
    if (season == null && detail.hasError) {
      body = Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.cloudOff),
          title: Text(t.vod.loadFailed),
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
      body = const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)));
    } else if (immersive) {
      body = _player(immersive: true);
    } else {
      body = _page(season);
    }
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
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
        const SingleActivator(LogicalKeyboardKey.escape): () {
          final handle = _handle;
          if (_immersive && handle != null) {
            unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
          } else {
            context.pop();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: immersive ? colors.canvas : colors.surface,
          appBar: immersive
              ? null
              : AppBar(
                  backgroundColor: colors.surface,
                  surfaceTintColor: const Color(0x00000000),
                  elevation: 0,
                  title: Text(season?.title ?? t.vod.opening, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
          body: body,
        ),
      ),
    );
  }

  Widget _page(VodSeasonDetail detail) {
    final window = MediaQuery.sizeOf(context).width;
    final inset = LiveWindow.pageInset(window);
    final showDetails = ref.watch(vodPlaybackSettingsProvider).showDetails;
    final episode = _episode;
    final episodes = detail.episodes;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s16,
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
              ),
              const DsDivider(),
              if (episodes.isNotEmpty)
                _EpisodesSection(
                  episodes: episodes,
                  current: episode,
                  onOpen: (candidate) => unawaited(_openEpisode(candidate)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Puts a picture on: the episode already on the player resumes, and before
  /// one has opened, the season's first does — the head's 立即播放 verb.
  void _playNow() {
    final handle = _handle;
    if (handle != null) {
      unawaited(handle.play());
      return;
    }
    final episodes = ref.read(vodSeasonDetailProvider(widget.seasonId)).value?.episodes ?? const <VodEpisode>[];
    if (episodes.isEmpty) return;
    unawaited(_openEpisode(episodes.first));
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
  Widget _player({required bool immersive}) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final handle = _handle;
    final transport = _transport;
    final episode = _episode;
    final duration = transport?.duration ?? episode?.duration ?? Duration.zero;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    final playing = transport?.isPlaying ?? false;
    // The bar follows the pointer: a tap on the picture puts it away while the
    // episode plays, and a stopped one keeps it, because a paused picture has nothing
    // else to read.
    final showBar = _controlsVisible || !playing;
    final qualities = _play?.qualities ?? const <VodQuality>[];
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive ? 0 : theme.radii.overlay),
      child: ColoredBox(
        color: colors.overlay,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (handle != null)
                MediaPlayerView(handle: handle, backgroundColor: colors.overlay)
              else
                const ColoredBox(color: Color(0xFF000000)),
              // The pointer's vocabulary over the picture: a tap raises or puts
              // away the bar, a drag along it scrubs, a drag down it takes the
              // sound or the screen's brightness, a double tap on either side steps
              // ten seconds and on the middle plays or pauses, and a hold runs the
              // episode faster until the finger lifts. The same shapes the archive
              // page answers with, from the same widget.
              VodPictureGestures(
                enabled: handle != null,
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
              if (_opening || (transport?.isBuffering ?? false))
                const Center(child: DsSpinner(style: DsSpinnerStyle(size: 40))),
              if (immersive)
                PositionedDirectional(
                  top: DsSpace.s8,
                  start: DsSpace.s8,
                  child: DsButton.icon(
                    variant: DsButtonVariant.ghost,
                    size: DsSize.sm,
                    semanticLabel: t.vod.exitFullscreen,
                    onPressed: _toggleFullscreen,
                    icon: const DsIcon(DsIcons.minimize2),
                  ),
                ),
              if (_silent)
                PositionedDirectional(
                  top: DsSpace.s8,
                  end: DsSpace.s8,
                  child: DsBadge(label: Text(t.vod.pictureOnly), icon: const DsIcon(DsIcons.volumeOff)),
                ),
              // The bar away, the picture keeps one line at its foot: how far
              // the episode ran, and the strip that brings the bar back.
              if (!showBar && playing && handle != null)
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
              if (showBar)
                PositionedDirectional(
                  bottom: 0,
                  start: 0,
                  end: 0,
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s24, DsSpace.s8, DsSpace.s4),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.bottomCenter,
                        end: AlignmentDirectional.topCenter,
                        colors: [Color(0xD9000000), Color(0x00000000)],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: DsSpace.s4,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The step to the next episode is announced and counted,
                        // so a viewer who is not done with this one can stop it.
                        if (_countdown > 0)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: VodPictureNotice(
                              icon: DsIcons.listVideo,
                              text: t.vod.nextPartIn(seconds: _countdown),
                              actionLabel: t.common.cancel,
                              onAction: _cancelCountdown,
                            ),
                          ),
                        if (vodDownloadOf(ref.watch(vodDownloadsProvider), 'ep${episode?.id ?? 0}', episode?.cid ?? 0)
                            case final download?
                            when download.phase == VodDownloadPhase.running ||
                                download.phase == VodDownloadPhase.queued)
                          Row(
                            spacing: DsSpace.s8,
                            children: [
                              const DsSpinner(style: DsSpinnerStyle(size: 12)),
                              Expanded(
                                child: Text(
                                  switch (download.progress) {
                                    final progress? => t.vod.downloading(percent: (progress * 100).round()),
                                    null => t.vod.downloadingUnknown,
                                  },
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                                ),
                              ),
                              DsButton.icon(
                                variant: DsButtonVariant.ghost,
                                size: DsSize.sm,
                                semanticLabel: t.vod.downloadPause,
                                onPressed: () => unawaited(ref.read(vodDownloadsProvider.notifier).pause(download.id)),
                                icon: const DsIcon(DsIcons.pause),
                              ),
                            ],
                          ),
                        Row(
                          spacing: DsSpace.s8,
                          children: [
                            SizedBox(
                              width: 54,
                              child: Text(
                                vodDurationText(position),
                                textAlign: TextAlign.center,
                                style: theme.typography.numeric(
                                  theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                                ),
                              ),
                            ),
                            Expanded(
                              // The same three claims the archive's line makes:
                              // watched, held, and — under the pointer — where
                              // the episode would go.
                              child: VodSeekBar(
                                position: position,
                                duration: duration,
                                semanticLabel: t.vod.progress,
                                buffered: _transport?.buffer.ranges ?? const [],
                                coverUrl: ref.read(vodSeasonDetailProvider(widget.seasonId)).value?.coverUrl,
                                showPreview: ref.watch(vodPlaybackSettingsProvider).seekPreview,
                                onScrub: (seconds) => setState(() => _dragSeconds = seconds),
                                onSeek: (seconds) {
                                  setState(() => _dragSeconds = null);
                                  unawaited(_seekTo(seconds));
                                },
                              ),
                            ),
                            SizedBox(
                              width: 54,
                              child: Text(
                                vodDurationText(duration),
                                textAlign: TextAlign.center,
                                style: theme.typography.numeric(
                                  theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          spacing: DsSpace.s8,
                          children: [
                            // The steps between episodes, beside play: a season is
                            // watched in both directions, and the shelf under the
                            // picture keeps the jump to any one of them.
                            if (_hasPreviousEpisode)
                              DsButton.icon(
                                variant: DsButtonVariant.ghost,
                                size: DsSize.sm,
                                semanticLabel: t.vod.previousPart,
                                onPressed: () {
                                  _wake();
                                  _openSteppedEpisode(-1);
                                },
                                icon: const DsIcon(DsIcons.skipBack),
                              ),
                            if (_hasNextEpisode)
                              DsButton.icon(
                                variant: DsButtonVariant.ghost,
                                size: DsSize.sm,
                                semanticLabel: t.vod.nextPart,
                                onPressed: () {
                                  _wake();
                                  _openSteppedEpisode(1);
                                },
                                icon: const DsIcon(DsIcons.skipForward),
                              ),
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              semanticLabel: playing ? t.vod.pause : t.vod.play,
                              onPressed: handle == null ? null : _togglePlay,
                              icon: DsIcon(playing ? DsIcons.pause : DsIcons.play),
                            ),
                            if (qualities.isNotEmpty)
                              DsMenuAnchor(
                                semanticLabel: _qualityMenuLabel(t),
                                builder: (context, controller, child) => DsButton.icon(
                                  variant: DsButtonVariant.ghost,
                                  size: DsSize.sm,
                                  semanticLabel: _qualityMenuLabel(t),
                                  onPressed: controller.open,
                                  icon: const DsIcon(DsIcons.settings2),
                                ),
                                items: [
                                  for (final quality in qualities)
                                    DsMenuItem(
                                      label: Text(quality.label),
                                      checked: quality.qn == _openedQn,
                                      onPressed: () {
                                        final current = _episode;
                                        if (current != null) unawaited(_openEpisode(current, qn: quality.qn));
                                      },
                                    ),
                                ],
                              ),
                            DsButton.icon(
                              variant: DsButtonVariant.ghost,
                              size: DsSize.sm,
                              semanticLabel: t.vod.download,
                              onPressed: (episode?.cid ?? 0) <= 0 ? null : () => unawaited(_startDownload()),
                              icon: const DsIcon(DsIcons.download),
                            ),
                            if (!immersive)
                              DsButton.icon(
                                variant: DsButtonVariant.ghost,
                                size: DsSize.sm,
                                semanticLabel: t.vod.fullscreen,
                                onPressed: handle == null ? null : _toggleFullscreen,
                                icon: const DsIcon(DsIcons.maximize2),
                              ),
                            if (_error != null)
                              Expanded(
                                child: Text(
                                  _error!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.typography.caption.copyWith(color: theme.colors.danger.text),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: DsSpace.s16,
      children: [
        SizedBox(
          width: posterWidth,
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
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(decoration: BoxDecoration(gradient: kRoomCoverScrim)),
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
                      style: theme.typography.heading.copyWith(fontWeight: FontWeight.w600, color: colors.text),
                    ),
                  ),
                  if (season.followed) DsBadge(label: Text(t.vod.following), dot: false),
                ],
              ),
              if (chips.isNotEmpty)
                Wrap(
                  spacing: DsSpace.s6,
                  runSpacing: DsSpace.s6,
                  children: [
                    for (final chip in chips)
                      if (chip.score)
                        _scoreBadge(context, '${t.vod.score} ${chip.text}')
                      else
                        DsBadge(label: Text(chip.text), dot: false),
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
                  DsButton(
                    variant: DsButtonVariant.primary,
                    size: DsSize.sm,
                    leading: const DsIcon(DsIcons.play, size: 14),
                    onPressed: canPlay ? onPlay : null,
                    child: Text(t.vod.playNow),
                  ),
                  DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    leading: const DsIcon(DsIcons.download, size: 14),
                    onPressed: canDownload ? onDownload : null,
                    child: Text(t.vod.download),
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
              if (showDetails && season.evaluate.isNotEmpty) _SeasonBlurb(text: season.evaluate),
            ],
          ),
        ),
      ],
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

/// The season's blurb, folded to two lines until the viewer asks for the
/// rest — the mockup's 简介 rule, measured the same way the video page's
/// fold is, so it only offers the verb when the words really run past.
final class _SeasonBlurb extends StatefulWidget {
  const _SeasonBlurb({required this.text});

  final String text;

  @override
  State<_SeasonBlurb> createState() => _SeasonBlurbState();
}

final class _SeasonBlurbState extends State<_SeasonBlurb> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final style = DsTheme.of(context).typography.body.copyWith(color: colors.textMuted);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 2,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        if (!overflows) return Text(widget.text, style: style);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DsSpace.s4,
          children: [
            Text(
              widget.text,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: style,
            ),
            DsButton(
              variant: DsButtonVariant.ghost,
              size: DsSize.sm,
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? t.vod.collapse : t.vod.expand),
            ),
          ],
        );
      },
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
const double kVodEpisodeInfoExtent = 30;

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
    final controller = TextEditingController();
    int? parse() {
      final typed = int.tryParse(controller.text.trim());
      if (typed == null) return null;
      final byIndex = episodes.where((episode) => int.tryParse(episode.index) == typed);
      if (byIndex.isNotEmpty) return episodes.indexOf(byIndex.first);
      return typed >= 1 && typed <= episodes.length ? typed - 1 : null;
    }

    final position = await showDsDialog<int>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.t;
        return DsDialog(
          title: Text(t.vod.episodesJump),
          description: DsTextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            placeholder: '1–${episodes.length}',
            onSubmitted: (_) => Navigator.of(dialogContext).pop(parse()),
          ),
          actions: [
            DsButton(
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(t.common.cancel),
            ),
            DsButton(onPressed: () => Navigator.of(dialogContext).pop(parse()), child: Text(t.common.confirm)),
          ],
        );
      },
    );
    controller.dispose();
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
    final muted = theme.typography.caption.copyWith(color: colors.textMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(
                '${t.vod.episodes} · ${episodes.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
            ),
            if (groups > 1) ...[
              Text('$first–$last / ${episodes.length}', style: muted),
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
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                leading: const DsIcon(DsIcons.listOrdered, size: 16),
                onPressed: () => unawaited(_jump()),
                child: Text(t.vod.episodesJump),
              ),
            ],
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
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              candidate.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.caption.copyWith(
                                color: playing ? colors.accent : colors.text,
                                fontWeight: playing ? FontWeight.w600 : null,
                              ),
                            ),
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
