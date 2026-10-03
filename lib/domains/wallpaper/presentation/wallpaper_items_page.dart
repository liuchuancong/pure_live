import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/wallpaper/data/wallpaper_repository.dart';
import 'package:pure_live/domains/wallpaper/domain/background_controller.dart';
import 'package:pure_live/domains/wallpaper/domain/wallpaper_catalog.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_grid_controller.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_preview_page.dart';
import 'package:pure_live/domains/wallpaper/presentation/wallpaper_tile.dart';
import 'package:remixicon/remixicon.dart';

/// The wallpaper grid of one source/group.
///
/// It runs on the app's shared paging component, so a wallpaper list pages
/// exactly like every other list: numbered pages, a per-page selector and a
/// refresh on desktop, pull-to-refresh and appending on a phone. The preview
/// opened from here walks the very same controller.
class WallpaperItemsPage extends StatefulWidget {
  const WallpaperItemsPage({super.key, required this.sourceId, this.groupId});

  final String sourceId;

  /// Null falls back to the source's first visible group.
  final String? groupId;

  @override
  State<WallpaperItemsPage> createState() => _WallpaperItemsPageState();
}

class _WallpaperItemsPageState extends State<WallpaperItemsPage> {
  WallpaperSource? _source;
  WallpaperGroup? _group;
  BasePageScrollAndStateBone<WallpaperItem>? _controller;

  @override
  void initState() {
    super.initState();
    final WallpaperSource? source = WallpaperRepository.instance.loadCatalog().sourceById(widget.sourceId);
    final WallpaperGroup? group = source == null ? null : _pickGroup(source, widget.groupId);
    _source = source;
    _group = group;
    if (source != null && group != null) {
      final controller = WallpaperPagingStore.instance.obtain(source, group);
      _controller = controller;
      // A revisit keeps the page the previous visit left behind; only a cold
      // entry asks the source for its first page.
      if (controller.list.isEmpty && !controller.loadding.value) {
        unawaited(controller.loadData());
      }
    }
  }

  @override
  void dispose() {
    final source = _source;
    final group = _group;
    if (source != null && group != null) WallpaperPagingStore.instance.release(source, group);
    super.dispose();
  }

  Future<void> _openPreview(WallpaperItem item, int index) async {
    final source = _source;
    final group = _group;
    if (source == null || group == null) return;
    await Get.to<void>(
      () => WallpaperPreviewPage.catalog(
        sourceId: source.id,
        groupId: group.id,
        kind: source.kind,
        title: group.localizedName(Get.locale?.languageCode ?? 'zh'),
        initialIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final WallpaperSource? source = _source;
    final WallpaperGroup? group = _group;
    final BasePageScrollAndStateBone<WallpaperItem>? controller = _controller;
    final String title = group == null ? i18n('wallpaper_library') : group.localizedName(context.locale.languageCode);

    return Scaffold(
      // The wallpaper painted by AppBackgroundLayer stays visible behind the
      // grid; only the tiles themselves are opaque.
      appBar: AppBar(title: Text(title)),
      body: source == null || group == null || controller == null
          ? AppStatusView(type: AppStatusType.empty, title: i18n('background_no_category'), subtitle: '')
          : BasePageView<BasePageScrollAndStateBone<WallpaperItem>, WallpaperItem>(
              controller: controller,
              showScrollToTopBtn: SettingsService.to.page.showScrollToTopBtn.v,
              pageSizeOptions: SettingsService.to.page.pageSizeOptions,
              showPageSizeSelector: SettingsService.to.page.showPageSizeSelector.v,
              emptyBuilder: (context) => AppStatusView(
                type: AppStatusType.empty,
                icon: Remix.image_line,
                title: i18n('background_catalog_empty'),
                subtitle: '',
                buttonText: i18n('refresh'),
                onButtonPressed: () => unawaited(controller.refreshData()),
              ),
              contentBuilder: (context, list, scrollController) => Obx(() {
                // Both reactive reads happen here, not in the grid's item
                // callbacks: those run later, outside GetX's dependency window.
                final List<WallpaperItem> items = controller.list;
                final BackgroundController background = BackgroundController.to;
                final List<bool> selected = List<bool>.generate(
                  items.length,
                  (index) => background.usesWallpaper(items[index]),
                );
                return CustomScrollView(
                  controller: scrollController,
                  semanticChildCount: items.length,
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: <Widget>[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      sliver: SliverGrid.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.62,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => WallpaperTile(
                          item: items[index],
                          kind: source.kind,
                          selected: selected[index],
                          onTap: () => unawaited(_openPreview(items[index], index)),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
    );
  }

  static WallpaperGroup? _pickGroup(WallpaperSource source, String? wanted) {
    final List<WallpaperGroup> groups = source.visibleGroups;
    if (groups.isEmpty) return null;
    if (wanted == null) return groups.first;
    for (final WallpaperGroup group in groups) {
      if (group.id == wanted) return group;
    }
    return groups.first;
  }
}
