import 'dart:async' show StreamSubscription, Timer, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io' show File;

import 'package:desen_ui/desen_ui.dart';
import 'package:flame_barrage/flame_barrage.dart' show BarrageController, EmojiAtlas, FlameBarrageWidget;
import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart' show PlatformScreenOrientationService, ScreenOrientationService;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart' show BarrageItemMapper, DanmakuPlayerBinding;
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/live/room/player/room_barrage_config.dart' show roomBarrageConfig;
import 'package:pure_live/modules/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/modules/vod/controller/vod_download.dart';
import 'package:pure_live/modules/vod/controller/vod_library.dart';
import 'package:pure_live/modules/vod/controller/vod_playback_settings.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart' show vodQualityProvider;
import 'package:pure_live/modules/vod/controller/vod_social.dart' show VodCommentsController, vodCommentsProvider;
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

final class _VodVideoPageState extends ConsumerState<VodVideoPage> with RouteAware, WidgetsBindingObserver {
  /// The progressive mp4's default qn (720P); the source may serve lower.
  static const int _defaultQn = 64;

  VodDetail? _detail;

  /// The related archives read so far and the window of twenty the rail
  /// shows; 换一换 walks the rest and folds in what a fresh read adds.
  List<VodVideo> _relatedPool = const [];
  int _relatedStart = 0;
  bool _relatedBusy = false;
  VodPlayInfo? _play;
  VodPart? _part;

  /// The download running off this page, if one is.
  VodDownloadTask? _download;

  /// The flying danmaku engine this page owns, the bridge that keeps its
  /// clock on the part's own, and the cid the loaded timeline belongs to.
  final BarrageController _barrage = BarrageController();
  DanmakuPlayerBinding? _danmakuBinding;
  int _danmakuCid = 0;
  int _qn = _defaultQn;
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

  /// Whether the overlay bars are up; a playing stream lets them settle away.
  bool _controlsVisible = true;

  /// Whether the blurb shows in full rather than its first six lines.
  bool _introExpanded = false;
  Timer? _hideTimer;

