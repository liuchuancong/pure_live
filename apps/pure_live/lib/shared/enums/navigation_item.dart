import 'package:desen_ui/desen_ui.dart';

import 'package:pure_live/l10n/translations.dart' show Translations;

/// The shell's navigation destinations. A module's menu is several blocks
/// with a divider between them (the live module reads the reference's rail
/// block for block: Search Live / Watch history, Link Parser / Multi-view, Favorites / Popular / Areas,
/// Recording centre), and settings is pinned to the sidebar's foot.
enum NavigationItem {
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

  /// The link-parser branch. The network probe, image-cache clear and log
  /// viewer that used to share this entry are settings utilities now.
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
  user(DsIcons.circleUser),

  /// The VOD module's own entry.
  vod(DsIcons.film),

  /// The music module's own entry.
  music(DsIcons.music);

  NavigationItem(this.icon);

  /// The destination's icon.
  final DsIconData icon;

  /// The localized label.
  String label(Translations t) => switch (this) {
    NavigationItem.live => t.navigation.live,
    NavigationItem.channels => t.navigation.channels,
    NavigationItem.discover => t.navigation.discover,
    NavigationItem.history => t.navigation.history,
    NavigationItem.multiview => t.navigation.multiview,
    NavigationItem.favorites => t.navigation.favorites,
    NavigationItem.hot => t.navigation.hot,
    NavigationItem.zones => t.navigation.zones,
    NavigationItem.search => t.navigation.search,
    // The reference's link parser: the toolbox surface's own link-parser title,
    // which already reads as the link parser in every locale.
    NavigationItem.toolbox => t.toolbox.toolLinkTitle,
    NavigationItem.record => t.navigation.record,
    NavigationItem.settings => t.navigation.settings,
    NavigationItem.appearance => t.navigation.appearance,
    NavigationItem.proxy => t.navigation.proxy,
    NavigationItem.user => t.navigation.user,
    NavigationItem.vod => t.common.moduleVod,
    NavigationItem.music => t.common.moduleMusic,
  };
}
