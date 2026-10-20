import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_iptv/live_iptv.dart' show IptvChannel, IptvLibrary, IptvLineCandidate;
import 'package:live_playback/live_playback.dart' show EngineProgress, EngineReady, EngineStopped, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart' show LivePlayFormatSource, LivePlayLine, LiveStreamFormat;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitPlayerAdapter, MediaKitVideoView;
import 'package:pure_live/app/engine/playback_engine.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/iptv/iptv_epg.dart' show IptvGuideCache, iptvEpgProvider;
import 'package:pure_live/features/settings/widgets/settings_surface.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// How long the on-screen display stays up without interaction.
const Duration _osdTimeout = Duration(seconds: 4);

/// How long a partly dialled channel number waits for the next digit before
/// it counts as complete.
const Duration _dialTimeout = Duration(milliseconds: 1600);

/// The stream format a channel's URL implies, from its scheme and extension.
LiveStreamFormat iptvFormatOf(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('.m3u8')) {
    return LiveStreamFormat.hls;
  }
  if (lower.contains('.mpd')) {
    return LiveStreamFormat.dash;
  }
  if (lower.startsWith('rtmp://')) {
    return LiveStreamFormat.rtmp;
  }
  if (lower.startsWith('rtsp://')) {
    return LiveStreamFormat.rtsp;
  }
  if (lower.startsWith('udp://') || lower.startsWith('rtp://')) {
    return LiveStreamFormat.udp;
  }
  if (lower.contains('.mp4')) {
    return LiveStreamFormat.mp4;
  }
  return LiveStreamFormat.flv;
}

/// One channel playing: the channel's best line through the app engine, an
/// on-screen display that zaps up and down the library's zap sequence, and
/// number entry — a typed number *looks up* the channel, the way a remote
/// control dials.
///
/// The channel switch OSD is the TV surface: arrow keys step the walk, the
/// digits dial, and a pointer user gets the same two as on-screen buttons
/// plus a channel list and a dial pad. Playback failures climb the channel's
/// health-ranked lines before giving up to a retry.
final class IptvPlayPage extends ConsumerStatefulWidget {
  /// Plays [channelId] from the library; [name] titles the bar until the
  /// library's own name loads.
  const new({required this.channelId, this.name = '', super.key});

  /// The library channel id.
  final String channelId;

  /// A caller-provided title hint.
  final String name;

  @override
  ConsumerState<IptvPlayPage> createState() => _IptvPlayPageState();
}

final class _IptvPlayPageState extends ConsumerState<IptvPlayPage> {
  late final MediaCorePlaybackEngine _engine = MediaCorePlaybackEngine();
  StreamSubscription<PlaybackEngineEvent>? _engineSub;
  late String _channelId = widget.channelId;
  _PlayPhase _phase = _PlayPhase.loading;
  List<IptvLineCandidate> _lines = const [];
  int _lineIndex = 0;

  // A load replaces the previous one wholesale; events from a superseded
  // load must not steer the current one.
  int _epoch = 0;

  bool _osdVisible = true;
  Timer? _osdTimer;
  bool _panelOpen = false;
  bool _keypadOpen = false;
  final TextEditingController _panelSearch = TextEditingController();
  String _dialed = '';
  Timer? _dialTimer;

  /// The session's programme guides; empty until a source names an EPG
  /// address, and empty is exactly when no strip is drawn.
  late final IptvGuideCache _epg = ref.read(iptvEpgProvider);
  Timer? _epgTimer;

  /// The EPG addresses the viewer's Xtream sources named.
  List<String> get _epgUrls => [
    for (final source in ref.read(iptvPreferencesProvider).xtreamSources)
      if (source.epgUrl.isNotEmpty) source.epgUrl,
  ];

  IptvLibrary get _library => ref.read(iptvLibraryProvider);

  IptvChannel? get _channel => _library.channelById(_channelId);

