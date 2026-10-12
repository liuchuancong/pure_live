import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:live_iptv/live_iptv.dart';
import 'package:live_library/live_library.dart';
import 'package:live_log/live_log.dart';
import 'package:live_net/live_net.dart';
import 'package:live_platform/live_platform.dart';
import 'package:live_preferences/live_preferences.dart';
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Everything the application runs on, built once at startup in dependency
/// order and handed down the tree.
///
/// The order is the point: the platform layer answers where things live
/// before anything writes, the log exists before the network so transport
/// failures have somewhere to go, the database exists before the preferences,
/// and the preferences exist before the first frame because the theme is
/// resolved from them. Nothing here is a global singleton — the composition
/// root owns the graph and passes it explicitly, so a second instance (a test
/// harness, a second window) cannot silently share one.
final class PureLiveServices {
  /// A built service graph; use [boot] to create one.
  const new({
    required this.log,
    required this.runtime,
    required this.preferences,
    required this.sites,
    required this.library,
    required this.history,
    required this.iptv,
    required this.iptvImporter,
    required this.iptvSync,
    required this.storage,
    required this.http,
  });

  /// The process log tree; every category hangs off it.
  final LiveLog log;

  /// The platform facts and the directory resolution.
  final PlatformRuntime runtime;

  /// The user's preferences, already loaded.
  final PreferencesService preferences;

  /// The live sites, keyed by id.
  final SiteRegistry sites;

  /// The followed rooms and their user metadata.
  final FollowRepository library;

  /// The watch history.
  final HistoryRepository history;

  /// The IPTV channel library.
  final IptvLibrary iptv;

  /// Imports and syncs IPTV playlists and programme guides.
  ///
  /// Every import goes through this rather than writing to [iptv] directly,
  /// because the rules that protect a user's library live here: a download
  /// cut off mid-file keeps the stored one, a name already in use is asked
  /// about, and two imports never interleave their writes.
  final IptvImporter iptvImporter;

  /// Refreshes what has gone stale, under the policy read from [preferences].
  final IptvSyncCoordinator iptvSync;

  /// The storage bootstrap; shutdown flushes and closes what it opened.
  final StorageBootstrap storage;

  /// The shared HTTP factory, so every package speaks through one pipeline.
  final DioFactory http;

  /// Boots the application.
  ///
  /// [declaredTvBuild] is the app shell's declaration that this build targets
  /// a TV (a launcher flag, a native bridge, a `--dart-define`); it is never
  /// inferred, because a phone misdetected as a TV would show a
  /// remote-control UI nobody can operate.
  static Future<PureLiveServices> boot({bool declaredTvBuild = false}) async {
    final runtime = await PlatformBootstrap.init(
      formFactor: declaredTvBuild ? FormFactor.tv : null,
      userDataDirectory: () => resolvePersistentDirectory(_dataDirectoryOverrideKey),
      cacheDirectory: resolveCacheDirectory,
    );

    // Logging first, so every later failure is reportable. The console sink
    // is the developer's view and the memory ring buffer is what a bug report
    // attaches; the rotating file sink joins them once the data directory is
    // known, because a read-only device must still log.
    final memory = MemorySink(capacity: 1000);
    // The developer console sink is the interactive view; the stdout sink
    // is the one a `flutter run` log and a portable build's terminal share.
    // `kDebugMode` is a getter, not a constant, so this choice cannot be
    // hoisted to a const.
    // ignore: prefer_const_declarations
    final console = kDebugMode ? const DeveloperConsoleSink() : const StdoutConsoleSink();

    final log = LiveLog.root(sinks: [SinkBinding(memory)], minLevel: LogLevel.debug);
    final appLog = log.forCategory('app');
    final logsDirectory = await _ensureDirectory(runtime.storage, StorageArea.data, child: 'logs');
    // Rotation keeps five files of 5 MiB: enough to cover a session's
    // worth of history without filling a phone's storage.
    final file = FileSink(Directory(logsDirectory));
    // Console and file join the ring buffer; a read-only device that cannot
    // write the file still logs to both of the others.
    log.replaceSink(memory, FanOutSink([console, memory, file]));

    // Storage first: Hive bound to the data directory, adapters
    // registered once, then every repository on top of it.
    final dataDirectory = await _ensureDirectory(runtime.storage, StorageArea.data);
    final storage = StorageBootstrap(
      pathProvider: StoragePathProvider(resolver: () async => dataDirectory),
      adapterRegistry: StorageAdapterRegistry(),
    );
    await storage.initialize();
    final boxes = StorageBoxManager();
    final preferences = PreferencesService(
      store: HiveStorageRepository<Map<dynamic, dynamic>>(box: await boxes.keyed(PreferencesKeys.box)),
      onError: (key, error, stack) => log
          .forCategory('app.preferences')
          .log(LogLevel.warning, '$key could not be stored', error: error, stackTrace: stack),
    );
    final report = await preferences.load();
    if (!report.isClean) {
      appLog.warning(
        'some preference documents were not loaded and keep their defaults',
        fields: {'undecoded': report.decodeFailures.join(',')},
      );
    }

    // The user's own data: followed rooms, history, IPTV channels — one
    // list repository per domain, written through the shared storage.
    final libraryStore = BoxLibraryStore(
      HiveStorageListRepository(box: await boxes.list<Map<dynamic, dynamic>>(LibraryKeys.table)),
    );
    final library = FollowRepository(libraryStore);
    final history = HistoryRepository(libraryStore, capacity: preferences.value.library.historyLimit);
    final iptv = IptvLibrary(
      BoxIptvStore(HiveStorageListRepository(box: await boxes.list<Map<dynamic, dynamic>>(IptvKeys.table))),
    );
    await library.load();
    await history.load();
    await iptv.load();

    // The network, then the sites on top of it — including the IPTV site,
    // which reads the channel library rather than a platform.
    final http = DioFactory(log: log.forCategory('live_net'));
    final sites = SiteRegistry(
      factories: defaultSiteFactories(http.create(), iptvSource: LibraryIptvChannelSource(iptv)),
    );

    // Playlist and guide downloads ride the media profile on purpose: it
    // never caches, so "sync now" re-reads the address instead of being
    // served the copy the interceptor kept, which is the one thing a manual
    // refresh must never do.
    final fetchHttp = http.create(profile: ClientProfile.media);
    final iptvImporter = IptvImporter(
      library: iptv,
      fetch: iptvFetcherFor(fetchHttp),
      fetchBytes: iptvBytesFetcherFor(fetchHttp),
    );
    final iptvSync = IptvSyncCoordinator(importer: iptvImporter);

    return PureLiveServices(
      log: log,
      runtime: runtime,
      preferences: preferences,
      sites: sites,
      library: library,
      history: history,
      iptv: iptv,
      iptvImporter: iptvImporter,
      iptvSync: iptvSync,
      storage: storage,
      http: http,
    );
  }

