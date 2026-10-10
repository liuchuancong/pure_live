// Module: lib/src/platform_paths.dart
// Purpose: Resolve every storage location from injected host facts - Android, iOS/macOS, Windows (incl. MSIX),
// Linux XDG, portable desktop builds, and a web host that has no file system at all.
// Author: liuchuancong
// Created: 2026-10-11
//
// Why this is pure string resolution rather than a path_provider call: an L0 package cannot depend on a
// Flutter plugin, and a path decision that needs the widget tree cannot be made during bootstrap (the very
// first settings read happens before the first frame). So the host gathers the facts once - environment
// variables, the executable path, the Android directories from its own platform channel, the MSIX package
// family name - and this file turns facts into directories. Everything above foundation then asks for a
// StorageKind and never mentions %LOCALAPPDATA% or /storage/emulated/0 again.

import 'dart:io' show Directory, Platform;

import 'package:path/path.dart' as p;
import 'package:xdg_directories/xdg_directories.dart' as xdg;

import 'storage_locations.dart';

/// The facts one host has about where its files may live.
///
/// Every field is optional except [platform] and [appName]: a resolver answers null for a location whose
/// facts are missing rather than inventing a directory, because an invented path is a write that lands
/// somewhere the user will never find.
final class PathSignals {
  const PathSignals({
    required this.platform,
    required this.appName,
    this.publisher = 'PureLive',
    this.packageFamilyName,
    this.homeDirectory,
    this.executablePath,
    this.environment = const <String, String>{},
    this.androidInternalFilesDir,
    this.androidInternalCacheDir,
    this.androidExternalFilesDir,
    this.androidExternalCacheDir,
    this.androidSharedStorageRoot,
    this.portableDataDirectory,
    this.isPortable = false,
  });

  /// Reads the facts a desktop or mobile host can answer from its own process, without a plugin.
  ///
  /// The Android directories are not readable from Dart (they come from the platform), so a mobile host
  /// passes them in after asking its channel; everything else is environment and process state.
  factory PathSignals.fromEnvironment({
    required HostPlatform platform,
    required String appName,
    String publisher = 'PureLive',
    String? packageFamilyName,
    Map<String, String>? environment,
    bool isPortable = false,
  }) {
    final env = environment ?? Platform.environment;
    return PathSignals(
      platform: platform,
      appName: appName,
      publisher: publisher,
      packageFamilyName: packageFamilyName ?? env['PURE_LIVE_MSIX_FAMILY'],
      homeDirectory: env['HOME'] ?? env['USERPROFILE'],
      executablePath: _resolvedExecutable(),
      environment: env,
      isPortable: isPortable,
      portableDataDirectory: null,
    );
  }

  final HostPlatform platform;

  /// The directory name the app owns, e.g. `pure_live`. One per app: four apps on one machine must not share
  /// a data directory, and the name is the only thing separating them.
  final String appName;

  /// The Windows vendor folder between the platform root and [appName].
  final String publisher;

  /// The MSIX package family name (`Name_PublisherId`), when the build is packaged.
  ///
  /// A packaged Windows build is redirected by the OS into `Packages\<family>\`, and writing to
  /// `%LOCALAPPDATA%\<Publisher>\<App>` from inside that sandbox silently lands in a virtualised copy the
  /// next launch does not see. Detecting packaging is therefore not a cosmetic detail.
  final String? packageFamilyName;

  final String? homeDirectory;

  /// The running executable, which is what a portable build hangs its data directory off.
  final String? executablePath;

  final Map<String, String> environment;

  /// `/data/user/0/<package>/files` - private, always present, removed on uninstall.
  final String? androidInternalFilesDir;

  /// `/data/user/0/<package>/cache`.
  final String? androidInternalCacheDir;

  /// `/storage/emulated/0/Android/data/<package>/files` - on shared storage, visible to a file manager that
  /// has been granted access, and removed on uninstall.
  final String? androidExternalFilesDir;

  final String? androidExternalCacheDir;

  /// `/storage/emulated/0`, when the app holds (or can ask for) shared-storage access.
  final String? androidSharedStorageRoot;

  /// An explicit data directory, which wins over every rule.
  final String? portableDataDirectory;

  /// Whether this build keeps its data beside the executable instead of in a platform profile.
  final bool isPortable;

  bool get hasFileSystem => hostHasFileSystem(platform);