  @override
  void initState() {
    super.initState();
    _engineSub = _engine.events.listen(_onEngineEvent);
    unawaited(_library.load());
    unawaited(_load());
    // The guides are fetched once per address; a "now" that creeps is the
    // periodic tick's business, not a refetch.
    final epgUrls = _epgUrls;
    if (epgUrls.isNotEmpty) {
      unawaited(
        _epg.ensureLoaded(epgUrls).then((_) {
          if (mounted) {
            setState(() {});
          }
        }),
      );
    }
    _epgTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _osdVisible) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _epoch++;
    _osdTimer?.cancel();
    _dialTimer?.cancel();
    _epgTimer?.cancel();
    _panelSearch.dispose();
    unawaited(_engineSub?.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_epoch;
    var channel = _channel;
    if (channel == null) {
      // A deep link can land before the library has read its box; load once
      // (idempotent) and look again before declaring the channel gone.
      await _library.load();
      channel = _channel;
    }
    if (channel == null) {
      if (mounted) {
        setState(() => _phase = _PlayPhase.failed);
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _PlayPhase.loading;
      _lines = _library.candidateLines(channel!);
      _lineIndex = 0;
    });
    // The first line's open is issued here; a failure arrives as
    // [EngineStopped] and the walk moves on from there.
    await _openCurrentLine(epoch);
  }

  /// Opens the line [_lineIndex] points at. Failures never throw — they come
  /// back through [_onEngineEvent].
  Future<void> _openCurrentLine(int epoch) async {
    if (epoch != _epoch || _lineIndex >= _lines.length) {
      if (mounted && _lineIndex >= _lines.length) {
        setState(() => _phase = _PlayPhase.failed);
      }
      return;
    }
    final channel = _channel;
    final candidate = _lines[_lineIndex];
    if (channel == null) {
      setState(() => _phase = _PlayPhase.failed);
      return;
    }
    await _engine.open(
      LivePlayLine(
        url: candidate.url,
        format: iptvFormatOf(candidate.url),
        formatSource: LivePlayFormatSource.inferred,
        headers: candidate.headers.isEmpty ? channel.entry.headers : candidate.headers,
      ),
    );
  }

  void _onEngineEvent(PlaybackEngineEvent event) {
    if (!mounted) {
      return;
    }
    switch (event) {
      case EngineReady():
        setState(() => _phase = _PlayPhase.playing);
        _scheduleOsdHide();
      case EngineStopped():
        _advanceLine();
      case EngineProgress():
        break;
    }
  }

  /// The recovery ladder: the next line, and only after the last one has
  /// failed does the page give up to a retry.
  void _advanceLine() {
    if (_phase == _PlayPhase.failed) {
      return;
    }
    final next = _lineIndex + 1;
    if (next >= _lines.length) {
      setState(() => _phase = _PlayPhase.failed);
      return;
    }
    setState(() => _lineIndex = next);
    unawaited(_openCurrentLine(_epoch));
  }

  /// Moves the page to [channel]: the id becomes the page's own state (the
  /// route stays where it was pushed), the choice persists, and the lines
  /// reload.
  void _switchTo(IptvChannel channel) {
    if (channel.id == _channelId && _phase != _PlayPhase.failed) {
      return;
    }
    setState(() {
      _channelId = channel.id;
      _keypadOpen = false;
      _dialed = '';
    });
    unawaited(
      ref
          .read(iptvPreferencesProvider.notifier)
          .update((preferences) => preferences.copyWith(lastChannelId: channel.id)),
    );
    unawaited(_load());
  }

  /// Steps the library's zap sequence — the walk a remote's channel keys
  /// take, wrap-around included.
  void _zap(int delta) {
    final step = _library.zapSequence().step(delta, fromId: _channelId);
    final channel = step.channel;
    if (step.needsLoad && channel != null) {
      _switchTo(channel);
    }
    _showOsd();
  }

  void _toggleFavorite() {
    unawaited(_library.toggleFavorite(_channelId));
    setState(() {});
  }

  /// Reads the guides again; the strip comes back with them, or stays away
  /// when the addresses answer nothing — absence is never faked.
  Future<void> _refreshEpg() async {
    final urls = _epgUrls;
    if (urls.isEmpty) {
      return;
    }
    await _epg.refresh(urls);
    if (mounted) {
      setState(() {});
    }
  }

  // On-screen display ---------------------------------------------------------

