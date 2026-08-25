import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/favorite/room_grid_view.dart';
import 'package:pure_live/common/widgets/common_appbar_actions.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';

class FavoritePage extends GetView<FavoriteController> {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraint) {
        return Obx(() {
          bool showAction = Get.width <= 680;
          final availableSitesList = Sites().availableSites(containsAll: true);
          final siteKey = ValueKey(availableSitesList.map((e) => e.id).join('|'));

          return Scaffold(
            appBar: AppBar(
              centerTitle: true,
              leading: showAction ? const MenuButton() : null,
              actions: showAction ? [CommonAppBarActions()] : null,
              title: TabBar(
                controller: controller.tabController,
                isScrollable: true,
                tabs: [
                  Tab(text: i18n("online_room_title")),
                  Tab(text: i18n("recording_room_title")),
                  Tab(text: i18n("offline_room_title")),
                ],
              ),
            ),
            body: _FavoriteSiteTabs(key: siteKey, controller: controller, availableSitesList: availableSitesList),
          );
        });
      },
    );
  }
}

@visibleForTesting
int resolveFavoriteSiteIndex({required List<String> siteIds, required String selectedSiteId, required int fallback}) {
  if (siteIds.isEmpty) return 0;
  final selectedIndex = siteIds.indexOf(selectedSiteId);
  return selectedIndex >= 0 ? selectedIndex : fallback.clamp(0, siteIds.length - 1).toInt();
}

/// Owns one stable site [TabController] across reactive data publications.
///
/// It also preserves the selected site by id when the configured platform
/// order changes, instead of resetting the visual controller to index zero
/// while the data controller still points at an older numeric index.
class _FavoriteSiteTabs extends StatefulWidget {
  const _FavoriteSiteTabs({super.key, required this.controller, required this.availableSitesList});

  final FavoriteController controller;
  final List<Site> availableSitesList;

  @override
  State<_FavoriteSiteTabs> createState() => _FavoriteSiteTabsState();
}

