import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show FormFactor;
import 'package:live_playback/live_playback.dart' show EngineStopped, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart'
    show LivePlayLine, LivePlayQuality, LivePlaybackProvider, LiveRoom, LiveRoomProvider, LiveSite, RoomContent;
import 'package:live_uikit/styling.dart' show LiveAppBar, LiveButton, LiveScaffold, LiveSelect, LiveSpinner, LiveTheme;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitVideoView;

import 'package:pure_live/app/engine/playback_engine.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/room/danmaku_pane.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The room page: the player surface, the room's own words, and the two
/// selectors that matter live — quality and line.
///
/// MVP of the reference's live_play: playback through the app engine
/// (media_core), quality and line re-opening the current stream. Danmaku,
/// PiP, recording and the control bar's full button set join with their
/// waves.
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
  late final MediaCorePlaybackEngine _engine = MediaCorePlaybackEngine();
  StreamSubscription<PlaybackEngineEvent>? _engineSub;

  LiveRoom? _room;
  Object? _detailError;

  List<LivePlayQuality> _qualities = const [];
  LivePlayQuality? _selectedQuality;
  List<LivePlayLine> _lines = const [];
  LivePlayLine? _currentLine;
  bool _loadingLines = false;

  /// The engine reported a stop: the surface offers a retry over the last
  /// line.
  bool _engineStopped = false;

  @override
  void initState() {
    super.initState();
    _engineSub = _engine.events.listen(_onEngineEvent);
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_engineSub?.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }

  void _onEngineEvent(PlaybackEngineEvent event) {
    if (event is EngineStopped && mounted) {
      setState(() => _engineStopped = true);
    }
  }

  LiveSite? get _site => ref.read(sitesProvider).registry.getById(widget.siteId);

  Future<void> _load() async {
    final site = _site;
    if (site == null) {
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
    await ref
        .read(historyRepositoryProvider)
        .record(
          known ??
              LiveRoom.normalized(
                platform: widget.siteId,
                roomId: widget.roomId,
                content: RoomContent(title: widget.roomName),
              ),
        );
    await _loadQualities();
  }

  Future<void> _loadQualities() async {
    final capability = _site?.capability<LivePlaybackProvider>();
    if (capability == null) {
      return;
    }
    final result = await capability.getQualities(roomId: widget.roomId);
    if (!mounted) {
      return;
    }
    setState(() {
      result.fold((error) => _detailError ??= error, (qualities) {
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
      if (quality != null) {
        _selectedQuality = quality;
      }
    });
    final result = await capability.getLines(roomId: widget.roomId, quality: quality ?? _selectedQuality);
    if (!mounted) {
      return;
    }
    final lines = result.fold((error) => <LivePlayLine>[], (lines) => lines);
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
    });
    await _engine.open(line);
  }

  @override
  Widget build(BuildContext context) {
    final wide = switch (ref.watch(environmentProvider).runtime.formFactor) {
      FormFactor.desktop || FormFactor.tv => true,
      FormFactor.phone || FormFactor.tablet => false,
    };
    final playerColumn = Column(children: [_player(context), _info(context)]);
    return LiveScaffold(
      appBar: LiveAppBar(
        title: _title(),
        actions: const [SettingsEntryButton()],
      ),
      body: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: playerColumn),
                SizedBox(
                  width: 320,
                  child: Material(
                    color: Colors.black,
                    child: DanmakuPane(siteId: widget.siteId, roomId: widget.roomId),
                  ),
                ),
              ],
            )
          : ListView(
              children: [
                playerColumn,
                SizedBox(
                  height: 240,
                  child: DanmakuPane(siteId: widget.siteId, roomId: widget.roomId),
                ),
              ],
            ),
    );
  }

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

  Widget _player(BuildContext context) {
    final adapter = _engine.surfaceAdapter;
    final Widget surface;
    if (adapter != null) {
      surface = MediaKitVideoView(adapter: adapter);
    } else if (_engineStopped) {
      surface = _failedSurface(context);
    } else if (_loadingLines || _currentLine != null) {
      surface = const Center(child: LiveSpinner(size: 40));
    } else {
      surface = const SizedBox.expand();
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(color: Colors.black, child: surface),
    );
  }

  Widget _failedSurface(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(context.t.room.failed, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 12),
        LiveButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _retry),
      ],
    ),
  );

  void _retry() {
    final line = _currentLine;
    if (line != null) {
      unawaited(_play(line));
    }
  }

  Widget _info(BuildContext context) {
    final anchor = _room?.anchor?.name ?? '';
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (anchor.isNotEmpty)
            Text(
              anchor,
              style: LiveTheme.of(context).text.caption.copyWith(color: LiveTheme.of(context).colors.primary),
            ),
          if (_engineStopped && _currentLine != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Text(context.t.room.failed, style: TextStyle(color: LiveTheme.of(context).colors.error)),
                  const SizedBox(width: 12),
                  LiveButton(label: context.t.common.retry, icon: Icons.refresh, onPressed: _retry),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                tooltip: context.t.room.pause,
                icon: const Icon(Icons.pause_circle_outline),
                onPressed: _engine.pause,
              ),
              IconButton(
                tooltip: context.t.room.play,
                icon: const Icon(Icons.play_circle_outline),
                onPressed: _engine.resume,
              ),
              const SizedBox(width: 12),
              if (_qualities.isNotEmpty)
                Expanded(
                  child: LiveSelect<LivePlayQuality>(
                    items: _qualities,
                    value: _selectedQuality,
                    itemLabel: (quality) => quality.label,
                    onChanged: (quality) => unawaited(_openLines(quality: quality)),
                  ),
                ),
            ],
          ),
          if (_lines.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: LiveSelect<int>(
                items: [for (var i = 0; i < _lines.length; i++) i],
                value: _currentLine == null ? null : _lines.indexOf(_currentLine!),
                itemLabel: (index) {
                  final label = _lines[index].lineLabel;
                  return label == null || label.isEmpty ? '${context.t.room.line} ${index + 1}' : label;
                },
                onChanged: (index) => unawaited(_play(_lines[index])),
              ),
            ),
        ],
      ),
    );
  }
}
