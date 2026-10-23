import 'package:pure_live/app/theme/system_accent_color.dart' show preloadSystemAccent;

/// One named unit of pre-shell work.
final class StartupTaskSpec {
  /// A task the coordinator runs and reports under [name].
  const new({required this.name, required this.run});

  /// The category the task's log lines and a failure report carry.
  final String name;

  /// The work itself; a throw stops the boot.
  final Future<void> Function() run;
}

/// The boot's task list, in the order the coordinator runs them.
///
/// The window's dress is deliberately not here: it happens in `bootstrap`
/// before Dart can draw anything, and a task that late would flash an
/// undressed window.
final List<StartupTaskSpec> kStartupTasks = [const StartupTaskSpec(name: 'accent', run: preloadSystemAccent)];
