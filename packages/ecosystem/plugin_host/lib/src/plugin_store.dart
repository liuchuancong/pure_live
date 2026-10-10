// Module: lib/src/plugin_store.dart
// Purpose: The installed-plugin directory: validate, persist, list, toggle and remove.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/plugin/plugin-lifecycle.md section 1 (Installed is a disk state,
// and Uninstall keeps nothing) and plugin-manifest.md section 3 (refuse on
// parse failure, unknown names or an incompatible apiVersion - the store
// delegates that judgement to the plugin_api validator instead of re-deriving
// it). Layout under the store root: plugins/<id>/manifest.json + plugin.js +
// state.json. Three files, because a corrupt script must not take the
// declaration down with it and the enable flag is user data.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';
import 'package:pure_live_utils/pure_live_utils.dart' show Clock, systemClock;

import 'plugin_bundle.dart';

/// The directory an install writes into before it swaps into place.
///
/// Spelled once because [PluginStore.list] has to recognise the remnant: an install that died after its last
/// write but before the rename leaves a *complete* staging directory, and reading it would show the same
/// plugin a second time under an id no manifest ever claimed.
const String kPluginStagingSuffix = '.staging';

/// One plugin as the store has it on disk.
final class InstalledPlugin {
  const InstalledPlugin({required this.manifest, required this.enabled, required this.installedAt, this.originUrl});

  final PluginManifest manifest;
  final bool enabled;
  final DateTime installedAt;

  /// Where an imported config came from, when it was a URL. Relative spider
  /// paths inside the config resolve against this.
  final Uri? originUrl;

  String get id => manifest.id;
}

/// Why an install was refused. The message carries the validator's issues.
final class PluginInstallException implements Exception {
  const PluginInstallException(this.message);

  final String message;

  @override
  String toString() => 'PluginInstallException($message)';
}

/// A stored plugin could not be read within the limit the caller asked for.
///
/// Distinct from an install refusal: the plugin on disk is fine, the reader drew the line. A runtime that
/// loads a script into a sandbox needs the size to be the sandbox's decision, not a surprise in the middle
/// of a decode.
final class PluginTooLargeException implements Exception {
  const PluginTooLargeException(this.id, this.path, this.limitBytes, this.actualBytes);

  final String id;
  final String path;
  final int limitBytes;
  final int actualBytes;

  @override
  String toString() => 'PluginTooLargeException($id at $path: $actualBytes bytes over the $limitBytes byte limit)';
}

/// The on-disk plugin registry. One store per app process; the composition
/// root owns it and hands loaded code to the runtime host.
final class PluginStore {
  PluginStore({required Directory root, PluginManifestValidator? validator, Clock? clock})
    : _pluginsRoot = Directory(p.join(root.path, 'plugins')),
      _validator = validator ?? PluginManifestValidator(),
      _clock = clock ?? systemClock;

  final Directory _pluginsRoot;
  final PluginManifestValidator _validator;

  /// Install timestamps come from here: the store used to call `DateTime.now()` directly, so a test that
  /// wanted a known `installedAt` had to wait for the wall clock, and the local-vs-UTC mistake this repository
  /// has fixed repeatedly was invisible at the call site.
  final Clock _clock;

  /// Validates and persists one bundle. An already-installed id is replaced:
  /// upgrading a plugin is installing the next version, and the enable state
  /// carries over so an update does not silently turn a source off. The import
  /// origin carries over for the same reason - relative spider paths inside the
  /// config resolve against it, and an update that dropped it breaks a plugin
  /// that was working.
  Future<InstalledPlugin> install(PluginBundle bundle, {Uri? originUrl}) async {
    final result = _validator.validate(bundle.manifest);
    if (!result.isAccepted) {
      final details = result.errors.map((issue) => issue.toString()).join('; ');
      throw PluginInstallException('${bundle.manifest.id} refused: $details');
    }
    final existing = await _readState(bundle.manifest.id);
    return _write(
      manifest: bundle.manifest,
      fileName: 'plugin.js',
      body: bundle.source,
      existing: existing,
      originUrl: originUrl,
    );
  }

  /// Installs a data plugin (TVBox config, M3U playlist): configuration only,
  /// with a parser-derived manifest and a content file instead of code.
  Future<InstalledPlugin> installData({
    required PluginManifest manifest,
    required String content,
    Uri? originUrl,
  }) async {
    final result = _validator.validate(manifest);
    if (!result.isAccepted) {
      final details = result.errors.map((issue) => issue.toString()).join('; ');
      throw PluginInstallException('${manifest.id} refused: $details');
    }
    final existing = await _readState(manifest.id);
    return _write(manifest: manifest, fileName: 'content.txt', body: content, existing: existing, originUrl: originUrl);
  }

