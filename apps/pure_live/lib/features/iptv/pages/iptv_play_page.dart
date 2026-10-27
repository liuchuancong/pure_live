import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart' show PlatformScreenAwakeService, ScreenAwakeService;
import 'package:live_iptv/live_iptv.dart';
import 'package:live_sites/live_sites.dart'
    show LivePlayFormatSource, LivePlayLine, LiveStreamFormat, inferStreamFormat;
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/iptv/controllers/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/features/iptv/controllers/iptv_user_agent.dart' show iptvHeadersWithUserAgent, iptvUserAgentProvider;
import 'package:pure_live/features/iptv/views/iptv_guide_panel.dart' show catchupUrlOf, showIptvGuide;
import 'package:pure_live/features/room/room.dart';
import 'package:pure_live/features/settings/settings.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/shared.dart';

/// One IPTV channel on media_core's own player: the playlist entry's URL
/// and headers, the alternatives as the line menu, the guide's current
/// programme under the channel's name — no live-room machinery involved.
final class IptvPlayPage extends ConsumerStatefulWidget {
  /// Plays [channelId]; [channel] is the card's own object when it opened
  /// the page (a deep link resolves it from the library instead).
  const IptvPlayPage({required this.channelId, this.channel, super.key});

  /// The library channel id.
  final String channelId;

  /// The channel, when the caller already held it.
  final IptvChannel? channel;

  @override
  ConsumerState<IptvPlayPage> createState() => _IptvPlayPageState();
}

final class _IptvPlayPageState extends ConsumerState<IptvPlayPage> with WidgetsBindingObserver {
  LivePlaybackController? _playback;
  StreamSubscription<PlayerHandle>? _handles;
  StreamSubscription<PlayerCoreState>? _states;
  StreamSubscription<PlayerFailure>? _failures;
  PlayerHandle? _handle;
  PlayerCoreState _playbackState = PlayerCoreState.idle;
  IptvChannel? _channel;
  String? _error;

  /// The page's own mute and volume, the app-wide mute that overrides the
  /// former, and the platform default the page starts on.
  bool _muted = false;
  bool _globalMute = false;
  double _volume = 1;

  /// The Android background-playback gate and the channel it paused.
  BackgroundPlaybackGate? _backgroundGate;
  String? _backgroundPausedChannel;

  /// The programme being replayed, null while the live stream plays.
  EpgProgramme? _catchup;

  /// The addresses behind the current play: the playlist's own first, then
  /// its alternatives (or the single catch-up address).
  List<String> _urls = const [];
  int _lineIndex = 0;

  /// Keeps the on-air slot's clock moving while the page stays open.
  Timer? _tick;

