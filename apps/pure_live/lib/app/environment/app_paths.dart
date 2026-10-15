import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:live_platform/live_platform.dart' show PlatformEnvironment, PlatformRuntimeInfo;
import 'package:live_platform_path_provider/live_platform_path_provider.dart';
import 'package:path/path.dart' as p;

import 'package:pure_live/app/environment/os_roots.dart';
import 'package:pure_live/app/environment/user_path_choices/user_path_choices.dart';

/// The name of the file that records the user's own directories.
const String _choicesFile = 'storage_paths.json';

/// The name of the file that records where the pinned trees actually
/// resolved at boot — the bookkeeping the next start needs in order to
/// carry a moved data tree over.
const String _journalFile = 'resolved_layout.json';

/// The journal's format version; a file this code cannot understand reads
/// as no journal, which only costs one redundant (and harmless) carry.
const int _journalSchemaVersion = 1;

/// The app's directory layout: what the operating system offers, what the
/// build decides, and what the user chose — in that order of precedence.
///
/// Business code asks for a [StorageArea] and gets a [StorageLocation]; it
/// never assembles a path and never learns which of the three layers answered.
/// The layering lives in [AppStoragePolicy], handed to `PathProviderBootstrap`
/// as the app's own policy, so the distribution rules stay where they belong: a
/// portable build keeps its data next to the executable and never in the user's
/// app-data tree, an installed or MSIX build does exactly the opposite.
///
/// The choices are persisted in the *default* config directory, deliberately
/// resolved without consulting them: the file that says where the moved folders
/// are has to be findable before any move is known.
final class AppPaths {
  /// The layout as measured on this device.
  // A private aggregate: only [boot] measures one, since the anchor file has
  // to be read before the layout can exist.
  // ignore: unnecessary_type_name_in_constructor
  AppPaths._({
    required this.environment,
    required this.roots,
    required this.storage,
    required this.policy,
    required this.choices,
    required this._anchorFile,
    this.dataAdoption,
  });

  /// The platform facts this layout was built on.
  final PlatformEnvironment environment;

  /// The operating-system roots the layout was measured from.
  final OsRoots roots;

  /// The manager every area resolves through.
  final StorageManager storage;

  /// The policy in force — inspected by the path-management screen to show
  /// what the app itself would have chosen.
  final AppStoragePolicy policy;

  /// The directories the user moved, as loaded at boot and kept current by
  /// [choose] and [restore].
  UserPathChoices choices;

  final File? _anchorFile;
  Future<void> _persistChain = Future<void>.value();

  /// The data tree this boot carried over from the previous layout, null on
  /// an unchanged layout. A report with [AdoptionReport.blocked] entries
  /// means both trees held a name — the leftovers stay where they were and
  /// the carry retries on the next start once the collision is gone.
  final AdoptionReport? dataAdoption;

