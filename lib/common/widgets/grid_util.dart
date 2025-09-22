import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'grid.dart';

final class GradUtil {
  static Widget count({
    Key? key,
    Axis scrollDirection = Axis.vertical,
    bool reverse = false,
    ScrollController? controller,
    bool? primary,
    ScrollPhysics? physics,
    bool shrinkWrap = false,
    EdgeInsetsGeometry? padding,
    required int crossAxisCount,
    mainAxisSpacing = 0.0,
    crossAxisSpacing = 0.0,
    required IndexedWidgetBuilder itemBuilder,
    int? itemCount,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    bool addSemanticIndexes = true,
    double? cacheExtent,
    int? semanticChildCount,
    ScrollViewKeyboardDismissBehavior keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    String? restorationId,
    Clip clipBehavior = Clip.hardEdge,
  }) {
    return CustomScrollView(cacheExtent: cacheExtent ?? 30, controller: ScrollController(), physics: const AlwaysScrollableScrollPhysics(), slivers: [
      SliverPadding(
          padding: padding ?? EdgeInsets.fromLTRB(0, 0, 0, 0),
          sliver: SliverGrid(
            key: key,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              // 行间距
              mainAxisSpacing: mainAxisSpacing,
              // 列间距
              crossAxisSpacing: crossAxisSpacing,
              // 列数
              crossAxisCount: crossAxisCount,
              mainAxisExtent: MediaQuery.of(Get.context!).size.width / crossAxisCount / 0.65 + MediaQuery.textScalerOf(Get.context!).scale(32.0),
            ),
            delegate: SliverChildBuilderDelegate(
              itemBuilder,
              childCount: itemCount,
            ),
          ))
    ]);
  }

  static Widget contentGrid({
    Key? key,
    EdgeInsetsGeometry? padding,
    required int crossAxisCount,
    mainAxisSpacing = 0.0,
    crossAxisSpacing = 0.0,
    required IndexedWidgetBuilder itemBuilder,
    int? itemCount,
    Clip clipBehavior = Clip.hardEdge,
    double? cacheExtent,
    ScrollController? controller,
  }) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithExtentAndRatio(
        // 行间距
        // mainAxisSpacing: StyleString.cardSpace,
        // 列间距
        // crossAxisSpacing: StyleString.cardSpace,
        // 最大宽度
        maxCrossAxisExtent: Grid.maxRowWidth,
        childAspectRatio: StyleString.aspectRatio,
        mainAxisExtent: MediaQuery.textScalerOf(Get.context!).scale(60),
      ),
      delegate: SliverChildBuilderDelegate(
        itemBuilder,
        childCount: itemCount,
      ),
    );
  }
}

class StyleString {
  static const double cardSpace = 8;
  static const double safeSpace = 12;
  static BorderRadius mdRadius = BorderRadius.circular(10);
  static const Radius imgRadius = Radius.circular(10);
  static const double aspectRatio = 16 / 10;
}