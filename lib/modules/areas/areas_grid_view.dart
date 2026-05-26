import 'package:pure_live/common/index.dart';
import 'package:waterfall_flow/waterfall_flow.dart';
import 'package:pure_live/modules/areas/widgets/area_card.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';

class AreaGridView extends StatefulWidget {
  final String tag;
  const AreaGridView(this.tag, {super.key});
  AreasListController get controller => Get.find<AreasListController>(tag: tag);

  bool get isFlatten => tag == Sites.douyinSite;

  @override
  State<AreaGridView> createState() => _AreaGridViewState();
}

class _AreaGridViewState extends State<AreaGridView> with TickerProviderStateMixin {
  TabController? _tabController;
  Worker? _listWorker;

  @override
  void initState() {
    super.initState();
    if (!widget.isFlatten) {
      _listWorker = ever(widget.controller.list, (_) => _createTabController());
      _createTabController();
      widget.controller.tabIndex.addListener(_handleExternalIndexChange);
    }
  }

  void _createTabController() {
    if (widget.isFlatten) return;
    final list = widget.controller.list;
    if (list.isEmpty) return;

    if (_tabController != null && _tabController!.length == list.length) {
      return;
    }

    if (_tabController != null) {
      _tabController!.removeListener(_handleInternalTabChange);
      _tabController!.dispose();
    }

    int initialIndex = widget.controller.tabIndex.value;
    if (initialIndex >= list.length) initialIndex = 0;

    _tabController = TabController(length: list.length, vsync: this, initialIndex: initialIndex);
    _tabController!.addListener(_handleInternalTabChange);

    if (mounted) setState(() {});
  }

  void _handleInternalTabChange() {
    if (_tabController == null || _tabController!.indexIsChanging) return;
    if (widget.controller.tabIndex.value != _tabController!.index) {
      widget.controller.tabIndex.value = _tabController!.index;
    }
  }

  void _handleExternalIndexChange() {
    if (_tabController == null) return;
    final targetIndex = widget.controller.tabIndex.value;
    if (_tabController!.index != targetIndex && targetIndex < _tabController!.length) {
      _tabController!.animateTo(targetIndex);
    }
  }

  @override
  void dispose() {
    if (!widget.isFlatten) {
      widget.controller.tabIndex.removeListener(_handleExternalIndexChange);
      _listWorker?.dispose();
      if (_tabController != null) {
        _tabController!.removeListener(_handleInternalTabChange);
        _tabController!.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      if (widget.controller.pageLoadding.value) {
        return const AppStatusView(type: AppStatusType.loading, title: "", subtitle: "");
      }

      if (widget.controller.pageError.value) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.controller.errorMsg.value,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => widget.controller.refreshData(),
                icon: const Icon(Icons.refresh),
                label: Text(i18n("retry")),
              ),
            ],
          ),
        );
      }

      if (widget.controller.pageEmpty.value || widget.controller.list.isEmpty) {
        return EmptyView(
          icon: Icons.area_chart_outlined,
          title: i18n("empty_areas_title"),
          subtitle: i18n("empty_areas_subtitle"),
        );
      }

      final list = widget.controller.list;

      if (widget.isFlatten) {
        final allChildren = list.expand((e) => e.children).toList();
        return buildFlattenAreasView(allChildren);
      }

      if (_tabController == null || _tabController!.length != list.length) {
        return const AppStatusView(type: AppStatusType.loading, title: "", subtitle: "");
      }

      return Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: list.map((e) => Tab(text: e.name)).toList(),
          ),
          Expanded(
            child: TabBarView(controller: _tabController, children: list.map((e) => buildAreasView(e)).toList()),
          ),
        ],
      );
    });
  }

  Widget buildAreasView(AppLiveCategory category) {
    return buildFlattenAreasView(category.children);
  }

  Widget buildFlattenAreasView(List<dynamic> childrenList) {
    return LayoutBuilder(
      builder: (context, constraint) {
        final width = constraint.maxWidth;
        final crossAxisCount = width > 1280 ? 9 : (width > 960 ? 7 : (width > 640 ? 5 : 3));
        return childrenList.isNotEmpty
            ? WaterfallFlow.builder(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                controller: widget.controller.scrollController,
                gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                  lastChildLayoutTypeBuilder: (index) => LastChildLayoutType.none,
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: widget.controller.settings.crossAxisSpacing.value,
                  mainAxisSpacing: widget.controller.settings.mainAxisSpacing.value,
                ),
                itemCount: childrenList.length,
                itemBuilder: (context, index) => AreaCard(category: childrenList[index]),
              )
            : EmptyView(
                icon: Icons.area_chart_outlined,
                title: i18n("empty_areas_title"),
                subtitle: i18n("empty_areas_subtitle"),
              );
      },
    );
  }
}
