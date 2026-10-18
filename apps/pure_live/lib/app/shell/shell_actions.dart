import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The ways to find a room that every home layout offers (the reference's
/// `HomeAction`): search on its own button, the others beside it — on the
/// rail each is its own tool button, on the phone the non-search ones live
/// in the app bar's "more" menu.
enum HomeAction {
  /// Search rooms.
  search,

  /// The watch history.
  history,

  /// Open a shared link (the toolbox).
  openLink,

  /// Multi-view.
  multiview;

  /// The action's glyph.
  IconData get icon => switch (this) {
    HomeAction.search => Icons.search_rounded,
    HomeAction.history => Icons.history_rounded,
    HomeAction.openLink => Icons.link_outlined,
    HomeAction.multiview => Icons.grid_view_outlined,
  };

  /// The action's label.
  String label(Translations t) => switch (this) {
    HomeAction.search => t.tabs.search,
    HomeAction.history => t.tabs.history,
    HomeAction.openLink => t.toolbox.title,
    HomeAction.multiview => t.multiview.title,
  };

  /// Opens its page.
  void run(BuildContext context) => switch (this) {
    HomeAction.search => unawaited(const SearchRoute().push<void>(context)),
    HomeAction.history => unawaited(const HistoryRoute().push<void>(context)),
    HomeAction.openLink => unawaited(const ToolboxRoute().push<void>(context)),
    HomeAction.multiview => unawaited(const MultiviewRoute().push<void>(context)),
  };
}

/// The home actions shown (the reference gates `multiview` on a setting;
/// this build always offers it — multi-view has no off switch here).
List<HomeAction> homeActions() => HomeAction.values;

/// The menu at the top of the rail and the leading button of the phone app
/// bars (the reference's `MenuButton`): settings, about and backup in one
/// small anchored menu.
class HomeMenuButton extends StatelessWidget {
  /// The menu button.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return PureMenu(
      key: const ValueKey('home-menu'),
      items: [
        PureMenuItem(
          id: 'settings',
          label: t.tabs.settings,
          icon: Icons.settings_outlined,
          onTap: () => unawaited(const SettingsRoute().push<void>(context)),
        ),
        PureMenuItem(
          id: 'about',
          label: t.about.title,
          icon: Icons.info_outline,
          onTap: () => unawaited(const AboutRoute().push<void>(context)),
        ),
        PureMenuItem(
          id: 'backup',
          label: t.backup.title,
          icon: Icons.cloud_outlined,
          onTap: () => unawaited(const BackupRoute().push<void>(context)),
        ),
      ],
      child: PureIconButton(icon: Icons.menu_rounded, tooltip: t.common.menu),
    );
  }
}

/// The buttons at the top right of the phone tabs: search in one tap and
/// "more" with the history, the link parser and multi-view (the reference's
/// `CommonAppBarActions`).
class CommonAppBarActions extends StatelessWidget {
  /// The action pair.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PureIconButton(
          key: const ValueKey('home-search'),
          icon: HomeAction.search.icon,
          tooltip: HomeAction.search.label(t),
          onPressed: () => HomeAction.search.run(context),
        ),
        PureMenu(
          key: const ValueKey('home-more'),
          items: [
            for (final action in homeActions())
              if (action != HomeAction.search)
                PureMenuItem(
                  id: action.name,
                  label: action.label(t),
                  icon: action.icon,
                  onTap: () => action.run(context),
                ),
          ],
          child: PureIconButton(icon: Icons.more_vert_rounded, tooltip: t.common.more),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
