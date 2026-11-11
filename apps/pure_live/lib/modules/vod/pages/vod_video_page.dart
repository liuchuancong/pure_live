import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:math' as math;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart' show BarrageController, EmojiAtlas, FlameBarrageWidget;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart' show FilteringTextInputFormatter, LogicalKeyboardKey, TextInputType;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_cache/live_cache.dart' show ImageCachePolicies;
import 'package:live_device/live_device.dart'
    show
        PlatformScreenAwakeService,
        PlatformScreenBrightnessService,
        PlatformScreenOrientationService,
        ScreenAwakeService,
        ScreenBrightnessScope,
        ScreenBrightnessService,
        ScreenOrientationService;
import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart' show BarrageItemMapper, DanmakuPlayerBinding;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_app_login.dart' show vodAppClientProvider;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_downloads.dart';
import 'package:pure_live/modules/vod/controller/vod_library.dart';
import 'package:pure_live/modules/vod/controller/vod_playback_settings.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show vodQualityProvider;
import 'package:pure_live/modules/vod/controller/vod_social.dart' show VodCommentsController, vodCommentsProvider;
import 'package:pure_live/modules/vod/widgets/vod_media_source.dart'
    show vodDashSourceOf, vodDashVideoOf, vodQualityLabel;
import 'package:pure_live/modules/vod/widgets/vod_picture_gestures.dart' show VodPictureGestures, VodTapSide;
import 'package:pure_live/modules/vod/widgets/vod_player_chrome.dart'
    show VodGestureKind, VodGestureTip, VodPictureNotice, VodSeekBar, VodSubtitleLayer;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodVideoRow, vodDateText, vodDurationText;
import 'package:pure_live/shared/shared.dart';

/// One Bilibili archive's page: the player over media_core, the archive's
/// metadata, its parts, and related archives — Bilibili's own video page,
/// reduced to what the station's sources provide.
///
/// Playback is one shared media_core handle: progressive mp4 when the source
/// serves it (picture and sound together), or the source's first DASH video
/// rendition with an honest "picture only" notice when it does not. Progress
/// is saved per bvid (part + seconds) so a return resumes where it stopped.
final class VodVideoPage extends ConsumerStatefulWidget {
  /// The archive behind [bvid].
  const VodVideoPage({required this.bvid, super.key});

  /// The archive's bvid.
  final String bvid;

  @override
  ConsumerState<VodVideoPage> createState() => _VodVideoPageState();
}

final LiveLog vodLog = appLog.forCategory('vod.play');

final class _VodVideoPageState extends ConsumerState<VodVideoPage> with RouteAware, WidgetsBindingObserver {
  /// The tier a part opens with before the station's own preference is read
  /// in `initState`. This is a choice about what plays; the number the source
  /// is asked with is the whole ladder, and lives with it.
  static const int _defaultQn = 64;

  VodDetail? _detail;

  /// The related archives read so far and the window of twenty the rail
  /// shows; 换一换 walks the rest and folds in what a fresh read adds.
  List<VodVideo> _relatedPool = const [];
  int _relatedStart = 0;
  bool _relatedBusy = false;
  VodPlayInfo? _play;
  VodPart? _part;

  /// The flying danmaku engine this page owns, the bridge that keeps its
  /// clock on the part's own, and the cid the loaded timeline belongs to.
  final BarrageController _barrage = BarrageController();
  DanmakuPlayerBinding? _danmakuBinding;
  int _danmakuCid = 0;
  int _qn = _defaultQn;

  /// The definition actually opened, which the source may answer below what
  /// was asked: the ladder the account is entitled to is the ceiling, and a
  /// bar that named the request rather than the answer would be selling a
  /// picture nobody is watching.
  int _openedQn = _defaultQn;
  String? _openedLabel;
  PlayerHandle? _handle;
  PlayerId? _boundPlayer;
  final FocusNode _playFocus = FocusNode(debugLabel: 'vod-play');
  StreamSubscription<PlayerTransportState>? _transportSub;
  StreamSubscription<PlayerAdapterEvent>? _eventSub;
  StreamSubscription<GeometryState>? _geometrySub;
  PlayerTransportState? _transport;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _gaveInitialFocus = false;
  bool _loading = true;
  bool _opening = false;
  bool _silent = false;
  bool _disposed = false;
  String? _error;
  double? _dragSeconds;
  double? _resumeSeconds;
  bool _muted = false;
  bool _globalMute = false;
  double _volume = 1;
  double _speed = 1;

  /// The volume a drag on the picture started from, so the gesture moves from
  /// where the sound stands rather than from the frame before it.
  double _dragVolume = 1;

  /// The line the subtitle track is on right now; null leaves the picture
  /// alone. It is read with the transport rather than in the build, so the
  /// words never arrive a frame late.
  String? _subtitleText;

  /// The figure the picture's gesture is answering with, and where it stands;
  /// a seek says a time, a drag says a percentage, a hold says a rate.
  VodGestureKind? _gestureKind;
  String? _gestureValue;
  String? _gestureNote;
  Timer? _gestureTimer;

  /// The screen's brightness, which the left half of the picture adjusts where
  /// the display will take the write and the right half alone is the volume
  /// where it will not — the room's rule, so one gesture reads the same on
  /// both players.
  final ScreenBrightnessService _screenBrightness = const PlatformScreenBrightnessService();
  bool? _brightnessWritable;
  ScreenBrightnessScope _brightnessScope = ScreenBrightnessScope.application;
  double _brightness = 100;
  double _dragBrightness = 100;
  bool _dragIsBrightness = false;

  /// Whether a hold has the picture running faster right now, and the rate it
  /// goes back to when the finger lifts.
  bool _speedHeld = false;
  double _speedBeforeHold = 1;

  /// The keyboard's seek step, which grows while the key keeps being held:
  /// five seconds once, then ten, then twenty, so a long skip is one key.
  double _seekStep = 5;
  DateTime? _lastSeekKey;

  /// The horizontal drag on the picture: where it started from, how far it
  /// has walked, and where that stands, so the release seeks once rather than
  /// on every frame of the drag.
  Duration? _scrubFrom;
  double _scrubWalked = 0;
  double? _scrubSeconds;

  /// How far the subtitle line stands off the picture's bottom edge while the
  /// bar is up: the bar's own height, so the two never sit on each other.
  static const double _subtitleInset = 72;

  /// What a double tap on either side of the picture steps over.
  static const double _doubleTapStep = 10;

  /// The archive's own opening and ending, in seconds: where the opening stops
  /// and where the ending starts. They belong to the archive and to this
  /// device, and the station does not supply them for a posted video.
  double? _headSeconds;
  double? _tailSeconds;

  /// The player's extras for the part: its marked moments, its subtitle tracks
  /// and, where the station sends one, its scrub filmstrip.
  VodPlayerExtra _extra = const VodPlayerExtra();

  /// The subtitle track the viewer chose and the lines it came with; the index
  /// walks forward while the picture plays rather than searching every frame.
  VodSubtitleTrack? _subtitleTrack;
  List<VodSubtitleLine> _subtitleLines = const [];
  int _subtitleCursor = 0;

  /// The countdown a finished part runs before the next one opens, so the step
  /// forward can be stopped; zero means nothing is counting.
  int _countdown = 0;
  Timer? _countdownTimer;

  /// The position the page jumped back to on opening, offered a way to undo it
  /// for as long as the notice stands.
  double? _resumedAt;
  Timer? _resumedTimer;

  /// Sound only: the part keeps playing and the picture is put away — the way
  /// to keep listening to a 广播剧-style episode at a desk.
  bool _audioOnly = false;

  /// Whether the overlay bars are up; a playing stream lets them settle away.
  bool _controlsVisible = true;

  /// The display's wake lock: held while a part plays and the app's own
  /// 屏幕常亮 allows it, the same rule the live room and the IPTV page keep.
  final ScreenAwakeService _screenAwake = const PlatformScreenAwakeService();
  bool _screenHeld = false;

  /// Whether the blurb shows in full rather than its first six lines.
  bool _introExpanded = false;
  Timer? _hideTimer;

  /// The picker whose catalogue hangs over the picture, if any.
  _VodPanel? _openPanel;
  Timer? _hoverTimer;
  Timer? _leaveTimer;

  /// The bar and each picker's box: the open catalogue hangs over the button
  /// that raised it rather than at the picture's end edge.
  final GlobalKey _barAnchor = GlobalKey(debugLabel: 'vod-bar');
  final Map<_VodPanel, GlobalKey> _panelAnchors = {
    for (final panel in _VodPanel.values) panel: GlobalKey(debugLabel: 'vod-picker-${panel.name}'),
  };

  /// The playing part's row in the parts catalogue, so opening the catalogue
  /// brings it into view instead of starting at the first.
  final GlobalKey _currentPartKey = GlobalKey();

  /// Whether the end of the current part has already been acted on, so the
  /// station's finish action runs once per part.
  bool _finished = false;

  /// The Android background-playback gate and the handle it paused.
  BackgroundPlaybackGate? _backgroundGate;
  PlayerId? _backgroundPausedHandle;

  /// The picture's aspect as the engine last reported it: the fullscreen
  /// orientation policy reads it to decide which way a phone turns.
  double _aspectRatio = 0;

  /// The phone's orientation lock (inert on a desktop).
  final ScreenOrientationService _screenOrientation = const PlatformScreenOrientationService();

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

  bool get _effectivelyMuted => _muted || _globalMute;

