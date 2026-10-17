import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_library/live_library.dart' show WatchRecordIdentity;
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_playback/live_playback.dart' show EngineProgress, EngineReady, EngineStopped, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart'
    show PlayerAdapterDurationChanged, PlayerAdapterEvent, PlayerAdapterPlaying, PlayerAdapterPositionChanged;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitVideoView;
import 'package:pure_live/app/engine/playback_engine.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/room/danmaku_pane.dart';
import 'package:pure_live/features/room/room_info_card.dart';
import 'package:pure_live/features/room/room_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:window_manager/window_manager.dart' show windowManager;

/// The room page (the reference's `LivePlayPage`, on the workspace stack):
/// the player with its quality and line selectors, the info card with the
/// follow toggle, and the interaction pane — a sidebar next to the video on
/// a wide window, a bottom sheet over it on a narrow one.
///
/// Degraded on purpose:
/// - **Picture-in-picture / the floating window** is not offered. The
///   reference drives media_core's PiP presentation service, which this app
///   does not wire; faking one would just be a smaller video. Fullscreen
///   (the OS window on the desktop, an in-app presentation elsewhere) is.
/// - **Danmaku sending** is unavailable until the app grows a platform
///   login layer — see [DanmakuPane].
final class RoomPage extends ConsumerStatefulWidget {
  /// Opens [roomId] on [siteId]; [roomName] titles the bar until the room
  /// detail arrives.
  const new({required this.siteId, required this.roomId, this.roomName = '', super.key});

  /// The platform the room belongs to.
  final String siteId;

  /// The platform-specific room id.
  final String roomId;

  /// A caller-provided title hint.
  final String roomName;

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

final class _RoomPageState extends ConsumerState<RoomPage> {
  /// How long the fullscreen overlay stays up after a tap.
  static const _overlayHold = Duration(seconds: 4);

  /// How often watch progress is written back while playback runs. Deliberately
  /// coarse: each write is a history upsert (a store save), and a resume target
  /// five seconds off is close enough.
  static const _progressWriteInterval = Duration(seconds: 5);

  /// A saved position closer than this to the start is not worth seeking to —
  /// the room would play from the top anyway.
  static const _seekWorthwhile = Duration(seconds: 5);

  /// The narrow layout's sheet stops, as fractions of the body height (the
  /// reference's `portraitPanelRange`): the pane is always on screen.
  static const _sheetMinFraction = 0.32;
  static const _sheetMidFraction = 0.48;
  static const _sheetMaxFraction = 0.72;

  late final MediaCorePlaybackEngine _engine = MediaCorePlaybackEngine();
  StreamSubscription<PlaybackEngineEvent>? _engineSub;
  final FocusNode _shortcutsFocus = FocusNode();
  Timer? _overlayTimer;

  LiveRoom? _room;
  Object? _detailError;
  bool _loading = false;

  List<LivePlayQuality> _qualities = const [];
  LivePlayQuality? _selectedQuality;
  List<LivePlayLine> _lines = const [];
  LivePlayLine? _currentLine;
  bool _loadingLines = false;
  Object? _streamError;

  /// The engine reported a stop: the surface offers a retry that re-resolves
  /// the lines (a single-use URL never plays twice).
  bool _engineStopped = false;

  bool _paused = false;

  /// The watch-progress writeback: a coarse ticker, the last position it
  /// wrote (equal positions — a paused or ended player — are skipped) and
  /// whether the saved resume position has already been applied.
  Timer? _progressTimer;
  Duration? _lastWrittenPosition;
  bool _resumeApplied = false;

  /// Where to seek once a real duration shows up — the position the watch
  /// history saved, carried from [_load]. Null for a first watch, and never
  /// honoured on a live stream (no duration, nothing to resume).
  Duration? _pendingResumePosition;

  /// Events of the currently playing adapter, watched for the first real
  /// duration report that arms the resume seek. Re-subscribed on every
  /// line switch — a switch swaps the adapter underneath the engine.
  StreamSubscription<PlayerAdapterEvent>? _adapterSub;

