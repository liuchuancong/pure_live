import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart' show GoRouterHelper;
import 'package:live_vod/live_vod.dart';
import 'package:pure_live/app/providers/browse_settings_providers.dart';
import 'package:pure_live/features/vod/vod_controller.dart';
import 'package:pure_live/features/vod/vod_widgets.dart' show VodVideoCard, VodVideoRow;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/shared/grids/card_grid.dart';
import 'package:pure_live/shared/widgets/choice_dialog.dart' show AdaptiveChoiceField;
import 'package:pure_live/shared/widgets/chrome_icon_button.dart';

/// The station's four surfaces.
enum VodTab { popular, ranking, regions, search }

/// The regions the leaderboard tab offers: Bilibili's classic ranking ids
/// with the platform's own names. Zero is the all-region board; the news
/// channel has no leaderboard, so it is absent here.
const List<(int, String)> kVodRankRegions = [
  (0, '全部'),
  (3, '音乐'),
  (1, '动画'),
  (4, '游戏'),
  (36, '知识'),
  (188, '科技'),
  (5, '娱乐'),
  (181, '影视'),
  (211, '美食'),
  (160, '生活'),
  (119, '鬼畜'),
  (129, '舞蹈'),
  (155, '时尚'),
  (223, '汽车'),
  (234, '运动'),
  (217, '动物圈'),
  (177, '纪录片'),
];

/// The regions the browse tab offers: the channel ids (1xxx) the region
/// feed takes, which are not the classic ids the leaderboard asks with —
/// the feed refuses those.
const List<(int, String)> kVodRegionChannels = [
  (1005, '动画'),
  (1008, '游戏'),
  (1007, '鬼畜'),
  (1003, '音乐'),
  (1004, '舞蹈'),
  (1001, '影视'),
  (1002, '娱乐'),
  (1010, '知识'),
  (1012, '科技'),
  (1009, '资讯'),
  (1020, '美食'),
  (1013, '汽车'),
  (1014, '时尚'),
  (1018, '运动'),
  (1024, '动物圈'),
];

/// The Bilibili video station: a popular feed, region leaderboards, a region
/// browse feed, and search — all opening the same video page.
///
/// The station's requests live in [vodFeedProvider] (one cached feed per
/// tab/region) and [vodProvider] (the committed search); the page only asks.
final class VodPage extends ConsumerStatefulWidget {
  /// The station's entry page.
  const VodPage({super.key});

  @override
  ConsumerState<VodPage> createState() => _VodPageState();
}