  static String? _resolvedExecutable() {
    try {
      return Platform.resolvedExecutable;
    } on Object {
      // A sandboxed or web-compiled host can throw here; the portable layout simply is not available then.
      return null;
    }
  }
}

/// Turns [PathSignals] into directories, one [StorageKind] at a time.
final class AppPaths {
  AppPaths(this.signals) : _context = _contextFor(signals.platform);

  final PathSignals signals;

  /// The separator convention of the host, so a resolved path is a string the host's own APIs accept.
  ///
  /// Building Windows paths with the posix context produces `C:\Users/x` - which Dart tolerates and the Win32
  /// file APIs sometimes do not, and the failure shows up as "file not found" on a path that is on screen.
  final p.Context _context;

  static p.Context _contextFor(HostPlatform platform) => switch (platform) {
    HostPlatform.windows => p.Context(style: p.Style.windows),
    _ => p.Context(style: p.Style.posix),
  };

  /// The directory for [kind], or null when this host cannot offer it.
  ///
  /// [namespace] adds one level under the kind, which is how two apps or two plugin bundles keep their cache
  /// apart inside a shared location.
  String? resolve(StorageKind kind, {String? namespace}) {
    final base = _baseFor(kind);
    if (base == null) {
      return null;
    }
    final withNamespace = namespace == null || namespace.isEmpty ? base : _context.join(base, namespace);
    final sub = subdirectoryFor(kind, signals.platform);
    return sub.isEmpty ? withNamespace : _context.join(withNamespace, sub);
  }

  String? get userData => resolve(StorageKind.userData);
  String? get database => resolve(StorageKind.database);
  String? get logs => resolve(StorageKind.logs);
  String? get cache => resolve(StorageKind.cache);
  String? get temp => resolve(StorageKind.temp);
  String? get downloads => resolve(StorageKind.downloads);
  String? get documents => resolve(StorageKind.documents);
  String? get media => resolve(StorageKind.media);
  String? get backups => resolve(StorageKind.backups);
  String? get plugins => resolve(StorageKind.plugins);

  /// Every location this host answers, for a diagnostics screen. Missing entries are reported as null rather
  /// than dropped, so "the host has no downloads directory" is distinguishable from "we forgot to ask".
  Map<StorageKind, String?> describe() => <StorageKind, String?>{
    for (final kind in StorageKind.values) kind: resolve(kind),
  };

  /// Whether this build keeps its data beside the executable.
  bool get isPortable => portableRoot != null;

  /// The portable data root, or null when this is not a portable build.
  ///
  /// Portable means: the user copied a folder to a USB stick and expects their settings to travel with it.
  /// An explicit [PathSignals.portableDataDirectory] wins; otherwise the flag is the directory of the
  /// executable, which is only meaningful on a desktop host that knows where it was started from.
  String? get portableRoot {
    final explicit = signals.portableDataDirectory;
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    if (!signals.isPortable) {
      return null;
    }
    final exe = signals.executablePath;
    if (exe == null || !signals.hasFileSystem) {
      return null;
    }
    return _context.join(_context.dirname(exe), 'data');
  }

  String? _baseFor(StorageKind kind) {
    if (!signals.hasFileSystem) {
      return null;
    }
    final portable = portableRoot;
    if (portable != null) {
      return _portableBase(kind, portable);
    }
    return switch (signals.platform) {
      HostPlatform.windows => _windowsBase(kind),
      HostPlatform.android => _androidBase(kind),
      HostPlatform.ios || HostPlatform.macos => _appleBase(kind),
      HostPlatform.linux => _linuxBase(kind),
      HostPlatform.web => null,
    };
  }

  /// A portable build puts everything under one folder that travels with the executable, except scratch space,
  /// which stays in the system temp directory: a USB stick can be read-only, and a half-written temp file
  /// must not be the reason a portable app cannot start.
  String _portableBase(StorageKind kind, String root) => switch (kind) {
    StorageKind.temp => _systemTemp() ?? _context.join(root, 'tmp'),
    StorageKind.cache => _context.join(root, 'cache'),
    StorageKind.logs => _context.join(root, 'logs'),
    StorageKind.database => _context.join(root, 'database'),
    StorageKind.downloads => _context.join(root, 'downloads'),
    StorageKind.documents => _context.join(root, 'documents'),
    StorageKind.media => _context.join(root, 'media'),
    StorageKind.backups => _context.join(root, 'backups'),
    StorageKind.plugins => _context.join(root, 'plugins'),
    StorageKind.userData => root,
  };

