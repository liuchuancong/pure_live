// Module: lib/src/models/extension/plugin_manifest.dart
// Purpose: What a plugin declares about itself before the platform runs any of its code.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/plugin-contract.md section 1 and docs/plugin/plugin-manifest.md sections 1-2.
// This is the serialisable declaration only. Deciding whether a declaration is acceptable - unknown
// capability or permission names, an apiVersion outside the supported range - needs the sets the host knows
// about, so that judgement lives in pure_live_plugin_api, which receives them from the composition root.

import '../../support/json.dart';
import 'extension_descriptor.dart';

/// How the plugin's code runs. docs/contracts/plugin-contract.md section 1.
enum PluginRuntimeKind {
  /// Dart compiled into the app.
  native,

  /// Script executed in the JS sandbox.
  js,

  /// No code: a data source whose manifest the parser derives (TVBox, M3U, XMLTV).
  data,
}

/// Where the plugin came from, which decides how much the platform trusts its declarations.
enum PluginOrigin { builtin, localFile, url, repository, marketplace }

/// One plugin's static declaration.
final class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.apiVersion,
    required this.runtime,
    required this.capabilityNames,
    required this.permissionNames,
    this.origin = PluginOrigin.builtin,
    this.metadata = const ExtensionMetadata(),
  });

  factory PluginManifest.fromJson(Map<String, Object?> json) {
    return PluginManifest(
      id: requireString(json, 'id', 'plugin_manifest'),
      name: requireString(json, 'name', 'plugin_manifest'),
      version: requireString(json, 'version', 'plugin_manifest'),
      apiVersion: (json['apiVersion'] as num?)?.toInt() ?? 0,
      runtime: enumByName(PluginRuntimeKind.values, json['runtime'] as String?) ?? PluginRuntimeKind.native,
      origin: enumByName(PluginOrigin.values, json['origin'] as String?) ?? PluginOrigin.builtin,
      capabilityNames: _names(json['capabilities']),
      permissionNames: _names(json['permissions']),
      metadata: json['metadata'] == null
          ? const ExtensionMetadata()
          : ExtensionMetadata.fromJson(asObjectMap(json['metadata'])),
    );
  }

  /// Globally unique, reverse-domain shaped; it is also the ContentRef sourceId (plugin-manifest.md §2).
  final String id;
  final String name;
  final String version;

  /// The plugin API contract revision the plugin was written against.
  final int apiVersion;
  final PluginRuntimeKind runtime;
  final PluginOrigin origin;

  /// Declared as written, without interpretation: a name this build does not know has to survive parsing so
  /// the validator can refuse it instead of a decoder silently dropping it.
  final Set<String> capabilityNames;
  final Set<String> permissionNames;
  final ExtensionMetadata metadata;

  bool get hasCode => runtime != PluginRuntimeKind.data;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'version': version,
    'apiVersion': apiVersion,
    'runtime': runtime.name,
    'origin': origin.name,
    'capabilities': capabilityNames.toList(growable: false),
    'permissions': permissionNames.toList(growable: false),
    if (metadata.description.isNotEmpty ||
        metadata.author.isNotEmpty ||
        metadata.icon.isNotEmpty ||
        metadata.homepage.isNotEmpty ||
        metadata.repository.isNotEmpty ||
        metadata.extra.isNotEmpty)
      'metadata': metadata.toJson(),
  };

  @override
  String toString() => 'PluginManifest($id v$version api$apiVersion ${runtime.name})';

  /// Two manifests describe the same plugin when the identity and the declaration agree; a changed
  /// capability or permission set is a different build and has to be reviewed again.
  @override
  bool operator ==(Object other) {
    return other is PluginManifest &&
        other.id == id &&
        other.version == version &&
        other.apiVersion == apiVersion &&
        other.runtime == runtime &&
        other.origin == origin &&
        other.capabilityNames.length == capabilityNames.length &&
        other.capabilityNames.containsAll(capabilityNames) &&
        other.permissionNames.length == permissionNames.length &&
        other.permissionNames.containsAll(permissionNames);
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    apiVersion,
    runtime,
    origin,
    Object.hashAllUnordered(capabilityNames),
    Object.hashAllUnordered(permissionNames),
  );
}

/// Kept in declaration order but stored as a set, because a manifest that lists `network` twice means one
/// permission, not two.
Set<String> _names(Object? value) {
  if (value is! List) {
    return const <String>{};
  }
  return value.map((item) => '$item').where((item) => item.isNotEmpty).toSet();
}
