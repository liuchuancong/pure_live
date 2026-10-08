// Module: lib/src/extension.dart
// Purpose: The interface an extension implements and the status view the gateway hands to callers.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md sections 4 and 6, and docs/contracts/platform-models.md
// section 4 for ExtensionStatus. An extension is written by somebody; a handle is what the platform knows
// about it. Only the handle is public API, which is what stops a feature from calling into a runtime's
// internals (docs/architecture/dependency-rules.md forbids UI reaching through the gateway).

import 'package:pure_live_platform/pure_live_platform.dart';

import 'context.dart';
import 'source.dart';

/// What an extension implementation promises the platform.
abstract interface class Extension {
  ExtensionDescriptor get descriptor;

  /// Receives the injection boundary. Anything the extension needs from the platform arrives here and
  /// nowhere else (docs/contracts/platform-contracts.md section 19).
  Future<void> initialize(ExtensionContext context);

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();
}

/// The gateway's view of one extension: identity, which runtime hosts it and where it is in its lifecycle.
final class ExtensionHandle {
  const ExtensionHandle({
    required this.descriptor,
    required this.runtimeId,
    required this.status,
    this.sources = const <Source>[],
  });

  final ExtensionDescriptor descriptor;
  final RuntimeId runtimeId;
  final ExtensionStatus status;

  /// Empty until the extension is loaded: a source list is a property of the running instance, not of the
  /// descriptor.
  final List<Source> sources;

  ExtensionId get id => descriptor.id;

  ExtensionLifecycleState get lifecycle => status.lifecycle;

  RuntimeHealth get health => status.health;

  PlatformErrorInfo? get error => status.error;

  bool get isRunning => lifecycle == ExtensionLifecycleState.running;

  bool get isUsable => lifecycle == ExtensionLifecycleState.ready || lifecycle == ExtensionLifecycleState.running;

  @override
  String toString() => 'ExtensionHandle($id ${lifecycle.name} via $runtimeId)';
}
