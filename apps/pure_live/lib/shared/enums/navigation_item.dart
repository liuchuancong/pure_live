import 'package:desen_ui/desen_ui.dart';
import 'package:pure_live/l10n/translations.dart' show Translations;

/// The shell's navigation destinations, named after the v4 navigation
/// design: three groups — high-frequency pages, content and tools,
/// personal and system — rendered as labelled sections in the desktop
/// sidebar and as flat bars on mobile and TV.
enum NavigationItem {
  /// The home branch.
  home(DsIcons.home),

  /// The live branch.
  live(DsIcons.tv),

  /// The channels branch.
  channels(DsIcons.layoutGrid),

  /// The discover branch.
  discover(DsIcons.compass),

  /// The history branch.
  history(DsIcons.history),

  /// The multi-view branch.
  multiview(DsIcons.columns2),

  /// The favorites branch.
  favorites(DsIcons.heart),

  /// The hot branch.
  hot(DsIcons.flame),

  /// The zones branch.
  zones(DsIcons.squareStack),

  /// The search branch.
  search(DsIcons.search),

  /// The toolbox branch.
  toolbox(DsIcons.wrench),

  /// The recording branch.
  record(DsIcons.disc3),

  /// The settings branch.
  settings(DsIcons.settings),

  /// The appearance branch.
  appearance(DsIcons.palette),

  /// The network proxy branch.
  proxy(DsIcons.globe),

  /// The user branch.
  user(DsIcons.circleUser);

  NavigationItem(this.icon);

  /// The destination's icon.
  final DsIconData icon;

  /// The localized label.
  String label(Translations t) => switch (this) {
    NavigationItem.home => t.navigation.home,
    NavigationItem.live => t.navigation.live,
    NavigationItem.channels => t.navigation.channels,
    NavigationItem.discover => t.navigation.discover,
    NavigationItem.history => t.navigation.history,
    NavigationItem.multiview => t.navigation.multiview,
    NavigationItem.favorites => t.navigation.favorites,
    NavigationItem.hot => t.navigation.hot,
    NavigationItem.zones => t.navigation.zones,
    NavigationItem.search => t.navigation.search,
    NavigationItem.toolbox => t.navigation.toolbox,
    NavigationItem.record => t.navigation.record,
    NavigationItem.settings => t.navigation.settings,
    NavigationItem.appearance => t.navigation.appearance,
    NavigationItem.proxy => t.navigation.proxy,
    NavigationItem.user => t.navigation.user,
  };
}

/// The sidebar's groups, top to bottom: (slang key of the section label,
/// destinations). The layouts resolve the label through the navigation
/// namespace.
const List<(String, List<NavigationItem>)> kNavigationGroups = [
  (
    'groupPrimary',
    [
      NavigationItem.home,
      NavigationItem.live,
      NavigationItem.channels,
      NavigationItem.discover,
      NavigationItem.history,
    ],
  ),
  (
    'groupContent',
    [
      NavigationItem.multiview,
      NavigationItem.favorites,
      NavigationItem.hot,
      NavigationItem.zones,
      NavigationItem.search,
      NavigationItem.toolbox,
    ],
  ),
  (
    'groupPersonal',
    [
      NavigationItem.record,
      NavigationItem.settings,
      NavigationItem.appearance,
      NavigationItem.proxy,
      NavigationItem.user,
    ],
  ),
];

/// Every destination, across the groups.
const List<NavigationItem> kNavigationItems = [...kPrimaryItems, ...kContentItems, ...kPersonalItems];

/// The high-frequency group, flat.
const List<NavigationItem> kPrimaryItems = [
  NavigationItem.home,
  NavigationItem.live,
  NavigationItem.channels,
  NavigationItem.discover,
  NavigationItem.history,
];

/// The content-and-tools group, flat.
const List<NavigationItem> kContentItems = [
  NavigationItem.multiview,
  NavigationItem.favorites,
  NavigationItem.hot,
  NavigationItem.zones,
  NavigationItem.search,
  NavigationItem.toolbox,
];

/// The personal-and-system group, flat.
const List<NavigationItem> kPersonalItems = [
  NavigationItem.record,
  NavigationItem.settings,
  NavigationItem.appearance,
  NavigationItem.proxy,
  NavigationItem.user,
];

/// The destinations the mobile bottom bar fits: five entries, the rest
/// wait for their pages' own entries.
const List<NavigationItem> kMobileNavigationItems = [
  NavigationItem.home,
  NavigationItem.live,
  NavigationItem.discover,
  NavigationItem.favorites,
  NavigationItem.settings,
];
