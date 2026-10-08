// Module: lib/src/models/extension/extension_descriptor.dart
// Purpose: Describes an extension the platform can load or import: its protocol, capabilities and lifecycle status.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md sections 4 and 12. The Permission enum is carried here because
// ExtensionDescriptor declares it; the grant, scope and decision models stay with the permission
// subsystem in a later wave.

import '../../support/json.dart';
import '../error/platform_error_info.dart';
import '../identifiers.dart';
import '../runtime/runtime_descriptor.dart';
import 'extension_type.dart';

/// A capability an extension can serve. Values serialize as their own name.
enum ExtensionCapability {
  live,
  vod,
  music,
  playlist,
  epg,
  search,
  resolve,
  lyrics,
  download,
  account,
  recommendation,
  metadata,
}

/// The minimum permission vocabulary an extension can be granted.
///
/// docs/plugin/plugin-permission.md section 1 is the plugin-facing list and calls the cookie permission
/// `cookies`; the canonical name here stays `cookie` because the models document (platform-models.md
/// section 12) is normative, and the alias is mapped when a manifest is read.
enum Permission {
  network,
  cookie,
  account,
  storage,
  cache,
  notification,
  background,
  clipboard,
  localServer,
  media,
  device,

  /// Reading and writing files the user explicitly chose, through the files package.
  filesystem,

  /// Location. Default denied and never granted quietly (plugin-permission.md section 2).
  location,
}

/// Where an extension came from. Descriptive only: it never carries secrets.
final class ExtensionMetadata {
  const ExtensionMetadata({
    this.description = '',
    this.author = '',
    this.homepage = '',
    this.repository = '',
    this.icon = '',
    this.extra = const <String, Object?>{},
  });

  factory ExtensionMetadata.fromJson(Map<String, Object?> json) {
    return ExtensionMetadata(
      description: json['description'] as String? ?? '',
      author: json['author'] as String? ?? '',
      homepage: json['homepage'] as String? ?? '',
      repository: json['repository'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      extra: asObjectMap(json['extra']),
    );
  }

  final String description;
  final String author;
  final String homepage;
  final String repository;
  final String icon;
  final Map<String, Object?> extra;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      if (description.isNotEmpty) 'description': description,
      if (author.isNotEmpty) 'author': author,
      if (homepage.isNotEmpty) 'homepage': homepage,
      if (repository.isNotEmpty) 'repository': repository,
      if (icon.isNotEmpty) 'icon': icon,
      if (extra.isNotEmpty) 'extra': extra,
    };
  }
}

/// The stable description of one extension.
final class ExtensionDescriptor {
  const ExtensionDescriptor({
    required this.id,
    required this.name,
    required this.version,
    required this.protocol,
    required this.type,
    this.protocolVersion = '',
    this.platformApiVersion = '',
    this.capabilities = const <ExtensionCapability>{},
    this.permissions = const <Permission>{},
    this.metadata = const ExtensionMetadata(),
  });

  factory ExtensionDescriptor.fromJson(Map<String, Object?> json) {
    return ExtensionDescriptor(
      id: requireString(json, 'id', 'extension_descriptor'),
      name: requireString(json, 'name', 'extension_descriptor'),
      version: requireString(json, 'version', 'extension_descriptor'),
      protocol: requireString(json, 'protocol', 'extension_descriptor'),
      type: enumByName(ExtensionType.values, json['type'] as String?) ?? ExtensionType.external,
      protocolVersion: json['protocolVersion'] as String? ?? '',
      platformApiVersion: json['platformApiVersion'] as String? ?? '',
      capabilities: _capabilities(json['capabilities']),
      permissions: _permissions(json['permissions']),
      metadata: ExtensionMetadata.fromJson(asObjectMap(json['metadata'])),
    );
  }

  final ExtensionId id;
  final String name;

  /// The extension's own version, distinct from the protocol it speaks.
  final String version;

  /// Which protocol family this extension is written for, for example `tvbox` or `pure_live_plugin`.
  final String protocol;
  final String protocolVersion;

  /// The platform API revision the extension was built against.
  final String platformApiVersion;
  final ExtensionType type;
  final Set<ExtensionCapability> capabilities;
  final Set<Permission> permissions;
  final ExtensionMetadata metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'version': version,
      'protocol': protocol,
      'type': type.name,
      if (protocolVersion.isNotEmpty) 'protocolVersion': protocolVersion,
      if (platformApiVersion.isNotEmpty) 'platformApiVersion': platformApiVersion,
      if (capabilities.isNotEmpty) 'capabilities': capabilities.map((c) => c.name).toList(),
      if (permissions.isNotEmpty) 'permissions': permissions.map((p) => p.name).toList(),
      'metadata': metadata.toJson(),
    };
  }

  /// Two descriptors describe the same extension when the identity and the contract match.
  @override
  bool operator ==(Object other) {
    return other is ExtensionDescriptor &&
        other.id == id &&
        other.version == version &&
        other.protocol == protocol &&
        other.protocolVersion == protocolVersion &&
        other.type == type &&
        _sameSet(other.capabilities, capabilities) &&
        _sameSet(other.permissions, permissions);
  }

  @override
  int get hashCode => Object.hash(
    id,
    version,
    protocol,
    protocolVersion,
    type,
    Object.hashAllUnordered(capabilities),
    Object.hashAllUnordered(permissions),
  );
}

/// Lifecycle states an extension moves through; see docs/contracts/plugin-lifecycle.md.
enum ExtensionLifecycleState {
  discovered,
  identified,
  loading,
  validating,
  ready,
  running,
  stopping,
  disabled,
  unloading,
  unloaded,
  incompatible,
  error,
}

/// A point-in-time status of an extension.
final class ExtensionStatus {
  const ExtensionStatus({required this.extensionId, required this.lifecycle, required this.health, this.error});

  factory ExtensionStatus.fromJson(Map<String, Object?> json) {
    return ExtensionStatus(
      extensionId: requireString(json, 'extensionId', 'extension_descriptor'),
      lifecycle:
          enumByName(ExtensionLifecycleState.values, json['lifecycle'] as String?) ??
          ExtensionLifecycleState.discovered,
      health: enumByName(RuntimeHealth.values, json['health'] as String?) ?? RuntimeHealth.unavailable,
      error: json['error'] == null ? null : PlatformErrorInfo.fromJson(asObjectMap(json['error'])),
    );
  }

  final ExtensionId extensionId;
  final ExtensionLifecycleState lifecycle;
  final RuntimeHealth health;
  final PlatformErrorInfo? error;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'extensionId': extensionId,
      'lifecycle': lifecycle.name,
      'health': health.name,
      if (error != null) 'error': error!.toJson(),
    };
  }
}

/// Sets compare by membership, not by identity or iteration order.
bool _sameSet<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);

Set<ExtensionCapability> _capabilities(Object? value) {
  if (value is! List) {
    return const <ExtensionCapability>{};
  }
  return value.map((item) => enumByName(ExtensionCapability.values, '$item')).whereType<ExtensionCapability>().toSet();
}

Set<Permission> _permissions(Object? value) {
  if (value is! List) {
    return const <Permission>{};
  }
  return value.map((item) => enumByName(Permission.values, '$item')).whereType<Permission>().toSet();
}
