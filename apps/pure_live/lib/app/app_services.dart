import 'package:live_log/live_log.dart' show LiveLog;
import 'package:live_platform/live_platform.dart' show PlatformRuntime;
import 'package:live_platform_path_provider/live_platform_path_provider.dart'
    show PathProviderBootstrap, StorageArea, StorageManager;
import 'package:live_storage/live_storage.dart'
    show HiveStorageRepository, StorageAdapterRegistry, StorageBootstrap, StorageBoxManager, StoragePathProvider;
import 'package:path_provider/path_provider.dart'
    show getApplicationCacheDirectory, getApplicationSupportDirectory, getDownloadsDirectory, getTemporaryDirectory;

import 'package:pure_live/app/composition/app_sites.dart' show AppSites;
import 'package:pure_live/app/configuration/app_preferences.dart' show AppearanceKeys, AppearanceStore;

/// The services the app runs on, in the order they depend on each other.
///
/// Nothing here is a business decision; it is only the wiring that turns
/// the packages into a running app. The order carries the meaning —
///
/// 1. the directory layout, because the deployment style decides where a
///    portable build may write and an installed one must;
/// 2. storage, whose boxes live inside the resolved data area;
/// 3. the preference documents, every one loaded before this returns, so
///    the first frame is drawn in the viewer's own theme and language;
/// 4. the network and site graph, last because everything before it
///    decided where data lives.
final class AppServices {
  new _({required this.paths, required this.storage, required this.appearance, required this.sites});

  /// Directory resolution for every storage area.
  final StorageManager paths;

  /// The opened storage layer, held so shutdown can close it in order.
  final StorageBootstrap storage;

  /// The appearance document (theme mode, accent, language), loaded.
  final AppearanceStore appearance;

  /// The network and site graph, initialized and ready.
  final AppSites sites;

  /// Boots the layout, storage, the documents and the site graph.
  static Future<AppServices> boot({required LiveLog log, required PlatformRuntime runtime}) async {
    final bootLog = log.forCategory('boot');
    final pathRuntime = await PathProviderBootstrap.init(
      environment: runtime.environment,
      userDataDirectory: getApplicationSupportDirectory,
      cacheDirectory: getApplicationCacheDirectory,
      temporaryDirectory: getTemporaryDirectory,
      downloadsDirectory: getDownloadsDirectory,
    );
    final paths = pathRuntime.storage;
    final dataDirectory = await paths.resolve(StorageArea.data);
    bootLog.info('data area resolved', fields: {'path': dataDirectory.path});

    final storage = StorageBootstrap(
      pathProvider: StoragePathProvider(resolver: () async => dataDirectory.path),
      adapterRegistry: StorageAdapterRegistry(),
    );
    await storage.initialize();

    final box = await StorageBoxManager().keyed<Map<dynamic, dynamic>>(AppearanceKeys.box);
    final storageLog = log.forCategory('storage');
    final appearance = AppearanceStore(
      repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box),
      onError: (failure, error, stack) =>
          storageLog.warning('appearance document ${failure.name} failed', fields: {'error': '$error'}),
    );
    await appearance.load();

    final sites = await AppSites.boot(
      log: log,
      kind: runtime.environment.runtime.kind,
      formFactor: runtime.environment.runtime.formFactor,
    );
    return AppServices._(paths: paths, storage: storage, appearance: appearance, sites: sites);
  }
}
