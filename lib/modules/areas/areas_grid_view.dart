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

class _AreaGridViewState extends State<AreaGridView> with SingleTickerProviderStateMixin {
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
    return Obx(() {
      final list = widget.controller.list;
      if (list.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (widget.isFlatten) {
        final allChildren = list.expand((e) => e.children).toList();
        return buildFlattenAreasView(allChildren);
      }
      if (_tabController == null || _tabController!.length != list.length) {
        return const Center(child: CircularProgressIndicator());
      }

      return Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            indicatorSize: TabBarIndicatorSize.label,
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
                padding: const EdgeInsets.all(0),
                controller: ScrollController(),
                gridDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
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
