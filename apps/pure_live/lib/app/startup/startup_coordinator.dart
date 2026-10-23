import 'package:live_log/live_log.dart' show LiveLog;

import 'package:pure_live/app/startup/startup_tasks.dart' show StartupTaskSpec, kStartupTasks;

/// A startup task that did not complete, carrying the task that stopped and
/// the reason it stopped.
final class StartupFailure implements Exception {
  /// A failure of [task] with [error] at [stackTrace].
  const new(this.task, this.error, this.stackTrace);

  /// The task that did not complete.
  final StartupTaskSpec task;

  /// What the task threw.
  final Object error;

  /// Where the task threw.
  final StackTrace stackTrace;

  @override
  String toString() => 'startup task "${task.name}" failed: $error';
}

/// Runs every task in [tasks], in order, reporting through [log].
///
/// The first failure stops the boot and surfaces as a [StartupFailure]: the
/// shell cannot start half-initialised, and the error screen names the task
/// so a crash log answers "how far did it get" without a debugger.
Future<void> runStartup({required LiveLog log, List<StartupTaskSpec>? tasks}) async {
  for (final task in tasks ?? kStartupTasks) {
    final taskLog = log.forCategory(task.name);
    try {
      await task.run();
    } on Object catch (error, stackTrace) {
      taskLog.error('startup task failed', error: error, stackTrace: stackTrace);
      throw StartupFailure(task, error, stackTrace);
    }
  }
}
