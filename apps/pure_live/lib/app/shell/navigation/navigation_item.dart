import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/widgets.dart' show Widget;
import 'package:pure_live/app/routing/route_names.dart' show RouteNames;
import 'package:pure_live/features/favorites/presentation/pages/favorites_page.dart' show FavoritesPage;
import 'package:pure_live/features/history/presentation/pages/history_page.dart' show HistoryPage;
import 'package:pure_live/features/home/presentation/pages/home_page.dart' show HomePage;
import 'package:pure_live/features/playlist/presentation/pages/playlist_page.dart' show PlaylistPage;
import 'package:pure_live/features/search/presentation/pages/search_page.dart' show SearchPage;
import 'package:pure_live/features/settings/presentation/pages/settings_page.dart' show SettingsPage;
import 'package:pure_live/i18n/translations.g.dart' show Translations;

/// The shell's branches, in display order.
///
/// One value answers everything the shells need — the route, the icon, the
/// localized label, the page — so a shell never re-states the list and a
/// branch can be added by touching this enum alone.
enum NavigationItem {
  /// The home branch.
  home(RouteNames.home, DsIcons.home),

  /// The favorites branch.
  favorites(RouteNames.favorites, DsIcons.heart),

  /// The history branch.
  history(RouteNames.history, DsIcons.history),

  /// The search branch.
  search(RouteNames.search, DsIcons.search),

  /// The playlist branch.
  playlist(RouteNames.playlist, DsIcons.list),

  /// The settings branch.
  settings(RouteNames.settings, DsIcons.settings);

  new(this.route, this.icon);

  /// The branch's route path.
  final String route;

  /// The branch's icon.
  final DsIconData icon;

  /// The localized label.
  String label(Translations t) => switch (this) {
    NavigationItem.home => t.nav.home,
    NavigationItem.favorites => t.nav.favorites,
    NavigationItem.history => t.nav.history,
    NavigationItem.search => t.nav.search,
    NavigationItem.playlist => t.nav.playlist,
    NavigationItem.settings => t.nav.settings,
  };

  /// The branch's page.
  Widget page() => switch (this) {
    NavigationItem.home => const HomePage(),
    NavigationItem.favorites => const FavoritesPage(),
    NavigationItem.history => const HistoryPage(),
    NavigationItem.search => const SearchPage(),
    NavigationItem.playlist => const PlaylistPage(),
    NavigationItem.settings => const SettingsPage(),
  };
}
