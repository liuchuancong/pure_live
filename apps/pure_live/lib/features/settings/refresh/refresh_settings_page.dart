import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/app_providers.dart' show followRepositoryProvider;
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The refresh settings page (3.x `RefreshSettingsPage`, trimmed to the backed
/// knobs): how often the visible feed refreshes itself in the foreground, and
/// how long away counts as worth a refresh on resume.
///
/// The interval and the threshold are read by the list feeds through the shared
/// auto-refresh mixin, so a change here re-arms their timers live. The
/// reference's per-favourite refresh, concurrency cap and thumbnail refresh have
/// no backing in this build and stay out.
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
    return SettingsChrome(
      title: t.settings.refreshSettings,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.groupAutoRefresh),
            tiles: [
              SettingsTile.navigation(
                leading: const Icon(Icons.update_outlined),
                title: Text(t.settings.autoRefreshInterval),
                value: Text(_intervalLabel(context, preferences.autoRefreshMinutes)),
                onPressed: (_) => unawaited(
                  _choose<int>(
                    context,
                    ref,
                    title: t.settings.autoRefreshInterval,
                    hint: t.settings.autoRefreshIntervalHint,
                    current: preferences.autoRefreshMinutes,
                    options: [for (final minutes in _intervalChoices) (minutes, _intervalLabel(context, minutes))],
                    apply: (value) => update((p) => p.copyWith(autoRefreshMinutes: value)),
                  ),
                ),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.history_outlined),
                title: Text(t.settings.refreshResumeThreshold),
                value: Text(_thresholdLabel(context, preferences.refreshResumeThresholdMinutes)),
                onPressed: (_) => unawaited(
                  _choose<int>(
                    context,
                    ref,
                    title: t.settings.refreshResumeThreshold,
                    hint: t.settings.refreshResumeThresholdHint,
                    current: preferences.refreshResumeThresholdMinutes,
                    options: [for (final minutes in _thresholdChoices) (minutes, _thresholdLabel(context, minutes))],
                    apply: (value) => update((p) => p.copyWith(refreshResumeThresholdMinutes: value)),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.liveAlertScope),
            tiles: [
              CustomSettingsTile(
                child: _LiveAlertScopeTile(
                  selected: preferences.liveAlertTagIds,
                  onChanged: (ids) => unawaited(update((p) => p.copyWith(liveAlertTagIds: ids))),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: Text(t.settings.groupCovers),
            tiles: [
              SettingsTile.switchTile(
                key: const ValueKey('refresh-auto-covers'),
                leading: const Icon(Icons.image_outlined),
                title: Text(t.settings.autoRefreshThumbnails),
                description: Text(t.settings.autoRefreshThumbnailsDesc),
                initialValue: preferences.autoRefreshThumbnails,
                onToggle: (value) => unawaited(update((p) => p.copyWith(autoRefreshThumbnails: value))),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('refresh-keep-old-covers'),
                leading: const Icon(Icons.archive_outlined),
                title: Text(t.settings.thumbnailKeepOldFiles),
                description: Text(t.settings.thumbnailKeepOldFilesDesc),
                initialValue: preferences.thumbnailKeepOldFiles,
                enabled: preferences.autoRefreshThumbnails,
                onToggle: (value) => unawaited(update((p) => p.copyWith(thumbnailKeepOldFiles: value))),
              ),
              SettingsTile.navigation(
                key: const ValueKey('refresh-cover-interval'),
                leading: const Icon(Icons.timelapse_outlined),
                title: Text(t.settings.thumbnailRefreshInterval),
                value: Text(_minutesLabel(context, preferences.thumbnailRefreshMinutes)),
                enabled: preferences.autoRefreshThumbnails,
                onPressed: (_) => unawaited(
                  _choose<int>(
                    context,
                    ref,
                    title: t.settings.thumbnailRefreshInterval,
                    hint: t.settings.autoRefreshThumbnailsDesc,
                    current: preferences.thumbnailRefreshMinutes,
                    options: [for (final minutes in _coverChoices) (minutes, _minutesLabel(context, minutes))],
                    apply: (value) => update((p) => p.copyWith(thumbnailRefreshMinutes: value)),
                  ),
                ),
              ),
            ],
          ),
          // 3.x kept the history size on the history page; v4 put it here.
          SettingsSection(
            title: Text(t.settings.groupHistory),
            tiles: [
              SettingsTile.navigation(
                key: const ValueKey('refresh-history-limit'),
                leading: const Icon(Icons.history_outlined),
                title: Text(t.settings.historyLimit),
                description: Text(t.settings.historyLimitDesc),
                value: Text(preferences.historyLimit == 0 ? t.settings.noLimit : '${preferences.historyLimit}'),
                onPressed: (_) => unawaited(
                  _choose<int>(
                    context,
                    ref,
                    title: t.settings.historyLimit,
                    hint: t.settings.historyLimitDesc,
                    current: preferences.historyLimit,
                    options: [
                      for (final count in const [0, 20, 50, 100, 200, 500])
                        (count, count == 0 ? t.settings.noLimit : '$count'),
                    ],
                    apply: (value) => update((p) => p.copyWith(historyLimit: value)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The cover-refresh interval choices, minutes.
  static const List<int> _coverChoices = [5, 10, 15, 30, 60, 120, 180, 240, 300, 360];

  static String _minutesLabel(BuildContext context, int minutes) => context.t.settings.minutesValue(minutes: minutes);

  static Future<void> _choose<T>(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String? hint,
    required T current,
    required List<(T, String)> options,
    required Future<void> Function(T) apply,
  }) async {
    final picked = await showSettingsChooser<T>(
      context,
      ref,
      title: title,
      hint: hint,
      current: current,
      options: options,
    );
    if (picked != null) {
      await apply(picked);
    }
  }

  static String _intervalLabel(BuildContext context, int minutes) =>
      minutes <= 0 ? context.t.settings.refreshOff : context.t.settings.minutesValue(minutes: minutes);

  static String _thresholdLabel(BuildContext context, int minutes) =>
      minutes <= 0 ? context.t.settings.refreshEveryResume : context.t.settings.minutesAway(minutes: minutes);
}

/// Which follow tags 开播提醒 covers: a switch per tag; none chosen means
/// every follow, which is what the hint says.
final class _LiveAlertScopeTile extends ConsumerWidget {
  const new({required this.selected, required this.onChanged});

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final groups = ref.watch(followRepositoryProvider).groups;
    final theme = PureTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PureSpacing.lg, vertical: PureSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.settings.liveAlertScopeDesc, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
          const SizedBox(height: 6),
          for (final group in groups)
            SwitchListTile(
              key: ValueKey('live-alert-tag-${group.id}'),
              contentPadding: EdgeInsets.zero,
              title: Text(group.name),
              value: selected.contains(group.id),
              onChanged: (on) {
                final next = [...selected]..remove(group.id);
                if (on) {
                  next.add(group.id);
                }
                onChanged(next);
              },
            ),
          if (groups.isEmpty)
            Text(t.settings.liveAlertAll, style: theme.text.bodySmall.copyWith(color: theme.colors.textSecondary)),
        ],
      ),
    );
  }
}
