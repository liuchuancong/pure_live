import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_platform/live_platform.dart' show PlatformKind;
import 'package:live_shell/live_shell.dart' show CloseAction, StartupRegistration;
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

/// The close row's \"ask every time\" — the absence of a stored action, given
/// a value of its own so the chooser can offer and compare it.
const Object _askClose = Object();

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
    final registration = ref.watch(startupRegistrationProvider);
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
              SettingsTile.switchTile(
                key: const ValueKey('general-splash'),
                leading: const Icon(Icons.branding_watermark_outlined),
                title: Text(t.settings.splashAnimation),
                description: Text(t.settings.splashAnimationDesc),
                initialValue: preferences.showSplash,
                onToggle: (value) => unawaited(update((p) => p.copyWith(showSplash: value))),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('general-github-updates'),
                leading: const Icon(Icons.hub_outlined),
                title: Text(t.settings.githubUpdates),
                description: Text(t.settings.githubUpdatesDesc),
                initialValue: preferences.githubOnlyUpdates,
                onToggle: (value) => unawaited(update((p) => p.copyWith(githubOnlyUpdates: value))),
              ),
              SettingsTile.switchTile(
                key: const ValueKey('general-clipboard-rooms'),
                leading: const Icon(Icons.content_paste_go_outlined),
                title: Text(t.settings.clipboardRooms),
                description: Text(t.settings.clipboardRoomsDesc),
                initialValue: preferences.detectClipboardRooms,
                onToggle: (value) => unawaited(update((p) => p.copyWith(detectClipboardRooms: value))),
              ),
            ],
          ),
          // 开机启动: the OS verb lives only on the desktop; a run without a
          // registrar (a mobile platform, a test harness) shows no row at all.
          if (registration case final registrar?)
            SettingsSection(
              title: Text(t.settings.general),
              tiles: [
                SettingsTile.switchTile(
                  key: const ValueKey('general-start-at-login'),
                  leading: const Icon(Icons.login_outlined),
                  title: Text(t.settings.startup),
                  description: Text(t.settings.startupDesc),
                  initialValue: preferences.startAtLogin,
                  onToggle: (value) => unawaited(_setStartAtLogin(context, ref, registrar, value)),
                ),
              ],
            ),
          // The close-button answer the shell runs; `ask every time` is the
          // absence of one, which is the same null the first-close prompt
          // replaces when the viewer checks \"remember\".
          if (isDesktop)
            SettingsSection(
              title: Text(t.shellSettings.sectionWindow),
              tiles: [
                SettingsTile.navigation(
                  key: const ValueKey('general-close-window'),
                  leading: const Icon(Icons.close_outlined),
                  title: Text(t.settings.closeWindow),
                  description: Text(t.settings.closeWindowDesc),
                  value: Text(_closeActionLabel(context, shell?.value.closeAction)),
                  onPressed: (_) => _chooseCloseAction(context, ref, shell),
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

  /// Writes the launch-at-sign-in entry through the OS and stores the answer
  /// only when the OS accepted it — a toggle that flips while nothing was
  /// registered is the lie the doc comment warns about.
  static Future<void> _setStartAtLogin(
    BuildContext context,
    WidgetRef ref,
    StartupRegistration registrar,
    bool enabled,
  ) async {
    final t = context.t;
    final ok = await registrar.setLaunchAtLogin(enabled: enabled);
    if (ok) {
      await ref.read(appPreferencesProvider.notifier).update((p) => p.copyWith(startAtLogin: enabled));
      return;
    }
    if (context.mounted) {
      PureToast.show(context, t.settings.startupFailed, type: PureToastType.error);
    }
  }

  /// What the close-window row says about the standing answer.
  static String _closeActionLabel(BuildContext context, CloseAction? action) {
    final t = context.t;
    return switch (action) {
      CloseAction.hideToTray => t.settings.closeHide,
      CloseAction.minimise => t.settings.closeMinimise,
      CloseAction.quit => t.settings.closeQuit,
      null => t.settings.closeAsk,
    };
  }

  /// Picks the window-close answer. `ask every time` clears the stored
  /// action, which is exactly what re-arms the first-close prompt.
  static Future<void> _chooseCloseAction(BuildContext context, WidgetRef ref, ShellPreferencesStore? shell) async {
    if (shell == null) {
      return;
    }
    final t = context.t;
    final current = shell.value.closeAction ?? _askClose;
    final picked = await showSettingsChooser<Object>(
      context,
      title: t.settings.closeWindow,
      hint: t.settings.closeWindowDesc,
      current: current,
      options: [
        (_askClose, t.settings.closeAsk),
        (CloseAction.hideToTray, t.settings.closeHide),
        (CloseAction.minimise, t.settings.closeMinimise),
        (CloseAction.quit, t.settings.closeQuit),
      ],
    );
    if (picked == null || picked == current) {
      return;
    }
    await shell.update(
      (preferences) => preferences.copyWith(
        closeAction: picked is CloseAction ? picked : null,
        clearCloseAction: picked == _askClose,
      ),
    );
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