  /// The picker whose catalogue hangs over the picture, if any.
  _VodPanel? _openPanel;
  Timer? _hoverTimer;
  Timer? _leaveTimer;

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
      unawaited(handle.pause());
    }
  }

  @override
  void dispose() {
    _download?.cancel();
    _download = null;
    _hideTimer?.cancel();
    _hoverTimer?.cancel();
    _leaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _backgroundGate?.dispose();
    _backgroundGate = null;
    _routeObserver?.unsubscribe(this);
    _saveProgress(force: true);
    _disposed = true;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _geometrySub = null;
    unawaited(_danmakuBinding?.dispose() ?? Future<void>.value());
    _danmakuBinding = null;
    _barrage.dispose();
    final handle = _handle;
    if (handle != null) {
      if (_presentationMode != PresentationMode.normal) {
        unawaited(_presentationNotifier.exit(handle.id));
      }
      unawaited(_kernel.release(handle.id));
    }
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
    try {
      final detail = await client.detail(widget.bvid);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      unawaited(_loadRelated(client));
      if (detail.parts.isEmpty) {
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
    // A download belongs to the part it was resolved for; the next part
    // resolves its own address instead of keeping this one's bytes.
    _download?.cancel();
    _download = null;
    // Keep the part being left before the page starts writing for the next
    // one; a stored position belongs to the part that reported it.
    _saveProgress(force: true);
    // The part being left loses its timeline; the next one loads its own.
    _barrage.clear();
    _danmakuCid = 0;
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
      final info = await client.playPart(bvid: widget.bvid, cid: part.cid, qn: qn ?? _qn);
      if (!mounted || _disposed) return;
      final existing = _handle;
      final handle =
          existing ??
          await kernel.create(
            config: const PlayerConfig(name: 'vod'),
            preferredBackend: ref.read(playerKernelBackendProvider).id,
          );
      if (!mounted || _disposed) {
        if (existing == null) unawaited(kernel.release(handle.id));
        return;
      }
      _handle = handle;
      _bind(handle);
      await _applyEngineOptions(handle);
      final uri = Uri.parse(info.url);
      await handle.open(
        PlayerSource.of(
          id: SourceId('vod:${widget.bvid}:${part.cid}:${DateTime.now().microsecondsSinceEpoch}'),
          uri: uri,
          type: SourceType.remote,
          protocol: SourceProtocol.fromScheme(uri.scheme),
          format: SourceFormat.fromUri(uri),
          headers: info.headers.isEmpty ? null : SourceHeaders(info.headers),
          title: _detail?.title ?? part.title,
        ),
        autoPlay: true,
      );
      await handle.setVolume(_volume);
      await handle.setMute(muted: _effectivelyMuted);
      await handle.setRate(_speed);
      final seekTo = resume ?? _resumeSeconds;
      _resumeSeconds = null;
      if (seekTo != null && seekTo > 5) {
        await handle.seek(Duration(milliseconds: (seekTo * 1000).round()));
      }
      unawaited(_loadDanmaku(part.cid));
      if (!mounted || _disposed) return;
      setState(() {
        _play = info;
        _qn = info.servedQuality ?? qn ?? _defaultQn;
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
        unawaited(kernel.release(stale.id));
      }
      setState(() {
        _opening = false;
        _transport = null;
        _error = error is VodFailure ? error.message : '$error';
      });
    }
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

  /// Writes the finished video's danmaku beside it, in the formats chosen in
  /// Settings → 弹幕 → 弹幕文件.
  Future<void> _saveDanmaku(File video, int cid) async {
    final client = ref.read(vodClientProvider);
    final formats = ref.read(danmakuSaveFormatsProvider);
    try {
      final xml = await client.danmakuXml(cid);
      final entries = BilibiliDanmakuXml.decode(xml);
      if (entries.isEmpty) return;
      await writeDanmakuFiles(video, entries, formats);
    } on Object {
      // The video is downloaded; a missing track does not undo it.
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
        if (index >= 0 && index + 1 < parts.length) {
          await _openPart(parts[index + 1], resume: _resumeFor(parts[index + 1]));
        }
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.space): _togglePlay,
        const SingleActivator(LogicalKeyboardKey.keyF): _toggleFullscreen,
        const SingleActivator(LogicalKeyboardKey.escape): _leave,
      },
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          backgroundColor: colors.surface,
          surfaceTintColor: const Color(0x00000000),
          elevation: 0,
          title: Text(detail?.title ?? t.vod.opening, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: _loading && detail == null
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
    );
  }

  Widget _body(BuildContext context, VodDetail? detail, Translations t) {
    if (detail == null) return const SizedBox.shrink();
    final colors = DsTheme.colorsOf(context);
    final player = _playerSurface(context, immersive: false);
    final info = _info(context, detail, t);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = LiveWindow.isExpanded(constraints.maxWidth);
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
            if (related != null)
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(0, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                  child: related,
                ),
              ),
          ],
        );
      },
    );
  }

  /// The picture and its controls.
  ///
  /// The bars follow the pointer — moving it over the picture brings them
  /// back, and a tap on a touch screen toggles them — while a playing stream
  /// lets them settle away again. A double tap plays or pauses, and the
  /// rendition, the part list and the speed hang their catalogues from the
  /// bar as glass panels, the way the live room's strip does. [immersive]
  /// adds the way out and the title over the picture, since the page's own
  /// headline is gone there.
  Widget _playerSurface(BuildContext context, {required bool immersive}) {
    final t = context.t;
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final handle = _handle;
    final transport = _transport;
    final playing = transport?.isPlaying ?? false;
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
                  MediaPlayerView(
                    handle: handle,
                    fit: playback.fit.boxFit,
                    backgroundColor: colors.overlay,
                  )
                else
                  const ColoredBox(color: Color(0xFF000000)),
                // The part's danmaku, on a clock the player's binding keeps
                // equal to the picture's; hidden while the layer is switched
                // off or no track loaded yet.
                if (handle != null && _danmakuCid > 0 && playback.danmakuVisible)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FlameBarrageWidget(
                        config: roomBarrageConfig(
                          danmakuStyle,
                          danmakuFps,
                          family: resolvedFontFamily(danmakuStyle.fontFamily),
                        ),
                        emojiAtlas: EmojiAtlas.instance,
                        controller: _barrage,
                      ),
                    ),
                  ),
                // The picture itself is the bar's switch: a press toggles it,
                // a double press plays or pauses.
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  onDoubleTap: handle == null
                      ? null
                      : () {
                          _wake();
                          unawaited(_togglePlay());
                        },
                ),
                if (_opening || (transport?.isBuffering ?? false))
                  const Center(child: DsSpinner(style: DsSpinnerStyle(size: 40))),
                if (immersive && showBar)
                  PositionedDirectional(top: 0, start: 0, end: 0, child: _vodTopStrip(t, detail)),
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
                          if (_download case final download? when download.status == VodDownloadStatus.running)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: DsSpace.s12, bottom: DsSpace.s4),
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: ListenableBuilder(
                                  listenable: download,
                                  builder: (context, _) => PlayerGlassPill(
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
                                          }, style: theme.typography.caption.copyWith(color: playerInk)),
                                          MediaBarButton(
                                            icon: DsIcons.x,
                                            label: t.vod.downloadCancel,
                                            size: 28,
                                            iconSize: 16,
                                            onPressed: download.cancel,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_openPanel case final panel?)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(end: DsSpace.s12, bottom: DsSpace.s4),
                              child: Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: MouseRegion(
                                  onEnter: (_) => _leaveTimer?.cancel(),
                                  onExit: (_) => _leavePanelSoon(),
                                  child: _vodPanel(t, panel),
                                ),
                              ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The strip over an immersive picture: the way out and the archive's name.
  Widget _vodTopStrip(Translations t, VodDetail? detail) {
    final theme = DsTheme.of(context);
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
            child: MediaBarButton(
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
              style: theme.typography.title.copyWith(color: playerInk),
            ),
          ),
        ],
      ),
    );
  }

  /// Resolves the current part's download address and streams it into the
  /// app's Videos folder, the bar showing how far it has come.
  ///
  /// The address is signed and short-lived, so it is resolved here rather
  /// than reused from the player; the player's own answer may be a
  /// picture-only DASH rendition, which is why the download asks for the
  /// muxed MP4 separately.
  Future<void> _startDownload() async {
    final t = context.t;
    final part = _part;
    final detail = _detail;
    if (part == null || detail == null) return;
    if (_download?.status == VodDownloadStatus.running) return;
    try {
      final info = await ref.read(vodClientProvider).downloadPart(bvid: widget.bvid, cid: part.cid, qn: _qn);
      if (!mounted) return;
      final task = VodDownloadTask(
        folder: ref.read(appPathsProvider).videos,
        url: info.url,
        headers: info.headers,
        fileName: vodDownloadFileName(
          title: detail.title,
          part: part.title,
          index: part.page,
          parts: detail.parts.length,
          extension: info.format == 'mp4' ? 'mp4' : 'm4s',
        ),
      );
      setState(() => _download = task);
      unawaited(
        task.start().then((_) {
          if (!mounted) return;
          setState(() {});
          switch (task.status) {
            case VodDownloadStatus.done:
              final file = task.file;
              if (file != null) unawaited(_saveDanmaku(file, part.cid));
              final name = task.file?.uri.pathSegments.last ?? task.fileName;
              showDsToast(
                context: context,
                title: t.vod.downloadDone(name: name),
                status: DsStatus.success,
              );
            case VodDownloadStatus.failed:
              showDsToast(context: context, title: t.vod.downloadFailed, status: DsStatus.danger);
            case VodDownloadStatus.cancelled:
              showDsToast(context: context, title: t.vod.downloadCancelled);
            case VodDownloadStatus.running:
              break;
          }
        }),
      );
    } on Object {
      if (mounted) showDsToast(context: context, title: t.vod.downloadFailed, status: DsStatus.danger);
    }
  }

  /// The bar under the picture: the seek line over the transport, then the
  /// rendition, the parts, the speed and the presentation verbs.
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
    final fit = playback.fit;
    final timeStyle = theme.typography.numeric(theme.typography.caption.copyWith(color: playerInk));
    return Container(
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
                child: DsSlider(
                  value: duration.inMilliseconds <= 0
                      ? 0
                      : position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble(),
                  max: duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds.toDouble(),
                  onChanged: duration.inMilliseconds <= 0
                      ? null
                      : (value) => setState(() => _dragSeconds = value / 1000),
                  onChangeEnd: duration.inMilliseconds <= 0
                      ? null
                      : (value) {
                          final seconds = value / 1000;
                          setState(() => _dragSeconds = null);
                          unawaited(_seekTo(seconds));
                        },
                  semanticLabel: t.vod.progress,
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
              // then the pickers' words, so a phone — or a desktop's paned
              // picture — never overflows.
              final compact = LiveWindow.isCompact(constraints.maxWidth);
              return Row(
                spacing: DsSpace.s4,
                children: [
                  MediaBarButton(
                    icon: playing ? DsIcons.pause : DsIcons.play,
                    label: playing ? t.vod.pause : t.vod.play,
                    focusNode: _playFocus,
                    onPressed: handle == null
                        ? null
                        : () {
                            _wake();
                            unawaited(_togglePlay());
                          },
                  ),
                  MediaBarButton(
                    icon: _effectivelyMuted ? DsIcons.volumeOff : DsIcons.volume,
                    label: _effectivelyMuted ? t.vod.unmute : t.vod.mute,
                    onPressed: handle == null
                        ? null
                        : () {
                            _wake();
                            unawaited(_setMuted(muted: !_effectivelyMuted));
                          },
                  ),
                  if (!compact)
                    SizedBox(
                      width: 96,
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
                  const Spacer(),
                  MediaBarButton(
                    icon: danmakuVisible ? DsIcons.captions : DsIcons.captionsOff,
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
                  if (qualities.isNotEmpty)
                    _vodPickerButton(
                      panel: _VodPanel.quality,
                      icon: DsIcons.gauge,
                      label: _play?.quality ?? t.vod.quality,
                      semanticLabel: t.vod.quality,
                      compact: compact,
                    ),
                  if (parts.length > 1)
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
                    label: VodSpeedChoice.nearest(_speed).label(t),
                    semanticLabel: t.vod.speed,
                    compact: compact,
                  ),
                  // The picture is already 16:9 on a phone, so the ratio's
                  // one more control stays out of the compact bar.
                  if (!compact)
                    _vodPickerButton(
                      panel: _VodPanel.fit,
                      icon: DsIcons.aspectRatio,
                      label: fitLabels(t)[fit.index],
                      semanticLabel: t.settings.fit,
                      compact: compact,
                    ),
                  MediaBarButton(
                    icon: DsIcons.download,
                    label: t.vod.download,
                    onPressed: _part == null || _detail == null
                        ? null
                        : () {
                            _wake();
                            unawaited(_startDownload());
                          },
                  ),
                  if (handle != null && presentationController.pipAvailable)
                    MediaBarButton(
                      icon: presentation == PresentationMode.pip
                          ? DsIcons.pictureInPictureExit
                          : DsIcons.pictureInPicture,
                      label: presentation == PresentationMode.pip ? t.room.pipOff : t.vod.pip,
                      onPressed: () {
                        _wake();
                        unawaited(_togglePip());
                      },
                    ),
                  MediaBarButton(
                    icon: immersive ? DsIcons.minimize2 : DsIcons.fullscreen,
                    label: immersive ? t.vod.exitFullscreen : t.vod.fullscreen,
                    onPressed: handle == null
                        ? null
                        : () {
                            _wake();
                            unawaited(_toggleFullscreen());
                          },
                  ),
                ],
              );
            },
          ),
        ],
      ),
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
    return MouseRegion(
      onEnter: (_) => _hoverPanel(panel),
      onExit: (_) => _leavePanelSoon(),
      child: TvFocusScale(
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
            final lit = open || states.contains(WidgetState.hovered);
            return Container(
              height: theme.sizes.sm,
              padding: EdgeInsets.symmetric(horizontal: compact ? DsSpace.s6 : DsSpace.s8),
              decoration: DsBoxDecoration(
                color: lit ? playerInkHover : null,
                borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [
                  DsIcon(icon, size: theme.sizes.iconSm, color: playerInkMuted),
                  if (!compact)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: playerInk),
                      ),
                    ),
                  DsIcon(open ? DsIcons.chevronDown : DsIcons.chevronUp, size: 12, color: playerInkMuted),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The open picker's catalogue.
  Widget _vodPanel(Translations t, _VodPanel panel) {
    switch (panel) {
      case _VodPanel.quality:
        final qualities = _play?.qualities ?? const <VodQuality>[];
        return PlayerOverlayPanel(
          title: t.vod.quality,
          width: 200,
          children: [
            for (final quality in qualities)
              PlayerPanelOption(
                label: quality.label,
                selected: quality.qn == _qn,
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
          width: 260,
          children: [
            for (final candidate in parts)
              PlayerPanelOption(
                label: 'P${candidate.page} ${candidate.title}',
                selected: candidate.cid == _part?.cid,
                onPressed: () {
                  _closePanel();
                  unawaited(_openPart(candidate, resume: _resumeFor(candidate)));
                },
              ),
          ],
        );
      case _VodPanel.speed:
        return PlayerOverlayPanel(
          title: t.vod.speed,
          width: 180,
          children: [
            for (final choice in VodSpeedChoice.values)
              PlayerPanelOption(
                label: choice.label(t),
                selected: choice.value == _speed,
                onPressed: () {
                  _closePanel();
                  unawaited(_setSpeed(choice.value));
                },
              ),
          ],
        );
      case _VodPanel.fit:
        final fit = ref.watch(playbackSettingsProvider).fit;
        return PlayerOverlayPanel(
          title: t.settings.fit,
          width: 180,
          children: [
            for (final option in PlaybackFit.values)
              PlayerPanelOption(
                label: fitLabels(t)[option.index],
                selected: option == fit,
                onPressed: () {
                  _closePanel();
                  unawaited(ref.read(playbackSettingsProvider.notifier).setFit(option));
                },
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
                variant: DsButtonVariant.ghost,
                size: DsSize.sm,
                onPressed: () => setState(() => _introExpanded = !_introExpanded),
                child: Text(_introExpanded ? t.vod.collapse : t.vod.expand),
              ),
          ],
        );
      },
    );
  }

  Widget _info(BuildContext context, VodDetail detail, Translations t) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final silent = _play?.silent ?? _silent;
    // The station's own switch: the archive's details under the picture are
    // what a viewer hides to keep the page on the parts and the rail.
    final showDetails = ref.watch(vodPlaybackSettingsProvider).showDetails;
    final saved = ref.watch(vodFavouritesProvider).any((video) => video.bvid == detail.bvid);
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
              onPressed: _part == null || _download?.status == VodDownloadStatus.running
                  ? null
                  : () => unawaited(_startDownload()),
              leading: const DsIcon(DsIcons.download, size: 14),
              child: Text(t.vod.download),
            ),
            if (detail.likeCount case final count?) _VodStat(icon: DsIcons.thumbsUp, value: count, label: t.vod.likes),
            if (detail.coinCount case final count?) _VodStat(icon: DsIcons.coins, value: count, label: t.vod.coins),
            if (detail.favoriteCount case final count?)
              _VodStat(icon: DsIcons.star, value: count, label: t.vod.favorites),
          ],
        ),
        if (showDetails && uploader.isNotEmpty)
          DsCard(
            style: const DsCardStyle(padding: EdgeInsets.all(DsSpace.s12)),
            child: Row(
              spacing: DsSpace.s12,
              children: [
                DsAvatar(
                  initials: uploader,
                  image: avatar == null || avatar.isEmpty ? null : cachedImage(avatar),
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
        if (detail.parts.length > 1)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              Text(
                '${t.vod.parts} · ${detail.parts.length}',
                style: theme.typography.title.copyWith(color: colors.text),
              ),
              Wrap(
                spacing: DsSpace.s8,
                runSpacing: DsSpace.s8,
                children: [
                  for (final candidate in detail.parts)
                    DsButton(
                      variant: DsButtonVariant.secondary,
                      size: DsSize.sm,
                      onPressed: () => unawaited(_openPart(candidate, resume: _resumeFor(candidate))),
                      leading: candidate.cid == _part?.cid ? const DsIcon(DsIcons.play, size: 12) : null,
                      child: Text('P${candidate.page} ${candidate.title}'),
                    ),
                ],
              ),
            ],
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

/// The catalogues the video bar hangs over the picture.
enum _VodPanel { quality, parts, speed, fit }

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

/// One count beside the save button: what the archive collected, read off
/// the picture's own ink rather than a heading.
final class _VodStat extends StatelessWidget {
  const _VodStat({required this.icon, required this.value, required this.label});

  final DsIconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpace.s8, vertical: DsSpace.s4),
      decoration: BoxDecoration(
        color: colors.control.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(DsRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: DsSpace.s4,
        children: [
          DsIcon(icon, size: theme.sizes.iconXs, color: colors.textMuted),
          Text(
            AudienceFormat.format(value),
            style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.text)),
          ),
          Text(label, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
        ],
      ),
    );
  }
}

