import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_device/live_device.dart' show PlatformScreenAwakeService, ScreenAwakeService;
import 'package:live_iptv/live_iptv.dart';
import 'package:live_sites/live_sites.dart' show LivePlayFormatSource, LivePlayLine, LiveStreamFormat, inferStreamFormat;
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/providers/player_providers.dart' show playerKernelProvider;
import 'package:pure_live/app/providers/presentation_providers.dart' show roomPresentationProvider;
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/features/iptv/iptv_controller.dart' show iptvLibraryProvider;
import 'package:pure_live/features/iptv/iptv_guide_panel.dart' show catchupUrlOf, showIptvGuide;
import 'package:pure_live/features/room/cast_dialog.dart' show showCastDialog;
import 'package:pure_live/l10n/translations.dart';

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

final class _IptvPlayPageState extends ConsumerState<IptvPlayPage> {
  LivePlaybackController? _playback;
  StreamSubscription<PlayerHandle>? _handles;
  StreamSubscription<PlayerCoreState>? _states;
  StreamSubscription<PlayerFailure>? _failures;
  PlayerHandle? _handle;
  PlayerCoreState _playbackState = PlayerCoreState.idle;
  IptvChannel? _channel;
  String? _error;

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
    final headers = channel.entry.headers.isEmpty ? null : SourceHeaders(channel.entry.headers);
    final replay = _catchup;
    final idPrefix = replay == null
        ? 'iptv:${channel.id}'
        : 'iptv:${channel.id}:catchup:${replay.start.millisecondsSinceEpoch}';
    final sources = [
      for (final (index, url) in urls.indexed)
        PlayerSource(
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
    });
    _failures ??= playback.onError.listen((failure) {
      if (mounted) setState(() => _error = failure.message ?? failure.code.name);
    });
    await playback.play(
      LiveSourceRequest(sources: sources, title: replay?.title ?? channel.entry.name, allowEngineFallback: true),
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
      headers: channel.entry.headers,
      lineLabel: channel.entry.name,
    );
    unawaited(showCastDialog(context, line: line, title: channel.entry.name));
  }

  /// Holds the display awake exactly while the channel plays.
  void _syncScreenWake(bool playing) {
    if (playing == _screenHeld) return;
    _screenHeld = playing;
    unawaited((playing ? _screenAwake.enable() : _screenAwake.disable()).catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final colors = DsTheme.colorsOf(context);
    final theme = DsTheme.of(context);
    final channel = _channel;
    final handle = _handle;
    final presentation = ref.watch(roomPresentationProvider);
    final fullscreen = presentation != PresentationMode.normal;
    final playing = _playbackState.playing;
    _syncScreenWake(playing);
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
                  _IconButton(semanticLabel: t.common.close, icon: DsIcons.chevronLeft, onPressed: () => context.pop()),
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
                    _IconButton(
                      semanticLabel: t.room.cast,
                      icon: DsIcons.cast,
                      onPressed: () => _cast(channel),
                    ),
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
                    MediaPlayerView(handle: handle, backgroundColor: colors.overlay)
                  else
                    const Center(child: DsSpinner()),
                  if (_error != null)
                    ColoredBox(
                      color: const Color(0xB3000000),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          spacing: DsSpace.s12,
                          children: [
                            Text(t.iptv.playerOpenFailed, style: theme.typography.title.copyWith(color: colors.text)),
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
                    semanticLabel: handle?.muted == true ? t.room.unmute : t.room.mute,
                    icon: handle?.muted == true ? DsIcons.volumeOff : DsIcons.volume,
                    onPressed: handle == null ? null : () => unawaited(handle.setMute(muted: !handle.muted)),
                  ),
                  Expanded(
                    child: DsSlider(
                      value: handle?.volume ?? 1,
                      onChanged: handle == null ? null : (value) => unawaited(handle.setVolume(value)),
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