  /// Measures the layout for [environment] on this device.
  ///
  /// [buildDataRoot] is `PURE_LIVE_DATA_DIR`: a build that pins the whole data
  /// tree somewhere else — a diagnostic run that must not touch the installed
  /// app's files. It outranks the user's own choice for that area, and the
  /// screen has to say so rather than offer a restore that changes nothing.
  ///
  /// A choices file that cannot be read is not a reason to refuse to start:
  /// every area falls back to its default for this run and the failure is
  /// reported through [onError]; the unreadable bytes are left alone rather
  /// than overwritten by silence.
  static Future<AppPaths> boot({
    required PlatformEnvironment environment,
    required OsRoots roots,
    String? buildDataRoot,
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    final runtime = environment.runtime;
    final anchorDirectory = AppStoragePolicy.defaults(
      runtime,
      roots,
    ).candidatesFor(StorageArea.config, runtime).firstOrNull;
    final anchorFile = anchorDirectory == null ? null : File('${anchorDirectory.path}/$_choicesFile');
    final choices = await _readChoices(anchorFile, onError: onError);
    // A relative `PURE_LIVE_DATA_DIR` (`.run-data`) means "next to where
    // this process was started"; pinning it absolute once here keeps every
    // later resolution off the drifting process working directory.
    final pinnedDataRoot = buildDataRoot == null ? null : p.absolute(buildDataRoot);
    final policy = AppStoragePolicy(runtime: runtime, roots: roots, choices: choices, buildDataRoot: pinnedDataRoot);
    final storage = (await PathProviderBootstrap.init(environment: environment, policy: policy)).storage;

    // The journal lives beside the anchor file — the default config
    // directory, deliberately untouched by the user's own choices — and
    // records where the pinned data tree actually lived. A build-pinned
    // data root is bookkeeping-free by design: a diagnostic run must
    // neither adopt the real installation's tree into `.run-data` nor
    // plant a journal that would drag diagnostic files back into the real
    // tree on the next normal start.
    final journal = anchorDirectory == null || policy.isBuildFixed(StorageArea.data)
        ? null
        : File('${anchorDirectory.path}/$_journalFile');
    final dataLocation = await storage.resolve(StorageArea.data);
    final adoption = await _adoptDataTree(journal: journal, current: dataLocation, onError: onError);

    return AppPaths._(
      environment: environment,
      roots: roots,
      storage: storage,
      policy: policy,
      choices: choices,
      anchorFile: anchorFile,
      dataAdoption: adoption,
    );
  }

  /// The writable location of [area]: the user's own directory when they moved
  /// it, otherwise the app default for this build.
  Future<StorageLocation> location(StorageArea area) => storage.resolve(area);

  /// The directory this app would use for [area] had the user never moved
  /// anything — the screen's "应用默认路径", and what [restore] returns to.
  ///
  /// Probed rather than guessed: a default the device cannot write is reported
  /// as null instead of being offered as a choice.
  Future<StorageLocation?> defaultLocation(StorageArea area) async {
    for (final candidate in policy.defaultCandidatesFor(area)) {
      if (await _writable(candidate)) {
        return StorageLocation(
          area: area,
          path: candidate.path,
          isPersistent: area.isPersistent,
          accessState: AccessState.writable,
          isPrivate: PathPrivacy.isPrivate(candidate.path, kind: environment.runtime.kind),
        );
      }
    }
    return null;
  }

  /// The directory the user chose for [area], null when they never moved it.
  String? customDirectory(StorageArea area) => choices.pathFor(area.name);

  /// Whether [area] answers to the build's own data root instead of to the
  /// user, so the screen can explain that rather than offer a restore with no
  /// effect.
  bool isFixedByBuild(StorageArea area) => policy.isBuildFixed(area);

  /// Records [directory] as the user's choice for [area] and re-resolves it.
  ///
  /// The choice is durable before it is handed back — a setting the user
  /// confirmed must survive the process — so a failed write throws instead of
  /// answering with a path that will not be there next start-up.
  ///
  /// Fresh [location] asks answer with the new directory right away — the
  /// lazy areas (downloads, exports) and the data area alike. Writers that
  /// captured their directory at boot (the storage layer, the log sink)
  /// keep writing where this boot pinned them, and the *next* start carries
  /// that tree over to the new directory (see [dataAdoption]) before
  /// storage opens, so nothing written in between is lost.
  Future<void> choose(StorageArea area, Directory directory) async {
    if (isFixedByBuild(area)) {
      throw StateError('${area.name} is pinned by this build (PURE_LIVE_DATA_DIR) and cannot be moved.');
    }
    await _apply(choices.withPath(area.name, directory.absolute.path), area);
  }

  /// Returns [area] to the app's default and re-resolves it.
  Future<void> restore(StorageArea area) => _apply(choices.without(area.name), area);

  /// Returns every movable area to its default.
  ///
  /// Each area that was moved is re-resolved afterwards: the storage manager
  /// keeps a location it has already probed, so clearing the record without
  /// invalidating it would leave the screen saying "default" while the app
  /// still wrote into the folder the user walked away from.
  Future<void> restoreAll() async {
    final moved = [for (final id in choices.customByArea.keys) _areaByName(id)].whereType<StorageArea>();
    await _apply(const UserPathChoices(), null);
    for (final area in moved) {
      await storage.revalidate(area);
    }
  }

  /// The same app's data found in two trees — an installed layout and a
  /// portable one, left behind by the other build of this app on this machine.
  ///
  /// A build only ever reads the tree its own deployment style resolves to, so
  /// a second populated tree is not a tidiness problem: the user sees two
  /// histories and two sets of recordings, and neither is the one they are
  /// looking at. This answers with what the start-up diagnostics must show —
  /// never a silent merge, and null when there is nothing to report.
  Future<StorageConflictReport?> detectSplitBrain() async {
    final runtime = environment.runtime;
    final preferred = await location(StorageArea.data);
    final legacy = runtime.isPortable
        ? switch (roots.userRoot) {
            final Directory root? => '${root.path}/data',
            _ => null,
          }
        // The portable tree at this same location is namespaced one segment
        // deeper than the Flutter runtime's own `data/` bundle — it is the
        // policy's `data/pure_live` candidate, never `data/` itself.
        : '${runtime.executableRoot.path}/data/pure_live';
    if (legacy == null || legacy == preferred.path) {
      return null;
    }
    final report = await StorageConflicts.inspect(preferred: Directory(preferred.path), legacy: Directory(legacy));
    return report.hasConflict ? report : null;
  }

  Future<void> _apply(UserPathChoices fresh, StorageArea? invalidated) async {
    choices = fresh;
    policy.choices = fresh;
    _persistChain = _persistChain.then((_) async {
      final file = _anchorFile;
      if (file == null) {
        throw const StorageUnavailableException('no writable config directory to record path choices in');
      }
      await AtomicFileWriter.writeString(file, const JsonEncoder.withIndent('  ').convert(fresh.toJson()));
    });
    await _persistChain;
    if (invalidated != null) {
      await storage.revalidate(invalidated);
    }
  }

  static Future<UserPathChoices> _readChoices(
    File? file, {
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    if (file == null || !file.existsSync()) {
      return const UserPathChoices();
    }
    try {
      return UserPathChoices.fromJson(Map<String, Object?>.from(jsonDecode(await file.readAsString()) as Map));
    } on Object catch (error, stack) {
      onError?.call(error, stack);
      return const UserPathChoices();
    }
  }

  /// Carries the previous boot's data tree into [current] and refreshes the
  /// journal.
  ///
  /// The journal is written only once the carry is complete (or there was
  /// nothing to carry): a carry blocked by a collision leaves the journal
  /// pointing at the old tree, so the next start retries the leftovers.
  /// Every failure here is reported, never raised — an unreadable or
  /// unwritable journal only costs one redundant carry, and a carry itself
  /// reports its per-entry outcome.
  static Future<AdoptionReport?> _adoptDataTree({
    required File? journal,
    required StorageLocation current,
    void Function(Object error, StackTrace stack)? onError,
  }) async {
    if (journal == null) {
      return null;
    }
    final previous = _readJournal(journal, onError);
    if (previous == null || p.equals(previous, current.path)) {
      await _writeJournal(journal, current.path, onError);
      return null;
    }
    final report = await StorageAdoption.carry(from: Directory(previous), to: Directory(current.path));
    if (report == null || report.isComplete) {
      await _writeJournal(journal, current.path, onError);
    }
    return report != null && report.moved.isEmpty && report.blocked.isEmpty ? null : report;
  }

  static String? _readJournal(File file, void Function(Object error, StackTrace stack)? onError) {
    if (!file.existsSync()) {
      return null;
    }
    try {
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map || decoded['schemaVersion'] != _journalSchemaVersion || decoded['dataPath'] is! String) {
        return null;
      }
      final path = decoded['dataPath'] as String;
      return path.isEmpty ? null : path;
    } on Object catch (error, stack) {
      onError?.call(error, stack);
      return null;
    }
  }

  static Future<void> _writeJournal(File file, String dataPath, void Function(Object, StackTrace)? onError) async {
    try {
      await AtomicFileWriter.writeString(
        file,
        const JsonEncoder.withIndent('  ').convert({'schemaVersion': _journalSchemaVersion, 'dataPath': dataPath}),
      );
    } on Object catch (error, stack) {
      onError?.call(error, stack);
    }
  }

  /// Per-process counter keeping concurrent probes out of each other's way —
  /// a timestamp alone is not unique, two probes inside one microsecond
  /// claimed the same file name once already (see `AtomicFileWriter`).
  static int _probeSequence = 0;

  static Future<bool> _writable(Directory directory) async {
    try {
      await directory.create(recursive: true);
      final probe = File('${directory.path}/.pure_live_probe_${pid}_${++_probeSequence}');
      await probe.writeAsBytes(const [0], flush: true);
      await probe.delete();
      return true;
    } on Object {
      return false;
    }
  }
}

/// The three-layer candidate list the app runs on.
///
/// `live_platform_path_provider` decides where an area may live from the
/// deployment facts; this only puts the user's override — and a build-pinned
/// data root — in front of the package's own candidates, so an unwriteable
/// choice degrades to the default instead of failing the area outright.
final class AppStoragePolicy implements StoragePolicy {
  /// A policy over [roots], the persisted [choices] and a build-pinned data
  /// root.
  new({required PlatformRuntimeInfo runtime, required this.roots, required this.choices, this.buildDataRoot})
    : _runtime = runtime,
      _defaults = defaults(runtime, roots);

