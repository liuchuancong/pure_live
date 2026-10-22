import 'package:flutter/material.dart';
import 'package:pure_live/app/icons/app_icon_keys.dart';
import 'package:pure_live/app/icons/app_icon_registry.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_live/system/navigation/route_paths.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The shell's branches in one table: the display order, each branch's
/// icon and localized label, and the position `goBranch` addresses.
///
/// The declaration order must stay in lockstep with the branch order of
/// the `@TypedStatefulShellRoute` table in `app_router.dart` — go_router
/// addresses branches by position, and this enum is the single place that
/// position is written beside the destinations the chromes render from it.
///
/// The first five are the primary branches: the destinations the chromes
/// list. The last four are the menu branches — reachable from the top-left
/// menu, drawn in the shell's content pane like a primary branch, but never
/// listed in the chrome and never offered to the page settings.
enum ShellBranch {
  /// The followed streamers' live grid — the shell's first screen (3.x
  /// `HomeMenu.favorites`, heart glyph).
  follow(0, AppIconKey.follow),

  /// The recommend feed (3.x `HomeMenu.popular`, fire glyph).
  popular(1, AppIconKey.popular),

  /// The category catalogue (3.x `HomeMenu.areas`, grid glyph).
  areas(2, AppIconKey.apps),

  /// The IPTV library, a primary branch since it joined the chrome ahead of
  /// the recording centre (3.x `HomeMenu.iptv`, server glyph).
  iptv(3, AppIconKey.iptv),

  /// The recording centre (3.x `HomeMenu.record`, download glyph).
  record(4, AppIconKey.record),

  /// Multi-view, a menu branch: shown in the content pane on a wide layout,
  /// pushed as a page on a phone.
  multiview(5, AppIconKey.multiview),

  /// The toolbox (link resolution), a menu branch.
  toolbox(6, AppIconKey.toolbox),

  /// Search, a menu branch.
  search(7, AppIconKey.search),

  /// The watch history, a menu branch (3.x kept it in `MenuButton` too).
  history(8, AppIconKey.history);

  new(this.branchIndex, this.icon);

  /// The primary branches, in chrome order — the destinations the bottom bar,
  /// the rail and the sidebar draw, and the set the page settings arrange.
  static const List<ShellBranch> primary = [follow, popular, areas, iptv, record];

  /// The menu branches, in menu order — what the top-left menu lists.
  static const List<ShellBranch> menu = [multiview, toolbox, search, history];

  /// The position inside the stateful shell — what `goBranch` takes.
  final int branchIndex;

  /// The icon every chrome resolves and renders for this branch.
  final AppIconKey icon;

  /// Whether the chromes list this branch.
  bool get isPrimary => primary.contains(this);

  /// The localized label.
  String label(BuildContext context) => switch (this) {
    ShellBranch.follow => context.t.tabs.favorites,
    ShellBranch.popular => context.t.tabs.popular,
    ShellBranch.areas => context.t.tabs.areas,
    ShellBranch.iptv => context.t.iptv.title,
    ShellBranch.record => context.t.tabs.record,
    ShellBranch.multiview => context.t.multiview.title,
    ShellBranch.toolbox => context.t.toolbox.title,
    ShellBranch.search => context.t.tabs.search,
    ShellBranch.history => context.t.tabs.history,
  };

  /// The route location this branch's root answers — what the router starts
  /// on when the launch preference names this branch.
  String get location => switch (this) {
    ShellBranch.follow => RoutePath.favorites,
    ShellBranch.popular => RoutePath.popular,
    ShellBranch.areas => RoutePath.areas,
    ShellBranch.iptv => RoutePath.iptv,
    ShellBranch.record => RoutePath.recorder,
    ShellBranch.multiview => RoutePath.multiview,
    ShellBranch.toolbox => RoutePath.toolbox,
    ShellBranch.search => RoutePath.search,
    ShellBranch.history => RoutePath.history,
  };

  /// The branch a destination widget's position stands for: the chromes
  /// hand selected indexes over, this turns one back into a branch.
  static ShellBranch at(int index) => values[index];

  /// The branch a shell destination's id stands for, null for an unknown id
  /// (a stored document written by a newer or older build).
  static ShellBranch? maybeFromId(String id) {
    for (final branch in values) {
      if (branch.name == id) {
        return branch;
      }
    }
    return null;
  }