  void _showOsd() {
    _osdTimer?.cancel();
    if (!_osdVisible) {
      setState(() => _osdVisible = true);
    }
    _scheduleOsdHide();
  }

  void _scheduleOsdHide() {
    _osdTimer?.cancel();
    _osdTimer = Timer(_osdTimeout, () {
      if (mounted && _phase == _PlayPhase.playing && !_panelOpen && !_keypadOpen) {
        setState(() => _osdVisible = false);
      }
    });
  }

  void _toggleOsd() {
    if (_osdVisible) {
      _osdTimer?.cancel();
      setState(() => _osdVisible = false);
    } else {
      _showOsd();
    }
  }

  // Number dialling -----------------------------------------------------------

  /// Appends [digit] to the dialled number; after [_dialTimeout] with no
  /// further digit the number counts as complete and is looked up.
  void _dial(int digit) {
    _dialTimer?.cancel();
    setState(() {
      if (_dialed.length >= 4) {
        _dialed = '';
      }
      _dialed += '$digit';
    });
    _showOsd();
    _dialTimer = Timer(_dialTimeout, _commitDial);
  }

  void _deleteDialed() {
    _dialTimer?.cancel();
    if (_dialed.isEmpty) {
      return;
    }
    setState(() => _dialed = _dialed.substring(0, _dialed.length - 1));
    _showOsd();
  }

  /// Looks up the dialled number — a typed number *is* the channel, not a
  /// step count — and switches to it, or says there is no such channel.
  void _commitDial() {
    _dialTimer?.cancel();
    final number = int.tryParse(_dialed);
    if (number == null) {
      return;
    }
    setState(() => _dialed = '');
    final channel = _library.channelByNumber(number);
    if (channel == null) {
      PureToast.show(context, context.t.iptv.noNumber(number: number), type: PureToastType.error);
      return;
    }
    _switchTo(channel);
  }