final class _VodPageState extends ConsumerState<VodPage> {
  VodTab _tab = VodTab.popular;
  int _rankRid = 0;
  int _regionTid = 1005;
  final TextEditingController _search = TextEditingController();
  final Map<String, ScrollController> _scrolls = {};
  String _order = 'totalrank';
  int _duration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodFeedProvider.notifier).open(_popularKey));
    });
  }

  @override
  void dispose() {
    _search.dispose();
    for (final controller in _scrolls.values) {
      controller.dispose();
    }
    _scrolls.clear();
    super.dispose();
  }

  String get _popularKey => vodFeedKey(VodFeedKind.popular);

  String get _rankingKey => vodFeedKey(VodFeedKind.ranking, id: _rankRid);

  String get _regionKey => vodFeedKey(VodFeedKind.region, id: _regionTid);

  ScrollController _scrollOf(String key) => _scrolls.putIfAbsent(key, ScrollController.new);

  /// Loads [key]'s first page if it has none; safe to call on every visit.
  void _ensureFeed(String key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(vodFeedProvider.notifier).open(key));
    });
  }

  void _selectTab(VodTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    switch (tab) {
      case VodTab.popular:
        _ensureFeed(_popularKey);
      case VodTab.ranking:
        _ensureFeed(_rankingKey);
      case VodTab.regions:
        _ensureFeed(_regionKey);
      case VodTab.search:
        break;
    }
  }

  void _selectRankRegion(int rid) {
    if (rid == _rankRid) return;
    setState(() => _rankRid = rid);
    _ensureFeed(_rankingKey);
  }

  void _selectRegion(int tid) {
    if (tid == _regionTid) return;
    setState(() => _regionTid = tid);
    _ensureFeed(_regionKey);
  }

  void _openVideo(VodVideo video) {
    final bvid = video.bvid ?? video.id;
    if (bvid.isEmpty) return;
    unawaited(context.push('/vod/$bvid'));
  }

  void _runSearch() {
    unawaited(ref.read(vodProvider.notifier).search(_search.text, order: _order, duration: _duration));
  }

  void _setOrder(String order) {
    if (order == _order) return;
    setState(() => _order = order);
    _rerunSearch();
  }

  void _setDuration(int duration) {
    if (duration == _duration) return;
    setState(() => _duration = duration);
    _rerunSearch();
  }

  void _rerunSearch() {
    final query = ref.read(vodProvider).query;
    if (query.isEmpty) return;
    unawaited(ref.read(vodProvider.notifier).search(query, order: _order, duration: _duration));
  }

  void _refreshCurrent() {
    if (_tab == VodTab.search) {
      unawaited(ref.read(vodProvider.notifier).retry());
      return;
    }
    final key = switch (_tab) {
      VodTab.popular => _popularKey,
      VodTab.ranking => _rankingKey,
      VodTab.regions => _regionKey,
      VodTab.search => _popularKey,
    };
    unawaited(ref.read(vodFeedProvider.notifier).refresh(key));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, DsSpace.s12, DsSpace.s20, DsSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: DsTopNav<VodTab>(
                  value: _tab,
                  onChanged: _selectTab,
                  items: [
                    DsTopNavItem(value: VodTab.popular, label: Text(t.vod.popular), icon: const DsIcon(DsIcons.flame)),
                    DsTopNavItem(
                      value: VodTab.ranking,
                      label: Text(t.vod.ranking),
                      icon: const DsIcon(DsIcons.chartNoAxesColumn),
                    ),
                    DsTopNavItem(
                      value: VodTab.regions,
                      label: Text(t.vod.regions),
                      icon: const DsIcon(DsIcons.compass),
                    ),
                    DsTopNavItem(value: VodTab.search, label: Text(t.vod.search), icon: const DsIcon(DsIcons.search)),
                  ],
                ),
              ),
              const SizedBox(width: DsSpace.s8),
              ChromeIconButton(
                icon: DsIcons.refresh,
                semanticLabel: t.vod.refresh,
                tooltip: t.vod.refresh,
                onPressed: _refreshCurrent,
                size: 36,
              ),
            ],
          ),
        ),
        if (_tab == VodTab.ranking)
          _RegionBar(value: _rankRid, onChanged: _selectRankRegion, regions: kVodRankRegions)
        else if (_tab == VodTab.regions)
          _RegionBar(value: _regionTid, onChanged: _selectRegion, regions: kVodRegionChannels),
        Expanded(
          child: switch (_tab) {
            VodTab.popular => _VodFeedView(
              feedKey: _popularKey,
              scrollController: _scrollOf(_popularKey),
              onOpen: _openVideo,
            ),
            VodTab.ranking => _VodFeedView(
              feedKey: _rankingKey,
              scrollController: _scrollOf(_rankingKey),
              onOpen: _openVideo,
            ),
            VodTab.regions => _VodFeedView(
              feedKey: _regionKey,
              scrollController: _scrollOf(_regionKey),
              onOpen: _openVideo,
            ),
            VodTab.search => _VodSearchPane(
              controller: _search,
              order: _order,
              duration: _duration,
              onSubmitted: _runSearch,
              onOrder: _setOrder,
              onDuration: _setDuration,
              onOpen: _openVideo,
            ),
          },
        ),
      ],
    );
  }
}

/// The region strip over the ranking and region feeds: the platform's own
/// top-level regions, horizontally scrollable, one focus stop.
final class _RegionBar extends StatelessWidget {
  const _RegionBar({required this.value, required this.onChanged, required this.regions});

  final int value;
  final ValueChanged<int> onChanged;
  final List<(int, String)> regions;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
      child: SizedBox(
        height: 40,
        child: DsTopNav<int>(
          value: value,
          onChanged: onChanged,
          items: [
            for (final (id, name) in regions) DsTopNavItem(value: id, label: Text(id == 0 ? t.vod.regionAll : name)),
          ],
        ),
      ),
    );
  }
}

/// One cached browse feed as the shared card grid.
final class _VodFeedView extends ConsumerWidget {
  const _VodFeedView({required this.feedKey, required this.scrollController, required this.onOpen});

