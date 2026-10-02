import 'dart:async';

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
/// It pages the iTab API the same way the rest of the app pages a site list:
/// the grid appends the next slice as it scrolls and keeps the buffer, so the
/// preview opened from here walks the very same list. Tapping a tile opens the
/// fullscreen preview, which is where a background is applied.
class WallpaperItemsPage extends StatefulWidget {
  const WallpaperItemsPage({super.key, required this.sourceId, this.groupId});

  final String sourceId;

  /// Null falls back to the source's first visible group.
  final String? groupId;

  @override
  State<WallpaperItemsPage> createState() => _WallpaperItemsPageState();
}

class _WallpaperItemsPageState extends State<WallpaperItemsPage> {
  static const double _loadMoreThreshold = 600;

  final ScrollController _scroll = ScrollController();

  WallpaperSource? _source;
  WallpaperGroup? _group;
  WallpaperGridController? _controller;

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
      _scroll.addListener(_onScroll);
      // A revisit keeps the buffer the previous visit built; only a cold entry
      // asks the API for the first page.
      if (controller.list.isEmpty) unawaited(controller.refresh());
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    final source = _source;
    final group = _group;
    if (source != null && group != null) WallpaperPagingStore.instance.release(source, group);
    super.dispose();
  }

  void _onScroll() {
    final controller = _controller;
    if (controller == null || !_scroll.hasClients) return;
    final ScrollPosition position = _scroll.position;
    if (position.maxScrollExtent - position.pixels <= _loadMoreThreshold) {
      unawaited(controller.loadMore());
    }
  }

  /// Pulls the next slice in when the loaded rows do not fill the viewport:
  /// without this a short first page leaves nothing to scroll and the grid looks
  /// as if it simply ended.
  void _fillViewport() {
    final controller = _controller;
    if (controller == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (_scroll.position.maxScrollExtent <= 0 && controller.canLoadMore.value) {
        unawaited(controller.loadMore().then((_) => _fillViewport()));
      }
    });
  }

  Future<void> _openPreview(List<WallpaperItem> items, int index) async {
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
    final source = _source;
    final group = _group;
    final controller = _controller;
    final String title = group == null
        ? i18n('wallpaper_library')
        : group.localizedName(Get.locale?.languageCode ?? 'zh');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: source == null || group == null || controller == null
          ? AppStatusView(type: AppStatusType.empty, title: i18n('background_no_category'), subtitle: '')
          : _buildBody(controller),
    );
  }

  Widget _buildBody(WallpaperGridController controller) {
    _fillViewport();
    // One watch for the whole grid: the in-use flags are resolved inside this
    // builder rather than in the grid's item callbacks, which run later and
    // outside GetX's dependency collector.
    return Obx(() {
      final List<WallpaperItem> items = controller.list;
      if (items.isEmpty) {
        if (controller.loadding.value) {
          return AppStatusView(type: AppStatusType.loading, title: i18n('refresh_loading'), subtitle: '');
        }
        if (controller.pageError.value) {
          return AppStatusView(
            type: AppStatusType.error,
            title: i18n('network_error_title'),
            subtitle: controller.errorMsg.value,
            buttonText: i18n('retry'),
            onButtonPressed: () => unawaited(controller.refresh()),
          );
        }
        return AppStatusView(type: AppStatusType.empty, title: i18n('background_catalog_empty'), subtitle: '');
      }

      final BackgroundController background = BackgroundController.to;
      final List<bool> selected = List<bool>.generate(items.length, (index) => background.usesWallpaper(items[index]));
      final WallpaperKind kind = _source!.kind;

      return CustomScrollView(
        controller: _scroll,
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                kind: kind,
                selected: selected[index],
                onTap: () => unawaited(_openPreview(items, index)),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildFooter(controller)),
        ],
      );
    });
  }

  Widget _buildFooter(WallpaperGridController controller) {
    if (controller.loadding.value) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (controller.errorMsg.value.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: context.buildModernCard([
          context.buildTile(
            icon: Remix.error_warning_line,
            title: i18n('background_load_failed'),
            subtitle: controller.errorMsg.value,
            trailing: const Icon(Remix.refresh_line),
            onTap: () => unawaited(controller.loadMore()),
          ),
        ]),
      );
    }
    return const SizedBox(height: 24);
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