  /// The package's own answer for this device: the executable tree when the
  /// build is portable, the OS directories when it is installed.
  static DefaultStoragePolicy defaults(PlatformRuntimeInfo runtime, OsRoots roots) => DefaultStoragePolicy(
    portableRoot: runtime.executableRoot,
    userRoot: roots.userRoot,
    cacheRoot: roots.cacheRoot,
    tempRoot: roots.temporaryRoot,
    downloadsRoot: roots.downloadsRoot,
  );

  /// The operating-system roots behind the defaults.
  final OsRoots roots;

  /// The directories the user moved; swappable so a change takes effect on the
  /// next resolution without rebuilding the layout.
  UserPathChoices choices;

  /// The build-pinned data root, `PURE_LIVE_DATA_DIR`.
  final String? buildDataRoot;

  final PlatformRuntimeInfo _runtime;
  final DefaultStoragePolicy _defaults;

  @override
  List<Directory> candidatesFor(StorageArea area, PlatformRuntimeInfo runtime) => [
    if (buildDataRoot case final root? when area == StorageArea.data) Directory(root),
    if (choices.pathFor(area.name) case final path?) Directory(path),
    ...defaultCandidatesFor(area),
  ];

  /// The candidates with no user choice and no build override: the app default
  /// for [area], first.
  List<Directory> defaultCandidatesFor(StorageArea area) => _defaults.candidatesFor(area, _runtime);

  /// Whether [area] answers to the build rather than to the user.
  bool isBuildFixed(StorageArea area) => area == StorageArea.data && buildDataRoot != null;
}

/// Which areas the app may lose without breaking anything.
///
/// The package keeps this table to itself (it decides `isPersistent` while
/// probing), so the app's own answer for a location it builds by hand has to
/// agree with it: only the two clearable areas are disposable.
extension on StorageArea {
  bool get isPersistent => this != StorageArea.cache && this != StorageArea.temporary;
}

/// The area an id names, null for one this build no longer ships.
///
/// A stored id that no longer resolves is not an error to fix by deleting it:
/// the choice stays in the file so a downgrade-and-upgrade round trip does not
/// silently move someone's recordings back onto the system drive.
StorageArea? _areaByName(String id) {
  for (final area in StorageArea.values) {
    if (area.name == id) {
      return area;
    }
  }
  return null;
}