  /// The presentation mode: a black canvas, the chrome hidden. On the
  /// desktop it drives the OS window's fullscreen; elsewhere it is in-app.
  bool _fullscreen = false;
  bool _overlayVisible = true;

  /// The narrow layout's sheet height, null = the middle stop.
  double? _sheetHeight;

  RoomIdentity get _identity => (siteId: widget.siteId, roomId: widget.roomId);

  /// The entry parse: both ids must be present and the site must exist. The
  /// route carries them as path segments, so a blank or unknown one is a
  /// malformed entry, not a network failure — its error state says so.
  bool get _entryValid => widget.siteId.trim().isNotEmpty && widget.roomId.trim().isNotEmpty;

  LiveSite? get _site => _entryValid ? ref.read(sitesProvider).registry.getById(widget.siteId) : null;

  bool get _wide => switch (ref.watch(environmentProvider).runtime.formFactor) {
    FormFactor.desktop || FormFactor.tv => true,
    FormFactor.phone || FormFactor.tablet => false,
  };

  @override
  void initState() {
    super.initState();
    _engineSub = _engine.events.listen(_onEngineEvent);
    _progressTimer = Timer.periodic(_progressWriteInterval, (_) => _writeProgress());
    unawaited(_load());
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    unawaited(_adapterSub?.cancel());
    // The final write goes first: it reads the adapter that
    // _engine.dispose() is about to tear down.
    _writeProgress(force: true);
    _overlayTimer?.cancel();
    unawaited(_engineSub?.cancel());
    unawaited(_engine.dispose());
    _shortcutsFocus.dispose();
    if (_fullscreen) {
      // Leaving the route returns the OS window it took over.
      unawaited(windowManager.setFullScreen(false));
    }
    super.dispose();
  }

  void _onEngineEvent(PlaybackEngineEvent event) {
    if (!mounted) {
      return;
    }
    switch (event) {
      case EngineReady():
        setState(() {
          _engineStopped = false;
          _streamError = null;
          _paused = false;
        });
      case EngineStopped():
        setState(() => _engineStopped = true);
      case EngineProgress():
        break;
    }
  }

  /// Adapter events feed the resume seek only; the writeback ticks on its
  /// own timer and reads the adapter's current position and duration.
  void _onAdapterEvent(PlayerAdapterEvent event) {
    switch (event) {
      case PlayerAdapterDurationChanged() || PlayerAdapterPositionChanged() || PlayerAdapterPlaying():
        _maybeResumeSeek();
      default:
        break;
    }
  }

  /// Applies the saved resume position, once per room visit, when the
  /// adapter reports a real duration — the sign the source is a replay or
  /// VOD rather than a live stream. The seek waits for that report instead
  /// of racing the open (a seek handed to mpv before the media is loaded is
  /// accepted but easy to lose); every position, duration and playing event
  /// re-runs this until the report lands.
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

  /// Writes the watched fraction back to the history — the resume point the
  /// history cards draw.
  ///
  /// Only a source with a real duration (a replay or VOD) has progress; a
  /// live stream reports none, and its entry keeps the visit snapshot the
  /// `_load` upsert made. A tick whose position has not moved since the
  /// last write — paused, ended, stalled — is skipped; [force] writes
  /// regardless, for the pause and room-exit flushes.
  void _writeProgress({bool force = false}) {
    if (!mounted || !_entryValid) {
      return;
    }
    final adapter = _engine.surfaceAdapter;
    final duration = adapter?.duration;
    if (adapter == null || duration == null || duration <= Duration.zero) {
      return;
    }
    final position = adapter.position;
    if (position <= Duration.zero) {
      // Nothing watched yet: the record the `_load` upsert (and its
      // re-asserted resume point) made stands.
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
            siteId: widget.siteId,
            roomId: widget.roomId,
            progress: position.inMilliseconds / duration.inMilliseconds,
            position: position,
          ),
    );
  }

