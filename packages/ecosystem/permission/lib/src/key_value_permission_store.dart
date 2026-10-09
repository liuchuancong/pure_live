// Module: lib/src/key_value_permission_store.dart
// Purpose: Keep permission grants in a KeyValueStore so an answer survives a restart.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-contracts.md section 15 (grants belong to the platform, not to a plugin) and
// the port's own rule in ports.dart: a denial is a record, not an absence. The store is a KeyValueStore so the
// composition root decides the backend (file today, Drift if it ever needs one) and this package stays free of
// both Flutter and a database.

import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_storage/pure_live_storage.dart';

import 'ports.dart';

/// A [PermissionStore] over one [KeyValueStore].
///
/// Keys are `permission.<extensionId>/<permissionName>`. The separator is `/` rather than `.` on purpose:
/// extension ids are dotted, so a prefix scan on `permission.purelive.a.` would also match
/// `permission.purelive.ab.network` and let one extension's removal reach another's grants.
final class KeyValuePermissionStore implements PermissionStore {
  KeyValuePermissionStore(this.store, {this.namespace = 'permission'});

  final KeyValueStore store;

  /// The leading segment. A host that keeps several kinds of record in one store gives each its own namespace.
  final String namespace;

  String _key(ExtensionId extensionId, Permission permission) => '$namespace.$extensionId/${permission.name}';

  String _prefixFor(ExtensionId extensionId) => '$namespace.$extensionId/';

  @override
  Future<PermissionGrant?> load(ExtensionId extensionId, Permission permission) async {
    final key = _key(extensionId, permission);
    final raw = await store.read(key);
    if (raw == null) {
      return null;
    }
    if (raw is! Map) {
      // A record nobody can read is not a grant, and leaving it in place would re-offend on every load.
      // Dropping it returns the permission to "never asked", which is the state that can be asked again.
      await store.remove(key);
      return null;
    }
    return PermissionGrant.fromJson(Map<String, Object?>.from(raw));
  }

  @override
  Future<void> save(PermissionGrant grant) => store.write(_key(grant.extensionId, grant.permission), grant.toJson());

  @override
  Future<void> remove(ExtensionId extensionId, Permission permission) => store.remove(_key(extensionId, permission));

  @override
  Future<List<PermissionGrant>> grantsFor(ExtensionId extensionId) async {
    final prefix = _prefixFor(extensionId);
    final grants = <PermissionGrant>[];
    for (final key in await store.keys()) {
      if (!key.startsWith(prefix)) {
        continue;
      }
      final raw = await store.read(key);
      if (raw is Map) {
        grants.add(PermissionGrant.fromJson(Map<String, Object?>.from(raw)));
      } else {
        await store.remove(key);
      }
    }
    return grants;
  }

  @override
  Future<void> removeAll(ExtensionId extensionId) async {
    final prefix = _prefixFor(extensionId);
    for (final key in await store.keys()) {
      if (key.startsWith(prefix)) {
        await store.remove(key);
      }
    }
  }
}