  @override
  void initState() {
    super.initState();
    _presentationNotifier = ref.read(roomPresentationProvider.notifier);
    _kernel = ref.read(playerKernelProvider);
    ref.listenManual(roomPresentationProvider, (_, next) => _presentationMode = next, fireImmediately: true);
    WidgetsBinding.instance.addObserver(this);
    _globalMute = ref.read(playbackSettingsProvider).globalMute;
    _volume = ref.read(playbackSettingsProvider.notifier).volume;
    _backgroundGate = BackgroundPlaybackGate(
      backgroundEnabled: () => ref.read(playbackSettingsProvider).backgroundPlay,
      shouldPause: () {
        final presentation = ref.read(roomPresentationProvider);
        return (_transport?.isPlaying ?? false) &&
            presentation != PresentationMode.pip &&
            presentation != PresentationMode.floating;
      },
      pause: () async {
        _backgroundPausedHandle = _handle?.id;
        await _handle?.pause();
      },
      canResume: () =>
          _backgroundPausedHandle != null &&
          _handle != null &&
          _handle?.id == _backgroundPausedHandle &&
          !(_transport?.isPlaying ?? false),
      resume: () async {
        _backgroundPausedHandle = null;
        await _handle?.play();
      },
    );
    // The station's setting names the rendition the first part asks for;
    // the source may still answer lower, and the menu follows what it
    // actually served.
    _qn = ref.read(vodQualityProvider).qn;
    // The station's playback choices: the rate a video opens with and what
    // a finished part leads to.
    _speed = ref.read(vodPlaybackSettingsProvider).speed.value;
    _readSkipPoints();
    unawaited(_syncBrightness());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load());
    });
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgroundGate?.handleLifecycle(state);
  }

  /// Another page covers this one (a related archive, a menu route): the
  /// picture pauses rather than playing under it.
  @override
  void didPushNext() {
    final handle = _handle;
    if (handle != null && (_transport?.isPlaying ?? false)) {
      unawaited(handle.pause().catchError((Object _) {}));
    }
  }

  /// Holds the display awake exactly while the part plays and the preference
  /// allows it.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_screenAwake.disable().catchError((Object _) {}));
    // The player goes quiet before anything else: the route's leave animation
    // runs while the release's queue drains, and the video must not be heard
    // over the page the viewer returned to.
    final handle = _handle;
    if (handle != null) {
      if (_presentationMode != PresentationMode.normal) {
        unawaited(_presentationNotifier.exit(handle.id));
      }
      silencePlayer(handle);
      unawaited(_kernel.release(handle.id));
    }
    _hideTimer?.cancel();
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    _gestureTimer?.cancel();
    _countdownTimer?.cancel();
    _resumedTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _backgroundGate?.dispose();
    _backgroundGate = null;
    _routeObserver?.unsubscribe(this);
    _saveProgress(force: true);
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _geometrySub = null;
    unawaited(_danmakuBinding?.dispose() ?? Future<void>.value());
    _danmakuBinding = null;
    _barrage.dispose();
    _playFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _play = null;
      _silent = false;
      _transport = null;
      _resumeSeconds = null;
    });
    final client = ref.read(vodClientProvider);
    final appClient = ref.read(vodAppClientProvider);
    try {
      // The chosen interface's detail: the app's view service when it is in
      // force, the web record otherwise; an app refusal falls back.
      VodDetail detail;
      if (ref.read(vodPlaybackSettingsProvider).apiType == VodApiType.app && appClient != null) {
        try {
          detail = await appClient.detail(bvid: widget.bvid);
        } on Object catch (error) {
          // The app service refusing a detail is routine (an unlogged session,
          // a gRPC tier the web still serves): say which door answered.
          vodLog.info('detail fell back to the web api', fields: {'bvid': widget.bvid, 'error': '$error'});
          detail = await client.detail(widget.bvid);
        }
      } else {
        detail = await client.detail(widget.bvid);
      }
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      unawaited(_loadRelated(client));
      if (detail.parts.isEmpty) {
        vodLog.warning('the archive carries no part', fields: {'bvid': widget.bvid});
        setState(() => _error = context.t.vod.openFailed);
        return;
      }
      final saved = _readProgress();
      final part = saved == null
          ? detail.parts.first
          : detail.parts.where((candidate) => candidate.cid == saved.cid).firstOrNull ?? detail.parts.first;
      _resumeSeconds = saved != null && saved.cid == part.cid ? saved.seconds : null;
      await _openPart(part);
    } on Object catch (error) {
      vodLog.warning(
        'detail load failed',
        fields: {'bvid': widget.bvid, 'error': error is VodFailure ? error.message : '$error'},
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is VodFailure ? error.message : '$error';
      });
    }
  }

  Future<void> _loadRelated(BilibiliVodClient client) async {
    try {
      final related = await client.related(widget.bvid);
      if (!mounted) return;
      // Bilibili offers up to forty; the rail shows twenty at a time and
      // 换一换 walks the rest.
      setState(() {
        _relatedPool = related;
        _relatedStart = 0;
      });
    } on Object {
      // Related videos are a bonus; the page stands without them.
    }
  }

  /// The rail's current twenty, wrapping through the pool it holds.
  List<VodVideo> get _relatedWindow {
    final pool = _relatedPool;
    if (pool.isEmpty) return const [];
    final count = pool.length < 20 ? pool.length : 20;
    final start = _relatedStart % pool.length;
    return [for (var index = 0; index < count; index++) pool[(start + index) % pool.length]];
  }

  /// Swaps the rail's twenty for the next ones: a fresh read folds in what
  /// the source newly offers, then the window moves on. A refused read still
  /// turns the page it already has.
  Future<void> _changeRelated() async {
    if (_relatedBusy || _relatedPool.length <= 20) return;
    setState(() => _relatedBusy = true);
    var pool = _relatedPool;
    try {
      final fresh = await ref.read(vodClientProvider).related(widget.bvid);
      final seen = {for (final video in pool) video.bvid ?? video.id};
      pool = [...pool, ...fresh.where((video) => seen.add(video.bvid ?? video.id))];
    } on Object {
      // Keep the pool as it was.
    }
    if (!mounted) return;
    setState(() {
      _relatedPool = pool;
      _relatedStart = (_relatedStart + 20) % pool.length;
      _relatedBusy = false;
    });
  }

  /// Opens [part] on the shared kernel, reusing the page's handle.
  Future<void> _openPart(VodPart part, {int? qn, double? resume}) async {
    if (_opening) return;
    // Keep the part being left before the page starts writing for the next
    // one; a stored position belongs to the part that reported it.
    _saveProgress(force: true);
    // The part being left loses its timeline; the next one loads its own.
    _barrage.clear();
    _danmakuCid = 0;
    // The next part has its own subtitle list, its own marked moments and its
    // own held position, so none of this part's carries over.
    _subtitleTrack = null;
    _subtitleLines = const [];
    _subtitleText = null;
    _subtitleCursor = 0;
    _resetScrub();
    _cancelCountdown();
    setState(() {
      _opening = true;
      _error = null;
      _part = part;
      _play = null;
      _silent = false;
      _transport = null;
      _dragSeconds = null;
      _finished = false;
    });
    final client = ref.read(vodClientProvider);
    final kernel = ref.read(playerKernelProvider);
    // The source being left stops before the next address is fetched, so a
    // failed switch cannot leave it sounding under the new part's page.
    final previous = _handle;
    if (previous != null) {
      try {
        await previous.pause();
      } on Object {
        // The switch itself reports a player that will not answer.
      }
    }
    try {
      // The interface the station asks: the app's gRPC channel when the
      // viewer chose it and signed in, the web REST answer otherwise. An app
      // refusal falls back to the web request rather than failing the part.
      final appClient = ref.read(vodAppClientProvider);
      final aid = _detail?.aid ?? 0;
      VodPlayInfo info;
      // The tier the viewer asked for this part: the ladder ask is the
      // source's business (it names the whole ladder so the menu can list
      // what the account is entitled to), and this number chooses which
      // rendition of that ladder is opened.
      final want = qn ?? _qn;
      _qn = want;
      if (ref.read(vodPlaybackSettingsProvider).apiType == VodApiType.app && appClient != null && aid > 0) {
        try {
          info = await appClient.playUgc(aid: aid, cid: part.cid);
        } on Object {
          info = await client.playPart(bvid: widget.bvid, cid: part.cid);
        }
      } else {
        info = await client.playPart(bvid: widget.bvid, cid: part.cid);
      }
      if (!mounted || _disposed) return;
      final existing = _handle;
      final handle =
          existing ??
          await kernel.create(
            config: const PlayerConfig(name: 'vod'),
            preferredBackend: ref.read(playerKernelBackendProvider).id,
          );
      if (!mounted || _disposed) {
        if (existing == null) {
          silencePlayer(handle);
          unawaited(kernel.release(handle.id));
        }
        return;
      }
      _handle = handle;
      _bind(handle);
      await _applyEngineOptions(handle);
      // What plays, and what the bar therefore says plays: the rendition at or
      // below the viewer's tier that this engine can be handed, named by the
      // answer's own list rather than by a table of ours.
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
          // This engine joins one URL only: ask for the muxed answer, whose
          // definition is lower but whose sound is already inside it.
          info = await client.playPart(bvid: widget.bvid, cid: part.cid, dash: false);
          if (!mounted || _disposed) return;
          _openedQn = info.servedQuality ?? _openedQn;
          _openedLabel = info.quality;
          await handle.open(_partSource(info, part), autoPlay: true);
        }
      } else {
        await handle.open(_partSource(info, part), autoPlay: true);
      }
      await handle.setVolume(_volume);
      await handle.setMute(muted: _effectivelyMuted);
      await handle.setRate(_speed);
      if (_audioOnly) await _applyAudioOnly(handle);
      final saved = resume ?? _resumeSeconds;
      _resumeSeconds = null;
      // A saved position outranks the opening; a part watched for the first
      // time starts after it, when the viewer asked the player to step over.
      final opening = ref.read(vodPlaybackSettingsProvider).skipHeadTail ? _headSeconds : null;
      final seekTo = saved != null && saved > 5 ? saved : opening;
      if (seekTo != null && seekTo > 5) {
        await handle.seek(Duration(milliseconds: (seekTo * 1000).round()));
        if (saved != null && saved > 5) _noteResumed(saved);
      }
      unawaited(_loadDanmaku(part.cid));
      unawaited(_loadExtra(part.cid));
      if (!mounted || _disposed) return;
      setState(() {
        _play = info;
        _silent = info.silent;
        _opening = false;
      });
      _giveInitialFocus();
    } on Object catch (error) {
      if (!mounted || _disposed) return;
      // The handle may still hold the previous part; it is not the part
      // this page now names, so it goes rather than playing on behind a
      // failed switch. Retry creates a fresh one.
      final stale = _handle;
      if (stale != null) {
        _handle = null;
        silencePlayer(stale);
        unawaited(kernel.release(stale.id));
      }
      setState(() {
        _opening = false;
        _transport = null;
        _error = error is VodFailure ? error.message : '$error';
      });
    }
  }

  /// The flat source of a muxed answer: the shape a single-URL engine opens,
  /// and the fallback when the DASH pair is unsupported.
  PlayerSource _partSource(VodPlayInfo info, VodPart part) {
    final uri = Uri.parse(info.url);
    return PlayerSource.of(
      id: SourceId('vod:${widget.bvid}:${part.cid}:${DateTime.now().microsecondsSinceEpoch}'),
      uri: uri,
      type: SourceType.remote,
      protocol: SourceProtocol.fromScheme(uri.scheme),
      format: SourceFormat.fromUri(uri),
      headers: info.headers.isEmpty ? null : SourceHeaders(info.headers),
      title: _detail?.title ?? part.title,
    );
  }

  void _bind(PlayerHandle handle) {
    if (_boundPlayer == handle.id) return;
    _boundPlayer = handle.id;
    // A handle released after a failed switch is replaced rather than
    // reused; the new handle gets its own subscriptions.
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _geometrySub = handle.geometryController.state.listen((state) {
      if (!mounted) return;
      final size = state.geometry.videoSize;
      if (size.width <= 0 || size.height <= 0) return;
      _aspectRatio = size.width / size.height;
      // The fullscreen and compact-window drivers shape their surfaces from
      // the picture's size. VOD used to feed them nothing, so the compact
      // window kept the config's 16:9 and never locked to the video.
      ref.read(fullscreenDriverProvider).onVideoSize(size.width, size.height);
      ref.read(pipDriverProvider).onVideoSize(size.width, size.height);
    });
    _transportSub = handle.playbackStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _transport = state;
        // A recovered engine keeps playing; the notice belongs to the
        // failure that stopped it, not to a session that healed.
        if (state.isPlaying) _error = null;
      });
      _syncSubtitle(state.position);
      _watchTail();
      if (state.isPlaying) _scheduleHide();
      _saveProgress();
    });
    _eventSub = handle.adapterEvents.listen((event) {
      if (!mounted) return;
      switch (event) {
        case final PlayerAdapterErrorEvent error:
          setState(() {
            _opening = false;
            _error = error.message;
          });
        case PlayerAdapterCompleted():
          unawaited(_handleFinished());
        default:
          break;
      }
    });
    // The engine's clock follows the new handle: play, pause, seek and rate
    // all reach the timeline through this one binding.
    unawaited(_danmakuBinding?.detach() ?? Future<void>.value());
    _danmakuBinding = DanmakuPlayerBinding.forHandle(controller: _barrage, handle: handle)..attach();
  }

  /// Reads [cid]'s danmaku track and puts it on the engine's timeline; a part
  /// with no readable track plays without one.
  Future<void> _loadDanmaku(int cid) async {
    if (cid <= 0) return;
    try {
      // Danmaku reads the web protobuf/XML track in both interfaces — the
      // reference's own App path does the same; only the detail and the
      // playback ladder switch.
      final xml = await ref.read(vodClientProvider).danmakuXml(cid);
      if (!mounted || _disposed || _part?.cid != cid) return;
      final entries = BilibiliDanmakuXml.decode(xml);
      final items = [for (final entry in entries) BarrageItemMapper.toItem(entry.toMessage(), at: entry.time)];
      _barrage
        ..clear()
        ..loadTimeline(items)
        ..seekTo(_transport?.position ?? Duration.zero);
      _danmakuCid = cid;
    } on Object {
      // The picture never depends on a comment track.
    }
  }

  /// What a part's end leads to — the reference's 播放结束动作. The engine
  /// already sits on the last frame, so leaving it alone is the "pause"
  /// choice; the others move the page.
  Future<void> _handleFinished() async {
    if (_finished) return;
    _finished = true;
    switch (ref.read(vodPlaybackSettingsProvider).finish) {
      case VodFinishAction.pause:
        break;
      case VodFinishAction.nextPart:
        final parts = _detail?.parts ?? const <VodPart>[];
        final current = _part;
        final index = parts.indexWhere((part) => part.cid == current?.cid);
        // The step forward is announced and counted, so a viewer who wants
        // this part again — or is not done with the last frame — can stop it.
        if (index >= 0 && index + 1 < parts.length) _startCountdown(parts[index + 1]);
      case VodFinishAction.exit:
        if (mounted) context.pop();
      case VodFinishAction.playRelated:
        final next = _relatedPool.isEmpty ? null : _relatedPool.first;
        if (next == null) return;
        final bvid = next.bvid ?? next.id;
        if (bvid.isEmpty) return;
        unawaited(context.push('/vod/$bvid'));
    }
  }

  /// The part [direction] steps from the one playing, or null at either end of
  /// the list. A serial is watched in both directions — back to the part whose
  /// point was quoted, forward to the next — so the bar's two chips are one
  /// question asked twice.
  VodPart? _partStepped(int direction) {
    final parts = _detail?.parts ?? const <VodPart>[];
    final index = parts.indexWhere((part) => part.cid == _part?.cid) + direction;
    if (index < 0 || index >= parts.length) return null;
    return parts[index];
  }

  /// Whether the step exists, which is all a chip needs to know before it
  /// names it.
  bool get _hasNextPart => _partStepped(1) != null;

  bool get _hasPreviousPart => _partStepped(-1) != null;

  /// Opens the part one step away — the chip's step, the sequential twin of
  /// the shelf's jump and of the finish action's own next part.
  void _openSteppedPart(int direction) {
    final target = _partStepped(direction);
    if (target == null) return;
    unawaited(_openPart(target, resume: _resumeFor(target)));
  }

  Future<void> _togglePlay() async {
    final handle = _handle;
    if (handle == null) return;
    final playing = _transport?.isPlaying ?? false;
    try {
      playing ? await handle.pause() : await handle.play();
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _seekTo(double seconds) async {
    final handle = _handle;
    if (handle == null) return;
    try {
      await handle.seek(Duration(milliseconds: (seconds * 1000).round()));
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _setMuted({required bool muted}) async {
    final handle = _handle;
    if (!muted && _globalMute) {
      // The global mute overrides this page's own choice; using the unmute
      // button clears it rather than silently doing nothing.
      _globalMute = false;
      unawaited(ref.read(playbackSettingsProvider.notifier).setGlobalMute(value: false));
    }
    if (mounted) setState(() => _muted = muted);
    if (handle == null) return;
    try {
      await handle.setMute(muted: _effectivelyMuted);
    } on Object catch (_) {
      // A refused mute is not a playback failure.
    }
  }

  Future<void> _applyGlobalMute() async {
    final handle = _handle;
    if (handle == null) return;
    try {
      await handle.setMute(muted: _effectivelyMuted);
    } on Object {
      // A refused mute is not a playback failure.
    }
  }

  /// The engine options this page keeps for every part and handle:
  /// hardware decoding and the player proxy.
  List<EngineOption> _storedEngineOptions() => playerStoredEngineOptions(
    hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
    tuning: ref.read(playerTuningProvider),
    proxy: ref.read(playerProxyProvider),
  );

  Future<void> _applyEngineOptions(PlayerHandle handle, {List<EngineOption> extra = const []}) async {
    try {
      await handle.applyEngineOptions(<EngineOption>[..._storedEngineOptions(), ...extra]);
    } on Object {
      // A refused engine option is not a playback failure.
    }
  }

  /// A custom-output or driver change reaches the running part: the stored
  /// options feed the next part, the handle gets them now, and a changed
  /// video/audio output rebuilds the render context in place (the open part
  /// and position are preserved by the handle). [playerPresetTransitionOptions]
  /// clears the previous recipe's keys when only the preset changed.
  Future<void> _applyTuning(PlayerTuning? previous, PlayerTuning next) async {
    final handle = _handle;
    if (handle == null) return;
    await _applyEngineOptions(
      handle,
      extra: previous == null ? const <EngineOption>[] : playerPresetTransitionOptions(previous, next),
    );
    if (previous == null || !playerOutputChanged(previous, next)) return;
    try {
      await handle.rebuildEngine(reason: 'video output settings changed');
    } on Object {
      // A rebuild the engine refused must not fail the page.
    }
  }

  Future<void> _setVolume(double volume) async {
    final handle = _handle;
    if (handle == null) return;
    setState(() => _volume = volume);
    try {
      await handle.setVolume(volume);
    } on Object catch (_) {
      // Same as mute.
    }
  }

  /// Answers a gesture on the picture with the figure it moved, and lets the
  /// answer settle away a moment after the last move — the room's rule, so a
  /// viewer learns one gesture and finds the same feedback on both players.
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

  /// Asks the display what it will take. A display that will not write has no
  /// brightness half, so that half stays the volume rather than a gesture that
  /// answers nothing.
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
      // A display that will not answer simply has no brightness half.
      if (mounted) setState(() => _brightnessWritable = false);
    }
  }

  /// A vertical drag on the picture: the right half is the volume, the left
  /// half the screen's brightness — where the display takes the write.
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
      // The same travel as the volume: a full-height drag crosses the range.
      final next = (_dragBrightness - delta / 2.2).clamp(0.0, 100.0);
      _dragBrightness = next;
      _showGesture(VodGestureKind.brightness, '${next.round()}%');
      // A native write only when the whole percent moved: a drag reports a
      // delta per frame, and the display takes one value per percent.
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

  /// A wheel step takes the viewer's own share of the range (the 画质与音频
  /// setting) and answers with the same chip a drag uses. The seek line
  /// answers the wheel too, so the step only moves over the picture.
  void _wheelVolume(double delta) {
    if (_handle == null) return;
    final step = ref.read(playbackSettingsProvider).volumeWheelStepPercent / 100;
    final next = (_volume + (delta > 0 ? -step : step)).clamp(0.0, 1.0);
    _showGesture(VodGestureKind.volume, '${(next * 100).round()}%');
    unawaited(_setVolume(next));
  }

  /// Steps the picture by [seconds] and says where it landed.
  Future<void> _stepSeek(double seconds) async {
    final transport = _transport;
    if (transport == null || _handle == null) return;
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

  /// The keyboard's step, which grows while the key keeps coming: five
  /// seconds once, then ten, then twenty, so a long skip is one key press.
  void _keySeek(double sign) {
    final now = DateTime.now();
    final chained = _lastSeekKey != null && now.difference(_lastSeekKey!) < const Duration(milliseconds: 900);
    final step = chained ? (_seekStep * 2).clamp(5.0, 30.0) : 5.0;
    _seekStep = step;
    _lastSeekKey = now;
    unawaited(_stepSeek(step * sign));
  }

  /// A double tap on the picture: either side steps ten seconds, the middle
  /// plays or pauses. The sides answer rather than the whole picture because a
  /// viewer who wants the part back taps where the line already went.
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

  /// A horizontal drag on the picture walks the part: a full sweep of its
  /// width is the whole length, so the drag says the same thing on a phone's
  /// picture and on a desktop's. The seek itself waits for the finger, and the
  /// chip carries the time it would land on.
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

  /// Seeks once, where the drag left the picture — or nowhere, when the drag
  /// was taken away by something else rather than let go.
  Future<void> _endScrub(bool committed) async {
    final target = committed ? _scrubSeconds : null;
    _resetScrub();
    if (target == null) return;
    await _seekTo(target);
  }

  /// Lets go of the drag's bookkeeping, so a cancelled gesture cannot leave a
  /// start point for the next one to read.
  void _resetScrub() {
    _scrubFrom = null;
    _scrubWalked = 0;
    _scrubSeconds = null;
  }

  /// A held picture runs faster until the finger lifts, at the rate the
  /// station's setting names; the part's own rate comes back with the hold.
  Future<void> _beginSpeedHold() async {
    final handle = _handle;
    if (handle == null || _speedHeld) return;
    _speedHeld = true;
    _speedBeforeHold = _speed;
    final boosted = ref.read(vodPlaybackSettingsProvider).longPressSpeed;
    // The words are read before the engine is asked: the chip answers on the
    // frame the hold started on, not on whatever is under the pointer after.
    final note = context.t.vod.gestureSpeedHold;
    setState(() => _speed = boosted.value);
    try {
      await handle.setRate(boosted.value);
    } on Object {
      // A rate the engine refused is not a reason to fail the hold.
    }
    _showGesture(VodGestureKind.speed, boosted.label, note: note);
  }

  /// The hold's two halves, in the shape the gesture surface reports them.
  void _speedHold(bool held) => unawaited(held ? _beginSpeedHold() : _endSpeedHold());

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

  /// Reads the part's own extras: its marked moments, its subtitle tracks and
  /// its scrub filmstrip. The station keeps the last two for a signed-in
  /// viewer, so an empty answer is the ordinary one and the surface simply
  /// shows less rather than failing.
  Future<void> _loadExtra(int cid) async {
    if (cid <= 0) return;
    final extra = await ref.read(vodClientProvider).playerExtra(bvid: widget.bvid, cid: cid);
    if (!mounted || _part?.cid != cid) return;
    setState(() => _extra = extra);
  }

  /// The archive's opening and ending, kept on this device: Bilibili marks
  /// them for its own cinema titles and nothing at all for a posted archive,
  /// so the points a viewer sets here are the only ones there are.
  String get _skipKey => 'vod.skip.${widget.bvid}';

  void _readSkipPoints() {
    try {
      final raw = StoragePrefs.getString(_skipKey);
      if (raw == null || raw.isEmpty) return;
      final json = jsonDecode(raw);
      if (json is! Map) return;
      _headSeconds = (json['head'] as num?)?.toDouble();
      _tailSeconds = (json['tail'] as num?)?.toDouble();
    } on Object {
      // No points is the ordinary answer.
    }
  }

  Future<void> _writeSkipPoints() async {
    try {
      await StoragePrefs.setString(
        _skipKey,
        jsonEncode({'head': _headSeconds?.round(), 'tail': _tailSeconds?.round()}),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  /// Marks the moment the picture stands on as the end of its opening, or the
  /// start of its ending.
  Future<void> _setHeadHere() async {
    final position = _transport?.position;
    if (position == null) return;
    setState(() => _headSeconds = position.inMilliseconds / 1000);
    await _writeSkipPoints();
  }

  Future<void> _setTailHere() async {
    final transport = _transport;
    if (transport == null || transport.duration.inMilliseconds <= 0) return;
    setState(() => _tailSeconds = transport.position.inMilliseconds / 1000);
    await _writeSkipPoints();
  }

  Future<void> _clearSkipPoints() async {
    setState(() {
      _headSeconds = null;
      _tailSeconds = null;
    });
    await _writeSkipPoints();
  }

  /// The ending is where the part stops for the viewer: the finish action runs
  /// there rather than at the last frame, so a long outro is not watched twice.
  void _watchTail() {
    if (!ref.read(vodPlaybackSettingsProvider).skipHeadTail || _finished || _opening) return;
    final tail = _tailSeconds;
    final transport = _transport;
    if (tail == null || tail <= 0 || transport == null) return;
    if (transport.position.inMilliseconds / 1000 >= tail) unawaited(_handleFinished());
  }

  /// Says where a saved position put the picture, and offers the way back to
  /// its start while the words stand.
  void _noteResumed(double seconds) {
    if (!mounted) return;
    _resumedTimer?.cancel();
    setState(() => _resumedAt = seconds);
    _resumedTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _resumedAt = null);
    });
  }

  /// Puts the part back at its first frame, and stops stepping over the
  /// opening for the rest of this one.
  Future<void> _playFromStart() async {
    _resumedTimer?.cancel();
    setState(() => _resumedAt = null);
    await _seekTo(0);
  }

  /// Runs the station's own countdown before the next part opens, so the step
  /// forward can be stopped while it is still a plan.
  void _startCountdown(VodPart next) {
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
        unawaited(_openPart(next, resume: _resumeFor(next)));
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

  /// Chooses the subtitle track, or none. A track's words are asked when it is
  /// picked rather than with the list, because a part may offer several.
  Future<void> _selectSubtitle(VodSubtitleTrack? track) async {
    if (track == null) {
      setState(() {
        _subtitleTrack = null;
        _subtitleLines = const [];
        _subtitleText = null;
      });
      return;
    }
    setState(() {
      _subtitleTrack = track;
      _subtitleLines = const [];
      _subtitleText = null;
    });
    try {
      final lines = await ref.read(vodClientProvider).subtitleLines(track.url);
      if (!mounted || _subtitleTrack?.id != track.id) return;
      setState(() => _subtitleLines = lines);
    } on Object {
      // A track that will not answer leaves the picture without words rather
      // than failing the part.
      if (mounted) {
        setState(() {
          _subtitleTrack = null;
          _subtitleLines = const [];
        });
      }
    }
  }

  /// The line the picture is on. The cursor walks forward with the position, so
  /// only a seek backwards reads the list from its top.
  void _syncSubtitle(Duration position) {
    final lines = _subtitleLines;
    if (lines.isEmpty) {
      if (_subtitleText != null) setState(() => _subtitleText = null);
      return;
    }
    var index = _subtitleCursor.clamp(0, lines.length - 1);
    if (lines[index].start > position) index = 0;
    while (index < lines.length && lines[index].end < position) {
      index++;
    }
    _subtitleCursor = index;
    final line = index < lines.length ? lines[index] : null;
    final shown = line != null && line.start <= position ? line.text : null;
    if (shown != _subtitleText && mounted) setState(() => _subtitleText = shown);
  }

  /// 音频模式: keep the sound, put the picture away.
  Future<void> _toggleAudioOnly() async {
    setState(() => _audioOnly = !_audioOnly);
    final handle = _handle;
    if (handle == null) return;
    await _applyAudioOnly(handle);
  }

  /// Writes the mode to [handle]; a kernel that has none leaves the picture up
  /// rather than failing the part switch it is applied on.
  Future<void> _applyAudioOnly(PlayerHandle handle) async {
    try {
      await handle.setAudioOnly(audioOnly: _audioOnly);
    } on Object {
      // The switch says what was asked; the next handle gets the same try.
    }
  }

  /// Keeps the frame the part is showing in the viewer's screenshot folder, and
  /// says how it went — a capture that fails silently reads as a dead button.
  Future<void> _screenshot() async {
    final handle = _handle;
    if (handle == null) return;
    final file = await capturePlayerFrame(handle, ref.read(appPathsProvider).screenshots, prefix: 'pure_live_vod');
    if (!mounted) return;
    final t = context.t;
    showDsToast(
      context: context,
      title: file == null ? t.room.screenshotFailed : t.room.screenshotSaved(name: file.uri.pathSegments.last),
      status: file == null ? DsStatus.danger : DsStatus.success,
    );
  }

  /// Sends the part's own address to a DLNA receiver. Bilibili's CDN answers
  /// only a request that carries the referer, so the headers travel with it —
  /// a TV that cannot send them surfaces a cast failure, which is the truth.
  Future<void> _cast() async {
    final info = _play;
    if (info == null) return;
    await showCastUriDialog(context, url: info.url, title: _detail?.title ?? _part?.title, headers: info.headers);
  }

  Future<void> _setSpeed(double speed) async {
    final handle = _handle;
    if (handle == null) return;
    setState(() => _speed = speed);
    try {
      await handle.setRate(speed);
    } on Object catch (_) {
      // Same as mute.
    }
  }

  /// One step along the station's own rate ladder, the keyboard's way through
  /// it: the choices the panel lists, walked in [direction] from where the
  /// picture stands now.
  Future<void> _stepSpeed(int direction) async {
    const choices = VodSpeedChoice.values;
    final current = choices.indexOf(VodSpeedChoice.nearest(_speed));
    final next = (current + (direction > 0 ? 1 : -1)).clamp(0, choices.length - 1);
    if (choices[next] == choices[current]) return;
    final rate = choices[next].value;
    _showGesture(VodGestureKind.speed, choices[next].label);
    await _setSpeed(rate);
  }

  Future<void> _toggleFullscreen() async {
    final handle = _handle;
    if (handle == null) return;
    await ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id);
  }

  Future<void> _togglePip() async {
    final handle = _handle;
    if (handle == null) return;
    final accepted = await ref.read(roomPresentationProvider.notifier).togglePip(handle.id);
    if (accepted || !mounted) return;
    showDsToast(context: context, title: context.t.common.pipUnavailable);
  }

  void _leave() {
    final handle = _handle;
    // A phone's picture-in-picture window floats over the page; leaving the
    // page is the way out of it (the system owns its own close).
    if (handle != null &&
        ref.read(roomPresentationProvider.notifier).modeOwnsWindow(ref.read(roomPresentationProvider))) {
      unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
      return;
    }
    context.pop();
  }

  /// Collects the archive, or drops it; the station's 个人 page lists what
  /// this writes.
  Future<void> _toggleFavourite() async {
    final detail = _detail;
    if (detail == null) return;
    final added = await ref.read(vodFavouritesProvider.notifier).toggle(VodSavedVideo.ofDetail(detail));
    if (!mounted) return;
    showDsToast(
      context: context,
      title: added ? context.t.vod.saveAdded : context.t.vod.saveRemoved,
      status: DsStatus.success,
    );
  }

  String get _progressKey => 'vod.progress.${widget.bvid}';

  ({int cid, double seconds})? _readProgress() {
    try {
      final raw = StoragePrefs.getString(_progressKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      // A finished archive keeps its history entry but is not resumed.
      if (json['completed'] == true) return null;
      final cid = (json['cid'] as num?)?.toInt();
      final seconds = (json['seconds'] as num?)?.toDouble();
      if (cid == null || seconds == null || seconds <= 0) return null;
      return (cid: cid, seconds: seconds);
    } on Object {
      return null;
    }
  }

  /// Saves the part and position at most once every few seconds. The entry is
  /// also the history record the station's 个人 page reads, so it carries the
  /// archive's metadata; the end of an archive marks it finished instead of
  /// clearing it.
  void _saveProgress({bool force = false}) {
    final part = _part;
    final transport = _transport;
    if (part == null || transport == null) return;
    final total = transport.duration.inMilliseconds;
    final position = transport.position.inMilliseconds;
    if (total <= 0 || position <= 0) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 5)) return;
    _lastSave = now;
    final completed = position >= total - 5000;
    final detail = _detail;
    try {
      unawaited(
        StoragePrefs.setString(
          _progressKey,
          jsonEncode({
            'cid': part.cid,
            'seconds': completed ? total / 1000 : position / 1000,
            'title': detail?.title ?? part.title,
            'cover': detail?.coverUrl,
            'uploader': detail?.uploader,
            'durationSeconds': total / 1000,
            'updatedAt': now.millisecondsSinceEpoch,
            if (completed) 'completed': true,
          }),
        ),
      );
    } on Object {
      // A preference; a closed store loses it.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(playbackSettingsProvider.select((settings) => settings.globalMute), (previous, next) {
      if (previous == next) return;
      if (mounted) setState(() => _globalMute = next);
      unawaited(_applyGlobalMute());
    });
    ref.listen(playerProxyProvider, (previous, next) {
      if (previous == next) return;
      final handle = _handle;
      if (handle != null) unawaited(_applyEngineOptions(handle));
    });
    ref.listen(playbackSettingsProvider.select((settings) => settings.hardwareDecoding), (previous, next) {
      if (previous == next) return;
      final handle = _handle;
      if (handle != null) unawaited(_applyEngineOptions(handle));
    });
    ref.listen(playerTuningProvider, (previous, next) {
      if (previous == next) return;
      unawaited(_applyTuning(previous, next));
    });
    // This archive's queue rows announce themselves: a finished part says
    // where it landed, a failed one says so — however the page was left.
    ref.listen(vodDownloadsProvider, (previous, next) {
      final before = {for (final item in previous ?? const <VodDownloadItem>[]) item.id: item.phase};
      for (final item in next) {
        if (item.bvid != widget.bvid || before[item.id] == item.phase) continue;
        if (!mounted) return;
        final t = context.t;
        if (item.phase == VodDownloadPhase.done) {
          showDsToast(
            context: context,
            title: t.vod.downloadDone(name: item.fileName),
            status: DsStatus.success,
          );
        } else if (item.phase == VodDownloadPhase.failed) {
          // The reason belongs on the toast: "下载失败" with no cause reads as
          // the app's own confusion, and the row keeps it too.
          showDsToast(context: context, title: t.vod.downloadFailed, description: item.error, status: DsStatus.danger);
        }
      }
    });
    // Leaving fullscreen or PiP — by any hand, including the system's —
    // puts the keyboard back on the play button, whose node outlives both
    // surfaces.
    ref.listen(roomPresentationProvider, (previous, next) {
      if (previous == null || previous == PresentationMode.normal || next != PresentationMode.normal) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          _playFocus.requestFocus();
        }
      });
    });
    // The room page's own rule, here too: a phone entering system fullscreen
    // asks the viewer's portrait policy which way it turns. The driver's exit
    // path puts the lock back.
    ref.listen(roomPresentationProvider, (previous, next) {
      if (next != PresentationMode.fullscreen || previous == PresentationMode.fullscreen) return;
      applyFullscreenOrientation(_screenOrientation, aspectRatio: _aspectRatio);
    });
    final presentation = ref.watch(roomPresentationProvider);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final t = context.t;
    final detail = _detail;
    final colors = DsTheme.colorsOf(context);
    // Only a mode that owns the app's window replaces this page's layout; a
    // phone's picture-in-picture window floats over it.
    final immersive = presentationController.modeOwnsWindow(presentation);
    if (immersive) {
      return Scaffold(backgroundColor: colors.canvas, body: _playerSurface(context, immersive: true));
    }
    // The arrows mirror the room page: up and down take the wheel's step (the
    // 画质与音频 setting) toward the volume, left and right skip five seconds.
    // A TV keeps its arrows for focus; the remote drives the volume itself.
    final tv = ref.watch(platformRuntimeProvider).environment.runtime.formFactor == FormFactor.tv;
    final volumeStep = ref.watch(playbackSettingsProvider.select((settings) => settings.volumeWheelStepPercent)) / 100;
    void nudgeVolume(double delta) {
      _wake();
      _showGesture(VodGestureKind.volume, '${((_volume + delta).clamp(0.0, 1.0) * 100).round()}%');
      unawaited(_setVolume((_volume + delta).clamp(0.0, 1.0)));
    }

    return PlayerBarTier(
      tv: tv,
      child: CallbackShortcuts(
        bindings: {
          // A remote cannot tap the picture to raise the bar, so its transport
          // keys wake the chrome they drive.
          const SingleActivator(LogicalKeyboardKey.space): () {
            _wake();
            unawaited(_togglePlay());
          },
          const SingleActivator(LogicalKeyboardKey.keyF): () {
            _wake();
            unawaited(_toggleFullscreen());
          },
          const SingleActivator(LogicalKeyboardKey.escape): _leave,
          // While the bar is down a TV's arrows and OK have nothing to move
          // through, so they raise it; while it is up they stay with focus.
          if (tv && !_controlsVisible) ...{
            const SingleActivator(LogicalKeyboardKey.arrowUp): _wake,
            const SingleActivator(LogicalKeyboardKey.arrowDown): _wake,
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _wake,
            const SingleActivator(LogicalKeyboardKey.arrowRight): _wake,
            const SingleActivator(LogicalKeyboardKey.select): _wake,
          },
          if (!tv) const SingleActivator(LogicalKeyboardKey.arrowUp): () => nudgeVolume(volumeStep),
          if (!tv) const SingleActivator(LogicalKeyboardKey.arrowDown): () => nudgeVolume(-volumeStep),
          // A held arrow keeps stepping, and each step in a row is bigger:
          // five seconds, then ten, then twenty, so reaching the middle of an
          // hour is one key rather than a hundred taps.
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
              _wake();
              _keySeek(-1);
            },
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              _wake();
              _keySeek(1);
            },
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.comma): () {
              _wake();
              unawaited(_stepSpeed(-1));
            },
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.period): () {
              _wake();
              unawaited(_stepSpeed(1));
            },
          if (!tv)
            const SingleActivator(LogicalKeyboardKey.keyM): () {
              _wake();
              unawaited(_setMuted(muted: !_effectivelyMuted));
            },
        },
        child: Scaffold(
          backgroundColor: colors.surface,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(title: detail?.title ?? t.vod.opening),
              Expanded(
                child: _loading && detail == null
                    ? const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)))
                    : _error != null && detail == null
                    ? Center(
                        child: DsEmptyState(
                          icon: const DsIcon(DsIcons.cloudOff),
                          title: Text(t.vod.loadFailed),
                          description: Text(_error!),
                          actions: [DsButton(onPressed: () => unawaited(_load()), child: Text(t.vod.retry))],
                        ),
                      )
                    : _body(context, detail, t),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, VodDetail? detail, Translations t) {
    if (detail == null) return const SizedBox.shrink();
    final colors = DsTheme.colorsOf(context);
    final player = _playerSurface(context, immersive: false);
    final window = _relatedWindow;
    final related = window.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              Row(
                spacing: DsSpace.s8,
                children: [
                  Expanded(
                    child: Text(
                      t.vod.related,
                      style: DsTheme.of(context).typography.title.copyWith(color: colors.text),
                    ),
                  ),
                  // The reference's rail turns the page of twenty.
                  if (_relatedPool.length > 20)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      leading: const DsIcon(DsIcons.refreshCw, size: 14),
                      onPressed: _relatedBusy ? null : () => unawaited(_changeRelated()),
                      child: Text(t.vod.changeRelated),
                    ),
                ],
              ),
              for (final video in window)
                VodVideoRow(video: video, onOpen: () => unawaited(context.push('/vod/${video.bvid ?? video.id}'))),
            ],
          );
    // The parts shelf sits in the rail beside the picture on a wide window —
    // the episode strip the reference's own video page draws — and back under
    // the picture on a narrow one, where no rail exists. Related reads under
    // it there, one column: choose the next part first, then wander off.
    final parts = detail.parts.length > 1
        ? _PartsSection(
            parts: detail.parts,
            current: _part,
            onOpen: (part) => unawaited(_openPart(part, resume: _resumeFor(part))),
          )
        : null;
    final rail = parts == null && related == null
        ? null
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: DsSpace.s16, children: [?parts, ?related]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = LiveWindow.isExpanded(constraints.maxWidth);
        final info = _info(context, detail, t, showParts: parts == null || !wide);
        if (!wide) {
          final inset = LiveWindow.pageInset(constraints.maxWidth);
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s16,
              children: [player, info, ?related],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(DsSpace.s24, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: DsSpace.s16,
                  children: [player, info],
                ),
              ),
            ),
            if (rail != null)
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                  child: rail,
                ),
              ),
          ],
        );
      },
    );
  }

  /// The picture and its controls — read as a video, not as a stream.
  ///
  /// The bars follow the pointer: moving it over the picture brings them back,
  /// and a tap on a touch screen toggles them, while a playing part lets them
  /// settle away again. The gestures are the ones a video is watched with, the
  /// room's arrangement carried over where it already agrees with them: a
  /// horizontal drag anywhere on the picture scrubs, a vertical drag takes the
  /// volume on the right half and the screen's brightness on the left (where
  /// the display will take it), a double tap on either side steps ten seconds
  /// and on the middle plays or pauses, and a hold runs the part faster until
  /// the finger lifts. Each one answers with a chip naming the figure it moved.
  /// Under the picture the seek line says what has been watched, what the
  /// engine already holds and where the station marked a moment, and the
  /// pointer's bubble says where the picture would go. The rendition, the part
  /// list, the speed and the subtitles hang their catalogues from the bar as
  /// glass panels, the way the live room's strip does. [immersive] adds the way
  /// out and the title over the picture, since the page's own headline is gone
  /// there.
  Widget _playerSurface(BuildContext context, {required bool immersive}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final handle = _handle;
    final transport = _transport;
    final playing = transport?.isPlaying ?? false;
    _syncScreenWake(playing && ref.watch(keepScreenOnProvider));
    final detail = _detail;
    final playback = ref.watch(playbackSettingsProvider);
    final danmakuStyle = ref.watch(danmakuStyleProvider);
    final danmakuFps = ref.watch(danmakuEffectiveFpsProvider);
    final showBar = _controlsVisible || !playing;
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive ? 0 : theme.radii.overlay),
      child: ColoredBox(
        color: colors.overlay,
        child: _PictureBox(
          immersive: immersive,
          child: MouseRegion(
            onHover: (_) => _wake(),
            onExit: (_) => _scheduleHide(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (handle != null)
                  MediaPlayerView(handle: handle, fit: playback.fit.boxFit, backgroundColor: colors.overlay)
                else
                  const ColoredBox(color: Color(0xFF000000)),
                // The part's danmaku, on a clock the player's binding keeps
                // equal to the picture's; hidden while the layer is switched
                // off or no track loaded yet.
                if (handle != null && _danmakuCid > 0 && playback.danmakuVisible)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FlameBarrageWidget(
                        config: playerBarrageConfig(
                          danmakuStyle,
                          danmakuFps,
                          family: resolvedFontFamily(danmakuStyle.fontFamily),
                        ),
                        emojiAtlas: EmojiAtlas.instance,
                        controller: _barrage,
                      ),
                    ),
                  ),
                // 音频模式 covers the frame rather than replacing the surface:
                // the part keeps playing, and the episode's name says what is
                // still running behind the card.
                if (_audioOnly && handle != null)
                  Positioned.fill(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        spacing: DsSpace.s8,
                        children: [
                          const DsIcon(DsIcons.headphones, size: 32, color: OnVideoColors.inkSubtle),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Text(
                              _part?.title ?? _detail?.title ?? '',
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.title.copyWith(color: OnVideoColors.foreground),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // The stream's own numbers, on the same session switch the room
                // and the preview use.
                if (handle case final player? when ref.watch(playerStatsVisibleProvider))
                  Positioned.fill(
                    child: IgnorePointer(child: PlayerStatsOverlay(handle: player)),
                  ),
                // What the last gesture on the picture did, in the corner it
                // happened in.
                if (_gestureKind case final kind?)
                  Positioned.fill(
                    child: VodGestureTip(kind: kind, value: _gestureValue ?? '', note: _gestureNote),
                  ),
                // The subtitle the part is on, above the bar and under the
                // flying danmaku: the words the station sent, not the ones the
                // viewers typed. It is content rather than chrome, so it keeps
                // standing while the bar settles away and on a TV too.
                if (_subtitleText case final words?)
                  Positioned.fill(
                    child: VodSubtitleLayer(text: words, bottomInset: showBar ? _subtitleInset : 0),
                  ),
                // The picture's own vocabulary, measured against this surface
                // and answered by the methods below.
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
                  child: const SizedBox.expand(),
                ),
                if (_opening || (transport?.isBuffering ?? false))
                  const Center(child: DsSpinner(style: DsSpinnerStyle(size: 40))),
                if (showBar)
                  PositionedDirectional(top: 0, start: 0, end: 0, child: _vodTopStrip(t, detail, immersive: immersive)),
                if (showBar)
                  PositionedDirectional(
                    bottom: 0,
                    start: 0,
                    end: 0,
                    // Resting on the bar keeps it; leaving it settles the bar
                    // the way an idle pointer does.
                    child: MouseRegion(
                      onEnter: (_) => _hideTimer?.cancel(),
                      onExit: (_) => _scheduleHide(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (vodDownloadOf(ref.watch(vodDownloadsProvider), widget.bvid, _part?.cid ?? 0)
                              case final download?
                              when download.phase == VodDownloadPhase.running ||
                                  download.phase == VodDownloadPhase.queued)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: DsSpace.s12, bottom: DsSpace.s4),
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: PlayerGlassPill(
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(
                                      DsSpace.s12,
                                      DsSpace.s4,
                                      DsSpace.s4,
                                      DsSpace.s4,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      spacing: DsSpace.s8,
                                      children: [
                                        const DsSpinner(style: DsSpinnerStyle(size: 14)),
                                        Text(switch (download.progress) {
                                          final progress? => t.vod.downloading(percent: (progress * 100).round()),
                                          null => t.vod.downloadingUnknown,
                                        }, style: theme.typography.caption.copyWith(color: OnVideoColors.foreground)),
                                        PlayerBarButton(
                                          icon: DsIcons.pause,
                                          label: t.vod.downloadPause,
                                          size: 28,
                                          iconSize: 16,
                                          onPressed: () =>
                                              unawaited(ref.read(vodDownloadsProvider.notifier).pause(download.id)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          // The part's own one-time offers, over its foot:
                          // the position the player jumped back to, the
                          // countdown before the next part, the opening and
                          // the ending the viewer can step over. They are not
                          // watching verbs, so they stand outside the bar.
                          for (final notice in _vodNotices(t))
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: DsSpace.s12, bottom: DsSpace.s4),
                              child: Align(alignment: AlignmentDirectional.centerEnd, child: notice),
                            ),
                          _vodControlBar(context),
                        ],
                      ),
                    ),
                  )
                // The bar away, the picture keeps one line at its bottom
                // edge: how far it played, and the strip that brings the bar
                // back under the pointer.
                else if (playing && handle != null)
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
                // The catalogue floats over the bar and its pill, so a menu
                // never hides behind the download status.
                if (showBar)
                  if (_openPanel case final panel?)
                    Positioned.fill(
                      child: PlayerPanelHost(
                        anchorKey: _panelAnchors[panel]!,
                        barKey: _barAnchor,
                        width: _panelWidth(panel),
                        child: MouseRegion(
                          onEnter: (_) => _leaveTimer?.cancel(),
                          onExit: (_) => _leavePanelSoon(),
                          child: _vodPanel(t, panel),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whether this archive is on the viewer's shelf. The action row under the
  /// player and the immersive strip's button both read it here, so the two can
  /// never disagree about what is bookmarked.
  bool savedOf(String bvid) => ref.watch(vodFavouritesProvider).any((video) => video.bvid == bvid);

  /// The part's own one-time offers, in the order the viewer meets them: the
  /// position the page jumped back to, the opening it is still inside, the
  /// ending it has reached, and the countdown to the next part. Each names the
  /// verb it takes; none of them stays once taken.
  List<Widget> _vodNotices(Translations t) {
    final transport = _transport;
    final position = transport == null ? 0.0 : transport.position.inMilliseconds / 1000;
    final total = transport == null ? 0.0 : transport.duration.inMilliseconds / 1000;
    final head = _headSeconds;
    final tail = _tailSeconds;
    return [
      if (_resumedAt case final seconds?)
        VodPictureNotice(
          icon: DsIcons.history,
          text: t.vod.resumedAt(time: vodDurationText(Duration(seconds: seconds.round()))),
          actionLabel: t.vod.playFromStart,
          onAction: () => unawaited(_playFromStart()),
        ),
      if (head != null && head > 0 && position < head)
        VodPictureNotice(
          icon: DsIcons.skipForward,
          text: t.vod.headRemaining(time: vodDurationText(Duration(seconds: (head - position).round()))),
          actionLabel: t.vod.skipHead,
          onAction: () => unawaited(_seekTo(head)),
        ),
      if (tail != null && tail > 0 && total > 0 && position >= tail)
        VodPictureNotice(
          icon: DsIcons.skipForward,
          text: t.vod.inTail,
          actionLabel: t.vod.skipTail,
          onAction: () => unawaited(_handleFinished()),
        ),
      if (_countdown > 0)
        VodPictureNotice(
          icon: DsIcons.listVideo,
          text: t.vod.nextPartIn(seconds: _countdown),
          actionLabel: t.common.cancel,
          onAction: _cancelCountdown,
        ),
    ];
  }

  /// The strip over the picture's top edge: what acts on the picture — keep a
  /// frame of it, send it to a TV, fold it into a window — in one glass pill,
  /// the rest under a ⋮ menu beside it, and, when the picture owns the whole
  /// window, the way out and the archive's name at the left.
  ///
  /// In-page the identity half is skipped on purpose — the page header above
  /// already names the archive — so what sits over the picture's top-right is
  /// only the verbs. Same rule as the live room's strip.
  Widget _vodTopStrip(Translations t, VodDetail? detail, {required bool immersive}) {
    final theme = DsTheme.of(context);
    final presentation = ref.watch(roomPresentationProvider);
    final pipAvailable = _handle != null && ref.read(roomPresentationProvider.notifier).pipAvailable;
    final actions = <Widget>[
      // The frame-copy leads, the room strip's order: keep the frame, send the
      // part to a TV, then the small window.
      if (_handle?.canCaptureScreenshot ?? false)
        PlayerBarButton(
          icon: DsIcons.camera,
          label: t.room.screenshot,
          onPressed: () {
            _wake();
            unawaited(_screenshot());
          },
        ),
      if (_play != null)
        PlayerBarButton(
          icon: DsIcons.cast,
          label: t.room.cast,
          onPressed: () {
            _wake();
            unawaited(_cast());
          },
        ),
      if (pipAvailable)
        PlayerBarButton(
          iconAsset: presentation == PresentationMode.pip ? 'assets/icons/pip-exit.svg' : 'assets/icons/pip.svg',
          label: presentation == PresentationMode.pip ? t.room.pipOff : t.vod.pip,
          selected: presentation == PresentationMode.pip,
          onPressed: () {
            _wake();
            unawaited(_togglePip());
          },
        ),
    ];
    final actionPill = actions.isEmpty
        ? const SizedBox.shrink()
        : PlayerGlassPill(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: PlayerBarTier.tvOf(context) ? DsSpace.s8 : DsSpace.s4,
              children: actions,
            ),
          );
    final morePill = PlayerGlassPill(
      child: DsMenuAnchor(
        semanticLabel: t.common.more,
        align: DsAlign.end,
        items: _vodMenuItems(t),
        builder: (context, controller, _) => PlayerBarButton(
          icon: DsIcons.ellipsisVertical,
          label: t.common.more,
          onPressed: () {
            _wake();
            controller.toggle();
          },
        ),
      ),
    );
    if (!immersive) {
      // No handle, no verbs: the picture has nothing yet to act on, and the
      // page header above carries the errands until it does.
      if (_handle == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s12, 0),
        child: Row(mainAxisAlignment: MainAxisAlignment.end, spacing: DsSpace.s8, children: [actionPill, morePill]),
      );
    }
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s8, DsSpace.s8, DsSpace.s12, DsSpace.s20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topCenter,
          end: AlignmentDirectional.bottomCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        spacing: DsSpace.s8,
        children: [
          PlayerGlassPill(
            child: PlayerBarButton(
              icon: DsIcons.minimize2,
              label: t.vod.exitFullscreen,
              autofocus: true,
              onPressed: () => unawaited(_toggleFullscreen()),
            ),
          ),
          Expanded(
            child: Text(
              detail?.title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.title.copyWith(color: OnVideoColors.foreground),
            ),
          ),
          // The page's own bookmark, reachable from the fullscreen picture: the
          // action row under the player is page chrome, and an immersive
          // surface has none of it — an action that vanished with the chrome is
          // one the viewer has to leave fullscreen to reach. One verb, so it is
          // a button rather than a menu of one row.
          if (detail != null)
            PlayerGlassPill(
              child: PlayerBarButton(
                icon: DsIcons.heart,
                label: savedOf(detail.bvid) ? t.vod.savedVideo : t.vod.saveVideo,
                selected: savedOf(detail.bvid),
                onPressed: () => unawaited(_toggleFavourite()),
              ),
            ),
          actionPill,
          morePill,
        ],
      ),
    );
  }

  /// The ⋮ menu's rows: how the picture meets its box, what rides on it (the
  /// stream's numbers, the sound-only mode) and the errand it feeds (a
  /// download). The bottom bar keeps to the watching verbs, so these — chosen
  /// once rather than while watching — read better as a list than as bar
  /// furniture. The info area's action row still carries its own download, so
  /// a row that dims here loses nothing.
  List<Widget> _vodMenuItems(Translations t) {
    final handle = _handle;
    final fit = ref.watch(playbackSettingsProvider).fit;
    return [
      DsMenuItem.submenu(
        leading: const DsIcon(DsIcons.aspectRatio),
        label: Text(t.settings.fit),
        submenu: [
          for (final option in PlaybackFit.values)
            DsMenuItem(
              label: Text(fitLabels(t)[option.index]),
              checked: option == fit,
              onPressed: () => unawaited(ref.read(playbackSettingsProvider.notifier).setFit(option)),
            ),
        ],
      ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.activity),
        label: Text(t.room.statsToggle),
        checked: ref.watch(playerStatsVisibleProvider),
        checkRole: DsMenuCheckRole.checkbox,
        onPressed: handle == null
            ? null
            : () {
                _wake();
                ref.read(playerStatsVisibleProvider.notifier).toggle();
              },
      ),
      DsMenuItem(
        leading: DsIcon(_audioOnly ? DsIcons.headphones : DsIcons.music2),
        label: Text(t.room.audioOnlyMode),
        checked: _audioOnly,
        checkRole: DsMenuCheckRole.checkbox,
        onPressed: handle == null
            ? null
            : () {
                _wake();
                unawaited(_toggleAudioOnly());
              },
      ),
      DsMenuItem.submenu(
        leading: const DsIcon(DsIcons.pin),
        label: Text(t.vod.skipHeadTail),
        submenu: [
          // Bilibili marks an opening and an ending for its own cinema
          // titles and says nothing at all for a posted archive, so the
          // points here are the viewer's: set them where the part stands
          // now, and the player steps over them from then on.
          DsMenuItem(
            leading: const DsIcon(DsIcons.skipForward),
            label: Text(t.vod.autoSkipHeadTail),
            checked: ref.watch(vodPlaybackSettingsProvider).skipHeadTail,
            checkRole: DsMenuCheckRole.checkbox,
            onPressed: () => unawaited(
              ref
                  .read(vodPlaybackSettingsProvider.notifier)
                  .setSkipHeadTail(value: !ref.read(vodPlaybackSettingsProvider).skipHeadTail),
            ),
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.history),
            label: Text(t.vod.setHeadHere),
            onPressed: handle == null
                ? null
                : () {
                    _closePanel();
                    unawaited(_setHeadHere());
                  },
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.history),
            label: Text(t.vod.setTailHere),
            onPressed: handle == null
                ? null
                : () {
                    _closePanel();
                    unawaited(_setTailHere());
                  },
          ),
          DsMenuItem(
            leading: const DsIcon(DsIcons.x),
            label: Text(t.vod.clearSkipPoints),
            onPressed: _headSeconds == null && _tailSeconds == null
                ? null
                : () {
                    _closePanel();
                    unawaited(_clearSkipPoints());
                  },
          ),
        ],
      ),
      DsMenuItem(
        leading: const DsIcon(DsIcons.download),
        label: Text(t.vod.download),
        onPressed: _part == null || _detail == null
            ? null
            : () {
                _wake();
                unawaited(_startDownload());
              },
      ),
    ];
  }

  /// Hands the current part to the app-wide download queue.
  ///
  /// The queue resolves its own muxed address when the task's turn comes —
  /// a signed one would be stale by then — and the 下载管理 page (the
  /// station's sidebar, or Settings → 视频) takes over from there.
  Future<void> _startDownload() async {
    final t = context.t;
    final part = _part;
    final detail = _detail;
    if (part == null || detail == null) return;
    final result = await ref
        .read(vodDownloadsProvider.notifier)
        .download(
          bvid: widget.bvid,
          cid: part.cid,
          title: detail.title,
          part: part.title,
          index: part.page,
          parts: detail.parts.length,
          qn: ref.read(vodDownloadQualityProvider).qn,
          cover: detail.coverUrl?.toString() ?? '',
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

  /// The bar under the picture: the seek line over the transport, then the
  /// watching verbs — play, the step to the next part, the sound, the
  /// rendition, the speed and the danmaku pair — and the two ways out of the
  /// box. What acts on the picture (capture, cast, the small window) and the
  /// errands live on the strip above and its ⋮ menu.
  Widget _vodControlBar(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final handle = _handle;
    final transport = _transport;
    final playing = transport?.isPlaying ?? false;
    final duration = transport?.duration ?? _detail?.duration ?? _part?.duration ?? Duration.zero;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    final qualities = _play?.qualities ?? const <VodQuality>[];
    final parts = _detail?.parts ?? const <VodPart>[];
    final presentation = ref.watch(roomPresentationProvider);
    final presentationController = ref.read(roomPresentationProvider.notifier);
    final immersive = presentationController.modeOwnsWindow(presentation);
    final playback = ref.watch(playbackSettingsProvider);
    final danmakuVisible = playback.danmakuVisible;
    final timeStyle = theme.typography.numeric(theme.typography.caption.copyWith(color: OnVideoColors.foreground));
    return Container(
      key: _barAnchor,
      padding: const EdgeInsetsDirectional.fromSTEB(DsSpace.s12, DsSpace.s8, DsSpace.s12, DsSpace.s8),
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
        children: [
          Row(
            spacing: DsSpace.s8,
            children: [
              SizedBox(
                width: 54,
                child: Text(vodDurationText(position), textAlign: TextAlign.center, style: timeStyle),
              ),
              Expanded(
                // The line says three things a slider cannot: what has been
                // watched, what the engine already holds, and where the
                // station marked a moment. Under the pointer it says where the
                // picture would go.
                child: VodSeekBar(
                  position: position,
                  duration: duration,
                  semanticLabel: t.vod.progress,
                  buffered: _transport?.buffer.ranges ?? const [],
                  chapters: _extra.chapters,
                  preview: _extra.preview,
                  coverUrl: _detail?.coverUrl,
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
                child: Text(vodDurationText(duration), textAlign: TextAlign.center, style: timeStyle),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              // The bar gives way from the outside in: the volume slider,
              // then the pickers' words — and what still does not fit
              // scrolls, the room bar's own answer, so a phone or a desktop's
              // paned picture never overflows.
              final compact = LiveWindow.isCompact(constraints.maxWidth);
              final bar = Row(
                mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
                spacing: PlayerBarTier.tvOf(context) ? DsSpace.s8 : DsSpace.s4,
                children: [
                  PlayerBarButton(
                    iconAsset: playing ? 'assets/icons/pause.svg' : 'assets/icons/play.svg',
                    label: playing ? t.vod.pause : t.vod.play,
                    focusNode: _playFocus,
                    onPressed: handle == null
                        ? null
                        : () {
                            _wake();
                            unawaited(_togglePlay());
                          },
                  ),
                  // The steps between parts, right beside play: a course or a
                  // serial is walked both ways, and the chips keep those steps
                  // on the bar while the shelf under the picture (or the rail
                  // beside it) keeps the jump to any part.
                  if (_hasPreviousPart) _vodPartStepChip(t, compact: compact, forward: false),
                  if (_hasNextPart) _vodPartStepChip(t, compact: compact, forward: true),
                  PlayerBarButton(
                    iconAsset: _effectivelyMuted ? 'assets/icons/volume-muted.svg' : 'assets/icons/volume.svg',
                    label: _effectivelyMuted ? t.vod.unmute : t.vod.mute,
                    onPressed: handle == null
                        ? null
                        : () {
                            _wake();
                            unawaited(_setMuted(muted: !_effectivelyMuted));
                          },
                  ),
                  // The volume slider fits every width: a compact window
                  // narrows it rather than losing it.
                  SizedBox(
                    width: compact ? 72 : 96,
                    child: DsSlider(
                      value: _effectivelyMuted ? 0 : _volume,
                      onChanged: handle == null
                          ? null
                          : (value) {
                              _wake();
                              unawaited(_setVolume(value));
                            },
                      semanticLabel: t.vod.volume,
                    ),
                  ),
                  // Only the fitted bar has spare width to split its clusters
                  // with; a scrolling one keeps the verbs right after.
                  if (!compact) const Spacer(),
                  if (qualities.isNotEmpty)
                    _vodPickerButton(
                      panel: _VodPanel.quality,
                      icon: DsIcons.gauge,
                      label: _openedLabel ?? t.vod.quality,
                      semanticLabel: t.vod.quality,
                      compact: compact,
                    ),
                  // The parts live under the picture, where the page draws them,
                  // so the bar that rests on the picture keeps no second copy of
                  // the choice: one list, one entry. The immersive surface has no
                  // page under it — the picture is the whole window — and there
                  // the catalogue on the bar is the only way to any part (the
                  // chip only steps forward), so it stays.
                  if (parts.length > 1 && immersive)
                    _vodPickerButton(
                      panel: _VodPanel.parts,
                      icon: DsIcons.listVideo,
                      label: 'P${_part?.page ?? 1}',
                      semanticLabel: t.vod.parts,
                      compact: compact,
                    ),
                  _vodPickerButton(
                    panel: _VodPanel.speed,
                    icon: DsIcons.timer,
                    label: VodSpeedChoice.nearest(_speed).label,
                    semanticLabel: t.vod.speed,
                    compact: compact,
                  ),
                  // The words the station wrote for this part. The door opens
                  // only where there is something behind it: a guest gets no
                  // list, and a CC button that has nothing to list is a button
                  // that answers nothing.
                  if (_extra.subtitles.isNotEmpty)
                    _vodPickerButton(
                      panel: _VodPanel.subtitle,
                      icon: DsIcons.captions,
                      label: _subtitleTrack?.languageName.isEmpty ?? true
                          ? t.vod.subtitles
                          : _subtitleTrack!.languageName,
                      semanticLabel: t.vod.subtitles,
                      compact: compact,
                    ),
                  // The danmaku's switch and its settings, the reading end of
                  // what is on the picture: the pair the room's bar draws.
                  PlayerBarButton(
                    iconAsset: 'assets/icons/danmaku.svg',
                    label: danmakuVisible ? t.vod.danmakuOff : t.vod.danmakuOn,
                    selected: danmakuVisible,
                    onPressed: handle == null
                        ? null
                        : () {
                            _wake();
                            unawaited(
                              ref.read(playbackSettingsProvider.notifier).setDanmakuVisible(value: !danmakuVisible),
                            );
                          },
                  ),
                  PlayerBarButton(
                    iconAsset: 'assets/icons/danmaku-settings.svg',
                    label: t.settings.navDanmaku,
                    onPressed: () {
                      _wake();
                      unawaited(context.push(SettingsSectionRoute(section: SettingsSection.danmaku.name).location));
                    },
                  ),
                  // The window verbs, then the way out of the picture's box —
                  // the room bar's pair: the desktop's window-fullscreen first,
                  // then the system fullscreen the phone turns for.
                  if (_desktop && presentation != PresentationMode.pip)
                    PlayerBarButton(
                      icon: presentation == PresentationMode.windowFullscreen
                          ? DsIcons.copy
                          : DsIcons.square,
                      label: presentation == PresentationMode.windowFullscreen
                          ? t.room.windowFullscreenOff
                          : t.room.windowFullscreenOn,
                      selected: presentation == PresentationMode.windowFullscreen,
                      onPressed: handle == null
                          ? null
                          : () {
                              _wake();
                              unawaited(presentationController.toggleWindowFullscreen(handle.id));
                            },
                    ),
                  if (presentation != PresentationMode.pip)
                    PlayerBarButton(
                      icon: presentation == PresentationMode.fullscreen ? DsIcons.minimize : DsIcons.maximize,
                      label: presentation == PresentationMode.fullscreen ? t.vod.exitFullscreen : t.vod.fullscreen,
                      onPressed: handle == null
                          ? null
                          : () {
                              _wake();
                              unawaited(_toggleFullscreen());
                            },
                    ),
                ],
              );
              return compact ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: bar) : bar;
            },
          ),
        ],
      ),
    );
  }

  /// The step chip: the step's glyph and word in the pickers' shape, one press
  /// to the part before or after this one. It stays a word, not a bare glyph,
  /// because a step between parts is a decision about the episode, not a
  /// twitch of the sound. [forward] says which way the step goes; the two
  /// chips are the same shape read in the other direction.
  Widget _vodPartStepChip(Translations t, {required bool compact, required bool forward}) {
    final theme = DsTheme.of(context);
    final label = forward ? t.vod.nextPart : t.vod.previousPart;
    return DsPressable(
      semanticLabel: label,
      onPressed: () {
        _wake();
        _openSteppedPart(forward ? 1 : -1);
      },
      builder: (context, states, _) {
        final lit = states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
        return Container(
          height: theme.sizes.md,
          padding: EdgeInsets.symmetric(horizontal: compact ? DsSpace.s6 : DsSpace.s8),
          decoration: DsBoxDecoration(
            color: lit ? OnVideoColors.inkHover : null,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: DsSpace.s4,
            children: [
              DsIcon(
                forward ? DsIcons.skipForward : DsIcons.skipBack,
                size: theme.sizes.iconLg,
                color: OnVideoColors.inkMuted,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: OnVideoColors.foreground),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// One picker on the bar: the glyph, the current choice's words when the
  /// bar has room, and the chevron that says a panel hangs above it.
  Widget _vodPickerButton({
    required _VodPanel panel,
    required DsIconData icon,
    required String label,
    required String semanticLabel,
    required bool compact,
  }) {
    final theme = DsTheme.of(context);
    final open = _openPanel == panel;
    return KeyedSubtree(
      key: _panelAnchors[panel],
      child: MouseRegion(
        onEnter: (_) => _hoverPanel(panel),
        onExit: (_) => _leavePanelSoon(),
        child: DsPressable(
          semanticLabel: semanticLabel,
          onPressed: () {
            _wake();
            if (_openPanel == panel) {
              _closePanel();
            } else {
              _showPanel(panel);
            }
          },
          builder: (context, states, _) {
            final lit = open || states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
            return Container(
              height: theme.sizes.md,
              padding: EdgeInsets.symmetric(horizontal: compact ? DsSpace.s6 : DsSpace.s8),
              decoration: DsBoxDecoration(
                color: lit ? OnVideoColors.inkHover : null,
                borderRadius: theme.radii.controlCorners(null, theme.sizes.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [
                  DsIcon(icon, size: theme.sizes.iconLg, color: OnVideoColors.inkMuted),
                  if (!compact)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: OnVideoColors.foreground),
                      ),
                    ),
                  DsIcon(open ? DsIcons.chevronDown : DsIcons.chevronUp, size: 12, color: OnVideoColors.inkMuted),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The width each catalogue asks for; the anchored host centres the card
  /// on its picker with this measure.
  static double _panelWidth(_VodPanel panel) => switch (panel) {
    _VodPanel.quality => 200,
    _VodPanel.parts => 260,
    _VodPanel.speed => 180,
    _VodPanel.subtitle => 240,
  };

  /// The open picker's catalogue.
  Widget _vodPanel(Translations t, _VodPanel panel) {
    switch (panel) {
      case _VodPanel.quality:
        final qualities = _play?.qualities ?? const <VodQuality>[];
        return PlayerOverlayPanel(
          title: t.vod.quality,
          width: _panelWidth(panel),
          children: [
            for (final quality in qualities)
              PlayerPanelOption(
                label: quality.label,
                selected: quality.qn == _openedQn,
                onPressed: () {
                  _closePanel();
                  final current = _part;
                  if (current == null) return;
                  final resume = _transport?.position.inMilliseconds;
                  unawaited(_openPart(current, qn: quality.qn, resume: resume == null ? null : resume / 1000));
                },
              ),
          ],
        );
      case _VodPanel.parts:
        final parts = _detail?.parts ?? const <VodPart>[];
        return PlayerOverlayPanel(
          title: t.vod.parts,
          width: _panelWidth(panel),
          children: [
            for (final candidate in parts)
              KeyedSubtree(
                key: candidate.cid == _part?.cid ? _currentPartKey : null,
                child: PlayerPanelOption(
                  label: 'P${candidate.page} ${candidate.title}',
                  selected: candidate.cid == _part?.cid,
                  onPressed: () {
                    _closePanel();
                    unawaited(_openPart(candidate, resume: _resumeFor(candidate)));
                  },
                ),
              ),
          ],
        );
      case _VodPanel.speed:
        return PlayerOverlayPanel(
          title: t.vod.speed,
          width: _panelWidth(panel),
          children: [
            for (final choice in VodSpeedChoice.values)
              PlayerPanelOption(
                label: choice.label,
                selected: choice.value == _speed,
                onPressed: () {
                  _closePanel();
                  unawaited(_setSpeed(choice.value));
                },
              ),
          ],
        );
      // The words the station wrote for this part, as opposed to the ones the
      // viewers fly over it. It sends the list only to a signed-in viewer, so
      // an empty one says which door is shut rather than pretending the
      // archive has nothing to say.
      case _VodPanel.subtitle:
        final tracks = _extra.subtitles;
        return PlayerOverlayPanel(
          title: t.vod.subtitles,
          width: _panelWidth(panel),
          children: [
            PlayerPanelOption(
              label: t.vod.subtitleOff,
              selected: _subtitleTrack == null,
              onPressed: () {
                _closePanel();
                unawaited(_selectSubtitle(null));
              },
            ),
            for (final track in tracks)
              PlayerPanelOption(
                label: track.languageName.isEmpty ? track.language : track.languageName,
                detail: track.auto ? t.vod.subtitleAuto : null,
                selected: _subtitleTrack?.id == track.id,
                onPressed: () {
                  _closePanel();
                  unawaited(_selectSubtitle(track));
                },
              ),
            if (tracks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpace.s12, vertical: DsSpace.s6),
                child: Text(
                  _extra.needsLoginForSubtitles ? t.vod.subtitleNeedsLogin : t.vod.subtitleNone,
                  style: DsTheme.of(context).typography.caption.copyWith(color: OnVideoColors.inkSubtle),
                ),
              ),
          ],
        );
    }
  }

  /// Shows the bars and, while the stream plays, lets them settle away again.
  void _wake() {
    if (mounted && !_controlsVisible) setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  /// A tap on the picture: up when they are down, down when they are up.
  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _wake();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    // An open catalogue holds the bar up; a paused stream keeps it too.
    if (_openPanel != null || !(_transport?.isPlaying ?? false)) return;
    final seconds = ref.read(playbackSettingsProvider).controlsAutoHideSeconds;
    _hideTimer = Timer(Duration(seconds: seconds), () {
      if (mounted && (_transport?.isPlaying ?? false) && _openPanel == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showPanel(_VodPanel panel) {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    if (_openPanel == panel) return;
    setState(() => _openPanel = panel);
    _hideTimer?.cancel();
    // The parts catalogue opens on the part being played, not on the first:
    // a multi-part upload hundreds deep would otherwise always start over.
    if (panel == _VodPanel.parts) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final keyContext = _currentPartKey.currentContext;
        if (keyContext != null && mounted) {
          Scrollable.ensureVisible(keyContext, alignment: 0.1, duration: const Duration(milliseconds: 120));
        }
      });
    }
  }

  void _closePanel() {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    if (_openPanel == null) return;
    setState(() => _openPanel = null);
    _scheduleHide();
  }

  /// Resting the pointer on a picker opens it after a breath, so crossing the
  /// bar on the way somewhere else does not flash every catalogue.
  void _hoverPanel(_VodPanel panel) {
    _leaveTimer?.cancel();
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 160), () {
      if (mounted) _showPanel(panel);
    });
  }

  /// The pointer leaving a picker gets a moment to reach the panel above it.
  void _leavePanelSoon() {
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    _leaveTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) _closePanel();
    });
  }

  /// Hands the first focus to the play button once there is a source: a
  /// remote or keyboard starts on the control that matters, as the room
  /// page's control bar does.
  void _giveInitialFocus() {
    if (_gaveInitialFocus) return;
    _gaveInitialFocus = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _playFocus.context == null) return;
      if (ModalRoute.of(context)?.isCurrent ?? false) {
        _playFocus.requestFocus();
      }
    });
  }

  /// The saved position for [part], when the store's entry names it.
  double? _resumeFor(VodPart part) {
    final saved = _readProgress();
    return saved != null && saved.cid == part.cid ? saved.seconds : null;
  }

  /// The archive's blurb: six lines until the viewer asks for the rest —
  /// the reference's 展开. The switch only appears when the words actually
  /// run past six lines.
  Widget _description(BuildContext context, VodDetail detail, Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final text = detail.description.isEmpty ? t.vod.noDescription : detail.description;
    final style = theme.typography.body.copyWith(color: colors.textMuted);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 6,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: DsSpace.s4,
          children: [
            Text(
              text,
              maxLines: _introExpanded ? null : 6,
              overflow: _introExpanded ? null : TextOverflow.ellipsis,
              style: style,
            ),
            if (overflows)
              DsButton(
                variant: DsButtonVariant.secondary,
                size: DsSize.sm,
                onPressed: () => setState(() => _introExpanded = !_introExpanded),
                child: Text(_introExpanded ? t.vod.collapse : t.vod.expand),
              ),
          ],
        );
      },
    );
  }

  /// The archive's details under the picture. [showParts] leaves the parts
  /// shelf out where the rail beside the picture draws it instead (the wide
  /// layout), so the page never names the same list twice.
  Widget _info(BuildContext context, VodDetail detail, Translations t, {required bool showParts}) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final silent = _play?.silent ?? _silent;
    // The station's own switch: the archive's details under the picture are
    // what a viewer hides to keep the page on the parts and the rail.
    final showDetails = ref.watch(vodPlaybackSettingsProvider).showDetails;
    final saved = savedOf(detail.bvid);
    final uploaded = detail.publishedAt;
    final plays = detail.playCount;
    final danmaku = detail.danmakuCount;
    final meta = [
      if (plays != null) '${AudienceFormat.format(plays)} ${t.vod.views}',
      if (danmaku != null) '${AudienceFormat.format(danmaku)} ${t.vod.danmaku}',
      if (uploaded != null) vodDateText(uploaded),
    ];
    final uploader = detail.uploader ?? '';
    final avatar = detail.uploaderAvatar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s16,
      children: [
        if (_error != null)
          DsAlert(
            status: DsStatus.danger,
            title: Text(t.vod.openFailed),
            description: Text(_error!),
            action: _part == null
                ? null
                : DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () => unawaited(_openPart(_part!)),
                    child: Text(t.vod.retry),
                  ),
          ),
        if (silent) DsAlert(status: DsStatus.warning, title: Text(t.vod.silentNotice)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: DsSpace.s6,
          children: [
            Text(detail.title, style: theme.typography.title.copyWith(color: colors.text)),
            if (meta.isNotEmpty)
              Text(meta.join(' · '), style: theme.typography.caption.copyWith(color: colors.textSubtle)),
          ],
        ),
        // Actions on one line, the crowd's numbers on the next: the buttons
        // are things the viewer does, the stats are things that happened,
        // and one Wrap mixed them into a single unordered strip.
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(_toggleFavourite()),
              leading: DsIcon(DsIcons.heart, size: 14, color: saved ? colors.accent : colors.textMuted),
              child: Text(saved ? t.vod.savedVideo : t.vod.saveVideo),
            ),
            // The bar's download without opening the bar: the reference's
            // own action row names it, and the address is resolved on press.
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: _part == null ? null : () => unawaited(_startDownload()),
              leading: const DsIcon(DsIcons.download, size: 14),
              child: Text(t.vod.download),
            ),
          ],
        ),
        if (detail.likeCount != null || detail.coinCount != null || detail.favoriteCount != null)
          Wrap(
            spacing: DsSpace.s16,
            runSpacing: DsSpace.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (detail.likeCount case final count?)
                _VodStat(icon: DsIcons.thumbsUp, value: count, label: t.vod.likes),
              if (detail.coinCount case final count?) _VodStat(icon: DsIcons.coins, value: count, label: t.vod.coins),
              if (detail.favoriteCount case final count?)
                _VodStat(icon: DsIcons.star, value: count, label: t.vod.favorites),
            ],
          ),
        if (showDetails && uploader.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
            child: Row(
              spacing: DsSpace.s12,
              children: [
                DsAvatar(
                  initials: avatarInitials(uploader),
                  image: avatar == null || avatar.isEmpty
                      ? null
                      : cachedImage(avatar, policy: ImageCachePolicies.avatar),
                  size: DsSize.sm,
                  toneIndex: DsAvatar.toneFor(uploader),
                  semanticLabel: uploader,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: DsSpace.s3,
                    children: [
                      Text(
                        uploader,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(color: colors.text, fontWeight: FontWeight.w600),
                      ),
                      Text(t.vod.up, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (showParts && detail.parts.length > 1)
          _PartsSection(
            parts: detail.parts,
            current: _part,
            onOpen: (part) => unawaited(_openPart(part, resume: _resumeFor(part))),
          ),
        if (showDetails) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              Text(t.vod.description, style: theme.typography.title.copyWith(color: colors.text)),
              DsCard(
                style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s12)),
                child: _description(context, detail, t),
              ),
            ],
          ),
          if (detail.aid > 0) _CommentsSection(aid: detail.aid),
        ],
      ],
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

