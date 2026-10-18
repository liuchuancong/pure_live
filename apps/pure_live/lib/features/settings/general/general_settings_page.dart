import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/features/settings/widgets/settings_chooser.dart';
import 'package:pure_live/features/settings/widgets/settings_chrome.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart' show ShellPreferencesStore, ShellWindowChrome;
import 'package:pure_settings_ui/pure_settings_ui.dart';
import 'package:pure_uikit/pure_uikit.dart';
import 'package:restart_app/restart_app.dart';
import 'package:window_manager/window_manager.dart';

/// The title-bar choices the settings screen offers, one more than the stored
/// preference has: `auto` is the absence of a choice, and it needs a value of
/// its own to be pickable.
enum _ChromeOption {
  /// No choice made: the operating system's version decides.
  auto,

  /// Pure Live draws the caption strip and its buttons.
  app,

  /// Windows draws the native caption.
  system,
}

/// The general settings page (3.x `GeneralSettingsPage`, trimmed to what
/// this build backs): refresh-on-resume, the update check, the countdown
/// close, the launch page and — on the desktop — the title-bar mode and the
/// stored window size, every control writing straight into the persisted
/// preferences.
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
    final shell = ref.watch(shellPreferencesProvider);
    final update = ref.read(appPreferencesProvider.notifier).update;
    final isDesktop = switch (ref.watch(environmentProvider).runtime.kind) {
      PlatformKind.windows || PlatformKind.macos || PlatformKind.linux => true,
      _ => false,
    };
    return SettingsChrome(
      title: t.settings.general,
      body: SettingsList(
        sections: [
          SettingsSection(
            title: Text(t.settings.general),
            tiles: [
              SettingsTile.switchTile(
                leading: const Icon(Icons.refresh_outlined),
                title: Text(t.settings.refreshOnResume),
                description: Text(t.settings.refreshOnResumeSubtitle),
                initialValue: preferences.refreshOnResume,
                onToggle: (value) => update((p) => p.copyWith(refreshOnResume: value)),
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.system_update_outlined),
                title: Text(t.settings.autoCheckUpdate),
                description: Text(t.settings.autoCheckUpdateSubtitle),
                initialValue: preferences.autoCheckUpdate,
                onToggle: (value) => update((p) => p.copyWith(autoCheckUpdate: value)),
              ),
              SettingsTile.switchTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text(t.settings.countdownClose),
                description: Text(t.settings.countdownCloseSubtitle),
                initialValue: preferences.countdownCloseEnabled,
                onToggle: (value) => update((p) => p.copyWith(countdownCloseEnabled: value)),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.av_timer_outlined),
                title: Text(t.settings.countdownDuration),
                value: Text(t.settings.minutesValue(minutes: preferences.countdownCloseMinutes)),
                onPressed: (_) => _chooseCountdownDuration(context, preferences, update),
              ),
              SettingsTile.navigation(
                leading: const Icon(Icons.start_outlined),
                title: Text(t.settings.launchPage),
                value: Text(_launchBranchLabel(context, preferences)),
                onPressed: (_) => _chooseLaunchPage(context, preferences, update),
              ),
            ],
          ),
          // The stored window size is a desktop answer only: a touch run has no
          // window to size.
          if (isDesktop)
            SettingsSection(
              title: Text(t.shellSettings.sectionWindow),
              tiles: [
                SettingsTile.navigation(
                  leading: const Icon(Icons.title_outlined),
                  title: Text(t.shellSettings.titleBar),
                  value: Text(_chromeLabel(context, shell)),
                  onPressed: (_) => _chooseWindowChrome(context, ref, shell),
                ),
                SettingsTile.navigation(
                  leading: const Icon(Icons.aspect_ratio_outlined),
                  title: Text(t.settings.windowSize),
                  value: Text(
                    preferences.windowWidth <= 0 || preferences.windowHeight <= 0
                        ? t.settings.windowSizeDefault
                        : '${preferences.windowWidth} × ${preferences.windowHeight}',
                  ),
                  onPressed: (_) => _chooseWindowSize(context, ref),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// What the title-bar row says about the viewer's choice.
  ///
  /// It states the *choice*, not the frame the window is wearing. The native
  /// helper settles the frame before this process can speak, so a choice made
  /// here is a true statement about the next start and a stale one about the
  /// live window — the row says which it is, and the restart offer that follows
  /// keeps the two from drifting apart silently.
  static String _chromeLabel(BuildContext context, ShellPreferencesStore? shell) {
    final t = context.t;
    return switch (shell?.value.windowChrome) {
      ShellWindowChrome.app => t.shellSettings.titleBarApp,
      ShellWindowChrome.system => t.shellSettings.titleBarSystem,
      null => t.shellSettings.titleBarAuto,
    };
  }

  /// Picks the title-bar mode.
  ///
  /// The chooser runs over [_ChromeOption] rather than straight over the
  /// preference's `ShellWindowChrome?` because "leave it to the system" is stored
  /// as null, and `showSettingsChooser` returns null for *dismissed* too — asking
  /// it about the nullable type directly would make closing the dialog without
  /// choosing silently set the mode to auto.
  static Future<void> _chooseWindowChrome(BuildContext context, WidgetRef ref, ShellPreferencesStore? shell) async {
    if (shell == null) {
      return;
    }
    final t = context.t;
    final current = switch (shell.value.windowChrome) {
      ShellWindowChrome.app => _ChromeOption.app,
      ShellWindowChrome.system => _ChromeOption.system,
      null => _ChromeOption.auto,
    };
    final picked = await showSettingsChooser<_ChromeOption>(
      context,
      title: t.shellSettings.titleBar,
      hint: t.shellSettings.titleBarHint,
      current: current,
      options: [
        (_ChromeOption.auto, t.shellSettings.titleBarAuto),
        (_ChromeOption.app, t.shellSettings.titleBarApp),
        (_ChromeOption.system, t.shellSettings.titleBarSystem),
      ],
    );
    if (picked == null || picked == current) {
      return;
    }
    // The preference is what carries the choice onward: `main.dart` mirrors it
    // into the flag file the runner reads before the window exists. Nothing here
    // can re-dress a live frame, so a restart is offered rather than assumed —
    // the running app is perfectly usable, only differently bordered.
    await shell.update(
      (preferences) => preferences.copyWith(
        windowChrome: switch (picked) {
          _ChromeOption.auto => null,
          _ChromeOption.app => ShellWindowChrome.app,
          _ChromeOption.system => ShellWindowChrome.system,
        },
        clearWindowChrome: picked == _ChromeOption.auto,
      ),
    );
    if (!context.mounted) {
      return;
    }
    final restart = await showPureDialog<bool>(
      context: context,
      title: t.shellSettings.titleBar,
      child: Text(t.shellSettings.titleBarHint),
      actions: (dialogContext) => [
        PureButton(
          label: dialogContext.t.common.restartLater,
          variant: ButtonVariant.ghost,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
        PureButton(label: dialogContext.t.common.restartNow, onPressed: () => Navigator.of(dialogContext).pop(true)),
      ],
    );
    if (restart == true) {
      await Restart.restartApp();
    }
  }

  static String _launchBranchLabel(BuildContext context, AppPreferences preferences) {
    final launch = preferences.launchBranch;
    return switch (launch) {
      AppLaunchBranch.follow => context.t.tabs.favorites,
      AppLaunchBranch.popular => context.t.tabs.popular,
      AppLaunchBranch.areas => context.t.tabs.areas,
      AppLaunchBranch.record => context.t.tabs.record,
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
        (AppLaunchBranch.follow, context.t.tabs.favorites),
        (AppLaunchBranch.popular, context.t.tabs.popular),
        (AppLaunchBranch.areas, context.t.tabs.areas),
        (AppLaunchBranch.record, context.t.tabs.record),
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
      options: [for (final preset in _windowPresets) (preset, '${preset.$1} × ${preset.$2}')],
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
    await ref
        .read(appPreferencesProvider.notifier)
        .update((p) => p.copyWith(windowWidth: picked.$1, windowHeight: picked.$2));
  }
}