  String? _windowsBase(StorageKind kind) {
    final env = signals.environment;
    final family = signals.packageFamilyName;

    // Packaged (MSIX) builds are redirected by the OS; the LocalState/LocalCache/TempState split is the
    // package's own convention and roaming does not exist for it.
    if (family != null && family.isNotEmpty) {
      final local = env['LOCALAPPDATA'];
      if (local == null || local.isEmpty) {
        return null;
      }
      final packageRoot = _context.join(local, 'Packages', family);
      return switch (kind) {
        StorageKind.userData => _context.join(packageRoot, 'LocalState', signals.appName),
        StorageKind.database => _context.join(packageRoot, 'LocalState', signals.appName),
        StorageKind.logs => _context.join(packageRoot, 'LocalState', signals.appName),
        StorageKind.backups => _context.join(packageRoot, 'LocalState', signals.appName),
        StorageKind.plugins => _context.join(packageRoot, 'LocalState', signals.appName),
        StorageKind.cache => _context.join(packageRoot, 'LocalCache', signals.appName),
        StorageKind.temp => _context.join(packageRoot, 'TempState', signals.appName),
        StorageKind.downloads => _userFolder('Downloads') ?? _context.join(packageRoot, 'LocalState', 'Downloads'),
        StorageKind.documents => _userFolder('Documents') ?? _context.join(packageRoot, 'LocalState', 'Documents'),
        StorageKind.media => _userFolder('Music') ?? _context.join(packageRoot, 'LocalState', 'Music'),
      };
    }

    final roaming = env['APPDATA'];
    final local = env['LOCALAPPDATA'];
    final roamingRoot = roaming == null || roaming.isEmpty
        ? null
        : _context.join(roaming, signals.publisher, signals.appName);
    final localRoot = local == null || local.isEmpty ? null : _context.join(local, signals.publisher, signals.appName);
    // Settings roam with the Windows account; caches and logs do not, because a cache rebuilt on the wrong
    // machine is worse than no cache and a log that roams follows the user to a device that cannot read it.
    return switch (kind) {
      StorageKind.userData => roamingRoot ?? localRoot,
      StorageKind.database => roamingRoot ?? localRoot,
      StorageKind.logs => localRoot ?? roamingRoot,
      StorageKind.backups => roamingRoot ?? localRoot,
      StorageKind.plugins => localRoot ?? roamingRoot,
      StorageKind.cache => localRoot,
      StorageKind.temp => _systemTemp() ?? (localRoot == null ? null : _context.join(localRoot, 'tmp')),
      StorageKind.downloads => _userFolder('Downloads') ?? localRoot,
      StorageKind.documents => _userFolder('Documents') ?? localRoot,
      StorageKind.media => _userFolder('Music') ?? localRoot,
    };
  }

  /// A known Windows user folder, from the environment or from the profile root.
  ///
  /// `USERPROFILE` is the fallback because the shell folders can be relocated, and a relocated Downloads is
  /// still where the user expects a recording to appear.
  String? _userFolder(String name) {
    final relocated = signals.environment['PURE_LIVE_${name.toUpperCase()}_DIR'];
    if (relocated != null && relocated.isNotEmpty) {
      return relocated;
    }
    final profile = signals.environment['USERPROFILE'] ?? signals.homeDirectory;
    if (profile == null || profile.isEmpty) {
      return null;
    }
    return _context.join(profile, name);
  }

  String? _androidBase(StorageKind kind) {
    final internal = signals.androidInternalFilesDir;
    final internalCache = signals.androidInternalCacheDir;
    final external = signals.androidExternalFilesDir;
    final externalCache = signals.androidExternalCacheDir;

    return switch (kind) {
      // Private storage first: it needs no permission, and shared storage can be revoked at runtime.
      StorageKind.userData => internal,
      StorageKind.database => internal,
      StorageKind.logs => internal,
      StorageKind.plugins => internal,
      StorageKind.backups => external ?? internal,
      StorageKind.cache =>
        externalCache ?? internalCache ?? (internal == null ? null : _context.join(internal, 'cache')),
      StorageKind.temp => internalCache ?? (internal == null ? null : _context.join(internal, 'tmp')),
      StorageKind.downloads => _androidPublic('Download') ?? external ?? internal,
      StorageKind.documents => _androidPublic('Documents') ?? external ?? internal,
      StorageKind.media => _androidPublic('Music') ?? external ?? internal,
    };
  }

