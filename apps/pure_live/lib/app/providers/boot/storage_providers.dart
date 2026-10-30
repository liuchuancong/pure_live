import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pure_live/app/providers/settings/storage_folder_provider.dart'
    show AppFolders, StorageFolder, StorageFolderOverrides;
import 'package:pure_live/infrastructure/infrastructure.dart';

/// The resolved storage layout (data / config / cache), from the
/// deployment facts; only the bootstrap can produce one, so `main`
/// overrides this.
final storagePathsProvider = Provider<StoragePaths>(
  (ref) => throw UnimplementedError('storagePathsProvider must be overridden at boot'),
);

/// The viewer's chosen folders; every reader goes through [appPathsProvider],
/// which lays this over the device defaults.
final storageFolderOverridesProvider =
    NotifierProvider<StorageFolderOverrides, Map<StorageFolder, String>>(StorageFolderOverrides.new);

/// The named folders the app writes: the storage layout's defaults with the
/// viewer's choices on top, so a subsystem asks one vocabulary instead of
/// joining segments — or remembering a preference — itself.
final appPathsProvider = Provider<AppFolders>(
  (ref) => AppFolders(AppPaths(ref.watch(storagePathsProvider)), ref.watch(storageFolderOverridesProvider)),
);
