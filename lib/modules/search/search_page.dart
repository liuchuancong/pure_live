import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/search_ranking.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:pure_live/modules/search/search_platform_strip.dart';
import 'package:pure_live/modules/search/search_controller.dart' as pure_live;

ScrollPhysics resolveSearchResultScrollPhysics(TargetPlatform platform) {
  return switch (platform) {
    TargetPlatform.android ||
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
              onPressed: () {
                if (Navigator.canPop(Get.context!)) {
                  Navigator.of(Get.context!).pop();
                }
              },
              icon: const Icon(Icons.arrow_back),
            ),
            suffixIcon: IconButton(onPressed: controller.doSearch, icon: const Icon(Icons.search)),
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
      body: Obx(() {
        return Column(
          children: [
            _SearchOptions(controller: controller),
            if (controller.pendingSiteCount.v > 0 && !controller.loading.v) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _buildContent(context)),
          ],
        );
      }),
    );
  }

  Widget _buildContent(BuildContext context) {
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
      return AppStatusView(
        type: AppStatusType.empty,
        icon: Icons.search_off_rounded,
        title: filteredOffline ? i18n('search_no_live_results') : i18n('search_no_results'),
        subtitle: controller.errorMessage.v,
        buttonText: filteredOffline
            ? i18n('search_show_offline')
            : controller.errorMessage.v.isNotEmpty
            ? i18n('retry')
            : controller.index.v == 0
            ? null
            : i18n('continue_web_search'),
        onButtonPressed: filteredOffline
            ? () => controller.setIncludeOffline(true)
            : controller.errorMessage.v.isNotEmpty
            ? controller.doSearch
            : controller.index.v == 0
            ? null
            : controller.openWebSearch,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width > 1280 ? 5 : (width > 960 ? 4 : (width > 640 ? 3 : 2));
        const spacing = 8.0;
        final itemWidth = (width - 16 - spacing * (columns - 1)) / columns;
        return Column(
          children: [
            if (controller.errorMessage.v.isNotEmpty)
              MaterialBanner(
                content: Text(controller.errorMessage.v),
                actions: [
                  if (controller.canOpenWebSearch)
                    TextButton(onPressed: controller.openWebSearch, child: Text(i18n('continue_web_search'))),
                  TextButton(
                    onPressed: () => controller.errorMessage.v = '',
                    child: Text(MaterialLocalizations.of(context).closeButtonLabel),
                  ),
                ],
              ),
            Expanded(
              child: CustomScrollView(
                controller: controller.scrollController,
                physics: resolveSearchResultScrollPhysics(Theme.of(context).platform),
                scrollCacheExtent: ScrollCacheExtent.pixels(width > 680 ? 480 : 320),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(8),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        mainAxisExtent: itemWidth * 9 / 16 + 72,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final room = controller.results[index];
                          return RoomCard(key: ValueKey('${room.platform}:${room.roomId}'), room: room, dense: true);
                        },
                        childCount: controller.results.length,
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
              ),
            ),
          ],
        );
      },
    );
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
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const PureLiveScrollPhysics(),
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
                    initialValue: controller.sortMode.v,
                    onSelected: controller.setSortMode,
                    itemBuilder: (context) => [
                      for (final mode in LiveSearchSortMode.values)
                        PopupMenuItem(value: mode, child: Text(_sortLabel(mode))),
                    ],
                    child: Chip(
                      avatar: const Icon(Icons.sort_rounded, size: 17),
                      label: Text(_sortLabel(controller.sortMode.v)),
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
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
