import 'dart:io';

import 'package:live_platform/live_platform.dart';
import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/app/composition/sites.dart';
import 'package:pure_live/app/environment/app_paths.dart';
import 'package:pure_live/app/environment/env.dart';
import 'package:pure_live/app/environment/os_roots.dart';
import 'package:pure_live/app/logging/app_log.dart';
import 'package:pure_live/app/theme/appearance_store.dart';

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
    required this.sites,
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

  /// The network and site graph: the transport factory, the site HTTP
  /// client and every built-in site, initialized and ready.
  final AppSites sites;

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
    final data = await paths.location(StorageArea.data);
    // Logs live under the data area: a bug report's logs must survive a cache
    // clear, and the file sink's rotation caps the growth.
    log.attachFileSink(Directory('${data.path}/logs'));

    final storage = StorageBootstrap(
      pathProvider: StoragePathProvider(resolver: () async => data.path),
      adapterRegistry: StorageAdapterRegistry(),
    );
    await storage.initialize();

    final box = await StorageBoxManager().keyed<Map<dynamic, dynamic>>(AppearanceKeys.box);
    final appearance = AppearanceStore(repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box));
    await appearance.load();

    // Real files in two trees is a fact the user has to hear about, not
    // something to merge quietly.
    final storageLog = log.forCategory('storage');
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
    );

    return AppServices._(
      log: log,
      environment: environment,
      paths: paths,
      storage: storage,
      appearance: appearance,
      sites: sites,
    );
  }

  /// Flushes pending writes and closes storage, the sites and the log, in
  /// the reverse of the boot order: preferences first (its debounce still
  /// has work to do), then the boxes under it, then the sites and their
  /// pooled transports, the log last — it was opened first, and the
  /// teardown itself should be the last thing it records.
  Future<void> shutdown() async {
    await appearance.dispose();
    await storage.shutdown();
    await sites.dispose();
    await log.close();
  }
}
