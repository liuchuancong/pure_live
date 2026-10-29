import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/modules/vod/widgets/vod_widgets.dart' show VodVideoCard, VodVideoRow;
import 'package:pure_live/shared/shared.dart';

/// The regions the 分区 page offers: the channel ids (1xxx) the region feed
/// takes, with the platform's own names. These are not the classic partition
/// ids — the feed refuses those.
const List<(int, String)> kVodRegionChannels = [
  (1005, '动画'),
  (1008, '游戏'),
  (1007, '鬼畜'),
  (1003, '音乐'),
  (1004, '舞蹈'),
  (1001, '影视'),
  (1002, '娱乐'),
  (1010, '知识'),
  (1012, '科技数码'),
  (1009, '资讯'),
  (1020, '美食'),
  (1013, '汽车'),
  (1014, '时尚美妆'),
  (1018, '体育运动'),
  (1024, '动物'),
];

/// The station's 分区 page: one channel at a time, its recommendation feed
/// paged by scroll.
final class VodRegionsPage extends ConsumerStatefulWidget {
  /// The regions page, opening on [channel].
  const VodRegionsPage({this.channel = 1005, super.key});

  /// The channel the page opens on.
  final int channel;

  @override
  ConsumerState<VodRegionsPage> createState() => _VodRegionsPageState();
}

final class _VodRegionsPageState extends ConsumerState<VodRegionsPage> {
  late int _channel = widget.channel;
  final Map<String, ScrollController> _scrolls = {};

  String get _key => vodFeedKey(VodFeedKind.region, id: _channel);

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

  void _select(int channel) {
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
          child: SizedBox(
            height: 40,
            child: DsTopNav<int>(
              value: _channel,
              onChanged: _select,
              items: [for (final (id, name) in kVodRegionChannels) DsTopNavItem(value: id, label: Text(name))],
            ),
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