/// The catalogues the video bar hangs over the picture. The picture's fit is
/// not one of them any more: it reads from the strip's ⋮ menu, where a choice
/// made once belongs.
enum _VodPanel { quality, parts, speed, subtitle }

/// The picture's box: a fixed 16:9 card inline, the container's own shape in
/// the immersive modes.
///
/// The compact window is already shaped to the video, and a phone turned
/// landscape has no room for bars around a card; a fixed 16:9 box there would
/// letterbox the picture a second time inside it.
final class _PictureBox extends StatelessWidget {
  const _PictureBox({required this.immersive, required this.child});

  /// Whether the surface takes the container's shape (the immersive modes).
  final bool immersive;

  /// The picture and its controls.
  final Widget child;

  @override
  Widget build(BuildContext context) => immersive ? child : AspectRatio(aspectRatio: 16 / 9, child: child);
}

/// One count in the archive's action row: the station's own reading — a
/// glyph and its number in flat ink, no capsule behind them.
final class _VodStat extends StatelessWidget {
  const _VodStat({required this.icon, required this.value, required this.label});

  final DsIconData icon;
  final int value;

  /// The count's name, spoken to the reader rather than printed.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: DsSpace.s4,
      children: [
        DsIcon(icon, size: theme.sizes.iconSm, color: colors.textMuted),
        Semantics(
          label: '$label ${AudienceFormat.format(value)}',
          child: Text(
            AudienceFormat.format(value),
            style: theme.typography.numeric(
              theme.typography.caption.copyWith(color: colors.text, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// The parts the archive splits into, as the playlist the reference's own
/// video page draws: one scrollable list — 「P1 标题」 per row, the playing
/// row highlighted and kept in view — instead of a paged strip of chips. The
/// recommendations read below the list, in the same rail.
final class _PartsSection extends StatefulWidget {
  const _PartsSection({required this.parts, required this.current, required this.onOpen});

  final List<VodPart> parts;

  /// The part the page is playing, when one is.
  final VodPart? current;

  /// Runs when the viewer picks another part.
  final void Function(VodPart part) onOpen;

  @override
  State<_PartsSection> createState() => _PartsSectionState();
}

final class _PartsSectionState extends State<_PartsSection> {
  /// One row's height, and the list's ceiling: a course running to hundreds
  /// of parts scrolls inside the panel rather than stretching the rail.
  static const double _rowHeight = 34;
  static const double _listMaxHeight = 420;

  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _keepCurrentVisible();
  }

  @override
  void didUpdateWidget(_PartsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Switching the playing part — from here or from the bar's catalogue —
    // scrolls the playing row back into view.
    if (oldWidget.current?.cid != widget.current?.cid) _keepCurrentVisible();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scrolls the playing part's row into view: a list this long opens with
  /// the thing being played on screen, not buried past the fold.
  void _keepCurrentVisible() {
    final index = _indexOf(widget.current);
    if (index < 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = (index * _rowHeight).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(target);
    });
  }

  int _indexOf(VodPart? part) {
    if (part == null) return -1;
    return widget.parts.indexWhere((candidate) => candidate.cid == part.cid);
  }

  /// Asks for a part number and opens it; an empty or unknown answer leaves
  /// the list where it was.
  Future<void> _jump() async {
    final parts = widget.parts;
    if (parts.isEmpty) return;
    final controller = TextEditingController();
    int? parse() {
      final typed = int.tryParse(controller.text.trim());
      if (typed == null) return null;
      final byPage = parts.where((part) => part.page == typed);
      if (byPage.isNotEmpty) return parts.indexOf(byPage.first);
      return typed >= 1 && typed <= parts.length ? typed - 1 : null;
    }

    final position = await showDsDialog<int>(
      context: context,
      builder: (dialogContext) {
        final t = dialogContext.t;
        return DsDialog(
          title: Text(t.vod.partsJump),
          description: DsTextField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            placeholder: '1–${parts.length}',
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
    if (position == null || position < 0 || position >= parts.length) return;
    widget.onOpen(parts[position]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final parts = widget.parts;
    final current = _indexOf(widget.current);
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
                t.vod.partsPlaylist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.title.copyWith(color: colors.text),
              ),
            ),
            Text(t.vod.partsCount(count: parts.length), style: muted),
            DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              leading: const DsIcon(DsIcons.listOrdered, size: 16),
              onPressed: () => unawaited(_jump()),
              child: Text(t.vod.partsJump),
            ),
          ],
        ),
        Container(
          height: math.min(parts.length * _rowHeight + DsSpace.s8 * 2, _listMaxHeight),
          decoration: BoxDecoration(
            color: colors.canvas,
            borderRadius: BorderRadius.circular(theme.radii.card),
            border: Border.all(color: colors.border),
          ),
          child: ListView.builder(
            controller: _scroll,
            itemExtent: _rowHeight,
            padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
            itemCount: parts.length,
            itemBuilder: (context, index) {
              final part = parts[index];
              final playing = index == current;
              return DsPressable(
                semanticLabel: 'P${part.page} ${part.title}',
                onPressed: () => widget.onOpen(part),
                builder: (context, states, child) => ColoredBox(
                  color: playing
                      ? colors.accent.withValues(alpha: 0.14)
                      : states.contains(WidgetState.hovered)
                      ? colors.hover
                      : OnVideoColors.clear,
                  child: child,
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: DsSpace.s12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(
                          'P${part.page}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.numeric(
                            theme.typography.caption.copyWith(
                              color: playing ? colors.accent : colors.textSubtle,
                              fontWeight: playing ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          part.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.caption.copyWith(
                            color: playing ? colors.accent : colors.text,
                            fontWeight: playing ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                      if (part.duration != null) Text(vodDurationText(part.duration!), style: theme.typography.numeric(muted)),
                      if (playing) ...[
                        const SizedBox(width: DsSpace.s6),
                        DsIcon(DsIcons.play, size: 12, color: colors.accent),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

final class _CommentsSection extends ConsumerStatefulWidget {
  const _CommentsSection({required this.aid});

  final int aid;

  @override
  ConsumerState<_CommentsSection> createState() => _CommentsSectionState();
}

final class _CommentsSectionState extends ConsumerState<_CommentsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodCommentsProvider.notifier).open(widget.aid));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final state = ref.watch(vodCommentsProvider.select((comments) => comments[widget.aid]));
    final comments = state?.comments ?? const <VodComment>[];
    final controller = ref.read(vodCommentsProvider.notifier);
    // The header counts what the comments endpoint reported, not the danmaku
    // figure the detail carries — until the first page lands it says nothing.
    final count = state?.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Row(
          spacing: DsSpace.s8,
          children: [
            Expanded(
              child: Text(
                count == null ? t.vod.comments : '${t.vod.comments} · ${AudienceFormat.format(count)}',
                style: theme.typography.title.copyWith(color: colors.text),
              ),
            ),
            // The reference's two orders; a pick restarts from the first page.
            DsSegmentedControl<int>(
              value: state?.sort ?? VodCommentsController.sortHot,
              onChanged: (sort) => unawaited(controller.setSort(widget.aid, sort)),
              semanticLabel: t.vod.comments,
              segments: [
                DsSegment(value: VodCommentsController.sortHot, label: Text(t.vod.commentsHot)),
                DsSegment(value: VodCommentsController.sortNewest, label: Text(t.vod.commentsNew)),
              ],
            ),
          ],
        ),
        if (state?.error case final failure?)
          DsAlert(
            status: DsStatus.danger,
            title: Text(t.vod.commentsFailed),
            description: Text(failure.message),
            action: DsButton(
              variant: DsButtonVariant.secondary,
              size: DsSize.sm,
              onPressed: () => unawaited(controller.refresh(widget.aid)),
              child: Text(t.vod.retry),
            ),
          ),
        if (state != null && state.loading && comments.isEmpty)
          const Center(child: DsSpinner(style: DsSpinnerStyle(size: 24)))
        else if (state != null && state.error == null && comments.isEmpty)
          Text(t.vod.commentsEmpty, style: theme.typography.body.copyWith(color: colors.textMuted)),
        for (final comment in comments) _CommentRow(comment: comment),
        if ((state?.hasMore ?? false) && comments.isNotEmpty)
          Center(
            child: (state?.loading ?? false)
                ? const DsSpinner(style: DsSpinnerStyle(size: 24))
                : DsButton(
                    variant: DsButtonVariant.secondary,
                    size: DsSize.sm,
                    onPressed: () => unawaited(controller.loadMore(widget.aid)),
                    child: Text(t.vod.loadMore),
                  ),
          ),
      ],
    );
  }
}

/// One comment, drawn the way the station lays its floor out: the author's
/// avatar and name, the words, then the floor's own line — when it was
/// posted, the likes it drew, the replies it gathered.
final class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});

  final VodComment comment;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final avatar = comment.avatar;
    final posted = comment.createdAt;
    final likes = comment.likeCount ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          DsAvatar(
            initials: avatarInitials(comment.author),
            image: avatar == null || avatar.isEmpty ? null : cachedImage(avatar, policy: ImageCachePolicies.userAvatar),
            size: DsSize.sm,
            toneIndex: DsAvatar.toneFor(comment.author),
            semanticLabel: comment.author,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s4,
              children: [
                Text(
                  comment.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.caption.copyWith(color: colors.link, fontWeight: FontWeight.w600),
                ),
                Text(comment.message, style: theme.typography.body.copyWith(color: colors.text)),
                Row(
                  spacing: DsSpace.s12,
                  children: [
                    if (posted != null)
                      Text(
                        vodDateText(posted),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                    if (likes > 0) ...[
                      DsIcon(DsIcons.thumbsUp, size: theme.sizes.iconXs, color: colors.textSubtle),
                      Text(
                        AudienceFormat.format(likes),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                    ],
                    if ((comment.replyCount ?? 0) > 0) ...[
                      DsIcon(DsIcons.messageCircle, size: theme.sizes.iconXs, color: colors.textSubtle),
                      Text(
                        AudienceFormat.format(comment.replyCount ?? 0),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
