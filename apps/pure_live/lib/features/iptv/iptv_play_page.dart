import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_playback/live_playback.dart' show EngineStopped, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart' show LivePlayFormatSource, LivePlayLine, LiveStreamFormat;
import 'package:live_uikit/styling.dart' show LiveAppBar, LiveButton, LiveScaffold, LiveSpinner;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitVideoView;

import 'package:pure_live/app/engine/playback_engine.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/shared/widgets/settings_entry_button.dart';

/// The stream format a channel's URL implies, from its extension.
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

/// One channel playing (3.x `TvIptvPane`'s player, phone/desktop slice):
/// the channel's URL through the app engine, the name above, the
/// favourite toggle beside it. Zap keys join with the TV wave.
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
  bool _engineStopped = false;

  @override
  void initState() {
    super.initState();
    _engineSub = _engine.events.listen((event) {
      if (event is EngineStopped && mounted) {
        setState(() => _engineStopped = true);
      }
    });
    unawaited(_open());
  }

  @override
  void dispose() {
    unawaited(_engineSub?.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }

  Future<void> _open() async {
    final library = ref.read(iptvLibraryProvider);
    final channel = library.channelById(widget.channelId);
    if (channel == null) {
      if (mounted) {
        setState(() => _engineStopped = true);
      }
      return;
    }
    final line = LivePlayLine(
      url: channel.entry.url,
      format: iptvFormatOf(channel.entry.url),
      formatSource: LivePlayFormatSource.inferred,
      headers: channel.entry.headers,
    );
    await _engine.open(line);
  }

  Future<void> _toggleFavorite() async {
    await ref.read(iptvLibraryProvider).toggleFavorite(widget.channelId);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.read(iptvLibraryProvider);
    final channel = library.channelById(widget.channelId);
    final title = channel?.entry.name.isNotEmpty ?? false ? channel!.entry.name : widget.name;
    final adapter = _engine.surfaceAdapter;
    return LiveScaffold(
      appBar: LiveAppBar(
        title: title,
        actions: [
          if (channel != null)
            IconButton(
              tooltip: context.t.iptv.favorite,
              icon: Icon(channel.favorite ? Icons.favorite : Icons.favorite_border),
              onPressed: _toggleFavorite,
            ),
          const SettingsEntryButton(),
        ],
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(
              color: Colors.black,
              child: adapter != null
                  ? MediaKitVideoView(adapter: adapter)
                  : Center(
                      child: _engineStopped
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(context.t.room.failed, style: const TextStyle(color: Colors.white70)),
                                const SizedBox(height: 12),
                                LiveButton(
                                  label: context.t.common.retry,
                                  icon: Icons.refresh,
                                  onPressed: () => unawaited(_open()),
                                ),
                              ],
                            )
                          : const LiveSpinner(size: 40),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
