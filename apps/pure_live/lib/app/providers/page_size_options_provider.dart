import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/providers/browse_settings_providers.dart' show browseSettingsProvider;

/// The reference's bounds for one page-size choice (`minPageSize` /
/// `maxPageSize` in `page_settings_controller.dart`).
const int kPageSizeOptionMin = 1;
const int kPageSizeOptionMax = 100;

/// The reference's per-width defaults for a [logicalWidth]: wider than 960
/// offers 20/40/60/80, anything else 12/24/36/48.
List<int> pageSizeOptionsForWidth(double? logicalWidth) =>
    (logicalWidth ?? 0) > 960 ? const [20, 40, 60, 80] : const [12, 24, 36, 48];

/// The defaults for the window this app is showing, read from the first
/// view; see [pageSizeOptionsForWidth].
List<int> defaultPageSizeOptions() {
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final ratio = view.devicePixelRatio > 0 ? view.devicePixelRatio : 1;
    return pageSizeOptionsForWidth(view.physicalSize.width / ratio);
  } on Object {
    return const [12, 24, 36, 48];
  }
}

/// The reference's `normalizePageSizeOptions`: drop out-of-range values,
/// deduplicate and sort. An empty set falls back to the width defaults, so
/// a pager always has something to offer.
List<int> normalizePageSizeOptions(Iterable<int> values) {
  final normalized =
      values.where((value) => value >= kPageSizeOptionMin && value <= kPageSizeOptionMax).toSet().toList()..sort();
  if (normalized.isNotEmpty) return normalized;
  return defaultPageSizeOptions();
}

/// The pagers' rooms-per-page choices (the reference's
/// `page_size_options_raw`), persisted as a JSON array under
/// `page.pageSizeOptions`.
///
/// The reference saves the normalized array and keeps `defaultPageSize`
/// inside it: when the current size is no longer offered, it moves to the
/// first choice. The pager selectors and the settings dialog share this
/// provider, so a change reaches every page at once.
final class PageSizeOptionsController extends Notifier<List<int>> {
  static const String prefsKey = 'page.pageSizeOptions';

  @override
  List<int> build() {
    try {
      final raw = StoragePrefs.getString(prefsKey);
      if (raw == null || raw.isEmpty) return defaultPageSizeOptions();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return defaultPageSizeOptions();
      return normalizePageSizeOptions(decoded.whereType<num>().map((value) => value.toInt()));
    } on Object {
      return defaultPageSizeOptions();
    }
  }

  /// Replaces the choices with [values], normalized. The current page size
  /// is kept visible: if it no longer fits, it moves to the first option.
  Future<void> save(Iterable<int> values) async {
    final normalized = normalizePageSizeOptions(values);
    state = normalized;
    final current = ref.read(browseSettingsProvider).homePageSize;
    if (!normalized.contains(current)) {
      ref.read(browseSettingsProvider.notifier).homePageSize = normalized.first;
    }
    try {
      await StoragePrefs.setString(prefsKey, jsonEncode(normalized));
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The pager's rooms-per-page choices.
final pageSizeOptionsProvider = NotifierProvider<PageSizeOptionsController, List<int>>(
  PageSizeOptionsController.new,
);
