import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The refresh settings page (3.x `RefreshSettingsPage`, trimmed to the
/// backed knobs): how often the visible feed refreshes itself in the
/// foreground, and how long away counts as worth a refresh on resume.
///
/// The interval and the threshold are read by the list feeds through the
/// shared auto-refresh mixin, so a change here re-arms their timers live.
/// The reference's per-favourite refresh, concurrency cap and thumbnail
/// refresh have no backing in this build and stay out.
final class RefreshSettingsPage extends ConsumerWidget {
  /// The refresh settings page.
  const new({super.key});

  /// The foreground interval choices, in minutes; 0 is off.
  static const List<int> _intervalChoices = [0, 5, 10, 15, 20, 30, 45, 60, 120, 240, 360];

  /// The resume threshold choices, in minutes; 0 refreshes on every resume.
  static const List<int> _thresholdChoices = [0, 1, 5, 10, 15, 30];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.refreshSettings),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SettingsSection.card(
            label: t.settings.groupAutoRefresh,
            tiles: [
              SettingsEntryTile(
                icon: Icons.update_outlined,
                title: t.settings.autoRefreshInterval,
                subtitle: _intervalLabel(context, preferences.autoRefreshMinutes),
                onTap: () async {
                  final picked = await showSettingsChooser<int>(
                    context,
                    title: t.settings.autoRefreshInterval,
                    hint: t.settings.autoRefreshIntervalHint,
                    current: preferences.autoRefreshMinutes,
                    options: [for (final minutes in _intervalChoices) (minutes, _intervalLabel(context, minutes))],
                  );
                  if (picked != null) {
                    await update((p) => p.copyWith(autoRefreshMinutes: picked));
                  }
                },
              ),
              SettingsEntryTile(
                icon: Icons.history_outlined,
                title: t.settings.refreshResumeThreshold,
                subtitle: _thresholdLabel(context, preferences.refreshResumeThresholdMinutes),
                onTap: () async {
                  final picked = await showSettingsChooser<int>(
                    context,
                    title: t.settings.refreshResumeThreshold,
                    hint: t.settings.refreshResumeThresholdHint,
                    current: preferences.refreshResumeThresholdMinutes,
                    options: [for (final minutes in _thresholdChoices) (minutes, _thresholdLabel(context, minutes))],
                  );
                  if (picked != null) {
                    await update((p) => p.copyWith(refreshResumeThresholdMinutes: picked));
                  }
                },
                divided: false,
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _intervalLabel(BuildContext context, int minutes) => minutes <= 0
      ? context.t.settings.refreshOff
      : context.t.settings.minutesValue(minutes: minutes);

  static String _thresholdLabel(BuildContext context, int minutes) => minutes <= 0
      ? context.t.settings.refreshEveryResume
      : context.t.settings.minutesAway(minutes: minutes);
}
