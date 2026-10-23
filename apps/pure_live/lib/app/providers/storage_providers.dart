import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/infrastructure/storage/storage_paths.dart' show StoragePaths;

/// The resolved storage layout (data / config / cache), from the
/// deployment facts; only the bootstrap can produce one, so `main`
/// overrides this.
final storagePathsProvider = Provider<StoragePaths>(
  (ref) => throw UnimplementedError('storagePathsProvider must be overridden at boot'),
);
