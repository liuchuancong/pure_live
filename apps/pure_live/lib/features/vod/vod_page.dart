import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_playback/live_playback.dart' show EngineProgress, EngineReady, EngineStopped, PlaybackEngineEvent;
import 'package:live_sites/live_sites.dart' show LivePlayFormatSource, LivePlayLine, LiveStreamFormat;
import 'package:live_vod/live_vod.dart' show BilibiliVodClient, VodFailure, VodVideo;
import 'package:media_core_media_kit/media_core_media_kit.dart' show MediaKitVideoView;
import 'package:pure_live/app/app_providers.dart' show httpProvider;
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/navigation/route_paths.dart' show RoutePath;
import 'package:pure_live/system/playback/playback_engine.dart' show MediaCorePlaybackEngine;
import 'package:pure_uikit/pure_uikit.dart';

/// The video source the VOD pages read: one Bilibili client over the app's
/// own transport, so proxies and retries stay where every other request puts
/// them.
final vodClientProvider = Provider<BilibiliVodClient>((ref) => BilibiliVodClient(ref.watch(httpProvider)));

/// The search's state: the last answers, the last failure and whether a
/// request runs.
typedef VodSearchState = ({List<VodVideo> videos, bool loading, Object? failure});

/// The video page: a search field, the hits as a grid of cards, and a card
/// opens the player. The reference's TV build has the same shape; this is its
/// phone-sized reading, reachable from 工具箱.
final class VodPage extends ConsumerStatefulWidget {
  /// The video page.
  const new({super.key});

  @override
  ConsumerState<VodPage> createState() => _VodPageState();
}

final class _VodPageState extends ConsumerState<VodPage> {
  final TextEditingController _keyword = TextEditingController();
  VodSearchState _state = (videos: const [], loading: false, failure: null);

  @override
  void dispose() {
    _keyword.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _keyword.text.trim();
    if (keyword.isEmpty || _state.loading) {
      return;
    }
    setState(() => _state = (videos: _state.videos, loading: true, failure: null));
    try {
      final page = await ref.read(vodClientProvider).search(keyword);
      if (mounted) {
        setState(() => _state = (videos: page.videos, loading: false, failure: null));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _state = (videos: _state.videos, loading: false, failure: error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final theme = PureTheme.of(context);
    final state = _state;
    return PureScaffold(
      appBar: PureAppBar(title: t.vod.title),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(PureSpacing.md, PureSpacing.sm, PureSpacing.md, PureSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: PureTextField(
                    key: const ValueKey('vod-search'),
                    controller: _keyword,
                    placeholder: t.vod.searchHint,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => unawaited(_search()),
                  ),
                ),
                const SizedBox(width: 8),
                PureIconButton(icon: Icons.search, tooltip: t.vod.search, onPressed: () => unawaited(_search())),
              ],
            ),
          ),
          if (state.failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: PureSpacing.md, vertical: PureSpacing.xs),
              child: Text(
                state.failure is VodFailure ? (state.failure! as VodFailure).message : t.errors.network,
                style: theme.text.bodySmall.copyWith(color: theme.colors.error),
              ),
            ),
          Expanded(
            child: state.loading
                ? const Center(child: PureSpinner(size: 32))
                : state.videos.isEmpty
                ? Center(
                    child: PureEmpty(title: t.vod.empty, icon: Icons.videocam_outlined),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(PureSpacing.md, PureSpacing.xs, PureSpacing.md, PureSpacing.xl),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280,
                      mainAxisSpacing: PureSpacing.sm,
                      crossAxisSpacing: PureSpacing.sm,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: state.videos.length,
                    itemBuilder: (context, index) {
                      final video = state.videos[index];
                      return _VodCard(
                        key: ValueKey('vod-${video.id}'),
                        video: video,
                        onOpen: () => unawaited(
                          context.push<void>(
                            Uri(
                              path: RoutePath.vodPlay,
                              queryParameters: {'videoId': video.id, 'title': video.title},
                            ).toString(),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// One search hit: the cover, its duration, the title and the uploader.
final class _VodCard extends StatelessWidget {
  const new({required this.video, required this.onOpen, super.key});

  final VodVideo video;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = PureTheme.of(context);
    final cover = video.coverUrl;
    final duration = video.duration;
    return PureCard(
      onTap: onOpen,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover == null)
                  ColoredBox(color: theme.colors.fillQuaternary)
                else
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(color: theme.colors.fillQuaternary),
                    ),
                  ),
                if (duration != null)
                  PositionedDirectional(
                    bottom: 6,
                    end: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        _durationLabel(duration),
                        style: theme.text.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  video.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.text.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
                if (video.uploader case final uploader?)
                  Text(
                    uploader,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.text.caption.copyWith(color: theme.colors.textSecondary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _durationLabel(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return duration.inHours > 0 ? '${duration.inHours}:$minutes:$seconds' : '$minutes:$seconds';
  }
}

/// The player page: the picture over the app's engine, the title at the top
/// and the failure — or the silent-address notice — where the picture would
/// be. Playback goes through the same `system/playback` seam the rooms use.
final class VodPlayPage extends ConsumerStatefulWidget {
  /// Plays the video [videoId].
  const new({required this.videoId, this.title = '', super.key});

  /// The source's video id.
  final String videoId;

  /// A title hint shown while the address resolves.
  final String title;

  @override
  ConsumerState<VodPlayPage> createState() => _VodPlayPageState();
}

final class _VodPlayPageState extends ConsumerState<VodPlayPage> {
  late final MediaCorePlaybackEngine _engine = MediaCorePlaybackEngine();
  StreamSubscription<PlaybackEngineEvent>? _events;
  String? _pictureUrl;
  bool _silent = false;
  Object? _failure;

  // Needed by the page's imports; aliases keep this file independent of the
  // engine's internals.
  @override
  void initState() {
    super.initState();
    _events = _engine.events.listen((event) {
      if (!mounted) {
        return;
      }
      switch (event) {
        case EngineReady():
          setState(() {});
        case EngineStopped(:final error):
          setState(() {
            _failure = error ?? StateError('engine stopped');
          });
        case EngineProgress():
          break;
      }
    });
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final client = ref.read(vodClientProvider);
      // The search hit's own id is the bvid on Bilibili; the play call takes
      // the video, so a bare id is wrapped.
      final info = await client.play(VodVideo(id: widget.videoId, title: widget.title));
      if (!mounted) {
        return;
      }
      _pictureUrl = info.url;
      _silent = info.format == 'm4s' && info.quality == 'silent';
      await _engine.open(
        LivePlayLine(
          url: info.url,
          format: LiveStreamFormat.mp4,
          formatSource: LivePlayFormatSource.inferred,
          headers: info.headers,
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _failure = error;
        });
      }
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(_engine.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final adapter = _engine.surfaceAdapter;
    return PureScaffold(
      appBar: PureAppBar(title: widget.title.isEmpty ? t.vod.title : widget.title),
      body: ColoredBox(
        color: Colors.black,
        child: Center(
          child: _failure != null
              ? Text(
                  '${t.errors.network}\n${_failure ?? ''}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                )
              : adapter == null || _pictureUrl == null
              ? const PureSpinner(size: 40)
              : _silent
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MediaKitVideoView(adapter: adapter),
                    const SizedBox(height: 8),
                    Text(t.vod.silentHint, style: const TextStyle(color: Colors.white70)),
                  ],
                )
              : MediaKitVideoView(adapter: adapter),
        ),
      ),
    );
  }
}
