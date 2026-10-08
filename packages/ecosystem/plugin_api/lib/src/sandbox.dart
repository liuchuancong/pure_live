// Module: lib/src/sandbox.dart
// Purpose: The isolation boundary a scripted plugin executes inside, and what it is never allowed to touch.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/security/plugin-sandbox.md and docs/architecture/platform-infrastructure.md section 7.2.
// Interfaces only in this wave: the engine is fjs (Rust + QuickJS) and its host lands with the plugin host
// in W10, so nothing here pretends to enforce a limit yet. What is decided now is the shape the engine has
// to fit, which is the part that is expensive to change later.

import 'package:pure_live_platform/pure_live_platform.dart';

/// What a sandbox refuses outright, regardless of what a plugin declared.
enum SandboxDenial { filesystem, process, nativeApi, foreignFunctionInterface, systemCommand, arbitrarySocket }

/// The bounds one sandbox instance enforces.
final class SandboxPolicy {
  const SandboxPolicy({this.limits = const SandboxLimits(), this.denials = defaultDenials});

  /// platform-infrastructure.md section 7.2: a scripted source is denied file system, processes, native API,
  /// FFI, system commands and arbitrary sockets by default. A host that allows fewer can narrow it; the list
  /// is what "the platform decided this, not the plugin" looks like.
  static const Set<SandboxDenial> defaultDenials = <SandboxDenial>{
    SandboxDenial.filesystem,
    SandboxDenial.process,
    SandboxDenial.nativeApi,
    SandboxDenial.foreignFunctionInterface,
    SandboxDenial.systemCommand,
    SandboxDenial.arbitrarySocket,
  };

  final SandboxLimits limits;
  final Set<SandboxDenial> denials;

  bool allows(SandboxDenial capability) => !denials.contains(capability);
}

/// Numeric bounds on one execution.
final class SandboxLimits {
  const SandboxLimits({
    this.timeout = const Duration(seconds: 10),
    this.maxOutputBytes = 1024 * 1024,
    this.maxConcurrentScripts = 2,
  });

  /// A script that passes it is marked degraded rather than left running (plugin-lifecycle.md section 2).
  final Duration timeout;

  /// An oversized answer is treated as a fault: a spider that returns 40 MB is not a plugin the app should
  /// hold in memory.
  final int maxOutputBytes;

  /// Per plugin, so one looping script cannot occupy every worker.
  final int maxConcurrentScripts;
}

/// Why an execution did not produce an answer.
enum SandboxFailure { none, threw, timedOut, outputTooLarge, crashed }

/// One script the sandbox can run.
final class SandboxUnit {
  const SandboxUnit({required this.pluginId, required this.key, required this.source});

  final ExtensionId pluginId;

  /// Which entry point inside the plugin, for example `spider.cateContent`.
  final String key;
  final String source;
}

/// What an execution returned.
final class SandboxOutcome {
  const SandboxOutcome({required this.failure, required this.elapsed, this.value, this.message});

  static const SandboxOutcome empty = SandboxOutcome(failure: SandboxFailure.none, elapsed: Duration.zero);

  final SandboxFailure failure;
  final Duration elapsed;
  final String? value;

  /// A short description of the fault, already free of script internals the host should not log.
  final String? message;

  bool get isClean => failure == SandboxFailure.none;

  /// Anything but a clean answer counts against the plugin's failure budget.
  bool get shouldDegrade => !isClean;

  @override
  String toString() => 'SandboxOutcome(${failure.name}, ${elapsed.inMilliseconds}ms)';
}

/// An isolated interpreter instance for one plugin.
abstract interface class ScriptSandbox {
  SandboxPolicy get policy;

  /// Runs one unit. A plugin crash must be reported here, never propagate into the app's isolate.
  Future<SandboxOutcome> evaluate(SandboxUnit unit);

  /// Releases the interpreter and anything it holds.
  Future<void> dispose();
}

/// Creates sandboxes. The host owns this so a plugin cannot choose its own isolation level.
abstract interface class ScriptSandboxFactory {
  Future<ScriptSandbox> create(ExtensionId pluginId, {SandboxPolicy policy});
}
