import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart' show goShellBranch;
import 'package:pure_live/app/routing/routes/about/about_routes.dart';
import 'package:pure_live/app/routing/routes/backup/backup_routes.dart';
import 'package:pure_live/app/routing/routes/history/history_routes.dart';
import 'package:pure_live/app/routing/routes/iptv/iptv_routes.dart';
import 'package:pure_live/app/routing/routes/login/login_routes.dart';
import 'package:pure_live/app/routing/routes/multiview/multiview_routes.dart';
import 'package:pure_live/app/routing/routes/search/search_routes.dart';
import 'package:pure_live/app/routing/routes/settings/settings_routes.dart';
import 'package:pure_live/app/routing/routes/toolbox/toolbox_routes.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Opens one destination from the wider navigation column.
///
/// Branch ids walk the stateful shell; the utility ids the new sidebar adds are
/// routes pushed above it, so they do not try to become a fifth branch.
void openShellRailDestination(BuildContext context, WidgetRef ref, StatefulNavigationShell navigationShell, String id) {
  switch (id) {
    case 'history':
      unawaited(const HistoryRoute().push<void>(context));
    case 'iptv':
      unawaited(const IptvRoute().push<void>(context));
    case 'multiview':
      unawaited(const MultiviewRoute().push<void>(context));
    case 'toolbox':
      unawaited(const ToolboxRoute().push<void>(context));
    default:
      if (ShellBranch.maybeFromId(id) case final branch?) {
        goShellBranch(ref, navigationShell, branch.name);
      }
  }
}

/// The utility cluster at the foot of the desktop drawer and tablet rail.
///
/// These are app actions rather than destinations: search, settings and the
/// account page live in the shell frame, while the branch and utility
/// destinations are rendered by the shell itself. The widget switches between a
/// row (260px drawer footer) and a column (88px rail) from its own constraints,
/// so it needs no breakpoint check.
final class ShellRailActions extends StatelessWidget {
  /// The action cluster.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      const _MenuButton(),
      PureIconButton(
        icon: Icons.search_rounded,
        tooltip: context.t.tabs.search,
        onPressed: () => unawaited(const SearchRoute().push<void>(context)),
      ),
      PureIconButton(
        icon: Icons.settings_outlined,
        tooltip: context.t.tabs.settings,
        onPressed: () => unawaited(const SettingsRoute().push<void>(context)),
      ),
      PureIconButton(
        icon: Icons.account_circle_outlined,
        tooltip: context.t.account.title,
        onPressed: () => unawaited(const AccountRoute().push<void>(context)),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 148) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (final action in actions) Padding(padding: const EdgeInsets.only(bottom: 2), child: action)],
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              if (index > 0) const SizedBox(width: 2),
              actions[index],
            ],
          ],
        );
      },
    );
  }
}

/// The menu the reference keeps beside the utility cluster: settings, about,
/// the watch history and backup, plus the tools that are not branch tabs.
final class _MenuButton extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => PureMenu(
    items: [
      PureMenuItem(
        id: 'settings',
        label: context.t.tabs.settings,
        icon: Icons.settings_outlined,
        onTap: () => unawaited(const SettingsRoute().push<void>(context)),
      ),
      PureMenuItem(
        id: 'history',
        label: context.t.tabs.history,
        icon: Icons.history,
        onTap: () => unawaited(const HistoryRoute().push<void>(context)),
      ),
      PureMenuItem(
        id: 'toolbox',
        label: context.t.toolbox.title,
        icon: Icons.link_outlined,
        onTap: () => unawaited(const ToolboxRoute().push<void>(context)),
      ),
      PureMenuItem(
        id: 'about',
        label: context.t.about.title,
        icon: Icons.info_outline,
        onTap: () => unawaited(const AboutRoute().push<void>(context)),
      ),
      PureMenuItem(
        id: 'backup',
        label: context.t.backup.title,
        icon: Icons.cloud_outlined,
        onTap: () => unawaited(const BackupRoute().push<void>(context)),
      ),
    ],
    child: PureIconButton(icon: Icons.menu_rounded, tooltip: context.t.common.menu),
  );
}
