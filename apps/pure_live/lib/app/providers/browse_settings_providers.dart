import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/shared/grids/card_grid.dart' show CardLayout;

/// The browsing surfaces' tunables: what a settings page will own.
typedef BrowseSettings = ({double homeCardExtent, int homePageSize, double crossSpacing, double mainSpacing});

/// The grid gaps' floor, ceiling and default: the settings sliders and the
/// stored values share them, so a stored value can never leave the range the
/// settings page offers.
const double kBrowseSpacingMin = 0;
const double kBrowseSpacingMax = 32;
const double kBrowseSpacingDefault = 16;

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
      homePageSize: _readStoredSize() ?? 30,
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
    final clamped = size.clamp(10, 90);
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

/// The browsing settings.
final browseSettingsProvider = NotifierProvider<BrowseSettingsController, BrowseSettings>(BrowseSettingsController.new);
