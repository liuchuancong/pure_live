// Module: lib/src/managed_extension_gateway.dart
// Purpose: The ExtensionGateway implementation: runtime selection, the lifecycle machine and the context it injects.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md sections 4-8 and section 19, plus
// docs/architecture/platform-infrastructure.md section 3 for the transition order
// (DISCOVER -> IDENTIFY -> SELECT RUNTIME -> LOAD -> VALIDATE -> REGISTER -> READY -> RUNNING -> DISABLE -> UNLOAD,
// with LOAD -> ERROR -> DIAGNOSTICS -> RETRY / DISABLE as the failure branch).
//
// What this class deliberately does not do: no business logic, no repository or provider construction, no
// knowledge of any protocol. It moves state, chooses a runtime, hands out one context per extension and
// reports - which is what keeps the isolation boundaries (extension, runtime, task, network, permission) real.

import 'dart:async';

import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_task/pure_live_task.dart';

import 'context.dart';
import 'extension.dart';
import 'gateway.dart';
import 'runtime.dart';
import 'source.dart';

/// A gateway that owns the lifecycle machine and hands each extension one scoped [ExtensionContext].
final class ManagedExtensionGateway implements ExtensionGateway {
  ManagedExtensionGateway({
    required RuntimeRegistry runtimes,
    required PermissionManager permissions,
    required ExtensionNetwork network,
    required ExtensionCookieStore cookies,
    required TaskScheduler tasks,
    DiagnosticTracer? diagnostics,
    this.supportedApiVersions = const <String>{},
  }) : _runtimes = runtimes,
       _permissions = permissions,
       _network = network,
       _cookies = cookies,
       _tasks = tasks,
       _diagnostics = diagnostics;

  final RuntimeRegistry _runtimes;
  final PermissionManager _permissions;
  final ExtensionNetwork _network;
  final ExtensionCookieStore _cookies;
  final TaskScheduler _tasks;

  /// The platform API revisions this build accepts. Empty means no check, which is the right default for a
  /// single-version app and the wrong default as soon as a plugin can declare one.
  final Set<String> supportedApiVersions;

  /// Created lazily when something actually reports, so a gateway that never emits allocates no buffer.
  DiagnosticTracer? _diagnostics;
  DiagnosticTracer get diagnostics => _diagnostics ??= InMemoryDiagnosticTracer();

  final Map<ExtensionId, _Record> _records = <ExtensionId, _Record>{};
  final StreamController<ExtensionStatus> _changes = StreamController<ExtensionStatus>.broadcast();

  @override
  Stream<ExtensionStatus> get changes => _changes.stream;

  @override
  Future<void> register(ExtensionDescriptor descriptor) async {
    final id = descriptor.id;
    if (_records[id] != null) {
      throw ExtensionGatewayException.alreadyRegistered(id);
    }

    if (supportedApiVersions.isNotEmpty && !supportedApiVersions.contains(descriptor.platformApiVersion)) {
      _record(
        descriptor,
        runtimeId: 'none',
        state: ExtensionLifecycleState.incompatible,
        error: ExtensionGatewayException.incompatible(
          id,
          'it asks for platform API "${descriptor.platformApiVersion}" and this build supports '
          '${supportedApiVersions.join(', ')}',
        ).error,
      );
      throw ExtensionGatewayException.incompatible(
        id,
        'unsupported platform API version "${descriptor.platformApiVersion}"',
      );
    }

    final runtime = _runtimes.select(descriptor);
    if (runtime == null) {
      _record(
        descriptor,
        runtimeId: 'none',
        state: ExtensionLifecycleState.incompatible,
        error: ExtensionGatewayException.incompatible(id, 'no runtime handles protocol "${descriptor.protocol}"').error,
      );
      throw ExtensionGatewayException.incompatible(id, 'no runtime for protocol "${descriptor.protocol}"');
    }

    _record(descriptor, runtimeId: runtime.descriptor.id, state: ExtensionLifecycleState.identified);
    // The permission ceiling is set here, before anything runs: an extension that cannot be identified can
    // not hold permissions either, but a hosted one has its ceiling from its first instruction.
    await _permissions.register(descriptor);
    diagnostics.emit(
      'extension.registered',
      extensionId: id,
      metadata: <String, Object?>{'runtime': runtime.descriptor.id},
    );
  }

