import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/search_ranking.dart';
import 'package:pure_live/modules/search/search_controller.dart' as pure_live;
import 'package:pure_live/modules/search/search_platform_strip.dart';

ScrollPhysics resolveSearchResultScrollPhysics(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.iOS => const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
    _ => const PureLiveScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
  };
}

class SearchPage extends GetView<pure_live.SearchController> {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: TextField(
          controller: controller.searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: i18n("search_input_hint"),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
            prefixIcon: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () {
                if (Navigator.canPop(Get.context!)) {
                  Navigator.of(Get.context!).pop();
                }
              },
              icon: const Icon(Icons.arrow_back),
            ),
            suffixIcon: IconButton(
              tooltip: i18n('search_live'),
              onPressed: controller.doSearch,
              icon: const Icon(Icons.search),
            ),
          ),
          onSubmitted: (e) {
            controller.doSearch();
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(searchPlatformStripHeight),
          child: Obx(
            () => SearchPlatformStrip(
              labels: [i18n('site_all'), ...controller.sites.map((site) => site.name)],
              selectedIndex: controller.index.v,
              onSelected: controller.selectPlatform,
            ),
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Obx(
          () => CustomScrollView(
            key: const ValueKey('search-content'),
            controller: controller.scrollController,
            physics: resolveSearchResultScrollPhysics(Theme.of(context).platform),
            scrollCacheExtent: ScrollCacheExtent.pixels(constraints.maxWidth > 680 ? 480 : 320),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            semanticChildCount: controller.loading.v ? 0 : controller.results.length,
            slivers: _buildSlivers(context, constraints.maxWidth),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSlivers(BuildContext context, double width) {
    final columns = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
    const spacing = 8.0;

    return [
      // Let all explanatory text scroll instead of consuming a fixed header
      // above an Expanded result region (which can shrink to zero).
      SliverToBoxAdapter(child: _SearchOptions(controller: controller)),
      if (controller.pendingSiteCount.v > 0 && !controller.loading.v)
        const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
      if (controller.loading.v || !controller.searched.v || controller.results.isEmpty)
        _buildStatusSliver(_buildStatus(context))
      else ...[
        if (controller.errorMessage.v.isNotEmpty)
          SliverToBoxAdapter(
            child: MaterialBanner(
              content: Text(controller.errorMessage.v),
              forceActionsBelow: true,
              actions: [
                if (controller.canOpenWebSearch)
                  TextButton(onPressed: controller.openWebSearch, child: Text(i18n('continue_web_search'))),
                TextButton(
                  onPressed: () => controller.errorMessage.v = '',
                  child: Text(MaterialLocalizations.of(context).closeButtonLabel),
                ),
              ],
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(8),
          // Lay out one lazy row at a time. Its natural height follows the
          // actual RoomCard text metrics, including nonlinear font scaling.
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, row) => Padding(
                padding: const EdgeInsets.only(bottom: spacing),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: spacing),
                      Expanded(
                        child: row * columns + column < controller.results.length
                            ? IndexedSemantics(
                                index: row * columns + column,
                                child: RoomCard(
                                  key: ValueKey(
                                    '${controller.results[row * columns + column].platform}:${controller.results[row * columns + column].roomId}',
                                  ),
                                  room: controller.results[row * columns + column],
                                  dense: true,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
              childCount: (controller.results.length + columns - 1) ~/ columns,
              addSemanticIndexes: false,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Center(
                child: controller.loadingMore.v
                    ? const SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : controller.hasMore.v
                    ? TextButton.icon(
                        onPressed: controller.loadMore,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(i18n('load_more_results')),
                      )
                    : Text(
                        i18n('all_results_loaded'),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
              ),
            ),
          ),
        ),
      ],
    ];
  }

  Widget _buildStatusSliver(Widget status) {
    return SliverLayoutBuilder(
      builder: (context, constraints) => SliverToBoxAdapter(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.viewportMainAxisExtent - constraints.precedingScrollExtent).clamp(
              0.0,
              double.infinity,
            ),
          ),
          child: status,
        ),
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    if (controller.loading.v) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!controller.searched.v) {
      return AppStatusView(
        type: AppStatusType.empty,
        icon: Icons.travel_explore_rounded,
        title: i18n('native_search_title'),
        subtitle: i18n('native_search_desc'),
      );
    }
    if (controller.results.isEmpty) {
      final filteredOffline = controller.hasFilteredOfflineResults;
      final canRetry = controller.errorMessage.v.isNotEmpty && controller.canSearchNatively;
      return AppStatusView(
        type: AppStatusType.empty,
        icon: Icons.search_off_rounded,
        title: filteredOffline ? i18n('search_no_live_results') : i18n('search_no_results'),
        subtitle: controller.errorMessage.v,
        buttonText: filteredOffline
            ? i18n('search_show_offline')
            : canRetry
            ? i18n('retry')
            : !controller.canOpenWebSearch
            ? null
            : i18n('continue_web_search'),
        onButtonPressed: filteredOffline
            ? () => controller.setIncludeOffline(true)
            : canRetry
            ? controller.doSearch
            : !controller.canOpenWebSearch
            ? null
            : controller.openWebSearch,
      );
    }
    throw StateError('Search status requested with visible results');
  }
}

class _SearchOptions extends StatelessWidget {
  const _SearchOptions({required this.controller});

  final pure_live.SearchController controller;

  String _sortLabel(LiveSearchSortMode mode) => switch (mode) {
    LiveSearchSortMode.smart => i18n('search_sort_smart'),
    LiveSearchSortMode.platform => i18n('search_sort_platform'),
    LiveSearchSortMode.audience => i18n('search_sort_audience'),
    LiveSearchSortMode.followers => i18n('search_sort_followers'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(
      () => Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const PureLiveBoundedScrollPhysics(),
                clipBehavior: Clip.hardEdge,
                child: Row(
                  children: [
                    FilterChip(
                      avatar: const Icon(Icons.offline_bolt_rounded, size: 17),
                      label: Text(i18n('search_include_offline')),
                      selected: controller.includeOffline.v,
                      onSelected: controller.setIncludeOffline,
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<LiveSearchSortMode>(
                      key: const ValueKey('search-sort-selector'),
                      tooltip: _sortLabel(controller.sortMode.v),
                      initialValue: controller.sortMode.v,
                      onSelected: controller.setSortMode,
                      itemBuilder: (context) => [
                        for (final mode in LiveSearchSortMode.values)
                          PopupMenuItem(value: mode, child: Text(_sortLabel(mode))),
                      ],
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: kMinInteractiveDimension,
                          minHeight: kMinInteractiveDimension,
                        ),
                        child: Chip(
                          avatar: const Icon(Icons.sort_rounded, size: 17),
                          label: Text(_sortLabel(controller.sortMode.v)),
                        ),
                      ),
                    ),
                    if (controller.canOpenWebSearch) ...[
                      const SizedBox(width: 8),
                      ActionChip(
                        avatar: const Icon(Icons.open_in_browser_rounded, size: 17),
                        label: Text(i18n('continue_web_search')),
                        onPressed: controller.openWebSearch,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      controller.capabilityText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
