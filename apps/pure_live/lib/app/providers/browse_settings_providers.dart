import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The browsing surfaces' tunables: what a settings page will own.
typedef BrowseSettings = ({double homeCardExtent, int homePageSize});

/// Owns the browsing settings the home feed and its grid read.
///
/// The values live here, not in the widgets, so the settings page (when it
/// arrives) writes through `set` and every surface follows at once; the
/// persistence seam is this notifier — once the storage wiring lands, the
/// initial value comes from the stored record and every setter writes it
/// back, and no widget changes.
final class BrowseSettingsController extends Notifier<BrowseSettings> {
  @override
  BrowseSettings build() => (homeCardExtent: 250, homePageSize: 30);

  /// The widest a home card gets before the grid adds a column.
  double get homeCardExtent => state.homeCardExtent;

  /// How many rooms one feed page asks for.
  int get homePageSize => state.homePageSize;

  /// Widens or narrows the home cards (the grid reflows at once).
  set homeCardExtent(double extent) =>
      state = (homeCardExtent: extent.clamp(160, 420), homePageSize: state.homePageSize);

  /// Changes how many rooms one feed page asks for.
  set homePageSize(int size) =>
      state = (homeCardExtent: state.homeCardExtent, homePageSize: size.clamp(10, 90));
}

/// The browsing settings.
final browseSettingsProvider = NotifierProvider<BrowseSettingsController, BrowseSettings>(BrowseSettingsController.new);
