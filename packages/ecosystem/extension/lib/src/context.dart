// Module: lib/src/context.dart
// Purpose: The injection boundary an extension is given: network, cookies, permissions, tasks, cache, storage and diagnostics.
// Author: liuchuancong
// Created: 2026-10-08
//
// Spec: docs/contracts/platform-contracts.md section 19. The rule behind this type is that an extension has
// no other way to reach a platform service: GlobalPlayerService, GlobalRouter, GlobalDatabase,
// GlobalCookieStore, GlobalHttpClient and GlobalSettings are all forbidden, so anything an extension needs
// arrives through this context or not at all.
//
// The views are scoped per extension by construction: the cache and the cookie jar are objects created for
// one ExtensionId, so isolation does not depend on a caller passing the right namespace string.

import 'package:pure_live_diagnostics/pure_live_diagnostics.dart';
import 'package:pure_live_permission/pure_live_permission.dart';
import 'package:pure_live_platform/pure_live_platform.dart';
import 'package:pure_live_task/pure_live_task.dart';

/// Per-extension key/value cache.
abstract interface class ExtensionCache {
  Future<Object?> read(String key);

  /// [ttl] bounds how long the entry may be served. A host without a clock policy still has to answer the
  /// question, so the value is carried rather than silently dropped.
  Future<void> write(String key, Object? value, {Duration? ttl});

  Future<void> remove(String key);

  Future<List<String>> keys();

  Future<void> clear();
}

/// Per-extension persistent settings, kept separate from the cache because it survives a clear.
abstract interface class ExtensionStorage {
  Future<Object?> read(String key);

  Future<void> write(String key, Object? value);

  Future<void> remove(String key);

  Future<List<String>> keys();
}

/// The diagnostic sink an extension reports through.
///
/// Implementations must redact credential-bearing values before storing anything
/// (docs/contracts/platform-models.md section 16); [DiagnosticEvent] carries a name and metadata rather
/// than a raw request so that rule has one place to live.
abstract interface class DiagnosticTracer {
  /// Records one event exactly as given.
  void record(DiagnosticEvent event);

  /// Builds and records an event, so every reporter does not invent its own id and timestamp.
  void emit(
    String name, {
    ExtensionId? extensionId,
    DiagnosticLevel level = DiagnosticLevel.info,
    PlatformErrorInfo? error,
    Map<String, Object?> metadata,
  });
}

/// The default tracer: the newest [capacity] events kept in memory and nothing else.
///
/// It is bounded by construction, because an unbounded "just in case" record is how a long session runs out
/// of memory while explaining a smaller problem. A host that ships events somewhere replaces it.
final class InMemoryDiagnosticTracer implements DiagnosticTracer {
  InMemoryDiagnosticTracer({int capacity = 512}) : _buffer = RingBuffer<DiagnosticEvent>(capacity: capacity);

  final RingBuffer<DiagnosticEvent> _buffer;
  int _sequence = 0;

  @override
  void record(DiagnosticEvent event) => _buffer.add(event);

  @override
  void emit(
    String name, {
    ExtensionId? extensionId,
    DiagnosticLevel level = DiagnosticLevel.info,
    PlatformErrorInfo? error,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    _sequence++;
    _buffer.add(
      DiagnosticEvent(
        id: 'diagnostic.$_sequence',
        timestamp: DateTime.now().toUtc(),
        level: level,
        name: name,
        extensionId: extensionId,
        error: error,
        metadata: metadata,
      ),
    );
  }

  /// Oldest first.
  List<DiagnosticEvent> get events => _buffer.entries;

  List<DiagnosticEvent> get newestFirst => _buffer.newestFirst;

  /// Non-zero means what is shown here is a partial view, which the UI has to be able to say.
  int get droppedCount => _buffer.droppedCount;
}

/// Everything an extension may reach. Passed to `Extension.initialize`.
final class ExtensionContext {
  const ExtensionContext({
    required this.descriptor,
    required this.network,
    required this.cookies,
    required this.permissions,
    required this.tasks,
    required this.cache,
    required this.storage,
    required this.diagnostics,
  });

  final ExtensionDescriptor descriptor;

  /// The only network exit (docs/contracts/platform-contracts.md section 15).
  final ExtensionNetwork network;
  final ExtensionCookieStore cookies;
  final PermissionManager permissions;

  /// Source refreshes, repository updates and ticket refreshes go through the one platform scheduler.
  final TaskScheduler tasks;

  /// Scoped to [descriptor]; an extension cannot name another one's namespace.
  final ExtensionCache cache;
  final ExtensionStorage storage;
  final DiagnosticTracer diagnostics;

  ExtensionId get extensionId => descriptor.id;
}

/// The default cache view: entries in memory, one per extension, expiring on read.
///
/// A host replaces it with something backed by pure_live_cache; the extension-facing shape does not change.
final class InMemoryExtensionCache implements ExtensionCache {
  final Map<String, Object?> _entries = <String, Object?>{};
  final Map<String, DateTime?> _expiresAt = <String, DateTime?>{};

  @override
  Future<Object?> read(String key) async {
    final expiry = _expiresAt[key];
    if (!_entries.containsKey(key)) {
      return null;
    }
    if (expiry != null && !DateTime.now().toUtc().isBefore(expiry)) {
      _entries.remove(key);
      _expiresAt.remove(key);
      return null;
    }
    return _entries[key];
  }

  @override
  Future<void> write(String key, Object? value, {Duration? ttl}) async {
    _entries[key] = value;
    _expiresAt[key] = ttl == null ? null : DateTime.now().toUtc().add(ttl);
  }

  @override
  Future<void> remove(String key) async {
    _entries.remove(key);
    _expiresAt.remove(key);
  }

  @override
  Future<List<String>> keys() async => _entries.keys.toList(growable: false);

  @override
  Future<void> clear() async {
    _entries.clear();
    _expiresAt.clear();
  }
}

/// The default storage view: entries in memory, one map per extension.
final class InMemoryExtensionStorage implements ExtensionStorage {
  final Map<String, Object?> _entries = <String, Object?>{};

  @override
  Future<Object?> read(String key) async => _entries[key];

  @override
  Future<void> write(String key, Object? value) async {
    _entries[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    _entries.remove(key);
  }

  @override
  Future<List<String>> keys() async => _entries.keys.toList(growable: false);
}
