import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/modules/vod/widgets/vod_toolbar.dart' show VodFeedToolbar, kVodFeedTabsStyle;
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodVideoCard, VodVideoRow, kVodCardInfoExtent;
import 'package:pure_live/shared/shared.dart';

/// The regions the 分区 page offers: the channel ids (1xxx) the region feed
/// takes. These are not the classic partition ids — the feed refuses those.
/// The names are the app's own words, not the platform's Chinese labels
/// pasted into a const table: every other label this row draws comes from
/// Slang, and a viewer reading the app in English had a Chinese tab strip.
enum VodRegionChannel {
  animation(1005),
  games(1008),
  guichu(1007),
  music(1003),
  dance(1004),
  film(1001),
  entertainment(1002),
  knowledge(1010),
  tech(1012),
  news(1009),
  food(1020),
  automotive(1013),
  fashion(1014),
  sports(1018),
  animals(1024);

  VodRegionChannel(this.id);

  /// The channel id the region feed takes.
  final int id;

  /// The channel's name in the viewer's language.
  String label(Translations t) => switch (this) {
    VodRegionChannel.animation => t.vod.regionAnimation,
    VodRegionChannel.games => t.vod.regionGames,
    VodRegionChannel.guichu => t.vod.regionGuichu,
    VodRegionChannel.music => t.vod.regionMusic,
    VodRegionChannel.dance => t.vod.regionDance,
    VodRegionChannel.film => t.vod.regionFilm,
    VodRegionChannel.entertainment => t.vod.regionEntertainment,
    VodRegionChannel.knowledge => t.vod.regionKnowledge,
    VodRegionChannel.tech => t.vod.regionTech,
    VodRegionChannel.news => t.vod.regionNews,
    VodRegionChannel.food => t.vod.regionFood,
    VodRegionChannel.automotive => t.vod.regionAutomotive,
    VodRegionChannel.fashion => t.vod.regionFashion,
    VodRegionChannel.sports => t.vod.regionSports,
    VodRegionChannel.animals => t.vod.regionAnimals,
  };
}

/// The station's 分区 page: one channel at a time, its recommendation feed
/// paged by scroll.
final class VodRegionsPage extends ConsumerStatefulWidget {
  /// The regions page, opening on [channel].
  const VodRegionsPage({this.channel = VodRegionChannel.animation, super.key});

  /// The channel the page opens on.
  final VodRegionChannel channel;

  @override
  ConsumerState<VodRegionsPage> createState() => _VodRegionsPageState();
}

final class _VodRegionsPageState extends ConsumerState<VodRegionsPage> {
  late VodRegionChannel _channel = widget.channel;
  final Map<String, ScrollController> _scrolls = {};

  String get _key => vodFeedKey(VodFeedKind.region, id: _channel.id);

  @override
  void initState() {
    super.initState();
    _ensureFeed(_key);
  }

  @override
  void didUpdateWidget(VodRegionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channel != _channel) _select(widget.channel);
  }

  @override
  void dispose() {
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  ScrollController _scrollOf(String key) => _scrolls.putIfAbsent(key, ScrollController.new);

  void _ensureFeed(String key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodFeedProvider.notifier).open(key));
    });
  }

  void _select(VodRegionChannel channel) {
    if (channel == _channel) return;
    setState(() => _channel = channel);
    _ensureFeed(_key);
  }

  void _openVideo(VodVideo video) {
    final bvid = video.bvid ?? video.id;
    if (bvid.isEmpty) return;
    unawaited(context.push('/vod/$bvid'));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final inset = LiveWindow.pageInset(MediaQuery.sizeOf(context).width);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, DsSpace.s12, inset, DsSpace.s8),
          child: VodFeedToolbar(
            owner: NavigationItem.vodRegions,
            tabs: DsTabs<VodRegionChannel>(
              value: _channel,
              onChanged: _select,
              style: kVodFeedTabsStyle,
              tabs: [
                for (final channel in VodRegionChannel.values) DsTab(value: channel, label: Text(channel.label(t))),
              ],
            ),
            onRefresh: () => ref.read(vodFeedProvider.notifier).refresh(_key),
          ),
        ),
        Expanded(
          child: _RegionFeedView(
            feedKey: _key,
            scrollController: _scrollOf(_key),
            onOpen: _openVideo,
            emptyHint: t.vod.regionEmptyDescription,
          ),
        ),
      ],
    );
  }
}

/// One channel's cached feed as the shared card grid.
final class _RegionFeedView extends ConsumerWidget {
  const _RegionFeedView({
    required this.feedKey,
    required this.scrollController,
    required this.onOpen,
    required this.emptyHint,
  });

  final String feedKey;
  final ScrollController scrollController;
  final ValueChanged<VodVideo> onOpen;
  final String emptyHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);
    final feed = ref.watch(vodFeedProvider.select((feeds) => feeds[feedKey]));
    final state = feed ?? (videos: const <VodVideo>[], nextPage: 1, hasMore: true, loading: false, error: null);
    final controller = ref.read(vodFeedProvider.notifier);
    return PagedCardGrid<VodVideo>(
      key: ValueKey(feedKey),
      scrollController: scrollController,
      items: state.videos,
      layout: ref.watch(browseLayoutProvider),
      listMainAxisExtent: 104,
      listItemBuilder: (context, video) => VodVideoRow(video: video, onOpen: () => onOpen(video)),
      infoExtent: kVodCardInfoExtent,
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      isLoading: state.loading,
      hasMore: state.hasMore,
      onLoadMore: () => controller.loadMore(feedKey),
      error: state.error?.message,
      onRetry: () => controller.refresh(feedKey),
      onRefresh: () => controller.refresh(feedKey),
      refreshError: state.error?.message,
      emptyIcon: DsIcons.film,
      emptyTitle: t.common.empty,
      emptyDescription: emptyHint,
      itemBuilder: (context, video) => VodVideoCard(video: video, onOpen: () => onOpen(video)),
    );
  }
}
