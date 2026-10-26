import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/shared/shared.dart';

/// The page size before the viewer picks one: the reference's
/// `defaultPageSize` — 20 on a window wider than 960 logical pixels, 12
/// otherwise.
int defaultBrowsePageSize() {
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final ratio = view.devicePixelRatio > 0 ? view.devicePixelRatio : 1;
    return view.physicalSize.width / ratio > 960 ? 20 : 12;
  } on Object {
    return 12;
  }
}

/// The browsing surfaces' tunables: what a settings page will own.
typedef BrowseSettings = ({double homeCardExtent, int homePageSize, double crossSpacing, double mainSpacing});

/// The grid gaps' floor, ceiling and default (the reference's
/// `crossAxisSpacing`/`mainAxisSpacing`): the settings sliders and the stored
/// values share them, so a stored value can never leave the range the
/// settings page offers.
const double kBrowseSpacingMin = 0;
const double kBrowseSpacingMax = 64;
const double kBrowseSpacingDefault = 6;

/// Owns the browsing settings the home feed and its grid read.
///
/// The values live here, not in the widgets, so the settings page writes
/// through `set` and every surface follows at once; the initial value
/// comes from the stored `browse.cardExtent`/`browse.pageSize`/
/// `browse.crossSpacing`/`browse.mainSpacing` and every setter writes it
/// back, and no widget changes.
final class BrowseSettingsController extends Notifier<BrowseSettings> {
  @override
  BrowseSettings build() {
    return (
      homeCardExtent: _readStoredExtent() ?? 250,
      homePageSize: _readStoredSize() ?? defaultBrowsePageSize(),
      crossSpacing: _readStoredSpacing('browse.crossSpacing'),
      mainSpacing: _readStoredSpacing('browse.mainSpacing'),
    );
  }

  /// The stored card extent, or null when storage never opened (its boot
  /// failure is logged); the defaults then stay.
  static double? _readStoredExtent() {
    try {
      return StoragePrefs.getDouble('browse.cardExtent');
    } on Object {
      return null;
    }
  }

  /// The stored page size, or null when storage never opened.
  static int? _readStoredSize() {
    try {
      return StoragePrefs.getInt('browse.pageSize');
    } on Object {
      return null;
    }
  }

  /// One stored grid gap, clamped to the range the settings offer; the
  /// default when the store never opened (or holds nonsense).
  static double _readStoredSpacing(String key) {
    try {
      final stored = StoragePrefs.getDouble(key);
      if (stored == null) return kBrowseSpacingDefault;
      return stored.clamp(kBrowseSpacingMin, kBrowseSpacingMax);
    } on Object {
      return kBrowseSpacingDefault;
    }
  }

  /// The widest a home card gets before the grid adds a column.
  double get homeCardExtent => state.homeCardExtent;

  /// How many rooms one feed page asks for.
  int get homePageSize => state.homePageSize;

  /// The gap between cards across a row.
  double get crossSpacing => state.crossSpacing;

  /// The gap between rows of cards.
  double get mainSpacing => state.mainSpacing;

  /// Widens or narrows the home cards (the grid reflows at once).
  set homeCardExtent(double extent) {
    // num.clamp answers num; the setting is a double.
    final clamped = extent.clamp(160, 420).toDouble();
    state = (
      homeCardExtent: clamped,
      homePageSize: state.homePageSize,
      crossSpacing: state.crossSpacing,
      mainSpacing: state.mainSpacing,
    );
    unawaited(StoragePrefs.setDouble('browse.cardExtent', clamped));
  }

  /// Changes how many rooms one feed page asks for.
  set homePageSize(int size) {
    final clamped = size.clamp(1, 100);
    state = (
      homeCardExtent: state.homeCardExtent,
      homePageSize: clamped,
      crossSpacing: state.crossSpacing,
      mainSpacing: state.mainSpacing,
    );
    unawaited(StoragePrefs.setInt('browse.pageSize', clamped));
  }

  /// Moves the gap between cards across a row.
  set crossSpacing(double spacing) {
    final clamped = spacing.clamp(kBrowseSpacingMin, kBrowseSpacingMax);
    state = (
      homeCardExtent: state.homeCardExtent,
      homePageSize: state.homePageSize,
      crossSpacing: clamped,
      mainSpacing: state.mainSpacing,
    );
    unawaited(StoragePrefs.setDouble('browse.crossSpacing', clamped));
  }