  /// The one install path: validate, fill a staging directory, swap it in.
  ///
  /// Both entry points had their own copy of this until the data variant drifted - it reset `enabled` to
  /// false on every update, which is exactly the "an update turned my source off" behaviour the code path
  /// above documents as the thing to avoid.
  Future<InstalledPlugin> _write({
    required PluginManifest manifest,
    required String fileName,
    required String body,
    required Map<String, Object?>? existing,
    required Uri? originUrl,
  }) async {
    final directory = _directoryFor(manifest.id);
    await _refuseForeignOccupant(directory, manifest.id);
    final staging = Directory('${directory.path}$kPluginStagingSuffix');
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);
    await File(p.join(staging.path, 'manifest.json')).writeAsString(jsonEncode(manifest.toJson()), flush: true);
    await File(p.join(staging.path, fileName)).writeAsString(body, flush: true);
    final keptOrigin = originUrl ?? _originFromState(existing);
    final state = <String, Object?>{
      'enabled': existing?['enabled'] is bool ? existing!['enabled'] : false,
      'installedAt': _clock().toUtc().toIso8601String(),
      if (keptOrigin != null) 'originUrl': keptOrigin.toString(),
    };
    await File(p.join(staging.path, 'state.json')).writeAsString(jsonEncode(state), flush: true);
    // The swap keeps states clean: the staging directory only appears once
    // every file is complete, so a crash mid-install leaves either the
    // previous plugin or the staging remnant (cleaned by the next install),
    // never a half-written live directory.
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    await staging.rename(directory.path);
    return InstalledPlugin(
      manifest: manifest,
      enabled: state['enabled']! as bool,
      installedAt: DateTime.parse(state['installedAt']! as String),
      originUrl: keptOrigin,
    );
  }

  /// The stored content of one data plugin, up to [maxBytes].
  ///
  /// The cap exists because a data plugin's content is handed to a parser that assumes it came from a
  /// config file; an unbounded read lets one 200 MB file turn the settings page into an out-of-memory
  /// crash on open, which is the moment a plugin becomes unremovable.
  Future<String> readContent(String id, {int maxBytes = kDefaultPluginTextBytes}) =>
      _readBounded(File(_contentPath(id)), id, 'content.txt', maxBytes);

  /// The one plugin stored under [id], or null when it is not installed (including the case where its
  /// directory exists but its declaration or state cannot be read - the same "not installed" reading [list]
  /// uses, so the two cannot disagree about a damaged plugin).
  Future<InstalledPlugin?> find(String id) async {
    final manifest = await _readManifest(id);
    final state = await _readState(id);
    if (manifest == null || state == null) {
      return null;
    }
    return _fromState(id, manifest, state);
  }

  /// Every installed plugin, id-ordered so the management page is stable.
  Future<List<InstalledPlugin>> list() async {
    if (!await _pluginsRoot.exists()) {
      return const <InstalledPlugin>[];
    }
    final installed = <InstalledPlugin>[];
    await for (final entity in _pluginsRoot.list(followLinks: false)) {
      if (entity is! Directory) {
        continue;
      }
      final id = entity.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      // A crash between the last staging write and the rename leaves a complete `.staging` directory behind.
      // It holds a real manifest, so reading it would list the same plugin twice, the second time under an id
      // that is the first one plus a suffix - which then uninstalls, enables and stores state as that phantom.
      if (id.endsWith(kPluginStagingSuffix)) {
        continue;
      }
      final plugin = await find(id);
      if (plugin == null) {
        // A half-written directory (crash between the three writes) reads as
        // not-installed rather than crashing the whole list.
        continue;
      }
      installed.add(plugin);
    }
    installed.sort((a, b) => a.id.compareTo(b.id));
    return installed;
  }

  /// Deletes staging remnants left by installs that died before their rename, and returns how many went.
  ///
  /// A sweep a caller runs deliberately (at start-up, from the settings page), because deleting directories on
  /// a user's plugin root is not something a `list()` should do on the side.
  Future<int> pruneStagingRemnants() async {
    if (!await _pluginsRoot.exists()) {
      return 0;
    }
    var removed = 0;
    await for (final entity in _pluginsRoot.list(followLinks: false)) {
      if (entity is Directory && entity.path.endsWith(kPluginStagingSuffix)) {
        await entity.delete(recursive: true);
        removed++;
      }
    }
    return removed;
  }

  /// The script of one installed plugin, for the runtime to load, up to [maxBytes].
  Future<String> readSource(String id, {int maxBytes = kDefaultPluginTextBytes}) =>
      _readBounded(File(_sourcePath(id)), id, 'plugin.js', maxBytes);

  /// The default ceiling for one text file of a plugin: 4 MB.
  ///
  /// Generous next to a real spider script (tens of kilobytes) and small next to a device's memory, so a
  /// limit here is a guard against a broken or hostile file and not a tuning knob.
  static const int kDefaultPluginTextBytes = 4 * 1024 * 1024;

  Future<String> _readBounded(File file, String id, String name, int maxBytes) async {
    if (!await file.exists()) {
      throw PluginInstallException('$id has no $name');
    }
    final size = await file.length();
    if (size > maxBytes) {
      throw PluginTooLargeException(id, name, maxBytes, size);
    }
    return file.readAsString();
  }

  /// Turns one plugin on or off.
  ///
  /// Written through a temporary file and a rename: this used to overwrite `state.json` in place, and a crash
  /// or a full disk half way through leaves a file that no longer parses - which [list] reads as "not
  /// installed". Pressing the toggle would then have made the plugin disappear from the management page while
  /// its directory and script stayed on disk, unlistable and so unremovable from the UI.
  Future<void> setEnabled(String id, bool enabled) async {
    final state = await _readState(id);
    if (state == null) {
      throw PluginInstallException('$id is not installed');
    }
    state['enabled'] = enabled;
    final target = File(_statePath(id));
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsString(jsonEncode(state), flush: true);
    await temporary.rename(target.path);
  }

  /// Removes the plugin's code and declaration. Its kv namespace belongs to
  /// the storage layer and is not touched here: uninstall of data is a
  /// separate, user-visible decision.
  ///
  /// The staging sibling goes with it: an uninstall that left `x.staging` behind would resurrect the plugin
  /// on the next listing once the phantom-suffix rule was relaxed, and it holds a full copy of the code the
  /// user just asked to delete.
  Future<void> uninstall(String id) async {
    final directory = _directoryFor(id);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    final staging = Directory('${directory.path}$kPluginStagingSuffix');
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
  }

  /// The one place an id becomes a path, so no caller has to remember to sanitise it.
  ///
  /// Replacing everything outside `[A-Za-z0-9._-]` was not enough: the dot is allowed, so the id `..`
  /// survived untouched and resolved to the directory *above* `plugins/` - where `uninstall` deletes
  /// recursively. Collapsing dot runs is what makes the escape unrepresentable, and the containment check
  /// behind it is belt-and-braces rather than the real guard: a path helper that resolves cleanly still has
  /// to be proven to stay inside the root.
  Directory _directoryFor(String id) {
    var safe = id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    safe = safe.replaceAll(RegExp(r'\.{2,}'), '_').replaceAll(RegExp(r'^\.+|\.+$'), '_');
    final directory = Directory(p.join(_pluginsRoot.path, safe));
    if (!_staysInsideRoot(directory.path)) {
      // Unreachable while the two rewrites above hold; kept because "the id can never escape" is a property
      // of code that changes, not a fact about the input.
      throw PluginInstallException('$id cannot be used as a plugin id: it escapes the plugin directory');
    }
    return directory;
  }

  bool _staysInsideRoot(String path) {
    final relative = p.relative(path, from: _pluginsRoot.path);
    return !relative.startsWith('..') && !p.isAbsolute(relative);
  }

  String _manifestPath(String id) => p.join(_directoryFor(id).path, 'manifest.json');

  String _sourcePath(String id) => p.join(_directoryFor(id).path, 'plugin.js');

  String _contentPath(String id) => p.join(_directoryFor(id).path, 'content.txt');

  String _statePath(String id) => p.join(_directoryFor(id).path, 'state.json');

  Future<PluginManifest?> _readManifest(String id) => _readManifestAt(_manifestPath(id));

  /// Refuses an install whose target directory already belongs to a different plugin.
  ///
  /// `_directoryFor` sanitises, so two distinct manifest ids can land in one directory (`a.` and `a_`), and
  /// without this check the second install would overwrite the first while the manifest on disk claimed the
  /// id nobody asked to replace.
  Future<void> _refuseForeignOccupant(Directory directory, String id) async {
    final occupant = await _readManifestAt(p.join(directory.path, 'manifest.json'));
    if (occupant != null && occupant.id != id) {
      throw PluginInstallException(
        '$id cannot be installed: its plugin directory already holds ${occupant.id}, '
        'and the two ids sanitise to the same name',
      );
    }
  }

  Future<PluginManifest?> _readManifestAt(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? PluginManifest.fromJson(Map<String, Object?>.from(decoded)) : null;
    } on Object {
      // Not just a FormatException: a manifest that parses but has the wrong shape (a list where the id
      // should be, a number for a version) throws from the model, and one damaged plugin must not take the
      // whole listing - or the settings page - down with it.
      return null;
    }
  }

  Future<Map<String, Object?>?> _readState(String id) async {
    final file = File(_statePath(id));
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } on Object {
      return null;
    }
  }

  InstalledPlugin _fromState(String id, PluginManifest manifest, Map<String, Object?> state) => InstalledPlugin(
    manifest: manifest,
    enabled: state['enabled'] is bool ? state['enabled']! as bool : false,
    installedAt: DateTime.tryParse('${state['installedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    originUrl: _originFromState(state),
  );

  /// The import origin in a stored state map, or null. A value that is not a url is treated as absent rather
  /// than passed to `Uri.parse`, which accepts almost anything and would hand a relative-path base that points
  /// nowhere.
  static Uri? _originFromState(Map<String, Object?>? state) {
    final raw = state?['originUrl'];
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(raw);
    return parsed == null || !parsed.hasScheme ? null : parsed;
  }
}
