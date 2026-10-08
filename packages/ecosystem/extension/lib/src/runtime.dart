// Module: lib/src/runtime.dart
// Purpose: The runtime contract - how a protocol family is recognised and how one extension is loaded by it.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 7. Two deliberate differences from the sketch there:
// a runtime answers with its RuntimeDescriptor instead of bare id and version, because selection needs the
// protocol set and the supported extension types anyway; and load() takes the ExtensionContext, because the
// runtime is what constructs the extension and section 19 forbids any other route to a platform service.

import 'package:pure_live_platform/pure_live_platform.dart';

import 'context.dart';
import 'source.dart';

/// One protocol family the platform can host: a PureLive plugin runtime, a TVBox runtime, M3U, XMLTV.
abstract interface class ExtensionRuntime {
  RuntimeDescriptor get descriptor;

  /// Type identification, not preference: whether this runtime understands [descriptor] at all.
  bool canHandle(ExtensionDescriptor descriptor);

  /// Creates the instance for [descriptor]. Anything the instance reaches must come through [context].
  Future<RuntimeInstance> load(ExtensionDescriptor descriptor, ExtensionContext context);
}

/// A loaded extension as the runtime sees it.
abstract interface class RuntimeInstance {
  ExtensionDescriptor get descriptor;

  /// Called after load and before start: build the repository, read the manifest, warm the index.
  Future<void> initialize();

  Future<void> start();

  Future<void> stop();

  Future<void> dispose();

  /// The sources this instance serves. A runtime that hosts user-configured sources returns more than one.
  List<Source> get sources;
}

/// The set of runtimes the gateway may choose from, in preference order.
final class RuntimeRegistry {
  RuntimeRegistry([Iterable<ExtensionRuntime> runtimes = const <ExtensionRuntime>[]])
    : _runtimes = List<ExtensionRuntime>.of(runtimes);

  List<ExtensionRuntime> _runtimes;

  List<ExtensionRuntime> get all => _runtimes;

  /// Adds a runtime at the end. A second runtime with the same id replaces the first, which is how a host
  /// upgrades a protocol implementation without restarting.
  void register(ExtensionRuntime runtime) {
    _runtimes = <ExtensionRuntime>[
      ..._runtimes.where((existing) => existing.descriptor.id != runtime.descriptor.id),
      runtime,
    ];
  }

  /// The first runtime that understands [descriptor]; null means the platform cannot host it at all.
  ExtensionRuntime? select(ExtensionDescriptor descriptor) {
    for (final runtime in _runtimes) {
      if (runtime.canHandle(descriptor)) {
        return runtime;
      }
    }
    return null;
  }

  ExtensionRuntime? byId(RuntimeId id) {
    for (final runtime in _runtimes) {
      if (runtime.descriptor.id == id) {
        return runtime;
      }
    }
    return null;
  }
}
