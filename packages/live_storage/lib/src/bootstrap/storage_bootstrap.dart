import 'package:live_storage/src/database/storage_stores.dart';
import 'package:live_storage/src/paths/storage_path_provider.dart';

/// Opens the process's SQLite database and keeps the lifecycle in one
/// place.
///
/// The main window owns this; room and tool windows do not call it. A
/// failure can be retried — the app's boot logs it and carries on with the
/// providers' defaults.
final class StorageBootstrap {
  /// Creates a storage bootstrap over the app-provided path.
  new({required this.pathProvider});

  /// Provides the application-configured storage directory.
  final StoragePathProvider pathProvider;

  Future<void>? _initialization;
  bool _initialized = false;

  /// Whether the database opened successfully.
  bool get isInitialized => _initialized;

  /// Opens the database. Concurrent callers share one operation; a
  /// failed attempt can be retried.
  Future<void> initialize() async {
    if (_initialized) return;

    final pending = _initialization ??= _initialize();

    try {
      await pending;
    } catch (_) {
      if (identical(_initialization, pending)) {
        _initialization = null;
      }
      rethrow;
    }
  }

  Future<void> _initialize() async {
    final directory = await pathProvider.getStoragePath();
    await StorageStores.open(directory: directory);
    _initialized = true;
  }

  /// Closes the database; storage must be re-initialized before further
  /// use. Called from the app lifecycle hook, never a business module.
  Future<void> shutdown() async {
    if (!_initialized) return;

    await StorageStores.closeInstance();
    _initialization = null;
    _initialized = false;
  }
}
