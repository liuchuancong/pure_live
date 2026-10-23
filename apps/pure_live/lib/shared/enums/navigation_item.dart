import 'package:desen_ui/desen_ui.dart';
import 'package:pure_live/l10n/translations.dart' show Translations;

/// The shell's navigation destinations, in display order.
///
/// One value answers everything the layouts need — the icon and the
/// localized label — so a layout never re-states the list and a
/// destination can be added by touching this enum alone.
enum NavigationItem {
  /// The home branch.
  home(DsIcons.home),

  /// The live branch.
  live(DsIcons.tv),

  /// The favorites branch.
  favorites(DsIcons.heart),

  /// The history branch.
  history(DsIcons.history),

  /// The search branch.
  search(DsIcons.search),

  /// The playlist branch.
  playlist(DsIcons.list),

  /// The settings branch.
  settings(DsIcons.settings);

  NavigationItem(this.icon);

  /// The destination's icon.
  final DsIconData icon;

  /// The localized label.
  String label(Translations t) => switch (this) {
    NavigationItem.home => t.navigation.home,
    NavigationItem.live => t.navigation.live,
    NavigationItem.favorites => t.navigation.favorites,
    NavigationItem.history => t.navigation.history,
    NavigationItem.search => t.navigation.search,
    NavigationItem.playlist => t.navigation.playlist,
    NavigationItem.settings => t.navigation.settings,
  };
}

/// The destinations the desktop and TV layouts show, in order.
const List<NavigationItem> kNavigationItems = NavigationItem.values;

/// The destinations the mobile bottom bar fits: five slots, so the two
/// library corners — search and the playlist — wait for their pages' own
/// entries.
const List<NavigationItem> kMobileNavigationItems = [
  NavigationItem.home,
  NavigationItem.live,
  NavigationItem.favorites,
  NavigationItem.history,
  NavigationItem.settings,
];
