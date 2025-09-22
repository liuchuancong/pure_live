import 'package:get/get.dart';
import 'package:flutter/material.dart';

/// 水平 排列的 List
class HorizontalList<T> extends StatefulWidget {
  final List<Widget> children;
  late final TabController tabController;
  ItemChange? itemChange;
  int initialIndex;

  HorizontalList({super.key, required this.children, this.initialIndex = 0, this.itemChange});

  @override
  State<StatefulWidget> createState() {
    // ignore: no_logic_in_create_state
    return HorizontalListState<T>(children: children, itemChange: itemChange, initialIndex: initialIndex);
  }
}

/// 临时 TabController
class TmpTabController extends GetxController with GetSingleTickerProviderStateMixin {}

typedef ItemChange = void Function(int index);

class HorizontalListState<T> extends State<HorizontalList<T>> {
  final List<Widget> children;
  late final TabController tabController;
  ItemChange? itemChange;

  HorizontalListState({required this.children, int initialIndex = 0, this.itemChange}) {
    tabController = TabController(initialIndex: initialIndex, length: children.length, vsync: TmpTabController());
    tabController.addListener(tabControllerListener);
  }

  void tabControllerListener() {
    if (itemChange != null) {
      itemChange!(tabController.index);
    }
  }

  @override
  void dispose() {
    tabController.removeListener(tabControllerListener);
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: tabController,
      padding: EdgeInsets.zero,
      tabAlignment: TabAlignment.center,
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      tabs: children,
      isScrollable: true,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.4),
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.transparent, Colors.black45],
        ),
      ),
    );
  }
}
