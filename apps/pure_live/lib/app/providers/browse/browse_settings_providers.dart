import 'dart:async' show unawaited;

import 'package:desen_ui/desen_ui.dart' show DsSpace;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;
import 'package:pure_live/shared/shared.dart';

/// The browsing surfaces' tunables: the grid gaps and the columns a feed
/// draws.
///
/// The columns default to 0 — the grid derives them from the window it is
/// drawn in ([browseCardExtentForWidth]) — and a viewer's number caps them:
/// the window lowers the count when it cannot hold that many cards at one
/// card's minimum width, so a choice never squeezes cards into a sliver.
/// The cap shapes both layouts: a list row is as wide as a grid card.
typedef BrowseSettings = ({double crossSpacing, double mainSpacing, int gridColumns});

/// The column counts a viewer may cap a feed at; 0 is "the window decides".
const List<int> kBrowseGridColumnChoices = [3, 4, 5, 6];

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
      gridColumns: _readStoredInt('browse.gridColumns', kBrowseGridColumnChoices),
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

  /// A stored choice from [choices]; 0 (the window decides) when absent or
  /// unknown.
  static int _readStoredInt(String key, List<int> choices) {
    try {
      final parsed = int.tryParse(StoragePrefs.getString(key) ?? '');
      if (parsed == null || parsed == 0) return 0;
      return choices.contains(parsed) ? parsed : 0;
    } on Object {
      return 0;
    }
  }

  /// The gap between cards across a row.
  double get crossSpacing => state.crossSpacing;

  /// The gap between rows of cards.
  double get mainSpacing => state.mainSpacing;

  /// How many grid columns a feed may draw; 0 lets the window decide. The
  /// list layout draws rows at the same width.
  int get gridColumns => state.gridColumns;

  /// Moves the gap between cards across a row to the nearest token.
  set crossSpacing(double spacing) {
    final clamped = nearestBrowseSpacing(spacing);
    state = _copy(crossSpacing: clamped);
    unawaited(StoragePrefs.setDouble('browse.crossSpacing', clamped));
  }

  /// Moves the gap between rows of cards to the nearest token.
  set mainSpacing(double spacing) {
    final clamped = nearestBrowseSpacing(spacing);
    state = _copy(mainSpacing: clamped);
    unawaited(StoragePrefs.setDouble('browse.mainSpacing', clamped));
  }

  /// Caps the grid's column count; 0 goes back to the window's own count.
  set gridColumns(int columns) {
    final value = columns == 0 || kBrowseGridColumnChoices.contains(columns) ? columns : state.gridColumns;
    state = _copy(gridColumns: value);
    unawaited(StoragePrefs.setString('browse.gridColumns', '$value'));
  }

  BrowseSettings _copy({double? crossSpacing, double? mainSpacing, int? gridColumns}) => (
    crossSpacing: crossSpacing ?? state.crossSpacing,
    mainSpacing: mainSpacing ?? state.mainSpacing,
    gridColumns: gridColumns ?? state.gridColumns,
  );
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
