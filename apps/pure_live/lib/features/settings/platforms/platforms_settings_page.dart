import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/navigation/app_router.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

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
    final preferences = ref.watch(appPreferencesProvider);
    final sites = ref.watch(sitesProvider).registry.all.map((site) => site.manifest.id).toList();
    final names = {
      for (final site in ref.watch(sitesProvider).registry.all)
        site.manifest.id: site.manifest.localizedName(Localizations.localeOf(context).toLanguageTag(), 'zh-CN'),
    };
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
                key: const ValueKey('platforms-preferred'),
                leading: const Icon(Icons.star_outline),
                title: Text(t.settings.preferredPlatform),
                description: Text(t.settings.preferredPlatformDesc),
                value: Text(
                  preferences.preferredSiteId.isEmpty
                      ? t.settings.preferredPlatformNone
                      : names[preferences.preferredSiteId] ?? preferences.preferredSiteId,
                ),
                onPressed: (_) => _choosePreferred(context, ref, sites, names),
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

/// Picks the discovery pages' opening platform; "platform order" clears it.
Future<void> _choosePreferred(
  BuildContext context,
  WidgetRef ref,
  List<String> siteIds,
  Map<String, String> names,
) async {
  final t = context.t;
  final picked = await showPureDialog<String>(
    context: context,
    title: t.settings.preferredPlatform,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(t.settings.preferredPlatformNone), onTap: () => Navigator.of(context).pop('')),
          for (final id in siteIds) ListTile(title: Text(names[id] ?? id), onTap: () => Navigator.of(context).pop(id)),
        ],
      ),
    ),
  );
  if (picked == null) {
    return;
  }
  await ref
      .read(appPreferencesProvider.notifier)
      .update((preferences) => preferences.copyWith(preferredSiteId: picked));
}
