// Module: lib/src/persistent_context.dart
// Purpose: Disk-backed ExtensionCache and ExtensionStorage views, one namespace per extension.
// Author: liuchuancong
// Created: 2026-10-09
//
// Spec: docs/contracts/platform-contracts.md section 19: "命名空间必须含属主(例
// extension.tvbox.source_001.repository)" and "插件 MUST NOT 直接访问 Drift/Hive/SQLite/SharedPreferences/
// 应用文件系统 —— 实现可换而 Extension API 不变". The namespace is built here from the ExtensionId the view was
// created for, so an extension cannot name another one's rows even by guessing the string.

import 'dart:convert';

import 'package:pure_live_platform/pure_live_platform.dart' show ExtensionId;
import 'package:pure_live_storage/pure_live_storage.dart';

import 'context.dart';

/// The area segments of section 19's namespace: `extension.<owner>.<area>.<key>`.
const String cacheArea = 'cache';
const String storageArea = 'storage';

/// The namespace prefix one extension's rows live under. Exposed so a host can find them (for example to
/// drop a namespace when a plugin is uninstalled, which no extension-facing API can do).
final class ExtensionNamespace {
  const ExtensionNamespace(this.extensionId);

  final ExtensionId extensionId;

  String get cachePrefix => 'extension.$extensionId.$cacheArea.';

  String get storagePrefix => 'extension.$extensionId.$storageArea.';
}

/// The durable cache view: rows survive a restart, a TTL is honoured against the deadline stored with the
/// row, and one extension's `clear` never touches another's keys.
///
/// A row this view cannot interpret reads back as a miss rather than an error. That is deliberate: the cost of
/// a wrong miss is one refetch, while the cost of throwing is an extension that cannot start.
final class PersistentExtensionCache implements ExtensionCache {
  PersistentExtensionCache({required KeyValueStore store, required ExtensionId extensionId, DateTime Function()? clock})
    : _store = store,
      _namespace = ExtensionNamespace(extensionId),
      _clock = clock ?? _utcNow;

  final KeyValueStore _store;
  final ExtensionNamespace _namespace;
  final DateTime Function() _clock;

  @override
  Future<Object?> read(String key) async => (await _project('${_namespace.cachePrefix}$key')).value;

  @override
  Future<void> write(String key, Object? value, {Duration? ttl}) async {
    requireJsonStorable(value);
    await _store.write('${_namespace.cachePrefix}$key', <String, Object?>{
      'v': value,
      // The deadline is stored, not the duration: a restart must not stretch a short TTL into a long one,
      // because the new process never saw the original write.
      if (ttl != null) 'e': _clock().add(ttl).toIso8601String(),
    });
  }

  @override
  Future<void> remove(String key) => _store.remove('${_namespace.cachePrefix}$key');

  @override
  Future<List<String>> keys() async {
    final prefix = _namespace.cachePrefix;
    final alive = <String>[];
    for (final stored in await _store.keys()) {
      if (!stored.startsWith(prefix)) {
        continue;
      }
      // Listing is the pruning point: expiry is otherwise noticed one key at a time, so a cache that is
      // written and rarely read would grow on disk forever.
      if ((await _project(stored)).present) {
        alive.add(stored.substring(prefix.length));
      }
    }
    return alive;
  }

  @override
  Future<void> clear() async {
    final prefix = _namespace.cachePrefix;
    for (final stored in await _store.keys()) {
      if (stored.startsWith(prefix)) {
        await _store.remove(stored);
      }
    }
  }

  /// The row with its expiry applied. Expired and unreadable rows are removed as they are seen, and reported
  /// as absent so a value of `null` stays distinguishable from no value at all.
  Future<_Row> _project(String storedKey) async {
    final raw = await _store.read(storedKey);
    if (raw == null) {
      return const _Row.absent();
    }
    if (raw is! Map) {
      await _store.remove(storedKey);
      return const _Row.absent();
    }
    final envelope = Map<String, Object?>.from(raw);
    final expiry = _parseExpiry(envelope['e']);
    if (expiry != null && !_clock().isBefore(expiry)) {
      await _store.remove(storedKey);
      return const _Row.absent();
    }
    return _Row.present(envelope['v']);
  }
}

/// The durable settings view: the same namespace rule, no TTL, and no `clear` because the contract does not
/// offer one for storage (platform-contracts.md section 19).
final class PersistentExtensionStorage implements ExtensionStorage {
  PersistentExtensionStorage({required KeyValueStore store, required ExtensionId extensionId})
    : _store = store,
      _namespace = ExtensionNamespace(extensionId);

  final KeyValueStore _store;
  final ExtensionNamespace _namespace;

  @override
  Future<Object?> read(String key) => _store.read('${_namespace.storagePrefix}$key');

  @override
  Future<void> write(String key, Object? value) async {
    requireJsonStorable(value);
    await _store.write('${_namespace.storagePrefix}$key', value);
  }

  @override
  Future<void> remove(String key) => _store.remove('${_namespace.storagePrefix}$key');

  @override
  Future<List<String>> keys() async {
    final prefix = _namespace.storagePrefix;
    return <String>[
      for (final stored in await _store.keys())
        if (stored.startsWith(prefix)) stored.substring(prefix.length),
    ];
  }
}

/// Rejected at write time rather than silently dropped at read time after a restart.
void requireJsonStorable(Object? value) {
  try {
    jsonEncode(value);
  } on JsonUnsupportedObjectError catch (error) {
    throw ArgumentError.value(
      error.unsupportedObject,
      'value',
      'A persistent extension view stores JSON-encodable values only',
    );
  }
}

/// Whether a projected row exists, independent of whether its value is null.
final class _Row {
  const _Row.absent() : present = false, value = null;

  const _Row.present(this.value) : present = true;

  final bool present;
  final Object? value;
}

DateTime? _parseExpiry(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

DateTime _utcNow() => DateTime.now().toUtc();
