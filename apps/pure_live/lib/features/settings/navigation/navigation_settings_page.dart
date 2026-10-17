import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/shell/shell_destinations.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The navigation settings page: whether the app resumes on the branch it
/// was last left on, in place of the fixed launch page (general settings).
///
/// The launch flow reads this once, at the splash's handover — a change
/// here decides the next start.
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
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SettingsSection.card(
            label: t.settings.groupLaunch,
            tiles: [
              SettingsSwitchTile(
                icon: Icons.restore_outlined,
                title: t.settings.restoreLastTab,
                subtitle: lastBranch == null
                    ? t.settings.restoreLastTabSubtitle
                    : t.settings.restoreLastTabOn(branch: lastBranch.label(context)),
                value: preferences.restoreLastTab,
                onChanged: (value) => update((p) => p.copyWith(restoreLastTab: value)),
                divided: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              t.settings.navigationHint,
              style: PureTheme.of(context).text.caption.copyWith(color: PureTheme.of(context).colors.textSecondary),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
