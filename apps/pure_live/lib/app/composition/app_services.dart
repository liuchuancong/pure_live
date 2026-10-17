import 'package:live_iptv/live_iptv.dart';
import 'package:live_library/live_library.dart';
import 'package:live_platform/live_platform.dart';
import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/app/composition/sites.dart';
import 'package:pure_live/app/environment/app_directory.dart';
import 'package:pure_live/app/environment/app_paths.dart';
import 'package:pure_live/app/environment/env.dart';
import 'package:pure_live/app/environment/os_roots.dart';
import 'package:pure_live/app/fonts/font_library.dart';
import 'package:pure_live/app/logging/app_log.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/app/theme/appearance_store.dart';
import 'package:pure_live/features/iptv/iptv_preferences.dart';
import 'package:pure_live/features/multiview/multiview_preferences.dart';
import 'package:pure_live/platforms/desktop/shell/shell_preferences.dart';

/// The services the app runs on, in the order they depend on each other.
///
/// Nothing here is a business decision: it is only the wiring that turns the
/// packages into a running app. The order carries the meaning —
///
/// 1. the operating system's roots, because the platform bootstrap needs a
///    writable home for its inferred distribution claim and cannot use the
///    install tree for that;
/// 2. the platform facts, because the layout is decided by the deployment
///    style: a portable build keeps its data beside the executable and never in
///    the user's app-data tree, an installed or packaged build does exactly the
///    opposite;
/// 3. the layout, which folds in whatever directories the user moved;
/// 4. the log's rotating file sink, which lands under the resolved data area —
///    everything the boot emitted before this point already reached the
///    console and the ring buffer;
/// 5. storage, whose boxes live inside the resolved data area;
/// 6. the documents, every one loaded before [boot] returns, so the first frame
///    is drawn in the user's own theme instead of the default and a repaint;
/// 7. the network and site graph, the last step because everything before it
///    decided where data lives and how the process presents itself — exactly
///    what the sites adapt to.
final class AppServices {
  // A private aggregate: only [boot] can build one, since it is the only
  // thing that knows the order.
  // ignore: unnecessary_type_name_in_constructor
  const AppServices._({
    required this.log,
    required this.environment,
    required this.paths,
    required this.storage,
    required this.appearance,
    required this.shell,
    required this.appPreferences,
    required this.sites,
    required this.followRepository,
    required this.historyRepository,
    required this.iptvLibrary,
    required this.iptvPreferences,
    required this.multiviewPreferences,
    required this.fontLibrary,
  });

  /// The process log, opened before anything here and closed after
  /// everything.
  final AppLog log;

  /// What this process runs on: OS family, form factor, deployment style and
  /// the capabilities that follow from them.
  final PlatformEnvironment environment;

  /// The app's directory layout, including the areas the user moved.
  ///
  /// Every file the app opens asks this for a [StorageArea]; no module
  /// assembles a path of its own. The settings screen that shows each area's
  /// app default, its current answer and the restore button reads it too.
  final AppPaths paths;

  /// The opened storage layer, held so shutdown can close it in order.
  final StorageBootstrap storage;

  /// The user's appearance, already loaded from disk.
  final AppearanceStore appearance;

  /// The desktop shell's choices (title bar mode, remembered close action),
  /// already loaded from disk.
  final ShellPreferencesStore shell;

  /// The app's general choices (refresh, launch, proxy, loading, room card),
  /// already loaded from disk.
  final AppPreferencesStore appPreferences;

  /// The network and site graph: the transport factory, the site HTTP
  /// client and every built-in site, initialized and ready.
  final AppSites sites;

  /// The user's followed rooms and their groups.
  final FollowRepository followRepository;

  /// The user's watch history.
  final HistoryRepository historyRepository;

  /// The IPTV library (imported playlists and their channels).
  final IptvLibrary iptvLibrary;

  /// The IPTV viewer's persisted choices (last channel, group, favourites
  /// filter), already loaded from disk.
  final IptvPreferencesStore iptvPreferences;

  /// The multi-view wall's persisted layout, already loaded from disk.
  final MultiviewPreferencesStore multiviewPreferences;

  /// The cloud font library: manifest, downloads and registration.
  final FontLibrary fontLibrary;

  /// Boots the layout, storage and the documents every screen needs at once.
  ///
  /// A store whose document cannot be read or decoded keeps its defaults and
  /// reports the failure rather than failing the start-up.
  static Future<AppServices> boot({required AppLog log}) async {
    final roots = await OsRoots.measure();
    // The app-support directory is where the inferred distribution claim gets
    // cached: writable on every deployment style, including one whose install
    // tree is read-only.
    final environment = Env.isTv
        ? PlatformBootstrap.init(claimDirectory: roots.userRoot, formFactor: FormFactor.tv).environment
        : PlatformBootstrap.init(claimDirectory: roots.userRoot).environment;

    final paths = await AppPaths.boot(
      environment: environment,
      roots: roots,
      // `PURE_LIVE_DATA_DIR` pins the whole data tree elsewhere, outranking any
      // directory the user moved. The value is baked in per build, so an
      // analysis that sees null here only proves this machine left it unset.
      // ignore: avoid_redundant_argument_values
      buildDataRoot: Env.dataDir,
    );
    // The data tree is the cold kind: its writers hold open files where boot
    // resolved them, so the two roots below capture this boot's answer once
    // rather than re-asking — a mid-session move lands on the next start,
    // when boot carries the old tree over before anything opens it.
    final dataDirectory = await paths.directory(AppDirectory.data);
    // Logs live under the data area: a bug report's logs must survive a cache
    // clear, and the file sink's rotation caps the growth.
    log.attachFileSink(await paths.directory(AppDirectory.logs));

    final storage = StorageBootstrap(
      pathProvider: StoragePathProvider(resolver: () async => dataDirectory.path),
      adapterRegistry: StorageAdapterRegistry(),
    );
    await storage.initialize();

    final box = await StorageBoxManager().keyed<Map<dynamic, dynamic>>(AppearanceKeys.box);
    final storageLog = log.forCategory('storage');
    final shellLog = log.forCategory('shell');
    final appearance = AppearanceStore(
      repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box),
      onError: (failure, error, stack) =>
          storageLog.warning('appearance document ${failure.name} failed', fields: {'error': '$error'}),
    );
    await appearance.load();