/// The archive's comments: twenty at a time, hot or newest first, read on
/// demand.
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

/// One comment: the author's avatar and name, when, the words, and the likes.
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
      padding: const EdgeInsets.symmetric(vertical: DsSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: DsSpace.s8,
        children: [
          DsAvatar(
            initials: comment.author,
            image: avatar == null || avatar.isEmpty ? null : cachedImage(avatar),
            size: DsSize.xs,
            toneIndex: DsAvatar.toneFor(comment.author),
            semanticLabel: comment.author,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: DsSpace.s3,
              children: [
                Row(
                  spacing: DsSpace.s8,
                  children: [
                    Flexible(
                      child: Text(
                        comment.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: colors.textMuted),
                      ),
                    ),
                    if (posted != null)
                      Text(
                        vodDateText(posted),
                        style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                      ),
                  ],
                ),
                Text(comment.message, style: theme.typography.body.copyWith(color: colors.text)),
                Row(
                  spacing: DsSpace.s4,
                  children: [
                    DsIcon(DsIcons.thumbsUp, size: theme.sizes.iconXs, color: colors.textSubtle),
                    Text(
                      AudienceFormat.format(likes),
                      style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.textSubtle)),
                    ),
                    if ((comment.replyCount ?? 0) > 0) ...[
                      const SizedBox(width: DsSpace.s8),
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