  // Keyboard ------------------------------------------------------------------

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      _zap(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _zap(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        _panelOpen = false;
        _keypadOpen = false;
        _osdVisible = false;
      });
      _osdTimer?.cancel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.select) {
      _commitDial();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _deleteDialed();
      return KeyEventResult.handled;
    }
    final digit = _digitOf(key);
    if (digit != null) {
      _dial(digit);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// The digit [key] names, on either the number row or the numpad.
  static int? _digitOf(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.digit0 || LogicalKeyboardKey.numpad0 => 0,
    LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => 1,
    LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => 2,
    LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => 3,
    LogicalKeyboardKey.digit4 || LogicalKeyboardKey.numpad4 => 4,
    LogicalKeyboardKey.digit5 || LogicalKeyboardKey.numpad5 => 5,
    LogicalKeyboardKey.digit6 || LogicalKeyboardKey.numpad6 => 6,
    LogicalKeyboardKey.digit7 || LogicalKeyboardKey.numpad7 => 7,
    LogicalKeyboardKey.digit8 || LogicalKeyboardKey.numpad8 => 8,
    LogicalKeyboardKey.digit9 || LogicalKeyboardKey.numpad9 => 9,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final channel = _channel;
    final title = (channel != null && channel.entry.name.isNotEmpty) ? channel.entry.name : widget.name;
    final adapter = _engine.surfaceAdapter;
    final player = _playerSurface(context, adapter);

    // Desktop/TV keeps the full-bleed dark stage; phone and tablet get the
    // vertical page the design mockup lays out: brand bar, 16:9 player, the
    // channel's info row, quick actions and the hot-channels list.
    if (PureBreakpoints.standard.qualify(context) == PureWidthClass.desktop) {
      return PureScaffold(
        appBar: PureAppBar(
          title: title,
          actions: [
            if (channel != null)
              PureIconButton(
                tooltip: context.t.iptv.favorite,
                icon: channel.favorite ? Icons.favorite : Icons.favorite_border,
                onPressed: _toggleFavorite,
              ),
            const SettingsEntryButton(),
          ],
        ),
        body: Focus(
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: Stack(
            children: [
              Center(child: player),
              if (_osdVisible) _osd(context),
              if (_panelOpen) _channelPanel(context),
              if (_keypadOpen) _keypad(context),
            ],
          ),
        ),
      );
    }
    return PureScaffold(
      appBar: PureAppBar(
        leading: PureIconButton(
          tooltip: context.t.iptv.channelList,
          icon: Icons.menu,
          onPressed: () => setState(() => _panelOpen = true),
        ),
        title: 'PureLive',
        actions: [
          PureIconButton(
            tooltip: context.t.iptv.channelList,
            icon: Icons.search,
            onPressed: () => setState(() => _panelOpen = true),
          ),
          const SettingsEntryButton(),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  player,
                  Expanded(child: _mobileBody(context, channel)),
                ],
              ),
              if (_osdVisible) Positioned(top: 0, left: 0, right: 0, child: _mobileOsd(context)),
              if (_panelOpen) _channelPanel(context),
              if (_keypadOpen) _keypad(context),
            ],
          ),
        ),
      ),
    );
  }

  /// The 16:9 video surface: black behind, the engine's view when a line is
  /// open, phase spinners/errors when not. Taps toggle the OSD.
  Widget _playerSurface(BuildContext context, MediaKitPlayerAdapter? adapter) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: GestureDetector(
        onTap: _toggleOsd,
        child: ColoredBox(
          color: Colors.black,
          child: adapter != null
              ? MediaKitVideoView(adapter: adapter)
              : Center(
                  child: switch (_phase) {
                    _PlayPhase.loading => const PureSpinner(size: 40),
                    _PlayPhase.failed => _errorView(context),
                    _PlayPhase.playing => const PureSpinner(size: 40),
                  },
                ),
        ),
      ),
    );
  }

  /// The mobile page under the player: the channel's info row (name, live
  /// badge, favourite and line picker), the three quick actions, then the
  /// hot-channels list.
  Widget _mobileBody(BuildContext context, IptvChannel? channel) {
    final t = context.t;
    final colors = PureTheme.of(context).colors;
    final channels = _library.zapSequence().channels;
    final hot = [...channels]
      ..sort((a, b) {
        if (a.favorite != b.favorite) {
          return a.favorite ? -1 : 1;
        }
        return 0;
      });
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (channel != null && channel.entry.name.isNotEmpty) ? channel.entry.name : widget.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: colors.error, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _lines.length > 1
                                ? '${t.iptv.liveNow} · ${t.iptv.lineOf(index: _lineIndex + 1, total: _lines.length)}'
                                : t.iptv.liveNow,
                            style: TextStyle(fontSize: 12, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (channel != null)
                  PureIconButton(
                    tooltip: t.iptv.favorite,
                    icon: channel.favorite ? Icons.favorite : Icons.favorite_border,
                    color: channel.favorite ? colors.error : colors.textSecondary,
                    onPressed: _toggleFavorite,
                  ),
                if (_lines.length > 1)
                  PureIconButton(tooltip: t.iptv.lineSelect, icon: Icons.tune, onPressed: _cycleLine),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _quickAction(context, icon: Icons.skip_previous, label: t.iptv.prevChannel, onPressed: () => _zap(-1)),
                _quickAction(
                  context,
                  icon: Icons.format_list_bulleted,
                  label: t.iptv.channelList,
                  onPressed: () => setState(() => _panelOpen = true),
                ),
                _quickAction(context, icon: Icons.tune, label: t.iptv.playbackSettings, onPressed: _openPlaybackSheet),
              ],
            ),
          ),
          const PureDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(t.iptv.hotChannels, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                PureButton(
                  label: t.iptv.viewAll,
                  variant: ButtonVariant.ghost,
                  onPressed: () => setState(() => _panelOpen = true),
                ),
              ],
            ),
          ),
          for (final hotChannel in hot.take(8))
            PureListRow(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: colors.bgLayout, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.live_tv, size: 20),
              ),
              title: hotChannel.entry.name,
              subtitle: hotChannel.entry.group?.isEmpty ?? true ? hotChannel.entry.url : hotChannel.entry.group!,
              trailing: PureIconButton(
                icon: hotChannel.favorite ? Icons.favorite : Icons.favorite_border,
                color: hotChannel.favorite ? colors.error : colors.textSecondary,
                size: ControlSize.sm,
                tooltip: t.iptv.favorite,
                onPressed: _toggleFavorite,
              ),
              onTap: () => _switchTo(hotChannel),
              divided: false,
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// One of the three labelled quick actions under the info row.
  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = PureTheme.of(context);
    final colors = theme.colors;
    return PureBox(
      style: (state) => Style(
        background: switch (state) {
          InteractionState.pressed || InteractionState.focused => colors.fillTertiary,
          InteractionState.hovered => colors.fillQuaternary,
          _ => null,
        },
        borderRadius: BorderRadius.circular(10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onTap: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: colors.textSecondary),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 12, color: colors.textSecondary)),
        ],
      ),
    );
  }

  /// Cycles to the next candidate line for the current channel.
  void _cycleLine() {
    if (_lines.length < 2) {
      return;
    }
    setState(() => _lineIndex = (_lineIndex + 1) % _lines.length);
    unawaited(_openCurrentLine(_epoch));
  }

  /// The playback settings sheet: line selection, the number pad, and an EPG
  /// refresh — the knobs that genuinely exist for IPTV playback.
  Future<void> _openPlaybackSheet() async {
    final t = context.t;
    await showSettingsSurface<void>(
      context,
      ref.settingsFormFactor,
      title: null,
      body: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_lines.length > 1)
            PureListRow(
              leading: const Icon(Icons.tune),
              title: t.iptv.lineSelect,
              subtitle: t.iptv.lineOf(index: _lineIndex + 1, total: _lines.length),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _cycleLine();
              },
              divided: false,
            ),
          PureListRow(
            leading: const Icon(Icons.dialpad),
            title: t.iptv.numberPad,
            onTap: () {
              Navigator.of(sheetContext).pop();
              setState(() => _keypadOpen = true);
            },
            divided: false,
          ),
          PureListRow(
            leading: const Icon(Icons.refresh),
            title: t.iptv.refreshGuide,
            onTap: () {
              Navigator.of(sheetContext).pop();
              final epgUrls = _epgUrls;
              if (epgUrls.isEmpty) {
                return;
              }
              unawaited(
                _epg.ensureLoaded(epgUrls).then((_) {
                  if (mounted) {
                    setState(() {});
                  }
                }),
              );
            },
            divided: false,
          ),
        ],
      ),
    );
  }

  /// The slim OSD for the mobile layout: channel number and name over the
  /// video, no side chrome — the page below carries the controls.
  Widget _mobileOsd(BuildContext context) {
    final channel = _channel;
    if (channel == null) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: Container(
        color: Colors.black38,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(
              channel.number == null ? 'TV' : 'CH ${channel.number}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                channel.entry.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorView(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(context.t.room.failed, style: const TextStyle(color: Colors.white70)),
      const SizedBox(height: 12),
      PureButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: () => unawaited(_load())),
    ],
  );

  /// The channel-switch overlay: number and name up top, prev/next at the
  /// sides, the list and the dial pad at the bottom.
  Widget _osd(BuildContext context) {
    final channel = _channel;
    return Positioned.fill(
      child: GestureDetector(
        // Taps on the chrome must not fall through to the video's toggle.
        onTap: () {},
        child: Container(
          color: Colors.black38,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  if (channel != null) ...[
                    Text(
                      channel.number == null ? 'TV' : 'CH ${channel.number}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        channel.entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_lines.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          context.t.iptv.lineOf(index: _lineIndex + 1, total: _lines.length),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ),
                    PureIconButton(
                      tooltip: context.t.iptv.favorite,
                      icon: channel.favorite ? Icons.favorite : Icons.favorite_border,
                      onPressed: _toggleFavorite,
                    ),
                  ],
                ],
              ),
              if (channel != null) _epgStrip(context, channel),
              Expanded(
                child: Center(
                  child: _dialed.isEmpty
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            PureIconButton(
                              tooltip: context.t.iptv.switchChannel,
                              icon: Icons.skip_previous,
                              onPressed: () => _zap(-1),
                            ),
                            PureIconButton(
                              tooltip: context.t.iptv.switchChannel,
                              icon: Icons.skip_next,
                              onPressed: () => _zap(1),
                            ),
                          ],
                        )
                      : Text(
                          _dialed,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 56,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PureButton(
                    label: context.t.iptv.channels,
                    icon: Icons.list,
                    variant: ButtonVariant.ghost,
                    onPressed: () => setState(() => _panelOpen = true),
                  ),
                  const SizedBox(width: 12),
                  PureButton(
                    label: context.t.iptv.dialPad,
                    icon: Icons.dialpad,
                    variant: ButtonVariant.ghost,
                    onPressed: () => setState(() => _keypadOpen = true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The wall-clock spelling a programme time carries: hours and minutes.
  static String _clock(DateTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  /// The guide strip under the channel name: what is on now and what comes
  /// next, matched by the channel's `tvg-id` or its name, from the session's
  /// guides. No guide loaded, or none that names this channel — no strip,
  /// and no stand-in rows either.
  Widget _epgStrip(BuildContext context, IptvChannel channel) {
    if (_epg.isEmpty) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    final current = _epg.currentFor(channel, now);
    final upcoming = _epg.upcomingFor(channel, now, limit: 2);
    if (current == null && upcoming.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(context.t.iptv.epgNow, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ),
              Expanded(
                child: Text(
                  current == null || current.title.isEmpty ? '—' : current.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (current != null)
                Text(
                  '${_clock(current.start.toLocal())} - ${_clock(current.stop.toLocal())}',
                  style: const TextStyle(color: Colors.white70, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              PureIconButton(
                tooltip: context.t.iptv.refreshEpg,
                icon: Icons.refresh,
                onPressed: () => unawaited(_refreshEpg()),
              ),
            ],
          ),
          if (upcoming.isNotEmpty)
            Row(
              children: [
                SizedBox(
                  width: 68,
                  child: Text(context.t.iptv.epgNext, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                Expanded(
                  child: Text(
                    [for (final programme in upcoming) '${_clock(programme.start.toLocal())} ${programme.title}'.trim()]
                        .join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// The channel list the OSD opens: the library's visible line-up, filtered
  /// as the viewer types, switching on tap.
  Widget _channelPanel(BuildContext context) {
    final colors = PureTheme.of(context).colors;
    final needle = _panelSearch.text.trim().toLowerCase();
    final channels = [
      for (final channel in _library.zapSequence().channels)
        if (needle.isEmpty || channel.entry.name.toLowerCase().contains(needle)) channel,
    ];
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: 320,
      child: ColoredBox(
        color: colors.bgElevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.t.iptv.channels, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  PureIconButton(
                    tooltip: context.t.common.close,
                    icon: Icons.close,
                    onPressed: () => setState(() => _panelOpen = false),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: PureTextField(
                controller: _panelSearch,
                placeholder: context.t.iptv.search,
                prefix: const Icon(Icons.search),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Expanded(
              child: channels.isEmpty
                  ? Center(child: Text(context.t.iptv.noMatch))
                  : ListView.builder(
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final item = channels[index];
                        return PureListRow(
                          selected: item.id == _channelId,
                          leading: SizedBox(
                            width: 48,
                            child: Text(
                              item.number == null ? '' : '${item.number}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          title: item.entry.name,
                          onTap: () => _switchTo(item),
                          divided: false,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The dial pad: the on-screen twin of the number keys.
  Widget _keypad(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: PureCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 216,
                child: Text(
                  _dialed.isEmpty ? '—' : _dialed,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final row in const [
                [1, 2, 3],
                [4, 5, 6],
                [7, 8, 9],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final digit in row)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: PureButton(
                            label: '$digit',
                            variant: ButtonVariant.secondary,
                            onPressed: () => _dial(digit),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PureButton(label: '⌫', variant: ButtonVariant.secondary, onPressed: _deleteDialed),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PureButton(label: '0', variant: ButtonVariant.secondary, onPressed: () => _dial(0)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PureButton(label: context.t.common.confirm, onPressed: _commitDial),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              PureButton(
                label: context.t.common.close,
                variant: ButtonVariant.ghost,
                onPressed: () => setState(() => _keypadOpen = false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where a channel's playback stands.
enum _PlayPhase {
  /// A line is opening.
  loading,

  /// A line produced picture.
  playing,

  /// Every line failed.
  failed,
}
