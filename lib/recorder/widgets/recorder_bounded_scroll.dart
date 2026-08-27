import 'package:flutter/material.dart';

class RecorderStatusTabBar extends StatelessWidget implements PreferredSizeWidget {
  const RecorderStatusTabBar({super.key, required this.labels});

  final List<String> labels;

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false, scrollbars: false),
      child: TabBar(
        isScrollable: true,
        physics: const ClampingScrollPhysics(),
        tabs: labels
            .map(
              (label) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Tab(text: label),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class RecorderBoundedTaskList extends StatelessWidget {
  const RecorderBoundedTaskList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false, scrollbars: false),
      child: ListView.builder(
        physics: const ClampingScrollPhysics(),
        clipBehavior: Clip.hardEdge,
        padding: padding,
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}
