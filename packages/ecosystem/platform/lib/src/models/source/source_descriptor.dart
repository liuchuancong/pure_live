// Module: lib/src/models/source/source_descriptor.dart
// Purpose: Describes one configured external source: where it lives, which runtime drives it and how it refreshes.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 5. The name collides with media_core's SourceDescriptor,
// which describes a media stream instead of a user configured source; docs/contracts/platform-models.md
// section 2 keeps this name in the platform barrel and maps the two in the wiring layer.

import '../../support/json.dart';
import '../error/platform_error_info.dart';
import '../identifiers.dart';

/// How the source is reached.
enum SourceType { url, file, script, builtin, repository }

/// The states a source moves through. Each one means something specific:
/// created = not started, detecting = protocol being identified, validating = format and configuration
/// checks, loading = first load, ready = usable, refreshing = updating, degraded = partly usable,
/// error = failed, disabled = turned off by user or platform, disposed = runtime resources released.
enum SourceState {
  created,
  detecting,
  validating,
  loading,
  ready,
  refreshing,
  degraded,
  error,
  disabled,
  disposed,
}

/// Per-source settings. Defaults follow docs/contracts/platform-models.md section 5.
final class SourceConfig {
  const SourceConfig({
    this.enabled = true,
    this.refreshInterval = const Duration(hours: 6),
    this.headers = const <String, String>{},
    this.userAgent,
    this.options = const <String, Object?>{},
  });

  factory SourceConfig.fromJson(Map<String, Object?> json) {
    return SourceConfig(
      enabled: json['enabled'] as bool? ?? true,
      refreshInterval: parseDurationMs(json['refreshIntervalMs']) ?? const Duration(hours: 6),
      headers: _stringMap(json['headers']),
      userAgent: json['userAgent'] as String?,
      options: asObjectMap(json['options']),
    );
  }

  final bool enabled;
  final Duration refreshInterval;

  /// Request headers. Authorization and Cookie values must not be persisted in clear text: they belong
  /// to secure storage and only appear here at runtime.
  final Map<String, String> headers;
  final String? userAgent;
  final Map<String, Object?> options;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'enabled': enabled,
      'refreshIntervalMs': durationMs(refreshInterval),
      if (headers.isNotEmpty) 'headers': headers,
      if (userAgent != null && userAgent!.isNotEmpty) 'userAgent': userAgent,
      if (options.isNotEmpty) 'options': options,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is SourceConfig &&
        other.enabled == enabled &&
        other.refreshInterval == refreshInterval &&
        other.userAgent == userAgent &&
        _sameStringMap(other.headers, headers) &&
        _sameObjectMap(other.options, options);
  }

  @override
  int get hashCode => Object.hash(
        enabled,
        refreshInterval,
        userAgent,
        Object.hashAllUnordered(headers.keys),
        Object.hashAllUnordered(headers.values),
      );
}

/// A configured external source.
final class SourceDescriptor {
  const SourceDescriptor({
    required this.id,
    required this.extensionId,
    required this.runtimeId,
    required this.uri,
    required this.type,
    this.name,
    this.config = const SourceConfig(),
  });

  factory SourceDescriptor.fromJson(Map<String, Object?> json) {
    return SourceDescriptor(
      id: requireString(json, 'id', 'source_descriptor'),
      extensionId: requireString(json, 'extensionId', 'source_descriptor'),
      runtimeId: requireString(json, 'runtimeId', 'source_descriptor'),
      uri: requireString(json, 'uri', 'source_descriptor'),
      type: enumByName(SourceType.values, json['type'] as String?) ?? SourceType.url,
      name: json['name'] as String?,
      config: SourceConfig.fromJson(asObjectMap(json['config'])),
    );
  }

  final SourceId id;

  /// The extension this source belongs to.
  final ExtensionId extensionId;

  /// The runtime chosen to drive it.
  final RuntimeId runtimeId;

  /// A location string at the configuration boundary; the platform parses it into a Uri when using it.
  final String uri;
  final SourceType type;
  final String? name;
  final SourceConfig config;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'extensionId': extensionId,
      'runtimeId': runtimeId,
      'uri': uri,
      'type': type.name,
      if (name != null && name!.isNotEmpty) 'name': name,
      'config': config.toJson(),
    };
  }

  /// Identity is the id plus the extension that owns it; configuration changes are not identity changes.
  @override
  bool operator ==(Object other) {
    return other is SourceDescriptor &&
        other.id == id &&
        other.extensionId == extensionId &&
        other.runtimeId == runtimeId &&
        other.uri == uri &&
        other.type == type;
  }

  @override
  int get hashCode => Object.hash(id, extensionId, runtimeId, uri, type);
}

/// Observed condition of a source.
final class SourceStatus {
  const SourceStatus({
    required this.state,
    this.lastUpdatedAt,
    this.nextRefreshAt,
    this.error,
    this.metadata = const <String, Object?>{},
  });

  factory SourceStatus.fromJson(Map<String, Object?> json) {
    return SourceStatus(
      state: enumByName(SourceState.values, json['state'] as String?) ?? SourceState.created,
      lastUpdatedAt: parseUtc(json['lastUpdatedAt']),
      nextRefreshAt: parseUtc(json['nextRefreshAt']),
      error: json['error'] == null
          ? null
          : PlatformErrorInfo.fromJson(asObjectMap(json['error'])),
      metadata: asObjectMap(json['metadata']),
    );
  }

  final SourceState state;

  /// Timestamps describe freshness. A null here means the source never loaded, which is a different
  /// fact from `state == created` and is therefore not encoded by the null.
  final DateTime? lastUpdatedAt;
  final DateTime? nextRefreshAt;
  final PlatformErrorInfo? error;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'state': state.name,
      if (lastUpdatedAt != null) 'lastUpdatedAt': formatUtc(lastUpdatedAt),
      if (nextRefreshAt != null) 'nextRefreshAt': formatUtc(nextRefreshAt),
      if (error != null) 'error': error!.toJson(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) {
    return const <String, String>{};
  }
  return Map<String, String>.fromEntries(
    value.entries.map((entry) => MapEntry('${entry.key}', '${entry.value}')),
  );
}

bool _sameStringMap(Map<String, String> a, Map<String, String> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final key in a.keys) {
    if (b[key] != a[key]) {
      return false;
    }
  }
  return true;
}

bool _sameObjectMap(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final key in a.keys) {
    if (!b.containsKey(key) || '${b[key]}' != '${a[key]}') {
      return false;
    }
  }
  return true;
}
