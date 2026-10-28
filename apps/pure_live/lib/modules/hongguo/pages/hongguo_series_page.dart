import 'dart:async' show StreamSubscription, unawaited;
import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart' show AppBar, Scaffold;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart' show PlatformScreenOrientationService, ScreenOrientationService;
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:media_core/media_core.dart';

import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_client.dart'
    show hongguoClientProvider, hongguoFailureText, hongguoPickRendition, hongguoStreamProxyProvider;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart' show hongguoSettingsProvider;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart' show hongguoDurationText;
import 'package:pure_live/shared/shared.dart';

/// One series' page: the player over media_core, the episodes as numbered
/// tiles, and the series' own metadata — the station's series page, reduced
/// to what the companion service provides.
///
/// Playback is one shared media_core handle fed the service's decrypted,
/// rangeable mp4. Progress is saved per series (episode + seconds) so a
/// return resumes where it stopped, and a finished episode leads to the
/// next one on its own.
final class HongguoSeriesPage extends ConsumerStatefulWidget {
  /// The series behind [seriesId].
  const HongguoSeriesPage({required this.seriesId, super.key});

  /// The series' id.
  final String seriesId;

  @override
  ConsumerState<HongguoSeriesPage> createState() => _HongguoSeriesPageState();
}

final class _HongguoSeriesPageState extends ConsumerState<HongguoSeriesPage>
    with RouteAware, WidgetsBindingObserver {
  HongguoSeriesDetail? _detail;
  HongguoEpisode? _episode;
  PlayerHandle? _handle;
  PlayerId? _boundPlayer;
  final FocusNode _playFocus = FocusNode(debugLabel: 'hongguo-play');
  StreamSubscription<PlayerTransportState>? _transportSub;
  StreamSubscription<PlayerAdapterEvent>? _eventSub;
  StreamSubscription<GeometryState>? _geometrySub;
  PlayerTransportState? _transport;
  DateTime _lastSave = DateTime.fromMillisecondsSinceEpoch(0);
  bool _loading = true;
  bool _opening = false;
  bool _disposed = false;
  bool _finished = false;
  bool _introExpanded = false;
  String? _error;
  double? _dragSeconds;
  double? _resumeSeconds;
  bool _muted = false;
  bool _globalMute = false;
  double _volume = 1;
  double _speed = 1;

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

  /// Another page covers this one: the picture pauses rather than playing
  /// under it.
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
    _routeObserver?.unsubscribe(this);
    _saveProgress(force: true);
    _disposed = true;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _geometrySub = null;
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
      _transport = null;
      _resumeSeconds = null;
    });
    try {
      final detail = await ref.read(hongguoClientProvider).detail(widget.seriesId);
      if (!mounted || _disposed) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      final episodes = detail.episodes;
      if (episodes.isEmpty) return;
      final resume = _readProgress();
      final start =
          episodes.firstWhere(
            (episode) => episode.index == resume?.$1,
            orElse: () => episodes.first,
          );
      await _openEpisode(start, resume: resume?.$2);
    } on Object catch (error) {
      if (!mounted || _disposed) return;
      setState(() {
        _loading = false;
        _error = hongguoFailureText(error);
      });
    }
  }

  /// Opens [episode] on the shared kernel, reusing the page's handle; a
  /// finished episode's last seconds are not replayed.
  Future<void> _openEpisode(HongguoEpisode episode, {double? resume}) async {
    if (_opening) return;
    _saveProgress(force: true);
    setState(() {
      _opening = true;
      _error = null;
      _episode = episode;
      _transport = null;
      _dragSeconds = null;
      _finished = false;
    });
    final client = ref.read(hongguoClientProvider);
    // The episode being left stops before the next address is fetched, so a
    // failed switch cannot leave it sounding under the new episode's page.
    final previous = _handle;
    if (previous != null) {
      try {
        await previous.pause();
      } on Object {
        // The switch itself reports a player that will not answer.
      }
    }
    try {
      // The ladder answers the renditions the platform serves this episode;
      // the pick rides through the local decrypting proxy so the player
      // reads plain mp4 off the loopback.
      final ladder = await client.playbackLadder(episode.vid);
      if (!mounted || _disposed) return;
      final rendition = hongguoPickRendition(ladder, ref.read(hongguoSettingsProvider).quality.maxHeight);
      final url = await ref.read(hongguoStreamProxyProvider).register(rendition);
      if (!mounted || _disposed) return;
      final existing = _handle;
      final handle =
          existing ??
          await _kernel.create(
            config: const PlayerConfig(name: 'hongguo'),
            preferredBackend: ref.read(playerKernelBackendProvider).id,
          );
      if (!mounted || _disposed) {
        if (existing == null) unawaited(_kernel.release(handle.id));
        return;
      }
      _handle = handle;
      _bind(handle);
      await _applyEngineOptions(handle);
      final uri = Uri.parse(url);
      await handle.open(
        PlayerSource.of(
          id: SourceId('hongguo:${widget.seriesId}:${episode.vid}:${DateTime.now().microsecondsSinceEpoch}'),
          uri: uri,
          type: SourceType.remote,
          protocol: SourceProtocol.fromScheme(uri.scheme),
          format: SourceFormat.fromUri(uri),
          title: _detail?.meta.title ?? episode.title,
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
      setState(() => _opening = false);
    } on Object catch (error) {
      if (!mounted || _disposed) return;
      // The handle may still hold the previous episode; it is not the
      // episode this page now names, so it goes rather than playing on
      // behind a failed switch.
      final stale = _handle;
      if (stale != null) {
        _handle = null;
        unawaited(_kernel.release(stale.id));
      }
      setState(() {
        _opening = false;
        _transport = null;
        _error = hongguoFailureText(error);
      });
    }
  }

  void _bind(PlayerHandle handle) {
    if (_boundPlayer == handle.id) return;
    _boundPlayer = handle.id;
    unawaited(_transportSub?.cancel() ?? Future<void>.value());
    unawaited(_eventSub?.cancel() ?? Future<void>.value());
    unawaited(_geometrySub?.cancel() ?? Future<void>.value());
    _geometrySub = handle.geometryController.state.listen((state) {
      final size = state.geometry.videoSize;
      if (size.width <= 0 || size.height <= 0) return;
      _aspectRatio = size.width / size.height;
      // The fullscreen and compact-window drivers shape their surfaces from
      // the picture's own size.
      ref.read(fullscreenDriverProvider).onVideoSize(size.width, size.height);
    });
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
  }

  /// A finished episode leads to the next one; the last one stands on its
  /// final frame with its progress marked complete.
  Future<void> _handleFinished() async {
    if (_finished) return;
    _finished = true;
    _saveProgress(force: true, completed: true);
    final episodes = _detail?.episodes ?? const <HongguoEpisode>[];
    final current = _episode;
    if (current == null) return;
    final index = episodes.indexWhere((episode) => episode.vid == current.vid);
    if (index >= 0 && index + 1 < episodes.length) {
      await _openEpisode(episodes[index + 1]);
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

  /// The engine options this page keeps for every episode and handle:
  /// hardware decoding and the stored outputs. The player proxy is left out —
  /// the stream is always the companion service on this machine, and a proxy
  /// client asked for a loopback address usually refuses the connection.
  List<EngineOption> _storedEngineOptions() => playerStoredEngineOptions(
    hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
    tuning: ref.read(playerTuningProvider),
    proxy: (mode: PlayerProxyMode.off, host: '', port: kDefaultPlayerProxyPort),
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

  Future<void> _toggleFullscreen() async {
    final handle = _handle;
    if (handle == null) return;
    await _presentationNotifier.toggleFullscreen(handle.id);
  }

  void _leave() {
    final handle = _handle;
    // A phone's picture-in-picture window floats over the page; leaving the
    // page is the way out of it (the system owns its own close).
    if (handle != null && _presentationNotifier.modeOwnsWindow(_presentationMode)) {
      unawaited(_presentationNotifier.exit(handle.id));
      return;
    }
    context.pop();
  }

  String get _progressKey => 'hongguo.progress.${widget.seriesId}';

  (int, double)? _readProgress() {
    try {
      final raw = StoragePrefs.getString(_progressKey);
      if (raw == null || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      // A finished series keeps its history entry but is not resumed.
      if (json['completed'] == true) return null;
      final index = (json['index'] as num?)?.toInt();
      final seconds = (json['seconds'] as num?)?.toDouble();
      if (index == null || seconds == null || seconds <= 0) return null;
      return (index, seconds);
    } on Object {
      return null;
    }
  }

  /// Saves the episode and position at most once every few seconds, the
  /// same record a return resumes from.
  void _saveProgress({bool force = false, bool completed = false}) {
    final episode = _episode;
    final transport = _transport;
    if (episode == null || transport == null) return;
    final total = transport.duration.inMilliseconds;
    final position = transport.position.inMilliseconds;
    if (total <= 0 || position <= 0) return;
    final now = DateTime.now();
    if (!force && now.difference(_lastSave) < const Duration(seconds: 5)) return;
    _lastSave = now;
    final done = completed || position >= total - 5000;
    final detail = _detail;
    try {
      unawaited(
        StoragePrefs.setString(
          _progressKey,
          jsonEncode({
            'index': episode.index,
            'vid': episode.vid,
            'seconds': done ? total / 1000 : position / 1000,
            'title': detail?.meta.title ?? episode.title,
            'cover': detail?.meta.cover,
            'durationSeconds': total / 1000,
            'updatedAt': now.millisecondsSinceEpoch,
            if (done) 'completed': true,
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
      final handle = _handle;
      if (handle != null) {
        unawaited(
          handle.setMute(muted: _muted || next).catchError((Object _) {
            // A refused mute is not a playback failure.
          }),
        );
      }
    });
    ref.listen(effectivePlayerProxyProvider, (previous, next) {
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
    // Leaving fullscreen — by any hand, including the system's — puts the
    // keyboard back on the play control.
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
    // A phone entering system fullscreen asks the viewer's portrait policy
    // which way it turns; the driver's exit path puts the lock back.
    ref.listen(roomPresentationProvider, (previous, next) {
      if (next != PresentationMode.fullscreen || previous == PresentationMode.fullscreen) return;
      applyFullscreenOrientation(
        _screenOrientation,
        policy: ref.read(portraitSettingsProvider).fullscreenPolicy,
        aspectRatio: _aspectRatio,
      );
    });
    final presentation = ref.watch(roomPresentationProvider);
    final t = context.t;
    final detail = _detail;
    final colors = DsTheme.colorsOf(context);
    final presentationController = ref.read(roomPresentationProvider.notifier);
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
          title: Text(detail?.meta.title ?? t.hongguo.opening, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        body: _loading && detail == null
            ? const Center(child: DsSpinner(style: DsSpinnerStyle(size: 28)))
            : _error != null && detail == null
            ? Center(
                child: DsEmptyState(
                  icon: const DsIcon(DsIcons.cloudOff),
                  title: Text(t.hongguo.loadFailed),
                  description: Text(_error!),
                  actions: [DsButton(onPressed: () => unawaited(_load()), child: Text(t.common.retry))],
                ),
              )
            : _body(context, detail, t),
      ),
    );
  }

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

  Widget _body(BuildContext context, HongguoSeriesDetail? detail, Translations t) {
    if (detail == null) return const SizedBox.shrink();
    final player = _playerSurface(context, immersive: false);
    final info = _info(context, detail, t);
    final episodes = _episodes(context, detail, t);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        if (!wide) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: DsSpace.s16,
              children: [player, episodes, info],
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
            SizedBox(
              width: 320,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, DsSpace.s12, DsSpace.s24, DsSpace.s24),
                child: episodes,
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
    final theme = DsTheme.of(context);
    final handle = _handle;
    final transport = _transport;
    final detail = _detail;
    final duration = transport?.duration ?? Duration.zero;
    final position = _dragSeconds != null
        ? Duration(milliseconds: (_dragSeconds! * 1000).round())
        : transport?.position ?? Duration.zero;
    final playing = transport?.isPlaying ?? false;
    final next = _nextEpisode();
    return ClipRRect(
      borderRadius: BorderRadius.circular(immersive ? 0 : theme.radii.overlay),
      child: ColoredBox(
        color: colors.overlay,
        child: AspectRatio(
          aspectRatio: _aspectRatio > 0 ? _aspectRatio : 16 / 9,
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
                          label: t.hongguo.exitFullscreen,
                          onPressed: () => unawaited(_toggleFullscreen()),
                          onDark: true,
                          autofocus: true,
                        ),
                        Expanded(
                          child: Text(
                            detail?.meta.title ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.typography.title.copyWith(color: const Color(0xFFFFFFFF)),
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
                              hongguoDurationText(position),
                              textAlign: TextAlign.center,
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
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
                              semanticLabel: t.hongguo.progress,
                            ),
                          ),
                          SizedBox(
                            width: 54,
                            child: Text(
                              hongguoDurationText(duration),
                              textAlign: TextAlign.center,
                              style: theme.typography.numeric(
                                theme.typography.caption.copyWith(color: const Color(0xFFFFFFFF)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 560;
                          return Row(
                            spacing: DsSpace.s4,
                            children: [
                              _PlayerIconButton(
                                icon: playing ? DsIcons.pause : DsIcons.play,
                                label: playing ? t.hongguo.pause : t.hongguo.play,
                                onPressed: handle == null ? null : () => unawaited(_togglePlay()),
                                focusNode: _playFocus,
                                onDark: true,
                              ),
                              _PlayerIconButton(
                                icon: _effectivelyMuted ? DsIcons.volumeOff : DsIcons.volume,
                                label: _effectivelyMuted ? t.hongguo.unmute : t.hongguo.mute,
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
                                    semanticLabel: t.hongguo.volume,
                                  ),
                                ),
                              const Spacer(),
                              if (next != null)
                                _PlayerIconButton(
                                  icon: DsIcons.skipForward,
                                  label: t.hongguo.nextEpisode,
                                  onPressed: () => unawaited(_openEpisode(next)),
                                  onDark: true,
                                ),
                              _PlayerMenu(
                                label: '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                                icon: DsIcons.timer,
                                semanticLabel: t.hongguo.speed,
                                compact: compact,
                                items: [
                                  for (final speed in const <double>[0.5, 0.75, 1, 1.25, 1.5, 2])
                                    DsMenuItem(
                                      label: Text('${speed == speed.roundToDouble() ? speed.toInt() : speed}x'),
                                      checked: speed == _speed,
                                      onPressed: () => unawaited(_setSpeed(speed)),
                                    ),
                                ],
                              ),
                              _PlayerIconButton(
                                icon: DsIcons.maximize2,
                                label: t.hongguo.fullscreen,
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

  /// The episode after the one held, in episode order.
  HongguoEpisode? _nextEpisode() {
    final episodes = _detail?.episodes ?? const <HongguoEpisode>[];
    final current = _episode;
    if (current == null) return null;
    final index = episodes.indexWhere((episode) => episode.vid == current.vid);
    if (index < 0 || index + 1 >= episodes.length) return null;
    return episodes[index + 1];
  }

  /// The episodes as numbered tiles — the station's own shelf of squares,
  /// with the one playing lit.
  Widget _episodes(BuildContext context, HongguoSeriesDetail detail, Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final current = _episode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(t.hongguo.episodes, style: theme.typography.title.copyWith(color: colors.text)),
        Wrap(
          spacing: DsSpace.s8,
          runSpacing: DsSpace.s8,
          children: [
            for (final episode in detail.episodes)
              DsChip(
                label: Text('${episode.index}'),
                selected: episode.vid == current?.vid && episode.index == current?.index,
                onChanged: episode.vid == current?.vid && episode.index == current?.index
                    ? null
                    : (_) => unawaited(_openEpisode(episode)),
                semanticLabel: t.hongguo.episodeLabel(index: episode.index),
              ),
          ],
        ),
      ],
    );
  }

  /// The series' own metadata: the status and figures, the shelf
  /// categories, and the story blurb with its way to read all of it.
  Widget _info(BuildContext context, HongguoSeriesDetail detail, Translations t) {
    final theme = DsTheme.of(context);
    final colors = DsTheme.colorsOf(context);
    final meta = detail.meta;
    final figures = <String>[
      if (meta.statusText.isNotEmpty) meta.statusText,
      if (meta.playCount > 0) '${t.hongguo.plays} ${AudienceFormat.format(meta.playCount)}',
      if (meta.followedCount > 0) '${t.hongguo.followers} ${AudienceFormat.format(meta.followedCount)}',
      if (meta.episodeCount > 0) t.hongguo.episodesCount(count: meta.episodeCount),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: DsSpace.s8,
      children: [
        Text(meta.title, style: theme.typography.title.copyWith(color: colors.text)),
        if (figures.isNotEmpty)
          Text(
            figures.join(' · '),
            style: theme.typography.caption.copyWith(color: colors.textMuted),
          ),
        if (meta.categories.isNotEmpty)
          Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [for (final category in meta.categories) DsBadge(label: Text(category), dot: false)],
          ),
        if (meta.intro.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: DsSpace.s4,
            children: [
              GestureDetector(
                onTap: () => setState(() => _introExpanded = !_introExpanded),
                child: Text(
                  meta.intro,
                  maxLines: _introExpanded ? null : 3,
                  overflow: _introExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: theme.typography.body.copyWith(color: colors.textMuted),
                ),
              ),
              DsLink(
                label: _introExpanded ? t.hongguo.collapse : t.hongguo.expand,
                onPressed: () => setState(() => _introExpanded = !_introExpanded),
              ),
            ],
          ),
      ],
    );
  }
}

/// An icon button on the dark control bar.
final class _PlayerIconButton extends StatelessWidget {
  /// The button for [icon].
  const _PlayerIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.autofocus = false,
    this.onDark = false,
    this.focusNode,
  });

  /// The glyph.
  final DsIconData icon;

  /// The control's name, shown on hover and to semantics.
  final String label;

  /// Null disables the control.
  final VoidCallback? onPressed;

  /// Whether the keyboard lands here first.
  final bool autofocus;

  /// Whether the button sits on the picture's dark gradient.
  final bool onDark;

  /// The node the keyboard returns to after a presentation change.
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
  /// The menu for [items].
  const _PlayerMenu({
    required this.label,
    required this.icon,
    required this.semanticLabel,
    required this.items,
    this.compact = false,
  });

  /// The menu's own label.
  final String label;

  /// The glyph beside it.
  final DsIconData icon;

  /// The menu's name, for semantics.
  final String semanticLabel;

  /// The menu's entries.
  final List<Widget> items;

  /// Whether the bar is too narrow for the label.
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
