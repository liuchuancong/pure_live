/// Defines a single storage schema migration.
abstract interface class StorageMigration {
  /// Creates a storage migration contract.
  const new();

  /// The schema version this migration upgrades to.
  ///
  /// Versions must be positive and strictly increasing.
  int get targetVersion;

  /// A stable identifier used for logging and diagnostics.
  String get id;

  /// Executes the migration.
  ///
  /// Implementations should be idempotent whenever possible.
  Future<void> migrate();
}
