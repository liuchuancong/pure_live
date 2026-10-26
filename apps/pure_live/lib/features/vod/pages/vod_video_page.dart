import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:live_vod/live_vod.dart';
import 'package:media_core/media_core.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/features/vod/controller/vod_controller.dart' show vodClientProvider;
import 'package:pure_live/features/vod/controller/vod_settings.dart' show vodQualityProvider;
import 'package:pure_live/features/vod/widgets/vod_widgets.dart' show VodVideoRow, vodDurationText;
import 'package:pure_live/l10n/translations.dart';
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

  static const List<double> _speeds = [0.5, 0.75, 1, 1.25, 1.5, 2];

  VodDetail? _detail;
  List<VodVideo> _related = const [];
  VodPlayInfo? _play;
  VodPart? _part;
  int _qn = _defaultQn;
  PlayerHandle? _handle;
  PlayerId? _boundPlayer;
  final FocusNode _playFocus = FocusNode(debugLabel: 'vod-play');
  StreamSubscription<PlayerTransportState>? _transportSub;
  StreamSubscription<PlayerAdapterEvent>? _eventSub;
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

  /// The Android background-playback gate and the handle it paused.
  BackgroundPlaybackGate? _backgroundGate;
  PlayerId? _backgroundPausedHandle;

  /// The window's observer, kept for `dispose` where the provider scope may
  /// already be gone.
  RouteObserver<ModalRoute<void>>? _routeObserver;

  bool get _effectivelyMuted => _muted || _globalMute;

  @override
  void initState() {
    super.initState();
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
    WidgetsBinding.instance.removeObserver(this);
    _backgroundGate?.dispose();
    _backgroundGate = null;
    _routeObserver?.unsubscribe(this);
    _saveProgress(force: true);
    _disposed = true;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    final handle = _handle;
    if (handle != null) {
      if (ref.read(roomPresentationProvider) != PresentationMode.normal) {
        unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
      }
      unawaited(ref.read(playerKernelProvider).release(handle.id));
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
      // Bilibili offers up to forty; the page's rail keeps the first
      // twenty, which is what its own page shows.
      setState(() => _related = related.take(20).toList());
    } on Object {
      // Related videos are a bonus; the page stands without them.
    }
  }

  /// Opens [part] on the shared kernel, reusing the page's handle.
  Future<void> _openPart(VodPart part, {int? qn, double? resume}) async {
    if (_opening) return;
    // Keep the part being left before the page starts writing for the next
    // one; a stored position belongs to the part that reported it.
    _saveProgress(force: true);
    setState(() {
      _opening = true;
      _error = null;
      _part = part;
      _play = null;
      _silent = false;
      _transport = null;
      _dragSeconds = null;
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
        PlayerSource(
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
    _transportSub = handle.playbackStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _transport = state;
        // A recovered engine keeps playing; the notice belongs to the
        // failure that stopped it, not to a session that healed.
        if (state.isPlaying) _error = null;
      });
      _saveProgress();
    });
    _eventSub = handle.adapterEvents.listen((event) {
      if (!mounted || event is! PlayerAdapterErrorEvent) return;
      setState(() {
        _opening = false;
        _error = event.message;
      });
    });
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
      final options = <EngineOption>[
        ...await withSuperResolution(_storedEngineOptions(), ref.read(superResolutionModeProvider)),
        ...extra,
      ];
      await handle.applyEngineOptions(options);
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
    await ref.read(roomPresentationProvider.notifier).togglePip(handle.id);
  }

  void _leave() {
    final handle = _handle;
    if (handle != null && ref.read(roomPresentationProvider) != PresentationMode.normal) {
      unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
      return;
    }
    context.pop();
  }

  String get _progressKey => 'vod.progress.${widget.bvid}';

  ({int cid, double seconds})? _readProgress() {
    try {
      final raw = StoragePrefs.getString(_progressKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final cid = (json['cid'] as num?)?.toInt();
      final seconds = (json['seconds'] as num?)?.toDouble();
      if (cid == null || seconds == null || seconds <= 0) return null;
      return (cid: cid, seconds: seconds);
    } on Object {
      return null;
    }
  }

  /// Saves the part and position at most once every few seconds; a position
  /// at the archive's end clears the entry instead of resuming there.
  void _saveProgress({bool force = false}) {
    final part = _part;
    final transport = _transport;
    if (part == null || transport == null) return;
    final total = transport.duration.inMilliseconds;
    final position = transport.position.inMilliseconds;
    if (total <= 0 || position <= 0) return;
    if (position >= total - 5000) {
      try {
        unawaited(StoragePrefs.remove(_progressKey));
      } on Object {
        // A preference; a closed store loses it.
      }
      return;
    }
    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 5)) return;
    _lastSave = now;
    try {
      unawaited(StoragePrefs.setString(_progressKey, jsonEncode({'cid': part.cid, 'seconds': position / 1000})));
    } on Object {
      // Same as above.
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentation = ref.watch(roomPresentationProvider);
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
    ref.listen(superResolutionModeProvider, (previous, next) {
      if (previous == next) return;
      final handle = _handle;
      if (handle != null) unawaited(applySuperResolution(handle, next));
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
    final immersive = presentation != PresentationMode.normal;
    final t = context.t;
    final detail = _detail;
    final colors = DsTheme.colorsOf(context);
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
    final related = _related.isEmpty
        ? null
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              Text(t.vod.related, style: DsTheme.of(context).typography.title.copyWith(color: colors.text)),
              for (final video in _related)
                VodVideoRow(video: video, onOpen: () => unawaited(context.push('/vod/${video.bvid ?? video.id}'))),
            ],
          );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
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

  /// The picture and its controls; [immersive] adds the way out and the
  /// title over the picture, since the page's app bar is gone there.
  Widget _playerSurface(BuildContext context, {required bool immersive}) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final handle = _handle;
    final transport = _transport;
    final part = _part;
    final detail = _detail;
    final duration = transport?.duration ?? detail?.duration ?? part?.duration ?? Duration.zero;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    final playing = transport?.isPlaying ?? false;
    final qualities = _play?.qualities ?? const <VodQuality>[];
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive ? 0 : DsTheme.of(context).radii.overlay),
      child: ColoredBox(
        color: colors.overlay,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (handle != null)
                MediaPlayerView(
                  handle: handle,
                  fit: ref.watch(playbackSettingsProvider).fit.boxFit,
                  backgroundColor: colors.overlay,
                )
              else
                const ColoredBox(color: Color(0xFF000000)),
              if (immersive)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  end: 0,
                  child: Container(
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
                        _PlayerIconButton(
                          icon: DsIcons.minimize2,
                          label: t.vod.exitFullscreen,
                          onPressed: () => unawaited(_toggleFullscreen()),
                          onDark: true,
                          autofocus: true,
                        ),
                        Expanded(
                          child: Text(
                            detail?.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DsTheme.of(context).typography.title.copyWith(color: const Color(0xFFFFFFFF)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_opening || (transport?.isBuffering ?? false))
                const Center(child: DsSpinner(style: DsSpinnerStyle(size: 40))),
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
                    children: [
                      Row(
                        spacing: DsSpace.s8,
                        children: [
                          SizedBox(
                            width: 54,
                            child: Text(
                              vodDurationText(position),
                              textAlign: TextAlign.center,
                              style: DsTheme.of(context).typography.numeric(
                                DsTheme.of(context).typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                              ),
                            ),
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
                            child: Text(
                              vodDurationText(duration),
                              textAlign: TextAlign.center,
                              style: DsTheme.of(context).typography.numeric(
                                DsTheme.of(context).typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // The bar gives way from the outside in: the volume
                          // slider, then the menus' labels, so a phone — or a
                          // desktop's paned picture — never overflows.
                          final compact = constraints.maxWidth < 640;
                          final parts = detail?.parts ?? const <VodPart>[];
                          return Row(
                            spacing: DsSpace.s4,
                            children: [
                              _PlayerIconButton(
                                icon: playing ? DsIcons.pause : DsIcons.play,
                                label: playing ? t.vod.pause : t.vod.play,
                                onPressed: handle == null ? null : () => unawaited(_togglePlay()),
                                focusNode: _playFocus,
                                onDark: true,
                              ),
                              _PlayerIconButton(
                                icon: _effectivelyMuted ? DsIcons.volumeOff : DsIcons.volume,
                                label: _effectivelyMuted ? t.vod.unmute : t.vod.mute,
                                onPressed: handle == null
                                    ? null
                                    : () => unawaited(_setMuted(muted: !_effectivelyMuted)),
                                onDark: true,
                              ),
                              if (!compact)
                                SizedBox(
                                  width: 100,
                                  child: DsSlider(
                                    value: _effectivelyMuted ? 0 : _volume,
                                    onChanged: handle == null ? null : (value) => unawaited(_setVolume(value)),
                                    semanticLabel: t.vod.volume,
                                  ),
                                ),
                              const Spacer(),
                              if (qualities.isNotEmpty)
                                _PlayerMenu(
                                  label: _play?.quality ?? t.vod.quality,
                                  icon: DsIcons.gauge,
                                  semanticLabel: t.vod.quality,
                                  compact: compact,
                                  items: [
                                    for (final quality in qualities)
                                      DsMenuItem(
                                        label: Text(quality.label),
                                        checked: quality.qn == _qn,
                                        onPressed: () {
                                          final current = part;
                                          if (current == null) return;
                                          final resume = _transport?.position.inMilliseconds;
                                          unawaited(
                                            _openPart(
                                              current,
                                              qn: quality.qn,
                                              resume: resume == null ? null : resume / 1000,
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              if (parts.length > 1)
                                _PlayerMenu(
                                  label: 'P${part?.page ?? 1}',
                                  icon: DsIcons.listVideo,
                                  semanticLabel: t.vod.parts,
                                  compact: compact,
                                  items: [
                                    for (final candidate in parts)
                                      DsMenuItem(
                                        label: Text('P${candidate.page} ${candidate.title}'),
                                        checked: candidate.cid == part?.cid,
                                        onPressed: () => unawaited(_openPart(candidate, resume: _resumeFor(candidate))),
                                      ),
                                  ],
                                ),
                              _PlayerMenu(
                                label: _speed == 1 ? t.vod.speed : '${_speed}x',
                                icon: DsIcons.timer,
                                semanticLabel: t.vod.speed,
                                compact: compact,
                                items: [
                                  for (final speed in _speeds)
                                    DsMenuItem(
                                      label: Text('${speed}x'),
                                      checked: speed == _speed,
                                      onPressed: () => unawaited(_setSpeed(speed)),
                                    ),
                                ],
                              ),
                              if (handle != null && ref.read(roomPresentationProvider.notifier).pipAvailable)
                                _PlayerIconButton(
                                  icon: DsIcons.pictureInPicture,
                                  label: t.vod.pip,
                                  onPressed: () => unawaited(_togglePip()),
                                  onDark: true,
                                ),
                              _PlayerIconButton(
                                icon: immersive ? DsIcons.minimize2 : DsIcons.fullscreen,
                                label: immersive ? t.vod.exitFullscreen : t.vod.fullscreen,
                                onPressed: handle == null ? null : () => unawaited(_toggleFullscreen()),
                                onDark: true,
                              ),
                            ],
                          );
                        },
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

  Widget _info(BuildContext context, VodDetail detail, Translations t) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final stats = <(DsIconData, String?, String)>[
      (DsIcons.eye, AudienceFormat.format(detail.playCount), t.vod.views),
      (DsIcons.messageCircle, AudienceFormat.format(detail.danmakuCount), t.vod.danmaku),
      (DsIcons.thumbsUp, AudienceFormat.format(detail.likeCount), t.vod.likes),
      (DsIcons.coins, AudienceFormat.format(detail.coinCount), t.vod.coins),
      (DsIcons.star, AudienceFormat.format(detail.favoriteCount), t.vod.favorites),
    ];
    final silent = _play?.silent ?? _silent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s12,
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
        Text(detail.title, style: theme.typography.title.copyWith(color: colors.text)),
        Row(
          spacing: DsSpace.s8,
          children: [
            ClipOval(
              child: detail.uploaderAvatar == null
                  ? SizedBox(
                      width: 36,
                      height: 36,
                      child: ColoredBox(color: colors.control, child: const DsIcon(DsIcons.user)),
                    )
                  : DsImage(
                      image: cachedImage(detail.uploaderAvatar!),
                      width: 36,
                      height: 36,
                      aspectRatio: 1,
                      semanticLabel: detail.uploader,
                    ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: DsSpace.s3,
                children: [
                  if ((detail.uploader ?? '').isNotEmpty)
                    Text(detail.uploader!, style: theme.typography.body.copyWith(color: colors.text)),
                  Text(t.vod.up, style: theme.typography.caption.copyWith(color: colors.textMuted)),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          spacing: DsSpace.s16,
          runSpacing: DsSpace.s8,
          children: [
            for (final (icon, value, label) in stats)
              if (value != null && value.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: DsSpace.s4,
                  children: [
                    DsIcon(icon, size: theme.sizes.iconSm, color: colors.textSubtle),
                    Text(value, style: theme.typography.numeric(theme.typography.caption.copyWith(color: colors.text))),
                    Text(label, style: theme.typography.caption.copyWith(color: colors.textSubtle)),
                  ],
                ),
          ],
        ),
        if (detail.parts.length > 1)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: DsSpace.s8,
            children: [
              Text(t.vod.parts, style: theme.typography.title.copyWith(color: colors.text)),
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
        Text(t.vod.description, style: theme.typography.title.copyWith(color: colors.text)),
        Text(
          detail.description.isEmpty ? t.vod.noDescription : detail.description,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: theme.typography.body.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

/// A square icon action over the picture: white ink, hover lightening on the
/// dark surface.
final class _PlayerIconButton extends StatelessWidget {
  const _PlayerIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.autofocus = false,
    this.onDark = false,
    this.focusNode,
  });

  final DsIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool autofocus;
  final bool onDark;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    final ink = onDark ? const Color(0xFFFFFFFF) : DsTheme.colorsOf(context).text;
    return DsTooltip(
      message: label,
      child: DsPressable(
        semanticLabel: label,
        onPressed: onPressed,
        autofocus: autofocus,
        focusNode: focusNode,
        builder: (context, states, _) {
          final hovered = states.contains(WidgetState.hovered);
          return Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: DsBoxDecoration(
              color: hovered ? const Color(0x33FFFFFF) : null,
              borderRadius: BorderRadius.circular(theme.radii.control(36)),
            ),
            child: DsIcon(icon, size: 18, color: onPressed == null ? const Color(0x66FFFFFF) : ink),
          );
        },
      ),
    );
  }
}

/// A labelled menu over the picture: the current choice and a chevron, or
/// just the icon where the bar is too narrow for labels.
final class _PlayerMenu extends StatelessWidget {
  const _PlayerMenu({
    required this.label,
    required this.icon,
    required this.semanticLabel,
    required this.items,
    this.compact = false,
  });

  final String label;
  final DsIconData icon;
  final String semanticLabel;
  final List<Widget> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = DsTheme.of(context);
    return DsMenuAnchor(
      semanticLabel: semanticLabel,
      items: items,
      builder: (context, controller, _) => DsTooltip(
        message: semanticLabel,
        child: DsPressable(
          semanticLabel: semanticLabel,
          onPressed: controller.toggle,
          builder: (context, states, _) {
            final hovered = states.contains(WidgetState.hovered);
            return Container(
              height: 36,
              width: compact ? 36 : null,
              padding: EdgeInsetsDirectional.symmetric(horizontal: compact ? 0 : DsSpace.s8),
              alignment: Alignment.center,
              decoration: DsBoxDecoration(
                color: hovered ? const Color(0x33FFFFFF) : null,
                borderRadius: BorderRadius.circular(theme.radii.control(36)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: DsSpace.s4,
                children: [
                  DsIcon(icon, size: 16, color: const Color(0xFFFFFFFF)),
                  if (!compact) ...[
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                      ),
                    ),
                    const DsIcon(DsIcons.chevronDown, size: 12, color: Color(0xCCFFFFFF)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
