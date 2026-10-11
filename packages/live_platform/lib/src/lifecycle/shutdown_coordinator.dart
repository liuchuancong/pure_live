/// Ordered shutdown coordination for platform-held resources.
///
/// Adapters register their teardowns (file sinks, database handles,
/// native bridges) with a phase; shutdown drains phases in order and
/// isolates individual failures.
abstract interface class ShutdownCoordinator {
  /// Registers a teardown under [phase]; lower phases run first.
  void register(ShutdownPhase phase, Future<void> Function() task);

  /// Runs every registered teardown, ordered by phase. Never throws —
  /// individual failures are reported through the returned results.
  Future<List<ShutdownResult>> shutdown();
}

/// Shutdown ordering: storage first, then session-level, then native.
enum ShutdownPhase {
  /// File sinks, databases, storage managers.
  storage,

  /// Sessions, players, network clients.
  session,

  /// Native bridges and platform channels.
  native,
}

/// Outcome of one teardown task.
final class ShutdownResult {
  /// One task's outcome.
  const new({required this.phase, this.error});

  /// Which phase the task ran in.
  final ShutdownPhase phase;

  /// The failure, when the task threw.
  final Object? error;

  /// Whether the task completed cleanly.
  bool get isClean => error == null;
}
