import 'dart:io';

import 'package:drift/native.dart';

import 'package:live_storage/src/database/storage_database.dart';

/// Opens the single SQLite database at [path].
///
/// WAL lets a future reader open the file without blocking the owner's
/// writes; the app still keeps one writer, the main window. The timeout
/// covers the one short overlap a backup or a second process may cause.
Future<StorageDatabase> openStorageDatabase(String path) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  return StorageDatabase(
    NativeDatabase(
      file,
      setup: (database) {
        database
          ..execute('PRAGMA journal_mode = WAL')
          ..execute('PRAGMA busy_timeout = 5000')
          ..execute('PRAGMA foreign_keys = ON');
      },
    ),
  );
}

/// An in-memory database for tests and the package example's dry run.
StorageDatabase openInMemoryStorageDatabase() => StorageDatabase(NativeDatabase.memory());
