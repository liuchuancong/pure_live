// Module: lib/src/gateway.dart
// Purpose: The ExtensionGateway contract and the error type its transitions throw.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 6 and docs/architecture/platform-infrastructure.md
// section 3. The gateway is the single entrance every extension passes through - registration, discovery,
// type identification, runtime selection, capability and permission setup, lifecycle, isolation, unloading -
// and it holds no business logic at all.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'extension.dart';

/// A gateway refusal: the requested transition is not legal for the current state, or the id is unknown.
///
/// It carries a structured code so a caller can branch on it; the message is for the human reading a log.
final class ExtensionGatewayException implements Exception {
  const ExtensionGatewayException(this.error);

  final PlatformErrorInfo error;

  String get code => error.code;

  factory ExtensionGatewayException.notFound(ExtensionId id) => ExtensionGatewayException(
    PlatformErrorInfo(
      code: PlatformErrorCodes.extensionNotFound,
      message: 'no extension registered under "$id"',
      category: PlatformErrorCategory.extension,
    ),
  );

  /// An extension that is registered but cannot be hosted, or cannot reach a usable state.
  factory ExtensionGatewayException.incompatible(ExtensionId id, String reason) => ExtensionGatewayException(
    PlatformErrorInfo(
      code: PlatformErrorCodes.extensionIncompatible,
      message: 'extension $id is incompatible: $reason',
      category: PlatformErrorCategory.extension,
    ),
  );

  factory ExtensionGatewayException.stateInvalid(
    ExtensionId id,
    String action,
    ExtensionLifecycleState actual,
    Set<ExtensionLifecycleState> required,
  ) => ExtensionGatewayException(
    PlatformErrorInfo(
      code: 'extension.state_invalid',
      message:
          'cannot $action $id while it is ${actual.name}; expected '
          '${required.map((state) => state.name).join(', ')}',
      category: PlatformErrorCategory.extension,
    ),
  );

  factory ExtensionGatewayException.alreadyRegistered(ExtensionId id) => ExtensionGatewayException(
    PlatformErrorInfo(
      code: 'extension.already_registered',
      message: '$id is already registered; unload it before registering another build',
      category: PlatformErrorCategory.extension,
    ),
  );

  factory ExtensionGatewayException.disabled(ExtensionId id) => ExtensionGatewayException(
    PlatformErrorInfo(
      code: 'extension.disabled',
      message: '$id is disabled; re-register it to enable it again',
      category: PlatformErrorCategory.extension,
    ),
  );

  factory ExtensionGatewayException.loadFailed(ExtensionId id, Object cause) => ExtensionGatewayException(
    PlatformErrorInfo(
      code: PlatformErrorCodes.extensionLoadFailed,
      message: 'loading $id failed: $cause',
      category: PlatformErrorCategory.extension,
      retryable: true,
    ),
  );

  @override
  String toString() => 'ExtensionGatewayException(${error.code}: ${error.message})';
}

/// The platform entrance for extensions.
abstract interface class ExtensionGateway {
  /// Discovery, identification and runtime selection in one step.
  ///
  /// Throws [ExtensionGatewayException.incompatible] when no runtime can host the descriptor, which leaves
  /// the extension recorded and inspectable rather than silently dropped.
  Future<void> register(ExtensionDescriptor descriptor);

  Future<void> load(ExtensionId id);

  Future<void> start(ExtensionId id);

  Future<void> stop(ExtensionId id);

  /// Stops, disposes and forgets the extension. Registration is required to bring it back.
  Future<void> unload(ExtensionId id);

  /// Stops and disposes but keeps the record, so a user can turn it off without losing its configuration.
  Future<void> disable(ExtensionId id);

  ExtensionHandle? find(ExtensionId id);

  List<ExtensionHandle> getAll();

  /// Every lifecycle transition, so a management screen and a diagnostic trace share one account of what
  /// happened instead of each polling [find].
  Stream<ExtensionStatus> get changes;
}
