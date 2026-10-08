// Module: lib/src/models/runtime/runtime_descriptor.dart
// Purpose: Describes an execution runtime that can host extensions, and its health as observed by the platform.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 4. A runtime is not an extension: one runtime hosts
// many extensions, and a single source failing must never mark the runtime itself unhealthy
// (docs/contracts/platform-models.md section 20 invariant 6).

import '../../support/json.dart';
import '../error/platform_error_info.dart';
import '../extension/extension_type.dart';
import '../identifiers.dart';

/// How usable a runtime currently is.
enum RuntimeHealth { healthy, degraded, unavailable }

/// A runtime the extension gateway can route work to.
final class RuntimeDescriptor {
  const RuntimeDescriptor({
    required this.id,
    required this.name,
    required this.version,
    this.protocols = const <String>{},
    this.supportedTypes = const <ExtensionType>{},
  });

  factory RuntimeDescriptor.fromJson(Map<String, Object?> json) {
    return RuntimeDescriptor(
      id: requireString(json, 'id', 'runtime_descriptor'),
      name: requireString(json, 'name', 'runtime_descriptor'),
      version: requireString(json, 'version', 'runtime_descriptor'),
      protocols: _strings(json['protocols']).toSet(),
      supportedTypes: json['supportedTypes'] is List
          ? (json['supportedTypes'] as List)
              .map((item) => enumByName(ExtensionType.values, '$item'))
              .whereType<ExtensionType>()
              .toSet()
          : const <ExtensionType>{},
    );
  }

  final RuntimeId id;
  final String name;
  final String version;

  /// Protocol families this runtime can drive, for example `tvbox` or `m3u`.
  final Set<String> protocols;

  /// Which kind of thing the runtime is able to host.
  final Set<ExtensionType> supportedTypes;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'version': version,
      if (protocols.isNotEmpty) 'protocols': protocols.toList(),
      if (supportedTypes.isNotEmpty) 'supportedTypes': supportedTypes.map((t) => t.name).toList(),
    };
  }

  @override
  bool operator ==(Object other) {
    return other is RuntimeDescriptor &&
        other.id == id &&
        other.name == name &&
        other.version == version &&
        _sameSet(other.protocols, protocols) &&
        _sameSet(other.supportedTypes, supportedTypes);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        version,
        Object.hashAllUnordered(protocols),
        Object.hashAllUnordered(supportedTypes),
      );
}

/// Observed condition of a runtime, including the failure that produced it when there is one.
final class RuntimeStatus {
  const RuntimeStatus({required this.health, this.lastCheckAt, this.error});

  factory RuntimeStatus.fromJson(Map<String, Object?> json) {
    return RuntimeStatus(
      health: enumByName(RuntimeHealth.values, json['health'] as String?) ?? RuntimeHealth.unavailable,
      lastCheckAt: parseUtc(json['lastCheckAt']),
      error: json['error'] == null
          ? null
          : PlatformErrorInfo.fromJson(asObjectMap(json['error'])),
    );
  }

  final RuntimeHealth health;

  /// When the platform last probed this runtime; null until the first check.
  final DateTime? lastCheckAt;
  final PlatformErrorInfo? error;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'health': health.name,
      if (lastCheckAt != null) 'lastCheckAt': formatUtc(lastCheckAt),
      if (error != null) 'error': error!.toJson(),
    };
  }
}

List<String> _strings(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((item) => '$item').toList(growable: false);
}

bool _sameSet<T>(Set<T> a, Set<T> b) => a.length == b.length && a.containsAll(b);