  /// The branch a shell destination's id stands for.
  static ShellBranch fromId(String id) => maybeFromId(id) ?? ShellBranch.follow;
}

/// The shell branches the user's page settings keep visible, in the order
/// they arranged them.
///
/// A stored list counts as customised only if this build's page settings
/// could have written it: known primary ids alone. Anything else is another
/// shape's document — `home` is an id an older build renamed away, and a
/// menu branch never appears in the page settings' list — so honouring it
/// pins the column to that build's world: the document `popular, follow,
/// areas, history, home` kept IPTV and the recording centre hidden after
/// they joined the chrome. The legacy default is the one all-known-ids list
/// that still grows: matching it means the document was never customised,
/// so it takes the current default instead.
List<ShellBranch> visibleShellBranches(AppPreferences preferences) {
  final stored = preferences.shellBranches;
  final customised =
      stored.isNotEmpty &&
      stored.every((id) => ShellBranch.maybeFromId(id)?.isPrimary ?? false);
  final untouchedLegacy = stored.length == legacyShellBranches.length && _sameIds(stored, legacyShellBranches);
  final seen = <ShellBranch>{};
  final result = <ShellBranch>[];
  if (customised && !untouchedLegacy) {
    for (final id in stored) {
      if (ShellBranch.maybeFromId(id) case final ShellBranch branch when seen.add(branch)) {
        result.add(branch);
      }
    }
  }
  if (result.isEmpty) {
    result.addAll(ShellBranch.primary);
  }
  return result;
}

bool _sameIds(List<String> a, List<String> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

/// The location the router starts on: the last visited branch when the
/// navigation preference asks for it and that branch is still visible, else
/// the configured launch branch, else the first visible one.
String launchLocationFor(AppPreferences preferences) {
  final visible = visibleShellBranches(preferences);
  if (preferences.restoreLastTab) {
    final last = ShellBranch.maybeFromId(preferences.lastBranchId ?? '');
    if (last != null && visible.contains(last)) {
      return last.location;
    }
  }
  for (final branch in visible) {
    if (branch.name == preferences.launchBranch.id) {
      return branch.location;
    }
  }
  return visible.first.location;
}

/// The chrome destinations: the user's visible primary branches, in their
/// order — the list the phone's bottom bar renders. The menu branches and
/// the settings entry are not here; the wide column and the drawer own them.
List<PureNavDestination> shellPrimaryDestinations(BuildContext context, {List<ShellBranch>? branches}) => [
  for (final branch in branches ?? ShellBranch.primary)
    PureNavDestination(id: branch.name, label: branch.label(context), icon: AppIcons.glyph(context, branch.icon)),
];

/// The wide column's destinations: the primary branches, then — under the
/// group divider — the four menu branches as rows of their own. A menu
/// branch activates like a primary one; the settings entry lives in the
/// column's footer, not in this list.
List<PureNavDestination> shellColumnDestinations(BuildContext context, {List<ShellBranch>? branches}) {
  const menu = ShellBranch.menu;
  return [
    for (final branch in branches ?? ShellBranch.primary)
      PureNavDestination(id: branch.name, label: branch.label(context), icon: AppIcons.glyph(context, branch.icon)),
    for (var index = 0; index < menu.length; index++)
      PureNavDestination(
        id: menu[index].name,
        label: menu[index].label(context),
        icon: AppIcons.glyph(context, menu[index].icon),
        startsGroup: index == 0,
      ),
  ];
}

/// The phone drawer's destinations: the four menu branches, then the
/// settings entry — a drawer has no footer, so settings travels with them.
List<PureNavDestination> shellDrawerDestinations(BuildContext context) => [
  for (final branch in ShellBranch.menu)
    PureNavDestination(id: branch.name, label: branch.label(context), icon: AppIcons.glyph(context, branch.icon)),
  PureNavDestination(
    id: 'settings',
    label: context.t.tabs.settings,
    icon: AppIcons.glyph(context, AppIconKey.settings),
  ),
];

/// The same column flattened for the TV shell's dispatched destinations: the
/// primary branches, then the menu branches, then settings.
List<PureShellDestination> shellTvDestinations(BuildContext context, {List<ShellBranch>? branches}) => [
  for (final destination in [
    ...shellPrimaryDestinations(context, branches: branches),
    ...shellDrawerDestinations(context),
  ])
    PureShellDestination(id: destination.id, label: destination.label, icon: destination.icon),
];