    // The library (follows, groups, watch history) owns one list box; its
    // repositories watch the box, so a second window stays in step.
    final libraryBox = await StorageBoxManager().list<Map<dynamic, dynamic>>('library');
    final libraryStore = BoxLibraryStore(HiveStorageListRepository<Map<dynamic, dynamic>>(box: libraryBox));
    final followRepository = FollowRepository(libraryStore);
    await followRepository.load();
    final historyRepository = HistoryRepository(libraryStore);
    await historyRepository.load();

    // The IPTV library owns its own list box, the same second-window rule.
    final iptvBox = await StorageBoxManager().list<Map<dynamic, dynamic>>('iptv');
    final iptvLibrary = IptvLibrary(BoxIptvStore(HiveStorageListRepository<Map<dynamic, dynamic>>(box: iptvBox)));
    await iptvLibrary.load();
    // The shell document lives in the same box under its own key: one open,
    // one document per preference group.
    final shell = ShellPreferencesStore(
      repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box),
      onError: (failure, error, stack) =>
          shellLog.warning('shell document ${failure.name} failed', fields: {'error': '$error'}),
    );
    await shell.load();

    // The IPTV and multi-view documents live in the same box under their own
    // keys: one open, one document per preference group.
    final iptvPreferences = IptvPreferencesStore(
      repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box),
      onError: (failure, error, stack) =>
          storageLog.warning('iptv document ${failure.name} failed', fields: {'error': '$error'}),
    );
    await iptvPreferences.load();
    final multiviewPreferences = MultiviewPreferencesStore(
      repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box),
      onError: (failure, error, stack) =>
          storageLog.warning('multiview document ${failure.name} failed', fields: {'error': '$error'}),
    );
    await multiviewPreferences.load();
    // The general-preferences document lives in the same box under its own
    // key. It loads before the sites because its proxy answer is one of the
    // things the site graph adapts to.
    final appPreferences = AppPreferencesStore(
      repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box),
      onError: (failure, error, stack) =>
          storageLog.warning('app preferences document ${failure.name} failed', fields: {'error': '$error'}),
    );
    await appPreferences.load();

    // Real files in two trees is a fact the user has to hear about, not
    // something to merge quietly.
    final conflict = await paths.detectSplitBrain();
    if (conflict != null) {
      storageLog.warning(
        '${conflict.conflicts.length} files exist in both trees',
        fields: {'preferred': conflict.preferred.path, 'legacy': conflict.legacy.path, 'files': conflict.conflicts},
      );
    }
    final adoption = paths.dataAdoption;
    if (adoption != null) {
      storageLog.info(
        'carried the previous data tree over',
        fields: {
          'from': adoption.from.path,
          'to': adoption.to.path,
          'moved': adoption.moved,
          if (adoption.blocked.isNotEmpty) 'blocked': adoption.blocked,
        },
      );
    }

    // The network and site graph is the last boot step: everything before it
    // decided where data lives and how the process presents itself, which is
    // exactly what the sites adapt to.
    final sites = await AppSites.boot(
      log: log.root,
      // `PURE_LIVE_PROXY` is baked in per build; an analysis that sees null
      // here only proves this machine left it unset.
      // ignore: avoid_redundant_argument_values
      proxy: Env.proxy,
      kind: environment.runtime.kind,
      formFactor: environment.runtime.formFactor,
      // The user's network-proxy preference wraps the boot's own route
      // decision: while it is disabled the requests fall through to the
      // build-time or system route, so the shipped behaviour is unchanged.
      proxyPolicyBuilder: (fallback) => PreferenceProxyPolicy(store: appPreferences, fallback: fallback),
    );

    // The font library downloads and registers through the shared client.
    final fontLibrary = FontLibrary(
      root: await paths.directory(AppDirectory.fonts),
      http: sites.http,
      commit: kFontCommit,
    );
    await fontLibrary.registerDownloaded();

    return AppServices._(
      log: log,
      environment: environment,
      paths: paths,
      storage: storage,
      appearance: appearance,
      shell: shell,
      appPreferences: appPreferences,
      sites: sites,
      followRepository: followRepository,
      historyRepository: historyRepository,
      iptvLibrary: iptvLibrary,
      iptvPreferences: iptvPreferences,
      multiviewPreferences: multiviewPreferences,
      fontLibrary: fontLibrary,
    );
  }

  /// Flushes pending writes and closes storage, the sites and the log, in
  /// the reverse of the boot order: preferences first (its debounce still
  /// has work to do), then the boxes under it, then the sites and their
  /// pooled transports, the log last — it was opened first, and the
  /// teardown itself should be the last thing it records.
  Future<void> shutdown() async {
    await appPreferences.dispose();
    await appearance.dispose();
    await shell.dispose();
    await iptvPreferences.dispose();
    await multiviewPreferences.dispose();
    await storage.shutdown();
    await followRepository.dispose();
    await historyRepository.dispose();
    await iptvLibrary.dispose();
    await sites.dispose();
    await log.close();
  }
}