  @override
  Future<void> load(ExtensionId id) async {
    final record = _require(id);
    if (record.state == ExtensionLifecycleState.disabled) {
      throw ExtensionGatewayException.disabled(id);
    }
    // platform-infrastructure.md section 3 puts RETRY on the ERROR branch, so a failed load may be retried;
    // anything the failed attempt left behind is released before the runtime is asked again.
    _requireState(id, record, 'load', const <ExtensionLifecycleState>{
      ExtensionLifecycleState.identified,
      ExtensionLifecycleState.error,
    });
    if (record.state == ExtensionLifecycleState.error) {
      await _teardown(record);
      record.instance = null;
    }
    final runtime = record.runtime;
    if (runtime == null) {
      // Only reachable if a record was written without a selection, which is the incompatible branch.
      throw ExtensionGatewayException.incompatible(id, 'no runtime was selected for it');
    }

    _transition(record, ExtensionLifecycleState.loading);
    final RuntimeInstance instance;
    try {
      instance = await runtime.load(record.descriptor, _contextFor(record));
    } catch (error) {
      _fail(record, ExtensionGatewayException.loadFailed(id, error).error);
      throw ExtensionGatewayException.loadFailed(id, error);
    }
    record.instance = instance;

    _transition(record, ExtensionLifecycleState.validating);
    try {
      await instance.initialize();
    } catch (error) {
      await _disposeQuietly(instance);
      record.instance = null;
      _fail(record, ExtensionGatewayException.loadFailed(id, error).error);
      throw ExtensionGatewayException.loadFailed(id, error);
    }
    _transition(record, ExtensionLifecycleState.ready);
  }

  @override
  Future<void> start(ExtensionId id) async {
    final record = _require(id);
    _requireState(id, record, 'start', const <ExtensionLifecycleState>{ExtensionLifecycleState.ready});
    try {
      await record.instance!.start();
    } catch (error) {
      _fail(record, ExtensionGatewayException.loadFailed(id, error).error);
      throw ExtensionGatewayException.loadFailed(id, error);
    }
    _transition(record, ExtensionLifecycleState.running);
  }

  @override
  Future<void> stop(ExtensionId id) async {
    final record = _require(id);
    _requireState(id, record, 'stop', const <ExtensionLifecycleState>{ExtensionLifecycleState.running});
    _transition(record, ExtensionLifecycleState.stopping);
    try {
      await record.instance!.stop();
    } catch (error) {
      _fail(record, ExtensionGatewayException.loadFailed(id, error).error);
      throw ExtensionGatewayException.loadFailed(id, error);
    }
    _transition(record, ExtensionLifecycleState.ready);
  }

  @override
  Future<void> disable(ExtensionId id) async {
    final record = _require(id);
    await _teardown(record);
    _transition(record, ExtensionLifecycleState.disabled);
    record.instance = null;
    diagnostics.emit('extension.disabled', extensionId: id, level: DiagnosticLevel.warning);
  }

  @override
  Future<void> unload(ExtensionId id) async {
    final record = _require(id);
    await _teardown(record);
    record.instance = null;
    _transition(record, ExtensionLifecycleState.unloaded);
    _records.remove(id);
    diagnostics.emit('extension.unloaded', extensionId: id);
  }

  @override
  ExtensionHandle? find(ExtensionId id) => _records[id]?.handle;

  @override
  List<ExtensionHandle> getAll() => _records.values.map((record) => record.handle).toList(growable: false);

  /// Builds the one injection boundary this extension will ever get, with cache and storage views scoped
  /// to it, so isolation does not depend on the extension naming its own namespace correctly.
  ExtensionContext _contextFor(_Record record) {
    return ExtensionContext(
      descriptor: record.descriptor,
      network: _network,
      cookies: _cookies,
      permissions: _permissions,
      tasks: _tasks,
      cache: record.cache,
      storage: record.storage,
      diagnostics: diagnostics,
    );
  }