class _FavoriteSiteTabsState extends State<_FavoriteSiteTabs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, ScrollController> _siteScrollControllers = {};

  ScrollController _scrollControllerFor(String siteId) =>
      _siteScrollControllers.putIfAbsent(siteId, () => createPureLiveScrollController());

  @override
  void initState() {
    super.initState();
    final initialIndex = resolveFavoriteSiteIndex(
      siteIds: widget.availableSitesList.map((site) => site.id).toList(growable: false),
      selectedSiteId: widget.controller.selectedPlatformId,
      fallback: widget.controller.tabSiteIndex.value,
    );
    _tabController = TabController(length: widget.availableSitesList.length, initialIndex: initialIndex, vsync: this)
      ..addListener(_handleTabChanged);
    widget.controller.bindActiveScrollController(_scrollControllerFor(widget.availableSitesList[initialIndex].id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.selectSiteIndex(initialIndex);
    });
  }

  void _handleTabChanged() {
    final tabController = _tabController;
    if (tabController.indexIsChanging) return;
    final animationValue = tabController.animation?.value ?? tabController.index.toDouble();
    if ((animationValue - tabController.index).abs() > 0.001) return;
    final controller = widget.controller;
    if (tabController.index < 0 || tabController.index >= widget.availableSitesList.length) return;
    controller.bindActiveScrollController(_scrollControllerFor(widget.availableSitesList[tabController.index].id));
    controller.selectSiteIndex(tabController.index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    widget.controller.bindActiveScrollController(null);
    for (final controller in _siteScrollControllers.values) {
      controller.dispose();
    }
    _siteScrollControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final availableSitesList = widget.availableSitesList;
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          physics: const PureLiveScrollPhysics(),
          tabs: availableSitesList.map((e) => Tab(text: e.name)).toList(),
        ),
        FavoriteTagStrip(
          tags: controller.visibleTags,
          selectedTagId: controller.selectedTagId,
          allLabel: i18n('recorder_tab_all'),
          onSelected: controller.changeSelectedTag,
        ),
        Expanded(
          child: BasePageView<FavoriteController, LiveRoom>(
            controller: controller,
            enableRefresh: true,
            enableLoadMore: true,
            wrapMobileRefresh: false,
            preserveContentWhenEmpty: true,
            showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
            showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
            pageSizeOptions: SettingsService.to.page.pageSizeOptions,
            contentBuilder: (context, list, _) {
              final activeSiteIndex = controller.tabSiteIndex.value;
              return TabBarView(
                controller: _tabController,
                children: availableSitesList.asMap().entries.map((entry) {
                  final site = entry.value;
                  return Builder(
                    key: ValueKey('favorite_site_${site.id}'),
                    builder: (context) {
                      // PageView mounts only the active/nearby pages. Defer
                      // platform filtering and ScrollController allocation to
                      // that point rather than doing both for every platform
                      // on each reactive rebuild.
                      final isCurrentSite = entry.key == activeSiteIndex;
                      final pageList = isCurrentSite ? list : controller.filteredSyncedRoomsForSite(site.id);
                      return RoomGridView(
                        siteId: site.id,
                        scrollController: _scrollControllerFor(site.id),
                        displayList: pageList,
                        emptyBuilder: (context) => _FavoriteEmptyState(controller: controller, siteId: site.id),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class FavoriteTagStrip extends StatelessWidget {
  const FavoriteTagStrip({
    super.key,
    required this.tags,
    required this.selectedTagId,
    required this.allLabel,
    required this.onSelected,
    this.labelStyle,
  });

  final RxList<LiveTag> tags;
  final RxString selectedTagId;
  final String allLabel;
  final ValueChanged<String> onSelected;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      // Read both reactive values before entering ListView.builder. Its lazy
      // itemBuilder runs outside GetX's dependency collector, which previously
      // left the visual chip on “全部” while the data filter had already moved
      // to a custom tag.
      final visibleTags = tags.toList(growable: false);
      final activeTagId = selectedTagId.value;
      if (visibleTags.isEmpty) return const SizedBox.shrink();
      return SizedBox(
        key: const ValueKey('favorite_tag_strip'),
        height: 44,
        width: double.infinity,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const PureLiveScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          itemCount: visibleTags.length + 1,
          itemBuilder: (context, index) {
            final isAll = index == 0;
            final tag = isAll ? null : visibleTags[index - 1];
            final tagId = tag?.id ?? TagManagementController.allTagKey;
            final isSelected = activeTagId == tagId;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                key: ValueKey('favorite_tag_$tagId'),
                showCheckmark: false,
                label: Text(
                  tag?.name ?? allLabel,
                  style: (labelStyle ?? AppTextStyles.t12).copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                selected: isSelected,
                selectedColor: theme.colorScheme.primary,
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : theme.dividerColor.withValues(alpha: 0.04),
                    width: 0.5,
                  ),
                ),
                onSelected: (_) => onSelected(tagId),
              ),
            );
          },
        ),
      );
    });
  }
}

class _FavoriteEmptyState extends StatelessWidget {
  const _FavoriteEmptyState({required this.controller, required this.siteId});

  final FavoriteController controller;
  final String siteId;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final statusIndex = controller.tabOnlineIndex.value;
      final totalForSite = controller.favoriteCountForSite(siteId);
      final globalTotal = SettingsService.to.fav.favoriteRooms.v.length;
      final offlineForSite = controller.favoriteCountForSite(siteId, statusIndex: 2);

      if (globalTotal == 0) {
        return AppStatusView(
          type: AppStatusType.empty,
          icon: Remix.heart_3_fill,
          title: i18n('empty_favorite_online_title'),
          subtitle: i18n('empty_favorite_online_subtitle'),
          buttonText: i18n('retry'),
          onButtonPressed: controller.refreshData,
        );
      }

      final title = switch (statusIndex) {
        1 => i18n('favorite_empty_recording_title'),
        2 => i18n('favorite_empty_offline_title'),
        _ => i18n('favorite_empty_online_title'),
      };
      final subtitleKey = totalForSite == 0 ? 'favorite_empty_platform_subtitle' : 'favorite_empty_filter_subtitle';
      final subtitle = i18n(subtitleKey).replaceAll('{count}', totalForSite.toString());
      final canShowOffline = statusIndex != 2 && offlineForSite > 0;

      return AppStatusView(
        type: AppStatusType.empty,
        icon: Remix.heart_3_fill,
        title: title,
        subtitle: subtitle,
        buttonText: canShowOffline ? i18n('favorite_show_offline') : i18n('retry'),
        onButtonPressed: canShowOffline ? () => controller.animateToStatusIndex(2) : controller.refreshData,
      );
    });
  }
}
