import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/routing/app_router.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';

/// The platforms page (the reference's `SettingsSection.platforms`): the
/// visibility/order of the platform list, the follow tags and the platform
/// accounts — the three things a viewer tunes about where rooms come from.
///
/// The platform list row opens the hot-areas page (3.x `HotAreasPage`), the
/// tags row the tag manager (3.x `SettingTagsPage`), and the accounts row the
/// account hub; none of them is a knob on this page itself, so this page is
/// three links and a note.
final class PlatformsSettingsPage extends ConsumerWidget {
  /// The platforms settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return SettingsChrome(
      title: t.settings.platformsTitle,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.platformsTitle),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.visibility_outlined),
                title: Text(t.hotAreas.title),
                description: Text(t.hotAreas.note),
                onPressed: (_) => unawaited(const HotAreasRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.sell_outlined),
                title: Text(t.tags.title),
                description: Text(t.follow.manageGroups),
                onPressed: (_) => unawaited(const TagsRoute().push<void>(context)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.person_outline),
                title: Text(t.settings.sectionAccount),
                description: Text(t.settings.accountSubtitle),
                onPressed: (_) => unawaited(const AccountRoute().push<void>(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