  Future<void> _teardown(_Record record) async {
    final instance = record.instance;
    if (instance == null) {
      return;
    }
    if (record.state == ExtensionLifecycleState.running) {
      try {
        await instance.stop();
      } catch (_) {
        // A stop that fails still has to be disposed; leaking the instance would be worse than the log line.
      }
    }
    await _disposeQuietly(instance);
  }

  Future<void> _disposeQuietly(RuntimeInstance instance) async {
    try {
      await instance.dispose();
    } catch (_) {
      // Dispose failures are recorded by the caller's state change, not propagated over the original error.
    }
  }

  _Record _require(ExtensionId id) {
    final record = _records[id];
    if (record == null) {
      throw ExtensionGatewayException.notFound(id);
    }
    return record;
  }

  void _requireState(ExtensionId id, _Record record, String action, Set<ExtensionLifecycleState> allowed) {
    if (!allowed.contains(record.state)) {
      throw ExtensionGatewayException.stateInvalid(id, action, record.state, allowed);
    }
  }

  void _transition(_Record record, ExtensionLifecycleState state, {PlatformErrorInfo? error}) {
    record.state = state;
    record.error = error ?? (state == ExtensionLifecycleState.error ? record.error : null);
    _emitStatus(record);
  }

  /// Every state change is one status on the stream and one event in the tracer, so a management screen and
  /// a diagnostic report cannot disagree about what the gateway did.
  void _emitStatus(_Record record) {
    if (!_changes.isClosed) {
      _changes.add(record.status);
    }
    diagnostics.emit(
      'extension.${record.state.name}',
      extensionId: record.id,
      level: switch (record.state) {
        ExtensionLifecycleState.error || ExtensionLifecycleState.incompatible => DiagnosticLevel.error,
        _ => DiagnosticLevel.info,
      },
      error: record.error,
    );
  }

  void _fail(_Record record, PlatformErrorInfo error) {
    record.error = error;
    _transition(record, ExtensionLifecycleState.error, error: error);
  }

  void _record(
    ExtensionDescriptor descriptor, {
    required RuntimeId runtimeId,
    required ExtensionLifecycleState state,
    PlatformErrorInfo? error,
  }) {
    final entry = _Record(descriptor: descriptor, runtime: _runtimes.byId(runtimeId), runtimeId: runtimeId);
    entry.state = state;
    entry.error = error;
    _records[descriptor.id] = entry;
    _emitStatus(entry);
  }
}

/// The gateway's bookkeeping for one registered extension.
class _Record {
  _Record({required this.descriptor, required this.runtime, required this.runtimeId});

  final ExtensionDescriptor descriptor;
  final ExtensionRuntime? runtime;
  final RuntimeId runtimeId;

  /// Scoped views: created with the record and dropped with it, so a reloaded extension does not inherit
  /// the previous run's cached rows.
  final ExtensionCache cache = InMemoryExtensionCache();
  final ExtensionStorage storage = InMemoryExtensionStorage();

  RuntimeInstance? instance;
  ExtensionLifecycleState state = ExtensionLifecycleState.discovered;
  PlatformErrorInfo? error;

  ExtensionId get id => descriptor.id;

  ExtensionStatus get status =>
      ExtensionStatus(extensionId: id, lifecycle: state, health: _healthOf(state), error: error);

  ExtensionHandle get handle => ExtensionHandle(
    descriptor: descriptor,
    runtimeId: runtimeId,
    status: status,
    sources: instance?.sources ?? const <Source>[],
  );

  /// Ready and running are healthy; a failed, incompatible, disabled or gone extension is unavailable;
  /// everything in between is still arriving.
  static RuntimeHealth _healthOf(ExtensionLifecycleState state) => switch (state) {
    ExtensionLifecycleState.ready || ExtensionLifecycleState.running => RuntimeHealth.healthy,
    ExtensionLifecycleState.error ||
    ExtensionLifecycleState.incompatible ||
    ExtensionLifecycleState.disabled ||
    ExtensionLifecycleState.unloaded => RuntimeHealth.unavailable,
    _ => RuntimeHealth.degraded,
  };
}
