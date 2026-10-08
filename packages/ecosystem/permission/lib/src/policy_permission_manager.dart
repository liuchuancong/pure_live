// Module: lib/src/policy_permission_manager.dart
// Purpose: The minimum-privilege PermissionManager: declared ceiling, stored grants, prompts and host scopes.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 15 and docs/architecture/platform-infrastructure.md
// section 7.2 ("权限默认最小化", network grants carry a host allow-list). Fails closed everywhere it has to
// choose: an unregistered extension, an undeclared permission and a missing prompt all end in a denial.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'permission_manager.dart';
import 'ports.dart';

/// A PermissionManager backed by a [PermissionStore] and answered by a [PermissionPrompt].
final class PolicyPermissionManager implements PermissionManager {
  PolicyPermissionManager({
    required PermissionStore store,
    PermissionPrompt prompt = const RejectAllPrompts(),
    DateTime Function()? clock,
  }) : _store = store,
       _prompt = prompt,
       _clock = clock ?? _utcNow;

  final PermissionStore _store;
  final PermissionPrompt _prompt;
  final DateTime Function() _clock;

  /// The declared ceiling, kept by id. Registration is what makes the ceiling enforceable rather than
  /// advisory, so it is held here and not re-read from a descriptor the caller could swap out.
  final Map<ExtensionId, ExtensionDescriptor> _registered = <ExtensionId, ExtensionDescriptor>{};

  @override
  Future<void> register(ExtensionDescriptor descriptor) async {
    _registered[descriptor.id] = descriptor;
  }

  @override
  Future<PermissionDecision> check(ExtensionId extensionId, Permission permission, {Uri? target}) async {
    final grant = await _store.load(extensionId, permission);
    if (grant == null) {
      return PermissionDecision.deny(
        permission: permission,
        state: PermissionState.unknown,
        reason: '$permission on $extensionId has never been requested',
      );
    }
    if (grant.state != PermissionState.granted) {
      return PermissionDecision.deny(
        permission: permission,
        state: grant.state,
        reason: '$permission on $extensionId is recorded as ${grant.state.name}',
      );
    }
    if (_expired(grant)) {
      // Reported as unknown, not denied: an expiry is a reason to ask again, not a refusal on the merits.
      return PermissionDecision.deny(
        permission: permission,
        state: PermissionState.unknown,
        reason: '$permission on $extensionId expired at ${grant.expiresAt}',
      );
    }
    if (target != null && !grant.scope.allowsUri(target)) {
      return PermissionDecision.deny(
        permission: permission,
        state: PermissionState.restricted,
        reason: '${target.host}${target.path} is outside the grant on $extensionId (${grant.scope})',
      );
    }
    return PermissionDecision.allow(permission: permission, scope: grant.scope);
  }

  @override
  Future<PermissionDecision> request(
    ExtensionId extensionId,
    Permission permission, {
    PermissionScope scope = PermissionScope.unrestricted,
  }) async {
    final descriptor = _registered[extensionId];
    if (descriptor == null) {
      return PermissionDecision.deny(
        permission: permission,
        state: PermissionState.restricted,
        reason: '$extensionId is not registered, so nothing may be granted to it',
      );
    }
    if (!descriptor.permissions.contains(permission)) {
      return PermissionDecision.deny(
        permission: permission,
        state: PermissionState.restricted,
        reason: '$permission is not declared by $extensionId; a prompt cannot widen a descriptor',
      );
    }

    final existing = await _store.load(extensionId, permission);
    if (existing != null && existing.state == PermissionState.denied) {
      return PermissionDecision.deny(
        permission: permission,
        state: PermissionState.denied,
        reason: 'a refusal for $permission is already recorded on $extensionId',
      );
    }

    final held = existing != null && existing.state == PermissionState.granted && !_expired(existing);
    if (held && _covers(existing.scope, scope)) {
      return PermissionDecision.allow(permission: permission, scope: existing.scope);
    }

    final state = await _prompt.decide(descriptor, permission, scope);
    if (state != PermissionState.granted) {
      await _store.save(_record(extensionId, permission, state, PermissionScope.unrestricted));
      return PermissionDecision.deny(
        permission: permission,
        state: state,
        reason: 'the request for $permission on $extensionId was answered ${state.name}',
      );
    }

    // A widening request merges instead of replacing: an extension approved for two hosts must not lose
    // the first one because it asked for the second.
    final merged = held ? _merge(existing.scope, scope) : scope;
    await _store.save(_record(extensionId, permission, PermissionState.granted, merged));
    return PermissionDecision.allow(permission: permission, scope: merged);
  }

  @override
  Future<void> revoke(ExtensionId extensionId, Permission permission) => _store.remove(extensionId, permission);

  @override
  Future<void> refuse(ExtensionId extensionId, Permission permission) async {
    await _store.save(_record(extensionId, permission, PermissionState.denied, PermissionScope.unrestricted));
  }

  @override
  Future<Set<Permission>> held(ExtensionId extensionId) async {
    final now = _clock();
    final grants = await _store.grantsFor(extensionId);
    return grants
        .where((grant) => grant.state == PermissionState.granted && grant.isEffectiveAt(now))
        .map((grant) => grant.permission)
        .toSet();
  }

  /// Grants created here carry no expiry: the prompt answers a state, and a credential that rotates on its
  /// own (a token, a cookie jar) is the writer that knows a deadline. [check] honours one either way.
  PermissionGrant _record(
    ExtensionId extensionId,
    Permission permission,
    PermissionState state,
    PermissionScope scope,
  ) {
    return PermissionGrant(
      extensionId: extensionId,
      permission: permission,
      state: state,
      grantedAt: _clock(),
      scope: scope,
    );
  }

  bool _expired(PermissionGrant grant) {
    final expiry = grant.expiresAt;
    return expiry != null && !_clock().toUtc().isBefore(expiry);
  }

  /// Whether an already held grant reaches everything [asked] wants.
  static bool _covers(PermissionScope stored, PermissionScope asked) {
    if (!stored.isHostLimited) {
      return true;
    }
    if (asked.hosts.any((host) => !stored.allowsHost(host))) {
      return false;
    }
    if (stored.paths.isEmpty) {
      return true;
    }
    return asked.paths.every((prefix) => stored.paths.any(prefix.startsWith));
  }

  static PermissionScope _merge(PermissionScope stored, PermissionScope asked) {
    final hosts = stored.isHostLimited && asked.isHostLimited
        ? <String>{...stored.hosts, ...asked.hosts}
        : const <String>{};
    final paths = stored.paths.isEmpty || asked.paths.isEmpty
        ? const <String>{}
        : <String>{...stored.paths, ...asked.paths};
    return PermissionScope(
      hosts: hosts,
      paths: paths,
      constraints: <String, Object?>{...stored.constraints, ...asked.constraints},
    );
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}
