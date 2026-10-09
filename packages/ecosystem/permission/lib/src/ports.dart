// Module: lib/src/ports.dart
// Purpose: The narrow ports the permission manager needs: where grants live and who answers a prompt.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 15. The manager must not know about Drift, Hive or a
// settings screen, so both sides are ports here. This is the same shape pure_live_auth uses: an L0 or L1
// package declares the port it needs instead of importing a sibling package.

import 'package:pure_live_platform/pure_live_platform.dart';

/// Where grants are kept.
///
/// A denial is stored as a record rather than as the absence of one: `unknown` may be asked again, while
/// `denied` means somebody already said no.
abstract interface class PermissionStore {
  Future<PermissionGrant?> load(ExtensionId extensionId, Permission permission);

  Future<void> save(PermissionGrant grant);

  Future<void> remove(ExtensionId extensionId, Permission permission);

  Future<List<PermissionGrant>> grantsFor(ExtensionId extensionId);

  /// Everything known about one extension, so removing an extension can clean its grants up.
  Future<void> removeAll(ExtensionId extensionId);
}

/// Grants held in memory; used by tests and by any host that has no persistence yet.
final class InMemoryPermissionStore implements PermissionStore {
  final Map<String, PermissionGrant> _grants = <String, PermissionGrant>{};

  static String _key(ExtensionId extensionId, Permission permission) => '$extensionId/${permission.name}';

  @override
  Future<PermissionGrant?> load(ExtensionId extensionId, Permission permission) async =>
      _grants[_key(extensionId, permission)];

  @override
  Future<void> save(PermissionGrant grant) async {
    _grants[_key(grant.extensionId, grant.permission)] = grant;
  }

  @override
  Future<void> remove(ExtensionId extensionId, Permission permission) async {
    _grants.remove(_key(extensionId, permission));
  }

  @override
  Future<List<PermissionGrant>> grantsFor(ExtensionId extensionId) async =>
      _grants.values.where((grant) => grant.extensionId == extensionId).toList(growable: false);

  @override
  Future<void> removeAll(ExtensionId extensionId) async {
    _grants.removeWhere((_, grant) => grant.extensionId == extensionId);
  }

  /// Count is what a test asserts; the keys are internal.
  int get length => _grants.length;
}

/// Whoever owns the yes-or-no decision: a user prompt, a policy file, or a preset for a built-in source.
abstract interface class PermissionPrompt {
  /// Returns the state to record. Implementations must not widen [requestedScope] on their own; the
  /// manager stores whatever comes back as the bounds of the grant.
  Future<PermissionState> decide(ExtensionDescriptor descriptor, Permission permission, PermissionScope requestedScope);
}

/// Refuses everything. This is the default, so a host that forgets to wire a prompt fails closed rather
/// than opening the network to an extension nobody approved.
final class RejectAllPrompts implements PermissionPrompt {
  const RejectAllPrompts();

  @override
  Future<PermissionState> decide(
    ExtensionDescriptor descriptor,
    Permission permission,
    PermissionScope requestedScope,
  ) async => PermissionState.denied;
}

/// Answers from a fixed table; tests and development hosts use this instead of a dialog. Anything the table
/// does not name is refused, so the table has to be written deliberately.
final class PresetPrompts implements PermissionPrompt {
  const PresetPrompts(this.answers);

  final Map<Permission, PermissionState> answers;

  @override
  Future<PermissionState> decide(
    ExtensionDescriptor descriptor,
    Permission permission,
    PermissionScope requestedScope,
  ) async => answers[permission] ?? PermissionState.denied;
}

/// Answers "nobody has decided yet", which is the state that stays re-askable.
///
/// A durable store changes what a placeholder prompt means: [RejectAllPrompts] answers `denied`, and a stored
/// denial is deliberately never re-prompted (the manager treats it as somebody already having said no). Pair
/// the two and a build without a prompt UI would brick every extension on its first request - a refusal the
/// user never made, kept forever. Until the settings screen exists, refusing without recording is the
/// fail-closed answer that still leaves the question open.
final class UnaskedPrompts implements PermissionPrompt {
  const UnaskedPrompts();

  @override
  Future<PermissionState> decide(
    ExtensionDescriptor descriptor,
    Permission permission,
    PermissionScope requestedScope,
  ) async => PermissionState.unknown;
}

/// Approves exactly what the descriptor declared and nothing else.
///
/// Only safe for sources the platform ships itself: a built-in extension's descriptor is reviewed with the
/// app, so its declaration is already the user's answer.
final class GrantDeclaredPrompts implements PermissionPrompt {
  const GrantDeclaredPrompts();

  @override
  Future<PermissionState> decide(
    ExtensionDescriptor descriptor,
    Permission permission,
    PermissionScope requestedScope,
  ) async => descriptor.permissions.contains(permission) ? PermissionState.granted : PermissionState.denied;
}
