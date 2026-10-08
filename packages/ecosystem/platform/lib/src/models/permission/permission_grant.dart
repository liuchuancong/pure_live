// Module: lib/src/models/permission/permission_grant.dart
// Purpose: The permission state a source holds: its scope, its grant record and its expiry.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-models.md section 12. The Permission enum itself is declared in
// extension/extension_descriptor.dart because the descriptor carries it; this file holds the state, scope
// and grant records the permission subsystem stores. docs/architecture/platform-infrastructure.md section
// 7.2 sets the rule these records exist to serve: permissions default to least privilege, and a network
// grant names hosts rather than opening the whole internet.

import '../../support/json.dart';
import '../extension/extension_descriptor.dart';
import '../identifiers.dart';

/// Whether a permission is held. `unknown` means nobody has decided yet, which is not the same as denied:
/// a request prompt is allowed for unknown, never for an explicit denial.
enum PermissionState { unknown, denied, granted, restricted }

/// The bounds of a grant.
///
/// An empty [hosts] means the grant is not host limited. That is legal but only for a source the platform
/// trusts wholesale, so the readers treat "no hosts" as a deliberate widening rather than a default.
final class PermissionScope {
  const PermissionScope({
    this.hosts = const <String>{},
    this.paths = const <String>{},
    this.constraints = const <String, Object?>{},
  });

  factory PermissionScope.fromJson(Map<String, Object?> json) => PermissionScope(
    hosts: _stringSet(json['hosts']),
    paths: _stringSet(json['paths']),
    constraints: asObjectMap(json['constraints']),
  );

  /// Hosts the grant covers. A `*.example.com` entry covers any subdomain and not the apex; a bare
  /// `example.com` covers only that host.
  final Set<String> hosts;

  /// Path prefixes the grant covers, when the protocol only needs one area of a host.
  final Set<String> paths;

  /// Numeric or flag limits carried with the grant, for example a response size cap.
  final Map<String, Object?> constraints;

  static const PermissionScope unrestricted = PermissionScope();

  bool get isHostLimited => hosts.isNotEmpty;

  /// Whether [uri] falls inside the host and path bounds.
  bool allowsUri(Uri uri) {
    final host = uri.host.toLowerCase();
    if (host.isEmpty || !allowsHost(host)) {
      return false;
    }
    if (paths.isEmpty) {
      return true;
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    return paths.any(path.startsWith);
  }

  bool allowsHost(String host) {
    if (hosts.isEmpty) {
      return true;
    }
    final lower = host.toLowerCase();
    for (final entry in hosts) {
      final pattern = entry.toLowerCase();
      if (pattern.startsWith('*.')) {
        // A wildcard covers subdomains only; the apex has to be listed as well to be reachable.
        if (lower.endsWith(pattern.substring(1))) {
          return true;
        }
      } else if (pattern == lower) {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (hosts.isNotEmpty) 'hosts': hosts.toList(growable: false),
    if (paths.isNotEmpty) 'paths': paths.toList(growable: false),
    if (constraints.isNotEmpty) 'constraints': constraints,
  };

  @override
  String toString() => 'PermissionScope(hosts:${hosts.isEmpty ? '*' : hosts.join(',')})';

  @override
  bool operator ==(Object other) {
    return other is PermissionScope &&
        other.hosts.length == hosts.length &&
        other.hosts.containsAll(hosts) &&
        other.paths.length == paths.length &&
        other.paths.containsAll(paths) &&
        _sameConstraints(other.constraints, constraints);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(hosts),
    Object.hashAllUnordered(paths),
    Object.hashAllUnordered(constraints.keys),
  );
}

/// One held permission for one extension.
final class PermissionGrant {
  const PermissionGrant({
    required this.extensionId,
    required this.permission,
    required this.state,
    this.grantedAt,
    this.expiresAt,
    this.scope = PermissionScope.unrestricted,
  });

  factory PermissionGrant.fromJson(Map<String, Object?> json) => PermissionGrant(
    extensionId: requireString(json, 'extensionId', 'permission_grant'),
    permission: _requirePermission(json['permission']),
    state: enumByName(PermissionState.values, json['state'] as String?) ?? PermissionState.unknown,
    grantedAt: parseUtc(json['grantedAt']),
    expiresAt: parseUtc(json['expiresAt']),
    scope: PermissionScope.fromJson(asObjectMap(json['scope'])),
  );

  final ExtensionId extensionId;
  final Permission permission;
  final PermissionState state;
  final DateTime? grantedAt;

  /// When the grant stops applying. A cookie or token rotation shows up as an expiry here rather than as a
  /// deleted row, so a source can re-request instead of silently losing the capability.
  final DateTime? expiresAt;
  final PermissionScope scope;

  /// Whether the grant is usable at [now]. Only an explicit `granted` counts; `unknown` and `restricted`
  /// both have to go back through the request path.
  bool isEffectiveAt(DateTime now, {Uri? target}) {
    if (state != PermissionState.granted) {
      return false;
    }
    final expiry = expiresAt;
    if (expiry != null && !now.toUtc().isBefore(expiry)) {
      return false;
    }
    return target == null || scope.allowsUri(target);
  }

  PermissionGrant asDenied() => PermissionGrant(
    extensionId: extensionId,
    permission: permission,
    state: PermissionState.denied,
    grantedAt: grantedAt,
    scope: scope,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'extensionId': extensionId,
    'permission': permission.name,
    'state': state.name,
    if (grantedAt != null) 'grantedAt': formatUtc(grantedAt),
    if (expiresAt != null) 'expiresAt': formatUtc(expiresAt),
    'scope': scope.toJson(),
  };

  @override
  String toString() => 'PermissionGrant($extensionId/${permission.name}=${state.name})';

  /// A grant is keyed by who holds it and what it covers; a rotated expiry is the same record.
  @override
  bool operator ==(Object other) {
    return other is PermissionGrant &&
        other.extensionId == extensionId &&
        other.permission == permission &&
        other.state == state &&
        other.expiresAt == expiresAt &&
        other.scope == scope;
  }

  @override
  int get hashCode => Object.hash(extensionId, permission, state, expiresAt, scope);
}

Set<String> _stringSet(Object? value) {
  if (value is! List) {
    return const <String>{};
  }
  return value.map((item) => '$item').where((item) => item.isNotEmpty).toSet();
}

/// An unrecognised permission name must not fall back to a known one: defaulting a corrupt record to
/// `network` would hand a source the widest capability exactly when its data is untrustworthy.
Permission _requirePermission(Object? value) {
  final found = enumByName(Permission.values, '$value');
  if (found == null) {
    throw FormatException('permission_grant has unknown permission "${value}"');
  }
  return found;
}

/// Compares the small numeric or flag limits a scope carries. A constraint whose value changed is a
/// different grant, so this cannot be a key-count comparison.
bool _sameConstraints(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) {
    return false;
  }
  return a.entries.every((entry) => b.containsKey(entry.key) && '${b[entry.key]}' == '${entry.value}');
}
