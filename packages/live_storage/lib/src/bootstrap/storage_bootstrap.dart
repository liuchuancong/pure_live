import 'package:hive_ce/hive.dart';
import 'package:live_storage/src/paths/storage_path_provider.dart';
import 'package:live_storage/src/registry/storage_adapter_registry.dart';

/// Coordinates storage initialization and adapter registration.
final class StorageBootstrap {
  /// Creates a storage bootstrap coordinator.
  new({required this.pathProvider, required this.adapterRegistry});

  /// Provides the application-configured storage path.
  final StoragePathProvider pathProvider;

  /// Registers adapters provided by feature packages.
  final StorageAdapterRegistry adapterRegistry;

  Future<void>? _initialization;
  bool _initialized = false;

  /// Whether storage initialization has completed successfully.
  bool get isInitialized => _initialized;

  /// Initializes Hive CE using the application-provided storage path.
  ///
  /// Concurrent callers share the same initialization operation.
  /// A failed initialization can be retried by calling this method again.
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
    final path = await pathProvider.getStoragePath();

    Hive.init(path);
    adapterRegistry.registerAll();

    _initialized = true;
  }

  /// Flushes and closes every open box; storage must be re-initialized
  /// before further use.
  ///
  /// Called from the app lifecycle hook, never from a business module.
  Future<void> shutdown() async {
    if (!_initialized) return;

    await Hive.close();
    _initialization = null;
    _initialized = false;
  }
}
