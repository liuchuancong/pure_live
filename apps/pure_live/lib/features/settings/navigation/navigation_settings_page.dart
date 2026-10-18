import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The navigation settings page: whether the app resumes on the branch it was
/// last left on, in place of the fixed launch page (general settings).
///
/// The launch flow reads this once, at the splash's handover — a change here
/// decides the next start.
final class NavigationSettingsPage extends ConsumerWidget {
  /// The navigation settings page.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    final lastBranch = ShellBranch.maybeFromId(preferences.lastBranchId ?? '');
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.navigationSettings),
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.groupLaunch),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.restore_outlined),
                title: Text(t.settings.restoreLastTab),
                description: Text(
                  lastBranch == null
                      ? t.settings.restoreLastTabSubtitle
                      : t.settings.restoreLastTabOn(branch: lastBranch.label(context)),
                ),
                initialValue: preferences.restoreLastTab,
                onToggle: (value) => update((p) => p.copyWith(restoreLastTab: value)),
              ),
            ],
          ),
          SettingsSection(
            tiles: [
              CustomSettingsTile(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    t.settings.navigationHint,
                    style: PureTheme.of(context).text.caption
                        .copyWith(color: PureTheme.of(context).colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
