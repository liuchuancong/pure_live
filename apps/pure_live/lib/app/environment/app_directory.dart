import 'package:live_platform_path_provider/live_platform_path_provider.dart';

/// Every named tree the app writes, defined once.
///
/// Business code asks `AppPaths.directory` for one of these names and never
/// concatenates a path of its own: which area backs a name, and which
/// segment names it under that area, is decided here and only here. A new
/// tree is one entry — every consumer, screen row and diagnostic reads the
/// same table.
///
/// The split the enum carries is the one the user feels: names over the
/// user-facing output areas ([StorageArea.downloads], [StorageArea.exports],
/// [StorageArea.imports]) are hot — nothing holds them open and every write
/// asks afresh, so a folder the user picks answers the very next download,
/// recording or backup. Names over every other area are cold — their
/// writers captured a directory at boot and keep it until a restart —
/// which is what [StorageAreaEffect] tells the caller to say.
enum AppDirectory {
  /// The data tree's root: settings, databases, history, accounts.
  data(StorageArea.data, null),

  /// The rotating file sink's tree, beneath the data area.
  logs(StorageArea.data, 'logs'),

  /// Configuration files: persistent, user-editable.
  config(StorageArea.config, null),

  /// Imported scripts and per-plugin runtime data.
  extensions(StorageArea.extensions, null),

  /// User-initiated imports (M3U, TVBox configs).
  imports(StorageArea.imports, null),

  /// User-initiated exports and hand-overs.
  exports(StorageArea.exports, null),

  /// Configuration backups and restores, beneath the exports area.
  backups(StorageArea.exports, 'backups'),

  /// Finished downloads the user will open outside the app.
  downloads(StorageArea.downloads, null),

  /// Finished recordings, beneath the downloads area — the recording
  /// domain's output tree.
  recordings(StorageArea.downloads, 'recordings'),

  /// Refetchable covers, thumbnails and parse results.
  cache(StorageArea.cache, null),

  /// Download intermediates and migration scratch.
  temporary(StorageArea.temporary, null);

  new(this.area, this.segment);

  /// The area that backs this name — the movable unit underneath.
  final StorageArea area;

  /// The segment that names this tree beneath its area; null when the name
  /// *is* the area.
  final String? segment;

  /// What changing this name's backing area costs the running app — the
  /// hint a screen row shows before the user moves anything.
  StorageAreaEffect get changeEffect => area.changeEffect;
}

/// What a path change means for the app that is still running.
enum StorageAreaEffect {
  /// The new directory answers the very next ask — downloads, recordings
  /// and backups land in the folder the user just picked, with no restart
  /// and no ceremony.
  immediate,

  /// Writers that captured their directory at boot keep writing where this
  /// boot pinned them — the open databases, the rotating log — so the
  /// change lands after a restart, when boot carries the old tree into the
  /// new directory before anything opens it. The caller says so instead of
  /// silently swapping folders underneath the user.
  afterRestart;
}

/// The app's own split of the areas into hot and cold.
extension StorageAreaChange on StorageArea {
  /// The user-facing output areas are hot: nothing in the process holds
  /// them open, so a choice recorded through `AppPaths.choose` is already
  /// in force for the next file. Every other area is cold — its writers
  /// hold open files where boot resolved them.
  StorageAreaEffect get changeEffect => switch (this) {
    StorageArea.downloads || StorageArea.exports || StorageArea.imports => StorageAreaEffect.immediate,
    _ => StorageAreaEffect.afterRestart,
  };
}
