import 'package:live_storage/live_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pure_live/user_data/preferences/preferences.dart' show PreferencesKeys, PreferencesService;

/// The application's storage + preferences composition root.
///
/// It initialises Hive (through `live_storage`'s bootstrap), opens the single
/// preferences box and hands the app a loaded [PreferencesService]. Nothing here
/// is a business decision — it is only the wiring that turns the packages into a
/// running app. The live-site registry is wired in once platform adapters are
/// ported to `live_sites`' capability/`Either` contract (none are yet).
final class AppServices {
  /// Wraps the loaded [preferences] over the `bootstrap` that backs them.
  // ignore: unnecessary_type_name_in_constructor
  const AppServices._(this.preferences, this._bootstrap);

  /// The user's preferences, already loaded from disk.
  final PreferencesService preferences;

  final StorageBootstrap _bootstrap;

  /// Boots storage and loads preferences, for the app's start-up.
  static Future<AppServices> boot() async {
    final bootstrap = StorageBootstrap(
      pathProvider: StoragePathProvider(resolver: () async => (await getApplicationSupportDirectory()).path),
      adapterRegistry: StorageAdapterRegistry(),
    );
    await bootstrap.initialize();
    await StoragePrefs.init();

    final box = await StorageBoxManager().keyed<Map<dynamic, dynamic>>(PreferencesKeys.box);
    final preferences = PreferencesService(store: HiveStorageRepository<Map<dynamic, dynamic>>(box: box));
    await preferences.load();

    return AppServices._(preferences, bootstrap);
  }

  /// Flushes pending writes and closes storage, for tear-down.
  Future<void> dispose() async {
    await preferences.dispose();
    await StoragePrefs.flush();
    await _bootstrap.shutdown();
  }
}
