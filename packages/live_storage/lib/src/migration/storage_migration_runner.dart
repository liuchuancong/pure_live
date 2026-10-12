import 'package:live_storage/src/migration/storage_migration.dart';

/// Executes storage migrations in ascending version order.
final class StorageMigrationRunner {
  /// Creates a migration runner.
  new({required Iterable<StorageMigration> migrations}) : _migrations = _validateAndSort(migrations);

  final List<StorageMigration> _migrations;

  static List<StorageMigration> _validateAndSort(Iterable<StorageMigration> migrations) {
    final result = migrations.toList()..sort((a, b) => a.targetVersion.compareTo(b.targetVersion));

    final versions = <int>{};
    final identifiers = <String>{};

    for (final migration in result) {
      if (migration.targetVersion <= 0) {
        throw ArgumentError.value(migration.targetVersion, 'targetVersion', 'Must be positive.');
      }

      if (migration.id.trim().isEmpty) {
        throw ArgumentError.value(migration.id, 'id', 'Must not be empty.');
      }

      if (!versions.add(migration.targetVersion)) {
        throw ArgumentError(
          'Duplicate migration target version: '
          '${migration.targetVersion}.',
        );
      }

      if (!identifiers.add(migration.id)) {
        throw ArgumentError('Duplicate migration ID: ${migration.id}.');
      }
    }

    return List.unmodifiable(result);
  }

  /// Runs migrations newer than [currentVersion] up to [targetVersion].
  ///
  /// Migrations are executed sequentially. The caller is responsible for
  /// persisting the resulting schema version after successful completion.
  Future<void> run({required int currentVersion, required int targetVersion}) async {
    if (currentVersion < 0) {
      throw ArgumentError.value(currentVersion, 'currentVersion', 'Must not be negative.');
    }

    if (targetVersion < currentVersion) {
      throw ArgumentError('Target version must not be less than the current version.');
    }

    for (final migration in _migrations) {
      if (migration.targetVersion <= currentVersion) continue;
      if (migration.targetVersion > targetVersion) break;

      await migration.migrate();
    }
  }
}
