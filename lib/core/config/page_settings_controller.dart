import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/storage/hive_rx.dart';

class PageSettingsController extends GetxController {
  static const int minPageSize = 1;
  static const int maxPageSize = 100;

  static PageSettingsController get to => Get.find<PageSettingsController>();

  final RxBool showPageSizeSelector = hiveBool('page_show_size_selector', true);
  final RxBool showGotoButton = hiveBool('page_show_goto_button', true);
  final RxBool showScrollToTopBtn = hiveBool('page_show_scroll_top', true);
  final RxInt defaultPageSize = hiveInt('page_default_size', _getInitPageSize());

  final RxString _pageSizeOptionsRaw = hiveString('page_size_options_raw', '');
  final pageSizeOptions = <int>[].obs;
  final List<Worker> _workers = [];

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

  static bool isValidPageSize(int value) => value >= minPageSize && value <= maxPageSize;

  static List<int> normalizePageSizeOptions(Iterable<int> values) {
    final normalized = values.where(isValidPageSize).toSet().toList()..sort();
    if (normalized.isNotEmpty) return normalized;
    return getInitPageSizeOptions().where(isValidPageSize).toSet().toList()..sort();
  }

  static int normalizeDefaultPageSize(int value, Iterable<int> options) {
    final normalizedOptions = normalizePageSizeOptions(options);
    return normalizedOptions.contains(value) ? value : normalizedOptions.first;
  }

  @override
  void onInit() {
    super.onInit();
    _loadPageSizeOptions();

    _workers.add(
      ever(pageSizeOptions, (List<int> options) {
        final normalized = normalizePageSizeOptions(options);
        if (!listEquals(options, normalized)) {
          pageSizeOptions.assignAll(normalized);
          return;
        }
        _pageSizeOptionsRaw.v = jsonEncode(normalized);
        final normalizedDefault = normalizeDefaultPageSize(defaultPageSize.v, normalized);
        if (normalizedDefault != defaultPageSize.v) defaultPageSize.v = normalizedDefault;
      }),
    );

    _workers.add(
      debounce(defaultPageSize, (int size) {
        final normalized = normalizeDefaultPageSize(size, pageSizeOptions);
        if (normalized != size) defaultPageSize.v = normalized;
      }, time: const Duration(milliseconds: 300)),
    );
  }

  @override
  void onClose() {
    for (final worker in _workers) {
      worker.dispose();
    }
    super.onClose();
  }

  void _loadPageSizeOptions() {
    late final List<int> decodedOptions;
    try {
      final List<dynamic> decoded = jsonDecode(_pageSizeOptionsRaw.v);
      decodedOptions = List<int>.from(decoded);
    } catch (_) {
      decodedOptions = getInitPageSizeOptions();
    }
    final normalized = normalizePageSizeOptions(decodedOptions);
    pageSizeOptions.assignAll(normalized);
    final encoded = jsonEncode(normalized);
    if (_pageSizeOptionsRaw.v != encoded) _pageSizeOptionsRaw.v = encoded;
    final normalizedDefault = normalizeDefaultPageSize(defaultPageSize.v, normalized);
    if (defaultPageSize.v != normalizedDefault) defaultPageSize.v = normalizedDefault;
  }

  void saveAllPageSizeOptions(List<int> newOptions) {
    final normalized = normalizePageSizeOptions(newOptions);
    pageSizeOptions.assignAll(normalized);
    _pageSizeOptionsRaw.v = jsonEncode(normalized);
    final normalizedDefault = normalizeDefaultPageSize(defaultPageSize.v, normalized);
    if (defaultPageSize.v != normalizedDefault) defaultPageSize.v = normalizedDefault;
  }

  Map<String, dynamic> toJson() {
    final options = normalizePageSizeOptions(pageSizeOptions);
    return {
      'showPageSizeSelector': showPageSizeSelector.v,
      'showGotoButton': showGotoButton.v,
      'showScrollToTopBtn': showScrollToTopBtn.v,
      'defaultPageSize': normalizeDefaultPageSize(defaultPageSize.v, options),
      'pageSizeOptions': options,
    };
  }

  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    final raw = json['pageSizeOptions'] as List?;
    // Eager copy: a lazy cast could throw after scalar settings were committed.
    final options = normalizePageSizeOptions(raw == null ? getInitPageSizeOptions() : List<int>.from(raw));
    final defaultSize = normalizeDefaultPageSize(json['defaultPageSize'] as int? ?? _getInitPageSize(), options);
    return {
      'showPageSizeSelector': json['showPageSizeSelector'] as bool? ?? true,
      'showGotoButton': json['showGotoButton'] as bool? ?? true,
      'showScrollToTopBtn': json['showScrollToTopBtn'] as bool? ?? true,
      'defaultPageSize': defaultSize,
      'pageSizeOptions': options,
      'pageSizeOptionsRaw': jsonEncode(options),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    showPageSizeSelector.v = parsed['showPageSizeSelector'];
    showGotoButton.v = parsed['showGotoButton'];
    showScrollToTopBtn.v = parsed['showScrollToTopBtn'];
    pageSizeOptions.assignAll(parsed['pageSizeOptions']);
    _pageSizeOptionsRaw.v = parsed['pageSizeOptionsRaw'];
    defaultPageSize.v = parsed['defaultPageSize'];
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final page = rootConfig?['page'] as Map<String, dynamic>? ?? {};
    final raw = page['pageSizeOptions'] as List?;
    final options = normalizePageSizeOptions(raw == null ? getInitPageSizeOptions() : List<int>.from(raw));
    return {
      'showPageSizeSelector': page['showPageSizeSelector'] as bool? ?? true,
      'showGotoButton': page['showGotoButton'] as bool? ?? true,
      'showScrollToTopBtn': page['showScrollToTopBtn'] as bool? ?? true,
      'defaultPageSize': normalizeDefaultPageSize(
        page['defaultPageSize'] as int? ?? PageSettingsController._getInitPageSize(),
        options,
      ),
      'pageSizeOptions': options,
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final page = Map<String, dynamic>.from(rootConfig['page'] ?? {});
    updateFields.forEach((k, v) => page[k] = v);
    rootConfig['page'] = page;
    return rootConfig;
  }
}
