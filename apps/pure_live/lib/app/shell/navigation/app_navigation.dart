import 'package:pure_live/app/shell/navigation/navigation_item.dart' show NavigationItem;

/// The branches the desktop shell shows, in rail order.
const List<NavigationItem> kDesktopNavigation = NavigationItem.values;

/// The branches the tablet shell shows, in rail order.
const List<NavigationItem> kTabletNavigation = NavigationItem.values;

/// The branches the TV shell shows, in row order.
const List<NavigationItem> kTvNavigation = NavigationItem.values;

/// The branches the mobile shell fits into its bottom bar: the phone bar
/// holds five destinations, so the two library corners — search and the
/// playlist — wait for their pages' own entries.
const List<NavigationItem> kMobileNavigation = [
  NavigationItem.home,
  NavigationItem.favorites,
  NavigationItem.history,
  NavigationItem.settings,
];