  Future<void> _load() async {
    if (_loading) {
      return;
    }
    setState(() {
      _loading = true;
      _detailError = null;
    });
    try {
      final site = _site;
      if (site == null) {
        // The route named a site the registry does not know (or carried a
        // blank id): the room cannot even be looked up — its error state.
        setState(() => _detailError = StateError('unknown site "${widget.siteId}"'));
        return;
      }
      final roomCapability = site.capability<LiveRoomProvider>();
      if (roomCapability != null) {
        final detail = await roomCapability.getRoom(widget.roomId);
        if (!mounted) {
          return;
        }
        setState(() {
          detail.fold((error) => _detailError = error, (room) => _room = room);
        });
      }
      // The visit enters the watch history as soon as the room resolves —
      // whether or not any line ends up playing.
      final known = _room;
      final repository = ref.read(historyRepositoryProvider);
      // `record` rewrites the entry without watch progress, so the saved
      // resume point is read off the previous entry first and re-asserted
      // after the upsert — a visit whose playback never starts keeps its
      // progress instead of silently resetting it.
      final previous = repository.records
          .where((record) => record.identity == LiveRoom.normalized(platform: widget.siteId, roomId: widget.roomId).identityKey)
          .firstOrNull;
      final savedProgress = previous?.progress;
      final savedPosition = previous?.position;
      await repository.record(
        known ??
            LiveRoom.normalized(
              platform: widget.siteId,
              roomId: widget.roomId,
              content: RoomContent(title: widget.roomName),
            ),
      );
      if (previous != null && (savedProgress != null || savedPosition != null)) {
        _pendingResumePosition = savedPosition;
        await repository.updateProgress(
          siteId: widget.siteId,
          roomId: widget.roomId,
          progress: savedProgress ?? 0.0,
          position: savedPosition,
        );
      }
      await _loadQualities();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadQualities() async {
    final capability = _site?.capability<LivePlaybackProvider>();
    if (capability == null) {
      // No playback capability: the surface shows what the room detail says
      // (offline or live), with no selectors to offer.
      return;
    }
    final result = await capability.getQualities(roomId: widget.roomId);
    if (!mounted) {
      return;
    }
    setState(() {
      result.fold((error) => _streamError = error, (qualities) {
        _qualities = qualities;
        _selectedQuality = qualities.isEmpty ? null : qualities.first;
      });
    });
    await _openLines();
  }

  Future<void> _openLines({LivePlayQuality? quality}) async {
    final capability = _site?.capability<LivePlaybackProvider>();
    if (capability == null) {
      return;
    }
    setState(() {
      _loadingLines = true;
      _engineStopped = false;
      _streamError = null;
      if (quality != null) {
        _selectedQuality = quality;
      }
    });
    final result = await capability.getLines(roomId: widget.roomId, quality: quality ?? _selectedQuality);
    if (!mounted) {
      return;
    }
    final lines = result.fold((error) {
      _streamError = error;
      return <LivePlayLine>[];
    }, (lines) => lines);
    setState(() {
      _lines = lines;
      _loadingLines = false;
    });
    if (lines.isNotEmpty) {
      await _play(lines.first);
    }
  }

  Future<void> _play(LivePlayLine line) async {
    setState(() {
      _currentLine = line;
      _engineStopped = false;
      _paused = false;
    });
    await _engine.open(line);
    if (!mounted) {
      return;
    }
    // A line switch swaps the adapter; watch the new one for the duration
    // report that arms the resume seek. The direct call covers a duration
    // the adapter already knows.
    unawaited(_adapterSub?.cancel());
    _adapterSub = _engine.surfaceAdapter?.events.listen(_onAdapterEvent);
    _maybeResumeSeek();
  }

  /// A retry re-resolves the current quality's lines: a lease-expired or
  /// single-use URL never plays again by re-opening it.
  void _retry() {
    unawaited(_openLines(quality: _selectedQuality));
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      // The pause position is the one the user chose to stop on: flush it
      // past the five-second throttle.
      _writeProgress(force: true);
      unawaited(_engine.pause());
    } else {
      unawaited(_engine.resume());
    }
  }

  Future<void> _setFullscreen(bool on) async {
    setState(() {
      _fullscreen = on;
      _overlayVisible = true;
    });
    _scheduleOverlayHide();
    // The OS window only follows on the desktop; touch layouts get the
    // in-app presentation.
    if (switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    }) {
      await windowManager.setFullScreen(on);
    }
  }

