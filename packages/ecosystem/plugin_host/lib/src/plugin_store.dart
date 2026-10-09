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

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_plugin_api/pure_live_plugin_api.dart';

import 'plugin_bundle.dart';

/// One plugin as the store has it on disk.
final class InstalledPlugin {
  const InstalledPlugin({required this.manifest, required this.enabled, required this.installedAt});

  final PluginManifest manifest;
  final bool enabled;
  final DateTime installedAt;

  String get id => manifest.id;
}

/// Why an install was refused. The message carries the validator's issues.
final class PluginInstallException implements Exception {
  const PluginInstallException(this.message);

  final String message;

  @override
  String toString() => 'PluginInstallException($message)';
}

/// The on-disk plugin registry. One store per app process; the composition
/// root owns it and hands loaded code to the runtime host.
final class PluginStore {
  PluginStore({required Directory root, PluginManifestValidator? validator})
    : _pluginsRoot = Directory('${root.path}${Platform.pathSeparator}plugins'),
      _validator = validator ?? PluginManifestValidator();

  final Directory _pluginsRoot;
  final PluginManifestValidator _validator;

  /// Validates and persists one bundle. An already-installed id is replaced:
  /// upgrading a plugin is installing the next version, and the enable state
  /// carries over so an update does not silently turn a source off.
  Future<InstalledPlugin> install(PluginBundle bundle) async {
    final result = _validator.validate(bundle.manifest);
    if (!result.isAccepted) {
      final details = result.errors.map((issue) => issue.toString()).join('; ');
      throw PluginInstallException('${bundle.manifest.id} refused: $details');
    }
    final directory = _directoryFor(bundle.manifest.id);
    await directory.create(recursive: true);
    await File(_manifestPath(bundle.manifest.id)).writeAsString(jsonEncode(bundle.manifest.toJson()), flush: true);
    await File(_sourcePath(bundle.manifest.id)).writeAsString(bundle.source, flush: true);

    final existing = await _readState(bundle.manifest.id);
    final state = <String, Object?>{
      'enabled': existing?['enabled'] ?? false,
      'installedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await File(_statePath(bundle.manifest.id)).writeAsString(jsonEncode(state), flush: true);
    return InstalledPlugin(
      manifest: bundle.manifest,
      enabled: state['enabled']! as bool,
      installedAt: DateTime.parse(state['installedAt']! as String),
    );
  }

  /// Every installed plugin, id-ordered so the management page is stable.
  Future<List<InstalledPlugin>> list() async {
    if (!await _pluginsRoot.exists()) {
      return const <InstalledPlugin>[];
    }
    final installed = <InstalledPlugin>[];
    for (final entity in _pluginsRoot.listSync()) {
      if (entity is! Directory) {
        continue;
      }
      final id = entity.uri.pathSegments.where((segment) => segment.isNotEmpty).last;
      final manifest = await _readManifest(id);
      final state = await _readState(id);
      if (manifest == null || state == null) {
        // A half-written directory (crash between the three writes) reads as
        // not-installed rather than crashing the whole list.
        continue;
      }
      installed.add(
        InstalledPlugin(
          manifest: manifest,
          enabled: state['enabled'] as bool? ?? false,
          installedAt: DateTime.tryParse('${state['installedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }
    installed.sort((a, b) => a.id.compareTo(b.id));
    return installed;
  }

  /// The script of one installed plugin, for the runtime to load.
  Future<String> readSource(String id) => File(_sourcePath(id)).readAsString();

  Future<void> setEnabled(String id, bool enabled) async {
    final state = await _readState(id);
    if (state == null) {
      throw PluginInstallException('$id is not installed');
    }
    state['enabled'] = enabled;
    await File(_statePath(id)).writeAsString(jsonEncode(state), flush: true);
  }

  /// Removes the plugin's code and declaration. Its kv namespace belongs to
  /// the storage layer and is not touched here: uninstall of data is a
  /// separate, user-visible decision.
  Future<void> uninstall(String id) async {
    final directory = _directoryFor(id);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Directory _directoryFor(String id) {
    final safe = id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return Directory('${_pluginsRoot.path}${Platform.pathSeparator}$safe');
  }

  String _manifestPath(String id) => '${_directoryFor(id).path}${Platform.pathSeparator}manifest.json';

  String _sourcePath(String id) => '${_directoryFor(id).path}${Platform.pathSeparator}plugin.js';

  String _statePath(String id) => '${_directoryFor(id).path}${Platform.pathSeparator}state.json';

  Future<PluginManifest?> _readManifest(String id) async {
    final file = File(_manifestPath(id));
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? PluginManifest.fromJson(Map<String, Object?>.from(decoded)) : null;
    } on FormatException {
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
    } on FormatException {
      return null;
    }
  }
}
