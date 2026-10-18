import 'package:flutter/material.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/routing/route_paths.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The shell's branches in one table: the display order, each branch's
/// icon and localized label, and the position `goBranch` addresses.
///
/// The declaration order must stay in lockstep with the branch order of
/// the `@TypedStatefulShellRoute` table in `app_router.dart` — go_router
/// addresses branches by position, and this enum is the single place that
/// position is written beside the destinations the chromes render from it.
enum ShellBranch {
  /// The followed streamers' live grid — the reference's first tab and the
  /// shell's first screen (3.x `HomeMenu.favorites`, heart glyph).
  follow(0, Icons.favorite),

  /// The recommend feed — the reference's second tab (3.x
  /// `HomeMenu.popular`, fire glyph).
  popular(1, Icons.local_fire_department),

  /// The category catalogue — the reference's third tab (3.x
  /// `HomeMenu.areas`, grid glyph).
  areas(2, Icons.apps),

  /// The recording centre — the reference's fourth tab (3.x
  /// `HomeMenu.record`, download glyph). It is a bottom-bar tab on a phone and
  /// a normal destination in the desktop/tablet column now that the branded
  /// sidebar has room for all four branches.
  record(3, Icons.download_outlined);

  new(this.branchIndex, this.icon);

  /// The position inside the stateful shell — what `goBranch` takes.
  final int branchIndex;

  /// The icon every chrome renders for this branch.
  final IconData icon;

  /// The localized label. The favorites branch carries the reference's
  /// favorites tab label (3.x `favorites_title`).
  String label(BuildContext context) => switch (this) {
    ShellBranch.follow => context.t.tabs.favorites,
    ShellBranch.popular => context.t.tabs.popular,
    ShellBranch.areas => context.t.tabs.areas,
    ShellBranch.record => context.t.tabs.record,
  };

  /// The route location this branch's root answers — what the router starts
  /// on when the launch preference names this branch.
  String get location => switch (this) {
    ShellBranch.follow => RoutePath.favorites,
    ShellBranch.popular => RoutePath.popular,
    ShellBranch.areas => RoutePath.areas,
    ShellBranch.record => RoutePath.recorder,
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
/// An id the enum does not know is dropped — which is how a document naming
/// the old `home` launcher or `history` branch stops drawing them. An empty or
/// unknown document falls back to every branch in table order: a shell with no
/// destination cannot be walked, so this never returns an empty list.
///
/// A stored document that is still the untouched default (`shellBranches`
/// before the popular and areas branches existed) has never been customised,
/// so it grows the new branches instead of hiding them: the tab conversion
/// must not land as two tabs going missing. A document that differs from the
/// default at all is a real choice and stands as stored.
List<ShellBranch> visibleShellBranches(AppPreferences preferences) {
  final stored = preferences.shellBranches;
  final seen = <ShellBranch>{};
  final result = <ShellBranch>[];
  if (stored.length != defaultShellBranches.length || !_sameIds(stored, defaultShellBranches)) {
    for (final id in stored) {
      final branch = ShellBranch.maybeFromId(id);
      if (branch != null && seen.add(branch)) {
        result.add(branch);
      }
    }
  }
  if (result.isEmpty) {
    result.addAll(ShellBranch.values);
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

/// Every branch as a shell destination, in display order — the one list the
/// dispatched shell renders from, whichever library draws it.
///
/// The id is the branch's own name, so the shell reports a choice as something
/// the router layer can map back without relying on positions surviving a change
/// to the table.
List<PureShellDestination> shellDestinations(BuildContext context, {List<ShellBranch>? branches}) => [
  for (final branch in branches ?? ShellBranch.values)
    PureShellDestination(id: branch.name, label: branch.label(context), icon: branch.icon),
];

/// The wider navigation column's destinations.
///
/// The four branches come first, then the utility pages the old rail exposed as
/// icon actions. Listing them as destinations is what gives the reference
/// sidebar its full column and lets the compact tablet rail carry the same set
/// as the desktop drawer. Selection stays branch-based: a utility page is pushed
/// above the shell, so no destination is selected while it is open.
List<PureShellDestination> shellRailDestinations(BuildContext context, {List<ShellBranch>? branches}) => [
  ...shellDestinations(context, branches: branches),
  PureShellDestination(id: 'history', label: context.t.tabs.history, icon: Icons.history_rounded),
  PureShellDestination(id: 'iptv', label: context.t.iptv.title, icon: Icons.dns_outlined),
  PureShellDestination(id: 'multiview', label: context.t.multiview.title, icon: Icons.grid_view_outlined),
  PureShellDestination(id: 'toolbox', label: context.t.toolbox.title, icon: Icons.link_outlined),
];

/// The adaptive shell's destination set, mirroring [shellRailDestinations].
///
/// The same one list serves every surface: the sidebar and rail render it all,
/// the drawer renders it all with the account card above, and the bottom bar
/// keeps only what [PureNavDestination.showInCompactBar] admits — the four
/// branches. The utilities carry a group divider before them so a wide column
/// shows where the tabs end.
List<PureNavDestination> shellAdaptiveDestinations(BuildContext context, {List<ShellBranch>? branches}) => [
  for (final branch in branches ?? ShellBranch.values)
    PureNavDestination(id: branch.name, label: branch.label(context), icon: branch.icon),
  PureNavDestination(
    id: 'history',
    label: context.t.tabs.history,
    icon: Icons.history_rounded,
    startsGroup: true,
    showInCompactBar: false,
  ),
  PureNavDestination(id: 'iptv', label: context.t.iptv.title, icon: Icons.dns_outlined, showInCompactBar: false),
  PureNavDestination(
    id: 'multiview',
    label: context.t.multiview.title,
    icon: Icons.grid_view_outlined,
    showInCompactBar: false,
  ),
  PureNavDestination(id: 'toolbox', label: context.t.toolbox.title, icon: Icons.link_outlined, showInCompactBar: false),
];