  final String feedKey;
  final ScrollController scrollController;
  final ValueChanged<VodVideo> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);
    final feed = ref.watch(vodFeedProvider.select((feeds) => feeds[feedKey]));
    final state = feed ?? (videos: const <VodVideo>[], nextPage: 1, hasMore: true, loading: false, error: null);
    final controller = ref.read(vodFeedProvider.notifier);
    return CardGrid<VodVideo>(
      scrollController: scrollController,
      items: state.videos,
      layout: ref.watch(browseLayoutProvider),
      listItemBuilder: (context, video) => VodVideoRow(video: video, onOpen: () => onOpen(video)),
      cardExtent: settings.homeCardExtent,
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
      emptyDescription: t.vod.noResultsDescription,
      itemBuilder: (context, video) => VodVideoCard(video: video, onOpen: () => onOpen(video)),
    );
  }
}

/// The search tab: the field, the two filters, and the paged results.
final class _VodSearchPane extends ConsumerWidget {
  const _VodSearchPane({
    required this.controller,
    required this.order,
    required this.duration,
    required this.onSubmitted,
    required this.onOrder,
    required this.onDuration,
    required this.onOpen,
  });

  final TextEditingController controller;
  final String order;
  final int duration;
  final VoidCallback onSubmitted;
  final ValueChanged<String> onOrder;
  final ValueChanged<int> onDuration;
  final ValueChanged<VodVideo> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final settings = ref.watch(browseSettingsProvider);
    final vod = ref.watch(vodProvider);
    final vodController = ref.read(vodProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: DsSearchField(
            controller: controller,
            autofocus: true,
            placeholder: t.vod.searchHint,
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(DsSpace.s20, 0, DsSpace.s20, DsSpace.s8),
          child: Wrap(
            spacing: DsSpace.s8,
            runSpacing: DsSpace.s8,
            children: [
              SizedBox(
                width: 150,
                child: AdaptiveChoiceField<String>(
                  value: order,
                  title: t.vod.sort,
                  semanticLabel: t.vod.sort,
                  onChanged: onOrder,
                  options: [
                    DsSelectOption(value: 'totalrank', label: t.vod.sortTotalrank),
                    DsSelectOption(value: 'click', label: t.vod.sortClick),
                    DsSelectOption(value: 'pubdate', label: t.vod.sortPubdate),
                    DsSelectOption(value: 'dm', label: t.vod.sortDm),
                    DsSelectOption(value: 'stow', label: t.vod.sortStow),
                  ],
                ),
              ),
              SizedBox(
                width: 160,
                child: AdaptiveChoiceField<int>(
                  value: duration,
                  title: t.vod.duration,
                  semanticLabel: t.vod.duration,
                  onChanged: onDuration,
                  options: [
                    DsSelectOption(value: 0, label: t.vod.durationAny),
                    DsSelectOption(value: 1, label: t.vod.durationUnder10),
                    DsSelectOption(value: 2, label: t.vod.duration10to30),
                    DsSelectOption(value: 3, label: t.vod.duration30to60),
                    DsSelectOption(value: 4, label: t.vod.durationOver60),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _VodSearchResults(state: vod, controller: vodController, settings: settings, onOpen: onOpen),
        ),
      ],
    );
  }
}

final class _VodSearchResults extends StatelessWidget {
  const _VodSearchResults({
    required this.state,
    required this.controller,
    required this.settings,
    required this.onOpen,
  });

  final VodState state;
  final VodController controller;
  final BrowseSettings settings;
  final ValueChanged<VodVideo> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    if (state.query.isEmpty) {
      return Center(
        child: DsEmptyState(
          icon: const DsIcon(DsIcons.search),
          title: Text(t.vod.idleTitle),
          description: Text(t.vod.idleDescription),
        ),
      );
    }
    return CardGrid<VodVideo>(
      items: state.videos,
      cardExtent: settings.homeCardExtent,
      crossSpacing: settings.crossSpacing,
      mainSpacing: settings.mainSpacing,
      isLoading: state.loading,
      hasMore: state.hasMore,
      onLoadMore: controller.loadMore,
      error: state.error?.message,
      onRetry: controller.retry,
      emptyIcon: DsIcons.searchX,
      emptyTitle: t.vod.noResultsTitle,
      emptyDescription: t.vod.noResultsDescription,
      itemBuilder: (context, video) => VodVideoCard(video: video, onOpen: () => onOpen(video)),
    );
  }
}