  void _scheduleOverlayHide() {
    final previous = _overlayTimer;
    previous?.cancel();
    _overlayTimer = Timer(_overlayHold, () {
      if (mounted && _fullscreen) {
        setState(() => _overlayVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen) {
      return CallbackShortcuts(
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => unawaited(_setFullscreen(false))},
        child: Focus(autofocus: true, child: _presentation(context)),
      );
    }
    final body = _wide ? _wideLayout(context) : _narrowLayout(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => unawaited(_setFullscreen(true)),
        const SingleActivator(LogicalKeyboardKey.space): _togglePause,
      },
      child: Focus(
        autofocus: true,
        child: PureScaffold(appBar: _appBar(context), body: body),
      ),
    );
  }

  PureAppBar _appBar(BuildContext context) => PureAppBar(
    title: _title(),
    actions: [
      PureIconButton(
        tooltip: context.t.room.fullscreen,
        icon: Icons.fullscreen,
        onPressed: () => unawaited(_setFullscreen(true)),
      ),
      const SettingsEntryButton(),
    ],
  );

  String _title() {
    final detail = _room?.content.title;
    if (detail != null && detail.isNotEmpty) {
      return detail;
    }
    if (widget.roomName.isNotEmpty) {
      return widget.roomName;
    }
    return widget.roomId;
  }

  /// The desktop split (the reference's `desktopSplit`): the video column
  /// beside the pane.
  Widget _wideLayout(BuildContext context) {
    final detailReady = _room != null || _detailError != null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(child: _player(context)),
              _controlsRow(context),
              if (detailReady) _infoCard(context),
            ],
          ),
        ),
        SizedBox(
          width: 360,
          child: ColoredBox(
            color: Colors.black,
            child: DanmakuPane(identity: _identity),
          ),
        ),
      ],
    );
  }

  /// The narrow bottom sheet (the reference's portrait interaction): the
  /// video keeps the canvas while the pane rides a draggable sheet with
  /// min/middle/max stops.
  Widget _narrowLayout(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final minimum = (height * _sheetMinFraction).clamp(200.0, height);
        final middle = (height * _sheetMidFraction).clamp(minimum, height);
        final maximum = (height * _sheetMaxFraction).clamp(middle, height);
        final current = (_sheetHeight ?? middle).clamp(minimum, maximum);
        return Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  AspectRatio(aspectRatio: 16 / 9, child: _player(context)),
                  const Spacer(),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: current,
              child: Material(
                elevation: 8,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) =>
                          setState(() => _sheetHeight = (current - details.delta.dy).clamp(minimum, maximum)),
                      onVerticalDragEnd: (details) => setState(() {
                        // Snap to the nearest stop, with a downward fling
                        // collapsing to the minimum.
                        final target = details.primaryVelocity != null && details.primaryVelocity! > 600
                            ? minimum
                            : current;
                        final stops = [minimum, middle, maximum]
                          ..sort((a, b) => (a - target).abs().compareTo((b - target).abs()));
                        _sheetHeight = stops.first;
                      }),
                      child: SizedBox(
                        height: 22,
                        width: double.infinity,
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: PureTheme.of(context).colors.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // The quality / line row rides at the sheet's top, the
                    // reference's portrait sheet does.
                    _controlsRow(context),
                    Expanded(child: _infoCard(context)),
                    const Divider(height: 1),
                    Expanded(flex: 3, child: DanmakuPane(identity: _identity, dark: false)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The video and its states: the live surface, the loading spinner, the
  /// stream failure, or the platform's own offline verdict.
  Widget _player(BuildContext context) {
    final adapter = _engine.surfaceAdapter;
    final Widget surface;
    if (adapter != null) {
      surface = MediaKitVideoView(adapter: adapter);
    } else if (_loadingLines || _loading) {
      surface = const Center(child: PureSpinner(size: 40));
    } else if (_engineStopped || _streamError != null) {
      surface = _failedSurface(context);
    } else if (_lines.isEmpty && (_room?.broadcast.isExplicitlyOfflineNow ?? false)) {
      surface = PureEmpty(title: context.t.room.offline, icon: Icons.tv_off_outlined, message: _room?.content.title);
    } else if (_detailError != null) {
      surface = PureError(
        message: context.t.room.entryFailed,
        retryLabel: context.t.common.retry,
        onRetry: () => unawaited(_load()),
      );
    } else {
      surface = const SizedBox.expand();
    }
    return ColoredBox(color: Colors.black, child: surface);
  }

  Widget _failedSurface(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.t.room.failed, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        PureButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _retry),
      ],
    ),
  );

  /// The quality / line row under the video, the reference's `ResolutionsRow`.
  Widget _controlsRow(BuildContext context) {
    final switching = _loadingLines;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          PureIconButton(
            tooltip: _paused ? context.t.room.play : context.t.room.pause,
            icon: _paused ? Icons.play_circle_outline : Icons.pause_circle_outline,
            onPressed: _currentLine == null ? null : _togglePause,
          ),
          const SizedBox(width: 8),
          if (_qualities.isNotEmpty)
            Expanded(
              child: PureSelect<LivePlayQuality>(
                items: _qualities,
                value: _selectedQuality,
                itemLabel: (quality) => quality.label,
                enabled: !switching,
                onChanged: (quality) => unawaited(_openLines(quality: quality)),
              ),
            ),
          if (_lines.length > 1) ...[
            const SizedBox(width: 8),
            Expanded(
              child: PureSelect<int>(
                items: [for (var i = 0; i < _lines.length; i++) i],
                value: _currentLine == null ? null : _lines.indexOf(_currentLine!),
                enabled: !switching,
                itemLabel: (index) {
                  final label = _lines[index].lineLabel;
                  return label == null || label.isEmpty ? context.t.room.lineN(n: '${index + 1}') : label;
                },
                onChanged: (index) => unawaited(_play(_lines[index])),
              ),
            ),
          ],
          const SizedBox(width: 8),
          PureIconButton(
            tooltip: context.t.room.fullscreen,
            icon: Icons.fullscreen,
            onPressed: () => unawaited(_setFullscreen(true)),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context) => RoomInfoCard(identity: _identity, room: _stubOrDetail());

  /// The detail when it arrived, else the identity the route carried — the
  /// follow toggle works on the room's identity either way.
  LiveRoom _stubOrDetail() => _room ?? LiveRoom.normalized(platform: widget.siteId, roomId: widget.roomId);

  /// The presentation canvas: the video fills the window, a tap brings the
  /// overlay back, Escape leaves. (Picture-in-picture is a media_core
  /// presentation this app does not wire — see the class doc.)
  Widget _presentation(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _overlayVisible = !_overlayVisible);
        _scheduleOverlayHide();
      },
      child: Container(
        color: Colors.black,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // The same surface states as the windowed player — offline and
            // entry failures read correctly here too.
            Positioned.fill(child: _player(context)),
            if (_overlayVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.55),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      PureIconButton(
                        tooltip: context.t.room.exitFullscreen,
                        icon: Icons.fullscreen_exit,
                        onPressed: () => unawaited(_setFullscreen(false)),
                      ),
                      PureIconButton(
                        tooltip: _paused ? context.t.room.play : context.t.room.pause,
                        icon: _paused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                        onPressed: _currentLine == null ? null : _togglePause,
                      ),
                      const SizedBox(width: 8),
                      if (_qualities.isNotEmpty)
                        Expanded(
                          child: PureSelect<LivePlayQuality>(
                            items: _qualities,
                            value: _selectedQuality,
                            itemLabel: (quality) => quality.label,
                            onChanged: (quality) => unawaited(_openLines(quality: quality)),
                          ),
                        ),
                      if (_lines.length > 1) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: PureSelect<int>(
                            items: [for (var i = 0; i < _lines.length; i++) i],
                            value: _currentLine == null ? null : _lines.indexOf(_currentLine!),
                            itemLabel: (index) {
                              final label = _lines[index].lineLabel;
                              return label == null || label.isEmpty ? context.t.room.lineN(n: '${index + 1}') : label;
                            },
                            onChanged: (index) => unawaited(_play(_lines[index])),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
