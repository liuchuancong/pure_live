import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class PageSettingsController extends GetxController {
  static PageSettingsController get to => Get.find<PageSettingsController>();

  final RxBool showPageSizeSelector = hiveBool('page_show_size_selector', false);
  final RxBool showGotoButton = hiveBool('page_show_goto_button', false);
  final RxBool showScrollToTopBtn = hiveBool('page_show_scroll_top', true);
  final RxInt defaultPageSize = hiveInt('page_default_size', _getInitPageSize());

  final RxString _pageSizeOptionsRaw = hiveString('page_size_options_raw', '');
  final pageSizeOptions = <int>[].obs;

  static int _getInitPageSize() {
    try {
      final double width = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width;
      final double devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final double logicalWidth = width / (devicePixelRatio > 0 ? devicePixelRatio : 1);

      if (logicalWidth > 960) return 20;
      return 12;
    } catch (_) {
      return 12;
    }
  }

  static List<int> getInitPageSizeOptions() {
    try {
      final double width = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width;
      final double devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
      final double logicalWidth = width / (devicePixelRatio > 0 ? devicePixelRatio : 1);

      if (logicalWidth > 960) {
        return [20, 40, 60, 80];
      }
      return [12, 24, 36, 48];
    } catch (_) {
      return [12, 24, 36, 48];
    }
  }

  @override
  void onInit() {
    super.onInit();
    _loadPageSizeOptions();

    ever(pageSizeOptions, (List<int> options) {
      if (options.isNotEmpty && !options.contains(defaultPageSize.v)) {
        defaultPageSize.v = options.first;
      }
    });

    debounce(defaultPageSize, (int size) {
      if (size <= 0 || !pageSizeOptions.contains(size)) {
        if (pageSizeOptions.isNotEmpty) {
          defaultPageSize.v = pageSizeOptions.first;
        } else {
          defaultPageSize.v = _getInitPageSize();
        }
      }
    }, time: const Duration(milliseconds: 300));
  }

  void _loadPageSizeOptions() {
    try {
      final List<dynamic> decoded = jsonDecode(_pageSizeOptionsRaw.v);
      pageSizeOptions.assignAll(decoded.cast<int>());
    } catch (_) {
      pageSizeOptions.assignAll(getInitPageSizeOptions());
    }
  }

  void saveAllPageSizeOptions(List<int> newOptions) {
    if (newOptions.isNotEmpty) {
      newOptions.sort();
      pageSizeOptions.assignAll(newOptions);
      _pageSizeOptionsRaw.v = jsonEncode(newOptions);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'showPageSizeSelector': showPageSizeSelector.v,
      'showGotoButton': showGotoButton.v,
      'showScrollToTopBtn': showScrollToTopBtn.v,
      'defaultPageSize': defaultPageSize.v,
      'pageSizeOptions': pageSizeOptions.toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    showPageSizeSelector.v = json['showPageSizeSelector'] as bool? ?? false;
    showGotoButton.v = json['showGotoButton'] as bool? ?? false;
    showScrollToTopBtn.v = json['showScrollToTopBtn'] as bool? ?? true;
    defaultPageSize.v = json['defaultPageSize'] as int? ?? _getInitPageSize();

    final List<dynamic>? options = json['pageSizeOptions'] as List<dynamic>?;
    if (options != null) {
      pageSizeOptions.assignAll(options.cast<int>());
      _pageSizeOptionsRaw.v = jsonEncode(options);
    } else {
      pageSizeOptions.assignAll(getInitPageSizeOptions());
      _pageSizeOptionsRaw.v = '';
    }
  }
}
