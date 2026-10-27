import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart' show DsSpace;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/shared/shared.dart';

/// The browsing surfaces' tunables: what a settings page will own.
///
/// Only the grid gaps are a viewer's choice. How wide a card is follows the
/// window it is drawn in ([browseCardExtentForWidth]) and how many rooms a
/// page holds follows the platform's own feed window
/// ([roomFeedRequestSize], [areaRequestSize], [searchRequestSize]), so
/// neither is a number the viewer has to set for a layout that already
/// knows it.
typedef BrowseSettings = ({double crossSpacing, double mainSpacing});

/// The grid gaps a viewer may pick: desen_ui's spacing tokens up to
/// `DsSpace.s12` and nothing else — the scale, not a free pixel range, is
/// what the setting offers, so a feed's gaps are numbers every other surface
/// already uses; the reference's 6 px default is one of the steps.
const List<double> kBrowseSpacingChoices = [DsSpace.s3, DsSpace.s4, DsSpace.s5, DsSpace.s6, DsSpace.s8, DsSpace.s12];

/// The gap a feed starts with when the store never answered: the reference's
/// 6, which is one of the tokens above.
const double kBrowseSpacingDefault = DsSpace.s6;

/// The token nearest [value]: what a gap becomes when it arrives from a
/// backup, another window or the days when this setting was a free slider.
double nearestBrowseSpacing(double value) {
  var best = kBrowseSpacingDefault;
  var bestGap = double.infinity;
  for (final choice in kBrowseSpacingChoices) {
    final gap = (value - choice).abs();
    if (gap < bestGap) {
      best = choice;
      bestGap = gap;
    }
  }
  return best;
}

/// Owns the browsing settings the home feed and its grids read.
///
/// The values live here, not in the widgets, so the settings page writes
/// through `set` and every surface follows at once; the initial value
/// comes from the stored `browse.crossSpacing`/`browse.mainSpacing` and every
/// setter writes it back, and no widget changes.
final class BrowseSettingsController extends Notifier<BrowseSettings> {
  @override
  BrowseSettings build() {
    return (
      crossSpacing: _readStoredSpacing('browse.crossSpacing'),
      mainSpacing: _readStoredSpacing('browse.mainSpacing'),
    );
  }

  /// One stored grid gap, on the token scale; the default when the store
  /// never opened (or holds nonsense).
  static double _readStoredSpacing(String key) {
    try {
      final stored = StoragePrefs.getDouble(key);
      if (stored == null) return kBrowseSpacingDefault;
      return nearestBrowseSpacing(stored);
    } on Object {
      return kBrowseSpacingDefault;
    }
  }

  /// The gap between cards across a row.
  double get crossSpacing => state.crossSpacing;

  /// The gap between rows of cards.
  double get mainSpacing => state.mainSpacing;

  /// Moves the gap between cards across a row to the nearest token.
  set crossSpacing(double spacing) {
    final clamped = nearestBrowseSpacing(spacing);
    state = (crossSpacing: clamped, mainSpacing: state.mainSpacing);
    unawaited(StoragePrefs.setDouble('browse.crossSpacing', clamped));
  }

  /// Moves the gap between rows of cards to the nearest token.
  set mainSpacing(double spacing) {
    final clamped = nearestBrowseSpacing(spacing);
    state = (crossSpacing: state.crossSpacing, mainSpacing: clamped);
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

/// The browsing settings.
final browseSettingsProvider = NotifierProvider<BrowseSettingsController, BrowseSettings>(BrowseSettingsController.new);