  /// The display stays awake while the channel plays.
  final ScreenAwakeService _screenAwake = const PlatformScreenAwakeService();
  bool _screenHeld = false;

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
        return _playbackState.playing &&
            presentation != PresentationMode.pip &&
            presentation != PresentationMode.floating;
      },
      pause: () async {
        _backgroundPausedChannel = _channel?.id;
        await _playback?.pause();
      },
      canResume: () =>
          _backgroundPausedChannel != null &&
          _playback != null &&
          !_playbackState.playing &&
          _channel?.id == _backgroundPausedChannel,
      resume: () async {
        _backgroundPausedChannel = null;
        await _playback?.resume();
      },
    );
    _channel = widget.channel ?? ref.read(iptvLibraryProvider).value?.channelById(widget.channelId);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundGate?.dispose();
    _backgroundGate = null;
    _tick?.cancel();
    unawaited(_screenAwake.disable().catchError((Object _) {}));
    final player = _handle?.id;
    final presentation = ref.read(roomPresentationProvider);
    if (player != null && presentation != PresentationMode.normal) {
      unawaited(ref.read(roomPresentationProvider.notifier).exit(player));
    }
    unawaited(_handles?.cancel() ?? Future<void>.value());
    unawaited(_states?.cancel() ?? Future<void>.value());
    unawaited(_failures?.cancel() ?? Future<void>.value());
    unawaited(_playback?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  Future<void> _open() async {
    final channel = _channel;
    if (channel == null) {
      setState(() => _error = context.t.iptv.playerChannelMissing);
      return;
    }
    final urls = <String>{
      if (channel.entry.url.trim().isNotEmpty) channel.entry.url.trim(),
      for (final alternative in channel.entry.alternatives)
        if (alternative.trim().isNotEmpty) alternative.trim(),
    }.toList();
    if (urls.isEmpty) {
      setState(() => _error = context.t.iptv.playerNoStream);
      return;
    }
    setState(() {
      _catchup = null;
      _error = null;
    });
    await _play(urls, channel);
  }

  /// Replays [programme] from the provider's catch-up URL; a channel whose
  /// playlist cannot build one says why instead of opening the live stream
  /// under the programme's name.
  Future<void> _playCatchup(EpgProgramme programme) async {
    final channel = _channel;
    if (channel == null) return;
    final url = catchupUrlOf(channel, programme);
    if (url == null) {
      if (mounted) showDsToast(context: context, title: context.t.iptv.catchupFailed);
      return;
    }
    setState(() {
      _catchup = programme;
      _error = null;
    });
    await _play([url], channel);
  }

  Future<void> _play(List<String> urls, IptvChannel channel) async {
    if (mounted) {
      setState(() {
        _urls = List.of(urls);
        _lineIndex = 0;
      });
    }
    // The playlist line's own User-Agent wins; otherwise the viewer's custom
    // one is sent, matching what the importer uses for downloads.
    final playbackHeaders = iptvHeadersWithUserAgent(channel.entry.headers.asMap(), ref.read(iptvUserAgentProvider));
    final headers = playbackHeaders.isEmpty ? null : SourceHeaders(playbackHeaders);
    final replay = _catchup;
    final idPrefix = replay == null
        ? 'iptv:${channel.id}'
        : 'iptv:${channel.id}:catchup:${replay.start.millisecondsSinceEpoch}';
    final sources = [
      for (final (index, url) in urls.indexed)
        PlayerSource.of(
          id: SourceId('$idPrefix:$index'),
          uri: Uri.parse(url),
          type: SourceType.live,
          protocol: SourceProtocol.fromScheme(Uri.parse(url).scheme),
          format: SourceFormat.fromUri(Uri.parse(url)),
          headers: headers,
          title: replay?.title ?? channel.entry.name,
        ),
    ];
    final playback = _playback ?? LivePlaybackController(ref.read(playerKernelProvider));
    _playback = playback;
    _states ??= playback.onStateChanged.listen((state) {
      if (mounted) setState(() => _playbackState = state);
    });
    _handles ??= playback.onHandleChanged.listen((handle) {
      if (mounted) setState(() => _handle = handle);
      unawaited(_applyAudio(handle));
      unawaited(_applyEngineOptions(handle));
    });
    _failures ??= playback.onError.listen((failure) {
      if (mounted) setState(() => _error = failure.message ?? failure.code.name);
    });
    await playback.play(
      LiveSourceRequest(
        sources: sources,
        title: replay?.title ?? channel.entry.name,
        allowEngineFallback: true,
        engineOptions: await _engineOptions(),
      ),
      preferredBackend: ref.read(playerKernelBackendProvider).id,
    );
  }

  Future<void> _retry() async {
    final playback = _playback;
    if (playback == null) {
      await _open();
      return;
    }
    setState(() => _error = null);
    await playback.retry();
  }

  /// Moves to another address the playlist carries for this channel, without
  /// re-reading the list: the player switches source and keeps its session.
  Future<void> _selectLine(int index) async {
    if (index == _lineIndex || index < 0 || index >= _urls.length) return;
    setState(() {
      _lineIndex = index;
      _error = null;
    });
    await _playback?.switchLine(index);
  }

  /// Steps through the visible channels in zap order, wrapping at the ends;
  /// the page is replaced so the old engine is torn down by its own dispose.
  void _switchChannel(int delta) {
    final channel = _channel;
    final library = ref.read(iptvLibraryProvider).value;
    if (channel == null || library == null) return;
    final step = library.zapSequence().step(delta, fromId: channel.id);
    final next = step.channel;
    if (next == null || !step.needsLoad) return;
    context.pushReplacement(RouteNames.iptvPlay.replaceFirst(':channelId', next.id), extra: next);
  }

  /// Sends the address currently playing to a DLNA receiver.
  void _cast(IptvChannel channel) {
    final url = _lineIndex < _urls.length ? _urls[_lineIndex] : '';
    if (url.isEmpty) return;
    final line = LivePlayLine.of(
      url: url,
      format: inferStreamFormat(url) ?? LiveStreamFormat.other,
      formatSource: LivePlayFormatSource.inferred,
      headers: iptvHeadersWithUserAgent(channel.entry.headers.asMap(), ref.read(iptvUserAgentProvider)),
      lineLabel: channel.entry.name,
    );
    unawaited(showCastDialog(context, line: line, title: channel.entry.name));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgroundGate?.handleLifecycle(state);
  }

  bool get _effectivelyMuted => _muted || _globalMute;

  Future<void> _applyAudio(PlayerHandle handle) async {
    try {
      await handle.setVolume(_volume);
      await handle.setMute(muted: _effectivelyMuted);
    } on Object {
      // A refused audio preference is not a playback failure.
    }
  }

  /// The engine options every IPTV channel keeps for its next line or
  /// recovery: hardware decoding and the player proxy.
  List<EngineOption> _storedEngineOptions() => playerStoredEngineOptions(
    hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
    tuning: ref.read(playerTuningProvider),
    proxy: ref.read(playerProxyProvider),
  );

  /// The stored options plus the chosen shader chain; the chain lives on disk
  /// and the engine mounts it as a list option.
  Future<List<EngineOption>> _engineOptions() =>
      withSuperResolution(_storedEngineOptions(), ref.read(superResolutionModeProvider));

  /// Routes and decodes this channel like every other live player; every
  /// handle gets the stored options, so a channel switch cannot keep an old
  /// decoder or route. [extra] carries the previous preset's key resets when
  /// a recipe change happens on the running channel.
  Future<void> _applyEngineOptions(PlayerHandle handle, {List<EngineOption> extra = const []}) async {
    try {
      await handle.applyEngineOptions(<EngineOption>[...await _engineOptions(), ...extra]);
    } on Object {
      // A refused engine option is not a playback failure.
    }
  }

  /// A custom-output or driver change applies to the running channel: the
  /// stored options feed the next line, the handle gets them now, and a
  /// changed video/audio output rebuilds the render context in place.
  Future<void> _applyTuning(PlayerTuning? previous, PlayerTuning next) async {
    final playback = _playback;
    if (playback != null) unawaited(playback.updateEngineOptions(_storedEngineOptions()));
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

  Future<void> _setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (mounted) setState(() => _volume = clamped);
    final handle = _handle;
    if (handle == null) return;
    try {
      await handle.setVolume(clamped);
    } on Object {
      // Same as mute.
    }
  }

  /// The player bar's mute button. Unmuting while the app-wide mute is on
  /// clears that setting, so the button always does what its icon promises.
  Future<void> _toggleMute() async {
    final handle = _handle;
    if (handle == null) return;
    if (_globalMute && _effectivelyMuted) {
      _globalMute = false;
      _muted = false;
      unawaited(ref.read(playbackSettingsProvider.notifier).setGlobalMute(value: false));
    } else {
      _muted = !_effectivelyMuted;
    }
    if (mounted) setState(() {});
    await _applyAudio(handle);
  }

  /// Holds the display awake exactly while the channel plays and the
  /// preference allows it.
  void _syncScreenWake(bool hold) {
    if (hold == _screenHeld) return;
    _screenHeld = hold;
    unawaited((hold ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // The app-wide mute can change while this page is on screen; apply it
    // to the live handle without tearing the stream down.
    ref.listen(playbackSettingsProvider.select((settings) => settings.globalMute), (previous, next) {
      if (previous == next) return;
      if (mounted) setState(() => _globalMute = next);
      final current = _handle;
      if (current != null) unawaited(_applyAudio(current));
    });
    ref.listen(playerProxyProvider, (previous, next) {
      if (previous == next) return;
      final playback = _playback;
      if (playback != null) unawaited(playback.updateEngineOptions(_storedEngineOptions()));
    });
    ref.listen(playbackSettingsProvider.select((settings) => settings.hardwareDecoding), (previous, next) {
      if (previous == next) return;
      final playback = _playback;
      if (playback != null) unawaited(playback.updateEngineOptions(_storedEngineOptions()));
    });
    ref.listen(playerTuningProvider, (previous, next) {
      if (previous == next) return;
      unawaited(_applyTuning(previous, next));
    });
    ref.listen(superResolutionModeProvider, (previous, next) {
      if (previous == next) return;
      final current = _handle;
      if (current != null) unawaited(applySuperResolution(current, next));
    });
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final channel = _channel;
    final handle = _handle;
    final muted = _effectivelyMuted;
    final presentation = ref.watch(roomPresentationProvider);
    final fullscreen = presentation != PresentationMode.normal;
    final playing = _playbackState.playing;
    _syncScreenWake(playing && ref.watch(keepScreenOnProvider));
    final library = ref.watch(iptvLibraryProvider).value;
    final slot = channel == null ? null : library?.programmeSlot(channel);
    final canStep = channel != null && (library?.zapSequence().length ?? 0) > 1;
    final replay = _catchup;
    final subtitle = replay != null
        ? '${t.iptv.playingCatchup} · ${replay.title}'
        : switch (slot?.title) {
            final programme? => '${slot!.current != null ? t.iptv.onAir : t.iptv.upNext} · $programme',
            _ => null,
          };
    void leave() {
      if (presentation != PresentationMode.normal && handle != null) {
        unawaited(ref.read(roomPresentationProvider.notifier).exit(handle.id));
      } else {
        context.pop();
      }
    }

    return Focus(
      autofocus: true,
      child: CallbackShortcuts(
        bindings: <SingleActivator, VoidCallback>{
          // A remote's up and down keys walk the channel list, as the
          // reference's zapping does; the bar's own buttons keep the rest.
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => _switchChannel(-1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => _switchChannel(1),
          const SingleActivator(LogicalKeyboardKey.escape): leave,
          const SingleActivator(LogicalKeyboardKey.keyF): () {
            if (handle == null) return;
            final controller = ref.read(roomPresentationProvider.notifier);
            unawaited(
              presentation == PresentationMode.normal
                  ? controller.toggleFullscreen(handle.id)
                  : controller.exit(handle.id),
            );
          },
        },
        child: ColoredBox(
          color: colors.overlay,
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(DsSpace.s8, DsSpace.s8, DsSpace.s16, DsSpace.s8),
                  child: Row(
                    spacing: DsSpace.s8,
                    children: [
                      _IconButton(
                        semanticLabel: t.common.close,
                        icon: DsIcons.chevronLeft,
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(
                              channel == null
                                  ? t.iptv.playerOpening
                                  : [if (channel.number != null) '${channel.number}', channel.entry.name].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.typography.title.copyWith(color: colors.text),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.typography.caption.copyWith(
                                  color: replay != null ? colors.accent : colors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (channel != null && canStep) ...[
                        _IconButton(
                          semanticLabel: t.iptv.previousDay,
                          icon: DsIcons.chevronUp,
                          onPressed: () => _switchChannel(-1),
                        ),
                        _IconButton(
                          semanticLabel: t.iptv.nextDay,
                          icon: DsIcons.chevronDown,
                          onPressed: () => _switchChannel(1),
                        ),
                      ],
                      if (channel != null && _urls.length > 1)
                        DsMenuAnchor(
                          semanticLabel: t.room.lineLabel,
                          items: [
                            for (final (index, _) in _urls.indexed)
                              DsMenuItem(
                                leading: DsIcon(index == _lineIndex ? DsIcons.check : DsIcons.gitBranch),
                                label: Text(t.room.line(n: '${index + 1}')),
                                onPressed: () => unawaited(_selectLine(index)),
                              ),
                          ],
                          builder: (context, controller, _) => _IconButton(
                            semanticLabel: t.room.lineLabel,
                            icon: DsIcons.gitBranch,
                            onPressed: controller.toggle,
                          ),
                        ),
                      if (channel != null)
                        _IconButton(semanticLabel: t.room.cast, icon: DsIcons.cast, onPressed: () => _cast(channel)),
                      if (channel != null)
                        _IconButton(
                          semanticLabel: t.iptv.guideTitle,
                          icon: DsIcons.list,
                          onPressed: () => unawaited(
                            showIptvGuide(
                              context,
                              channel: channel,
                              catchup: _catchup,
                              onCatchup: _playCatchup,
                              onBackToLive: _open,
                            ),
                          ),
                        ),
                      if (replay != null)
                        _IconButton(
                          semanticLabel: t.iptv.backToLive,
                          icon: DsIcons.radio,
                          onPressed: () => unawaited(_open()),
                        ),
                    ],
                  ),
                ),
                Expanded(
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
                        const Center(child: AppLoadingIndicator(size: 28)),
                      if (_error != null)
                        ColoredBox(
                          color: const Color(0xB3000000),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              spacing: DsSpace.s12,
                              children: [
                                Text(
                                  t.iptv.playerOpenFailed,
                                  style: theme.typography.title.copyWith(color: colors.text),
                                ),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: theme.typography.caption.copyWith(color: colors.textMuted),
                                ),
                                DsButton(onPressed: () => unawaited(_retry()), child: Text(t.common.retry)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(DsSpace.s16, DsSpace.s8, DsSpace.s16, DsSpace.s12),
                  child: Row(
                    spacing: DsSpace.s8,
                    children: [
                      _IconButton(
                        semanticLabel: playing ? t.room.pause : t.room.play,
                        icon: playing ? DsIcons.pause : DsIcons.play,
                        onPressed: () => unawaited(_playback?.togglePlayPause() ?? Future<void>.value()),
                      ),
                      _IconButton(
                        semanticLabel: muted ? t.room.unmute : t.room.mute,
                        icon: muted ? DsIcons.volumeOff : DsIcons.volume,
                        onPressed: handle == null ? null : () => unawaited(_toggleMute()),
                      ),
                      Expanded(
                        child: DsSlider(
                          value: handle?.volume ?? _volume,
                          onChanged: handle == null ? null : (value) => unawaited(_setVolume(value)),
                          semanticLabel: t.room.volume,
                        ),
                      ),
                      _IconButton(
                        semanticLabel: fullscreen ? t.room.fullscreenOff : t.room.fullscreenOn,
                        icon: fullscreen ? DsIcons.minimize2 : DsIcons.fullscreen,
                        onPressed: handle == null
                            ? null
                            : () => unawaited(
                                fullscreen
                                    ? ref.read(roomPresentationProvider.notifier).exit(handle.id)
                                    : ref.read(roomPresentationProvider.notifier).toggleFullscreen(handle.id),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small icon-only button on the player bar: the room page's bar pattern
/// without its menu machinery.
final class _IconButton extends StatelessWidget {
  const _IconButton({required this.semanticLabel, required this.icon, required this.onPressed});

  final String semanticLabel;
  final DsIconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    return DsPressable(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      builder: (context, states, _) {
        final hovered = states.contains(WidgetState.hovered);
        return Container(
          width: theme.sizes.sm,
          height: theme.sizes.sm,
          decoration: DsBoxDecoration(
            color: hovered && onPressed != null ? colors.hover : null,
            borderRadius: theme.radii.controlCorners(null, theme.sizes.sm),
          ),
          child: Center(
            child: DsIcon(
              icon,
              size: theme.sizes.iconSm,
              color: onPressed == null ? colors.textSubtle : colors.textMuted,
            ),
          ),
        );
      },
    );
  }
}
