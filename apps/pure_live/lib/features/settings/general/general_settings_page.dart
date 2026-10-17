import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_sections.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:window_manager/window_manager.dart';

/// The general settings page (3.x `GeneralSettingsPage`, trimmed to what
/// this build backs): refresh-on-resume, the update check, the countdown
/// close, the launch page and — on the desktop — the stored window size,
/// every control writing straight into the persisted preferences.
///
/// The reference's refresh-rate modes, splash animation, Windows start-up
/// and secondary-window switches have no backing here and stay out.
final class GeneralSettingsPage extends ConsumerWidget {
  /// The general settings page.
  const new({super.key});

  /// The window-size presets the chooser offers.
  static const List<(int, int)> _windowPresets = [(1080, 720), (1280, 720), (1600, 900), (1920, 1080), (2560, 1440)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final preferences = ref.watch(appPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    final isDesktop = switch (ref.watch(environmentProvider).runtime.kind) {
      PlatformKind.windows || PlatformKind.macos || PlatformKind.linux => true,
      _ => false,
    };
    return PureScaffold(
      appBar: PureAppBar(title: t.settings.general),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SettingsSection.card(
            label: t.settings.general,
            tiles: [
              SettingsSwitchTile(
                icon: Icons.refresh_outlined,
                title: t.settings.refreshOnResume,
                subtitle: t.settings.refreshOnResumeSubtitle,
                value: preferences.refreshOnResume,
                onChanged: (value) => update((p) => p.copyWith(refreshOnResume: value)),
              ),
              SettingsSwitchTile(
                icon: Icons.system_update_outlined,
                title: t.settings.autoCheckUpdate,
                subtitle: t.settings.autoCheckUpdateSubtitle,
                value: preferences.autoCheckUpdate,
                onChanged: (value) => update((p) => p.copyWith(autoCheckUpdate: value)),
              ),
              SettingsSwitchTile(
                icon: Icons.timer_outlined,
                title: t.settings.countdownClose,
                subtitle: t.settings.countdownCloseSubtitle,
                value: preferences.countdownCloseEnabled,
                onChanged: (value) => update((p) => p.copyWith(countdownCloseEnabled: value)),
              ),
              SettingsEntryTile(
                icon: Icons.av_timer_outlined,
                title: t.settings.countdownDuration,
                subtitle: t.settings.minutesValue(minutes: preferences.countdownCloseMinutes),
                onTap: () => _chooseCountdownDuration(context, preferences, update),
              ),
              SettingsEntryTile(
                icon: Icons.start_outlined,
                title: t.settings.launchPage,
                subtitle: _launchBranchLabel(context, preferences),
                onTap: () => _chooseLaunchPage(context, preferences, update),
                divided: false,
              ),
            ],
          ),
          if (isDesktop) ...[
            const SettingsSectionGap(),
            SettingsSection.card(
              label: t.shellSettings.sectionWindow,
              tiles: [
                SettingsEntryTile(
                  icon: Icons.aspect_ratio_outlined,
                  title: t.settings.windowSize,
                  subtitle: preferences.windowWidth <= 0 || preferences.windowHeight <= 0
                      ? t.settings.windowSizeDefault
                      : '${preferences.windowWidth} × ${preferences.windowHeight}',
                  onTap: () => _chooseWindowSize(context, ref),
                  divided: false,
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  static String _launchBranchLabel(BuildContext context, AppPreferences preferences) {
    final launch = preferences.launchBranch;
    return switch (launch) {
      AppLaunchBranch.home => context.t.tabs.home,
      AppLaunchBranch.follow => context.t.tabs.favorites,
      AppLaunchBranch.popular => context.t.tabs.popular,
      AppLaunchBranch.areas => context.t.tabs.areas,
      AppLaunchBranch.history => context.t.tabs.history,
    };
  }

  static Future<void> _chooseCountdownDuration(
    BuildContext context,
    AppPreferences preferences,
    Future<void> Function(AppPreferences Function(AppPreferences)) update,
  ) async {
    const minutesOptions = [15, 30, 45, 60, 90, 120, 180];
    final picked = await showSettingsChooser<int>(
      context,
      title: context.t.settings.countdownDuration,
      current: preferences.countdownCloseMinutes,
      options: [for (final minutes in minutesOptions) (minutes, context.t.settings.minutesValue(minutes: minutes))],
    );
    if (picked != null) {
      await update((p) => p.copyWith(countdownCloseMinutes: picked));
    }
  }

  static Future<void> _chooseLaunchPage(
    BuildContext context,
    AppPreferences preferences,
    Future<void> Function(AppPreferences Function(AppPreferences)) update,
  ) async {
    final picked = await showSettingsChooser<AppLaunchBranch>(
      context,
      title: context.t.settings.launchPage,
      hint: context.t.settings.launchPageHint,
      current: preferences.launchBranch,
      options: [
        (AppLaunchBranch.home, context.t.tabs.home),
        (AppLaunchBranch.follow, context.t.tabs.favorites),
        (AppLaunchBranch.history, context.t.tabs.history),
      ],
    );
    if (picked != null) {
      await update((p) => p.copyWith(launchBranch: picked));
    }
  }

  /// The window-size chooser: presets plus the entry in use, applied live
  /// through the window manager and persisted for the next launch. A
  /// non-desktop run never reaches here.
  static Future<void> _chooseWindowSize(BuildContext context, WidgetRef ref) async {
    final preferences = ref.read(appPreferencesProvider);
    final current = (preferences.windowWidth, preferences.windowHeight);
    final picked = await showSettingsChooser<(int, int)>(
      context,
      title: context.t.settings.windowSize,
      hint: context.t.settings.windowSizeHint,
      current: current,
      options: [
        for (final preset in _windowPresets) (preset, '${preset.$1} × ${preset.$2}'),
      ],
    );
    if (picked == null) {
      return;
    }
    final size = Size(picked.$1.toDouble(), picked.$2.toDouble());
    try {
      await windowManager.setSize(size);
    } on Object {
      // The window manager refused (an unsupported host, a headless run) —
      // the stored answer still holds for the next launch.
    }
    await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(windowWidth: picked.$1, windowHeight: picked.$2));
  }
}