  /// Moves the gap between rows of cards.
  set mainSpacing(double spacing) {
    final clamped = spacing.clamp(kBrowseSpacingMin, kBrowseSpacingMax);
    state = (
      homeCardExtent: state.homeCardExtent,
      homePageSize: state.homePageSize,
      crossSpacing: state.crossSpacing,
      mainSpacing: clamped,
    );
    unawaited(StoragePrefs.setDouble('browse.mainSpacing', clamped));
  }
}

/// Owns the collection layout (cards or rows), one choice for every feed
/// that uses the shared card grid; persists under `browse.layout`.
final class BrowseLayoutController extends Notifier<CardLayout> {
  @override
  CardLayout build() {
    try {
      return switch (StoragePrefs.getString('browse.layout')) {
        'list' => CardLayout.list,
        _ => CardLayout.grid,
      };
    } on Object {
      return CardLayout.grid;
    }
  }

  /// Switches the feed layout and writes it through.
  Future<void> set(CardLayout layout) async {
    state = layout;
    try {
      await StoragePrefs.setString('browse.layout', layout.name);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// The feed layout choice.
final browseLayoutProvider = NotifierProvider<BrowseLayoutController, CardLayout>(BrowseLayoutController.new);

/// Owns the follows page's card density (the reference's
/// `enableDenseFavorites`): compact cards when on, large cards when off;
/// persists under `browse.denseFavorites`.
final class FavoritesDensityController extends Notifier<bool> {
  static const String prefsKey = 'browse.denseFavorites';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(prefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Turns the compact follows grid on or off and writes it through.
  Future<void> set({required bool dense}) async {
    state = dense;
    try {
      await StoragePrefs.setBool(prefsKey, dense);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// Whether the follows page uses compact cards.
final favoritesDensityProvider = NotifierProvider<FavoritesDensityController, bool>(FavoritesDensityController.new);

/// Whether pagers show the rooms-per-page selector (the reference's
/// `showPageSizeSelector`). Turning it off hides the control only: the
/// current size keeps paging the list.
final class PageSizeSelectorController extends Notifier<bool> {
  static const String prefsKey = 'page.showSizeSelector';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(prefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Shows or hides the selector and writes it through.
  Future<void> set({required bool show}) async {
    state = show;
    try {
      await StoragePrefs.setBool(prefsKey, show);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// Whether pagers show their rooms-per-page selector.
final showPageSizeSelectorProvider = NotifierProvider<PageSizeSelectorController, bool>(PageSizeSelectorController.new);

/// Whether pagers show the jump-to-page field (the reference's
/// `showGotoButton`). Turning it off hides the field only: the page numbers
/// and their arrows keep paging.
final class PageGotoButtonController extends Notifier<bool> {
  static const String prefsKey = 'page.showGotoButton';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(prefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Shows or hides the field and writes it through.
  Future<void> set({required bool show}) async {
    state = show;
    try {
      await StoragePrefs.setBool(prefsKey, show);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// Whether pagers show their jump-to-page field.
final showGotoButtonProvider = NotifierProvider<PageGotoButtonController, bool>(PageGotoButtonController.new);

/// Whether lists show their floating back-to-top button (the reference's
/// `showScrollToTopBtn`). Turning it off hides the button only; scrolling
/// and paging still work.
final class PageScrollToTopController extends Notifier<bool> {
  static const String prefsKey = 'page.showScrollToTop';

  @override
  bool build() {
    try {
      return StoragePrefs.getBool(prefsKey) ?? true;
    } on Object {
      return true;
    }
  }

  /// Shows or hides the button and writes it through.
  Future<void> set({required bool show}) async {
    state = show;
    try {
      await StoragePrefs.setBool(prefsKey, show);
    } on Object {
      // A preference; a closed store loses it.
    }
  }
}

/// Whether lists show their floating back-to-top button.
final showScrollToTopProvider = NotifierProvider<PageScrollToTopController, bool>(PageScrollToTopController.new);

/// The browsing settings.
final browseSettingsProvider = NotifierProvider<BrowseSettingsController, BrowseSettings>(BrowseSettingsController.new);