  /// Refreshes the stale playlists and guides the settings allow, and answers
  /// what the round did.
  ///
  /// Call it at start-up and again on returning to the foreground; a second
  /// call while a round is in flight joins that one rather than starting a
  /// parallel download of the same list.
  ///
  /// [force] ignores the two switches that turn automatic refresh off — the
  /// viewer asked for it, so the settings that say "never" are about
  /// unattended rounds, not this one — while keeping the intervals, which
  /// still decide what counts as stale enough to re-read.
  Future<IptvSyncReport> syncIptv({bool force = false}) {
    final settings = preferences.value.iptv;
    return iptvSync.syncDue(
      IptvSyncPolicy(
        playlistInterval: settings.playlistSyncInterval,
        guideInterval: settings.guideSyncInterval,
        playlists: force || settings.autoSyncPlaylists,
        guides: force || settings.autoSyncGuides,
      ),
    );
  }

  /// Flushes and closes everything, in reverse order of construction.
  ///
  /// Called from the app's lifecycle hook, not from a widget's dispose: the
  /// preference write and the storage close must both finish before the
  /// process exits, or the last change is lost.
  Future<void> shutdown() async {
    await preferences.dispose();
    await library.dispose();
    await history.dispose();
    await iptv.dispose();
    await storage.shutdown();
  }

  /// The environment variable a portable or diagnostic run sets to keep its
  /// data tree somewhere of its choosing.
  static const String _dataDirectoryOverrideKey = 'PURE_LIVE_DATA_DIR';

  /// Resolves the directory durable data lives in.
  ///
  /// The chain, in order: an explicit environment override (portable and
  /// diagnostic runs), the OS application-support directory, then the
  /// documents directory. The *cache* directory is deliberately not in the
  /// chain: the storage policy forbids keeping persistent data in a
  /// clearable area, so a build that cannot find a persistent root must fail
  /// loudly rather than lose the user's settings at the next cleanup — which
  /// is why a failure here propagates and the app shows a boot error instead
  /// of starting with settings it cannot keep.
  static Future<Directory?> resolvePersistentDirectory(String overrideKey) async {
    final override = Platform.environment[overrideKey];
    if (override != null && override.trim().isNotEmpty) {
      return Directory(override)..createSync(recursive: true);
    }
    for (final resolve in <Future<Directory> Function()>[
      getApplicationSupportDirectory,
      getApplicationDocumentsDirectory,
    ]) {
      try {
        return await resolve();
      } on Object {
        // Try the next candidate; the error is reported by the caller when
        // every candidate failed.
        continue;
      }
    }
    return null;
  }

  /// Resolves the directory re-fetchable data lives in; the cache area may
  /// degrade, so this one is allowed to come back null.
  static Future<Directory?> resolveCacheDirectory() async {
    try {
      return await getApplicationCacheDirectory();
    } on Object {
      return null;
    }
  }

  static Future<String> _ensureDirectory(StorageManager storage, StorageArea area, {String? child}) async {
    final location = await storage.resolve(area);
    final path = child == null ? location.path : p.join(location.path, child);
    final directory = Directory(path);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return path;
  }
}
