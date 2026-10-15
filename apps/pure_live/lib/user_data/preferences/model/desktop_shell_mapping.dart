import 'package:live_shell/live_shell.dart' show RenderFallbacks, ShellSettings;
import 'package:pure_live/user_data/preferences/model/desktop_preferences.dart';

/// The desktop group read as shell configuration.
///
/// This mapping exists so it can be **tested**. The alternative — the app writing
/// the equivalent seven lines inside its start-up — looks identical until the day
/// a field is added to `DesktopPreferences` and quietly not passed on, which is
/// experienced as "I turned that setting off and nothing happened" and is close to
/// impossible to see in a review of the call site. Here the pairing is in one
/// place, next to the table of consumers below, with a test that fails when a
/// field appears in the document and nowhere else.
extension DesktopPreferencesAsShell on DesktopPreferences {
  /// What the shell is handed to decide close, hide, tray and reclaim behaviour.
  ///
  /// `idlePollInterval` is deliberately **not** persisted: how often to ask the
  /// machine whether it has been touched is a property of the question, not of
  /// what the viewer wants, and a setting nobody can reason about ("reclaim after
  /// 30 minutes" plus "poll every ? minutes") is worse than the shell's own
  /// default. If it ever needs tuning, that belongs next to the idle reader.
  ShellSettings get shellSettings => ShellSettings(
    closeAction: closeAction,
    trayEnabled: showTrayIcon,
    rememberBounds: rememberWindowBounds,
    startHidden: startHidden,
    reclaimWhenIdle: reclaimWhenIdle,
    idleReclaimAfter: idleReclaimAfter,
  );

  /// The two escape hatches, as the shell's rendering fallbacks.
  ///
  /// Both are read **before the first frame**, so applying these is a next-start
  /// change and the settings screen has to say so. Turning either one off also
  /// forces an opaque window surface — that consequence is the shell's, not this
  /// mapping's, and it is tested in `RenderFallbacks`.
  RenderFallbacks get renderFallbacks => RenderFallbacks(effects: effects, hardwareAcceleration: hardwareAcceleration);
}

/// Every field of the desktop group and what actually consumes it.
///
/// The keys must match the persisted document exactly; `desktop_preferences_test`
/// compares them against `toJson()`, which is why adding a setting here without
/// giving it a consumer is a failing test rather than a silent gap.
const Map<String, String> desktopFieldConsumers = {
  'closeAction': 'ShellSettings.closeAction, then resolveCloseDisposition',
  'showTrayIcon': 'ShellSettings.trayEnabled, then TrayHost.isCreated',
  'rememberWindowBounds': 'ShellSettings.rememberBounds → WindowStateStore',
  'startHidden': 'ShellSettings.startHidden → resolveStartState',
  'reclaimWhenIdle': 'ShellSettings.reclaimWhenIdle → shouldReclaimForIdle',
  'idleReclaimAfter': 'ShellSettings.idleReclaimAfter → IdleWatcher threshold',
  'effects': 'RenderFallbacks.effects',
  'hardwareAcceleration': 'RenderFallbacks.hardwareAcceleration',
  'launchAtLogin': 'the app applies it through CommandStartupRegistration',
  'systemNotifications': 'the app gates notification posting on it',
};
