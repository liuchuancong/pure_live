import 'dart:async' show unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

/// The browsing surfaces' tunables: what a settings page will own.
typedef BrowseSettings = ({double homeCardExtent, int homePageSize});

/// Owns the browsing settings the home feed and its grid read.
///
/// The values live here, not in the widgets, so the settings page writes
/// through `set` and every surface follows at once; the initial value
/// comes from the stored `browse.cardExtent`/`browse.pageSize` and every
/// setter writes it back, and no widget changes.
final class BrowseSettingsController extends Notifier<BrowseSettings> {
  @override
  BrowseSettings build() {
    return (homeCardExtent: _readStoredExtent() ?? 250, homePageSize: _readStoredSize() ?? 30);
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

  /// The widest a home card gets before the grid adds a column.
  double get homeCardExtent => state.homeCardExtent;

  /// How many rooms one feed page asks for.
  int get homePageSize => state.homePageSize;

  /// Widens or narrows the home cards (the grid reflows at once).
  set homeCardExtent(double extent) {
    // num.clamp answers num; the setting is a double.
    final clamped = extent.clamp(160, 420).toDouble();
    state = (homeCardExtent: clamped, homePageSize: state.homePageSize);
    unawaited(StoragePrefs.setDouble('browse.cardExtent', clamped));
  }

  /// Changes how many rooms one feed page asks for.
  set homePageSize(int size) {
    final clamped = size.clamp(10, 90);
    state = (homeCardExtent: state.homeCardExtent, homePageSize: clamped);
    unawaited(StoragePrefs.setInt('browse.pageSize', clamped));
  }
}

/// The browsing settings.
final browseSettingsProvider = NotifierProvider<BrowseSettingsController, BrowseSettings>(BrowseSettingsController.new);