  /// A public shared-storage directory, only when the app actually has shared storage to point at.
  String? _androidPublic(String name) {
    final shared = signals.androidSharedStorageRoot;
    if (shared == null || shared.isEmpty) {
      return null;
    }
    return _context.join(shared, name);
  }

  String? _appleBase(StorageKind kind) {
    final home = signals.homeDirectory;
    if (home == null || home.isEmpty) {
      return null;
    }
    final library = _context.join(home, 'Library');
    // iOS and macOS both put writable per-app state under Library; the app's own container is already the
    // home directory on iOS, so no bundle-id level is added there.
    final support = _context.join(library, 'Application Support', signals.appName);
    return switch (kind) {
      StorageKind.userData => support,
      StorageKind.database => support,
      StorageKind.logs => _context.join(library, 'Logs', signals.appName),
      StorageKind.backups => _context.join(support, 'Backups'),
      StorageKind.plugins => _context.join(support, 'Plugins'),
      // Caches is excluded from device backup by the OS, which is exactly what a cache is for.
      StorageKind.cache => _context.join(library, 'Caches', signals.appName),
      StorageKind.temp => _context.join(home, 'tmp'),
      StorageKind.downloads => _context.join(home, 'Documents', signals.appName),
      StorageKind.documents => _context.join(home, 'Documents', signals.appName),
      StorageKind.media => _context.join(home, 'Documents', signals.appName, 'Media'),
    };
  }

  String? _linuxBase(StorageKind kind) {
    // The XDG base directories are read through the package that owns the specification's fallbacks, so a
    // host without XDG_* set still gets ~/.local/share instead of a null the caller cannot use.
    final data = _safeXdg(() => xdg.dataHome.path);
    final config = _safeXdg(() => xdg.configHome.path);
    final state = _safeXdg(() => xdg.stateHome.path);
    final cache = _safeXdg(() => xdg.cacheHome.path);
    final home = signals.homeDirectory;

    return switch (kind) {
      // Settings belong in config, everything the app accumulates in data: `rm -rf ~/.config/<app>` is the
      // documented way to reset an app on Linux, and it must not take the user's history with it.
      StorageKind.userData => _first(config, data, home),
      StorageKind.database => _first(data, home),
      StorageKind.logs => _first(state, home),
      StorageKind.backups => _first(data, home),
      StorageKind.plugins => _first(data, home),
      StorageKind.cache => _first(cache, home),
      StorageKind.temp => _systemTemp() ?? (home == null ? null : _context.join(home, '.cache', 'tmp')),
      StorageKind.downloads => _xdgUserDir('DOWNLOAD', home),
      StorageKind.documents => _xdgUserDir('DOCUMENTS', home),
      StorageKind.media => _xdgUserDir('MUSIC', home),
    };
  }

  /// A user-dirs folder, from `$XDG_<NAME>_DIR` when the session set it, else `~/<Capitalised>`.
  String? _xdgUserDir(String name, String? home) {
    final fromEnv = signals.environment['XDG_${name}_DIR'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (home == null || home.isEmpty) {
      return null;
    }
    final label = name[0] + name.substring(1).toLowerCase();
    return _context.join(home, label);
  }

  String? _first(String? a, [String? b, String? c]) {
    for (final candidate in <String?>[a, b, c]) {
      if (candidate != null && candidate.isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  String? _safeXdg(String? Function() read) {
    try {
      return read();
    } on Object {
      // xdg_directories reads the environment and can throw on a host with no HOME at all; that is a missing
      // fact, not a crash, and the caller's fallback chain is what handles it.
      return null;
    }
  }

  String? _systemTemp() {
    final fromEnv = signals.environment['TMPDIR'] ?? signals.environment['TEMP'] ?? signals.environment['TMP'];
    if (fromEnv != null && fromEnv.isNotEmpty) {
      return fromEnv;
    }
    try {
      return Directory.systemTemp.path;
    } on Object {
      return null;
    }
  }
}

/// A resolved location plus why it is what it is, for the "where does this app put my files" screen.
final class ResolvedPath {
  const ResolvedPath({required this.kind, required this.path, required this.portable, this.reason = ''});

  final StorageKind kind;
  final String? path;
  final bool portable;
  final String reason;

  bool get isAvailable => path != null;

  @override
  String toString() => 'ResolvedPath(${kind.name}: ${path ?? 'unavailable'})';
}
