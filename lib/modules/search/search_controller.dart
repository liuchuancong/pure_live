import 'package:get/get.dart';
import '../../core/sites.dart';
import 'search_list_controller.dart';
import 'package:flutter/material.dart';

class SearchController extends GetxController with GetSingleTickerProviderStateMixin {
  late TabController tabController;
  var index = 0.obs;

  SearchController() {
    tabController = TabController(
      length: Sites().availableSites().length,
      vsync: this,
    );

    tabController.addListener(() {
      index.value = tabController.index;
      var controller = Get.find<SearchListController>(tag: Sites().availableSites()[index.value].id);
      controller.keyword.value = searchController.text;
      controller.refreshData();
    });
  }

  TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    for (var site in Sites().availableSites(containsAll: true)) {
      Get.put(SearchListController(site), tag: site.id);
    }

    super.onInit();
  }

  void doSearch() {
    if (searchController.text.isEmpty) {
      return;
    }
    var controller = Get.find<SearchListController>(tag: Sites().availableSites()[index.value].id);
    controller.clear();
    controller.keyword.value = searchController.text;
    controller.loadData();
  }
}
