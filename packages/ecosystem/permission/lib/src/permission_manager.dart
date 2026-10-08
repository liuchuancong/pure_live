// Module: lib/src/permission_manager.dart
// Purpose: The permission decision type and the PermissionManager contract the platform answers through.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 15 and docs/architecture/platform-infrastructure.md
// section 7.2. The contract is deliberately narrow: check, request, revoke. Everything else in the
// permission subsystem is an implementation of these three.

import 'package:pure_live_platform/pure_live_platform.dart';

/// The outcome of one permission question.
///
/// A denial always carries a reason: an unexplained "no" cannot be shown to the user, cannot be logged
/// usefully and cannot be fixed by the extension author.
final class PermissionDecision {
  const PermissionDecision.allow({required this.permission, this.scope = PermissionScope.unrestricted, this.reason})
    : allowed = true,
      state = PermissionState.granted;

  const PermissionDecision.deny({required this.permission, required this.state, required this.reason})
    : allowed = false,
      scope = PermissionScope.unrestricted;

  final bool allowed;
  final Permission permission;

  /// Why the answer is what it is, in the caller's terms: `denied` means it was refused, `restricted`
  /// means the extension never had standing to ask, `unknown` means nobody has been asked yet.
  final PermissionState state;

  /// The bounds that apply when the answer is yes. An allowed decision with a host-limited scope is not a
  /// blanket grant.
  final PermissionScope scope;
  final String? reason;

  /// Structured code so a caller can build a PlatformErrorInfo without parsing text
  /// (docs/contracts/platform-models.md section 14).
  String get code => switch (state) {
    PermissionState.restricted => PlatformErrorCodes.permissionRestricted,
    _ => PlatformErrorCodes.permissionDenied,
  };

  PlatformErrorInfo toErrorInfo() => PlatformErrorInfo(
    code: code,
    message: reason ?? 'permission ${permission.name} is not available',
    category: PlatformErrorCategory.permission,
    retryable: false,
    recoverable: state == PermissionState.unknown,
  );

  @override
  String toString() =>
      'PermissionDecision(${allowed ? 'allow' : 'deny'} ${permission.name}${scope.isHostLimited ? ' $scope' : ''})';
}

/// Who holds what, and what happens when someone asks.
abstract interface class PermissionManager {
  /// Records the ceiling an extension may ever reach.
  ///
  /// Registration is what makes minimum privilege enforceable: an extension can only be granted a
  /// permission its descriptor declared, so a source that never asked for `cookie` cannot get one later by
  /// finding a prompt it likes.
  Future<void> register(ExtensionDescriptor descriptor);

  /// Whether [permission] is held now. Pass [target] to ask about one specific host or path.
  Future<PermissionDecision> check(ExtensionId extensionId, Permission permission, {Uri? target});

  /// Asks for [permission]. A request outside the declared ceiling is refused without prompting, because
  /// prompting would let an extension talk its way past its own descriptor.
  Future<PermissionDecision> request(ExtensionId extensionId, Permission permission, {PermissionScope scope});

  /// Drops the grant so the next request starts from unknown.
  Future<void> revoke(ExtensionId extensionId, Permission permission);

  /// Records a refusal, which sticks: an explicit no is not re-asked on the next retry loop.
  Future<void> refuse(ExtensionId extensionId, Permission permission);

  /// The permissions currently held, so a management screen and a diagnostics dump agree on one answer.
  Future<Set<Permission>> held(ExtensionId extensionId);
}
