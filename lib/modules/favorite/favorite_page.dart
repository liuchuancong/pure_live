import 'package:remixicon/remixicon.dart';
import 'package:pure_live/common/index.dart';
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
            body: DefaultTabController(
              length: availableSitesList.length,
              child: _FavoriteSiteTabs(controller: controller, availableSitesList: availableSitesList),
            ),
          );
        });
      },
    );
  }
}

/// Keeps the inherited site [TabController] listener stable across Obx rebuilds.
///
/// Registering the listener inside `build` accumulated callbacks whenever a
/// room status changed, which made tab swipes and later refreshes progressively
/// more expensive on desktop.
class _FavoriteSiteTabs extends StatefulWidget {
  const _FavoriteSiteTabs({required this.controller, required this.availableSitesList});

  final FavoriteController controller;
  final List<Site> availableSitesList;

  @override
  State<_FavoriteSiteTabs> createState() => _FavoriteSiteTabsState();
}

class _FavoriteSiteTabsState extends State<_FavoriteSiteTabs> {
  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextController = DefaultTabController.of(context);
    if (identical(nextController, _tabController)) return;
    _tabController?.removeListener(_handleTabChanged);
    _tabController = nextController..addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    final tabController = _tabController;
    if (tabController == null || tabController.indexIsChanging) return;
    final controller = widget.controller;
    if (controller.tabSiteIndex.value == tabController.index) return;

    controller.selectedTagId.value = TagManagementController.allTagKey;
    controller.tabSiteIndex.value = tabController.index;
    controller.currentPage = 1;
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final availableSitesList = widget.availableSitesList;
    return Column(
      children: [
        TabBar(isScrollable: true, tabs: availableSitesList.map((e) => Tab(text: e.name)).toList()),
        Expanded(
          child: BasePageView<FavoriteController, LiveRoom>(
            controller: controller,
            enableRefresh: true,
            enableLoadMore: true,
            emptyBuilder: (context) => AppStatusView(
              type: AppStatusType.empty,
              icon: Remix.heart_3_fill,
              title: i18n("empty_favorite_online_title"),
              subtitle: i18n("empty_favorite_online_subtitle"),
            ),
            showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
            showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
            pageSizeOptions: SettingsService.to.page.pageSizeOptions,
            contentBuilder: (context, list, scrollController) {
              return TabBarView(
                children: availableSitesList.map((e) {
                  return RoomGridView(
                    site: e.id,
                    isOnline: controller.tabOnlineIndex.value != 1,
                    scrollController: scrollController,
                    displayList: list,
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
