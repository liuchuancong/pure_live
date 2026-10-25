import 'dart:async';

import 'package:live_storage/src/database/json_store.dart';
import 'package:live_storage/src/database/storage_stores.dart';

// The facade keeps the monolith's SharedPreferences-shaped signatures, so
// the boolean value parameter stays positional.
// ignore_for_file: avoid_positional_boolean_parameters

/// The simple typed settings facade: one namespaced store, static one-line
/// reads and writes for the ad-hoc flags that do not deserve a repository
/// or a typed document.
///
/// Reads are synchronous and answer from the store's memory snapshot;
/// writes are awaited SQLite upserts, or land in a [persistBatch] when one
/// is collecting. Call [init] once after `StorageBootstrap.initialize` —
/// every other member throws before that. A clone window calls the same
/// [init]: its [StorageStores] is the remote projection, so reads come from
/// the primary's snapshot and writes are commands the window bridge
/// forwards. [initSeeded] serves tests and examples that want a memory-only
/// backing.
final class StoragePrefs {
  new _();

  /// The namespace the simple settings live in.
  static const String storeName = 'settings';

  static late PrefsBacking _backing;
  static Map<String, Object?>? _writeBatch;

  /// Whether a [persistBatch] is currently collecting writes.
  static bool get isCollectingWrites => _writeBatch != null;

  /// Opens the settings namespace in the process's database.
  static Future<void> init() async {
    _backing = DriftPrefsBacking(await StorageStores.instance.settings);
  }

  /// Serves prefs from an in-memory copy of [seed]: a memory-only backing
  /// for tests and examples. Reads answer the seed and the engine's own
  /// writes; nothing reaches disk. A clone window uses [init] over its
  /// remote store instead.
  static Future<void> initSeeded(Map<String, Object?> seed) async {
    _backing = MemoryPrefsBacking(seed);
  }

  /// Every pref as a plain map, for handing a secondary engine its seed.
  static Map<String, Object?> snapshot() => _backing.readAll();

  /// Emits the keys whose stored value changed.
  ///
  /// The process's own engine is the only writer, so this is exactly the
  /// stream a window bridge follows to hand updates to the other windows:
  /// a seeded-memory backing never writes a file and therefore never emits.
  static Stream<Set<String>> watch() => _backing.watch();

  /// Collects the settings writes made by [update] and commits them in
  /// one database transaction so readers never observe only part of a
  /// multi-key state transition. This is not a transaction for external
  /// side effects.
  static Future<void> persistBatch(void Function() update) async {
    if (_writeBatch != null) throw StateError('Nested settings write batch');

    final values = <String, Object?>{};
    _writeBatch = values;
    try {
      update();
      // Listeners may persist asynchronously (streams, provider
      // scheduling); keep the collection open until the notifications
      // queued by this synchronous update have drained.
      await Future<void>.delayed(Duration.zero);
    } finally {
      _writeBatch = null;
    }

    if (values.isEmpty) return;

    final puts = {for (final MapEntry(:key, :value) in values.entries) key: ?value};
    final deletes = [
      for (final MapEntry(:key, :value) in values.entries)
        if (value == null) key,
    ];
    if (puts.isNotEmpty) {
      await _backing.writeAll(puts);
    }
    if (deletes.isNotEmpty) {
      await _backing.deleteKeys(deletes);
    }
    await _backing.flush();
  }

  /// Returns the raw value stored under [key], or null when absent.
  static Object? getAnyPref(String key) => _get(key);

  /// Stores any encodable [value] under [key]; null removes the entry.
  static Future<bool> setAnyPref(String key, Object? value) async {
    await _put(key, value);
    return true;
  }

  /// Commits related preferences in one database transaction.
  static Future<void> setPrefs(Map<String, Object> values) async {
    final batch = _writeBatch;
    if (batch != null) {
      batch.addAll(values);
      return;
    }
    await _backing.writeAll(values);
  }

  /// Returns the bool stored under [key], or null when absent or of
  /// another type.
  static bool? getBool(String key) {
    final value = _get(key);
    return value is bool ? value : null;
  }

  /// Stores [value] under [key].
  static Future<bool> setBool(String key, bool value) async {
    await _put(key, value);
    return true;
  }

  /// Returns the int stored under [key], or null when absent or of
  /// another type.
  static int? getInt(String key) {
    final value = _get(key);
    return value is int ? value : null;
  }

  /// Stores [value] under [key].
  static Future<bool> setInt(String key, int value) async {
    await _put(key, value);
    return true;
  }

  /// Returns the string stored under [key], or null when absent or of
  /// another type.
  static String? getString(String key) {
    final value = _get(key);
    return value is String ? value : null;
  }

  /// Stores [value] under [key].
  static Future<bool> setString(String key, String value) async {
    await _put(key, value);
    return true;
  }

  /// Returns the double stored under [key], or null when absent or of
  /// another type.
  static double? getDouble(String key) {
    final value = _get(key);
    return value is double ? value : null;
  }

  /// Stores [value] under [key].
  static Future<bool> setDouble(String key, double value) async {
    await _put(key, value);
    return true;
  }

  /// Returns a copy of the string list stored under [key], or null when
  /// absent or of another shape.
  ///
  /// The copy matters: JSON hands back a fresh list after a restart, so a
  /// bare type check would silently drop the stored value.
  static List<String>? getStringList(String key) {
    final value = _get(key);
    return value is List ? List<String>.from(value) : null;
  }

  /// Stores [value] under [key].
  static Future<bool> setStringList(String key, List<String> value) async {
    await _put(key, value);
    return true;
  }

  /// Removes the entry stored under [key].
  static Future<bool> remove(String key) async {
    await _backing.deleteKeys([key]);
    return true;
  }

  /// Whether [key] has an entry, including one pending in a write batch.
  static bool containsKey(String key) {
    return (_writeBatch?.containsKey(key) ?? false) || _backing.contains(key);
  }

  /// Removes every entry in the settings namespace.
  static Future<bool> clear() async {
    await _backing.wipe();
    return true;
  }

  /// Writes are awaited before they reach the store; kept for callers that
  /// flush before shutting down.
  static Future<void> flush() => _backing.flush();

  static Object? _get(String key) {
    final batch = _writeBatch;
    return batch != null && batch.containsKey(key) ? batch[key] : _backing.read(key);
  }

  static Future<void> _put(String key, Object? value) {
    final batch = _writeBatch;
    if (batch != null) {
      batch[key] = value;
      return Future<void>.value();
    }
    return value == null ? _backing.deleteKeys([key]) : _backing.write(key, value);
  }
}

/// Where the prefs values actually live: the document store the process
/// opened (SQLite in the primary, the remote projection in a clone), or the
/// seeded-memory shape tests and examples use.
abstract interface class PrefsBacking {
  /// The value under [key], or null when absent.
  Object? read(String key);

  /// Every value, keyed as stored.
  Map<String, Object?> readAll();

  /// Writes [value] under [key].
  Future<void> write(String key, Object value);

  /// Writes every entry of [values] in one commit.
  Future<void> writeAll(Map<String, Object> values);

  /// Deletes [keys]; absent keys are no-ops.
  Future<void> deleteKeys(Iterable<String> keys);

  /// Deletes every entry.
  Future<void> wipe();

  /// Whether [key] has an entry.
  bool contains(String key);

  /// Waits until pending writes reach their storage.
  Future<void> flush();

  /// Emits the keys a committed write or delete touched.
  Stream<Set<String>> watch();
}

/// The SQLite-backed backing: the process's own settings rows.
final class DriftPrefsBacking implements PrefsBacking {
  /// Serves [store].
  new(this.store);

  /// The opened settings document store.
  final JsonStore store;

  @override
  Object? read(String key) => store.get(key);

  @override
  Map<String, Object?> readAll() => store.entries;

  @override
  Future<void> write(String key, Object value) => store.put(key, value);

  @override
  Future<void> writeAll(Map<String, Object> values) => store.putAll(values);

  @override
  Future<void> deleteKeys(Iterable<String> keys) => store.deleteAll(keys);

  @override
  Future<void> wipe() => store.clear();

  @override
  bool contains(String key) => store.contains(key);

  @override
  Future<void> flush() => store.flush();

  @override
  Stream<Set<String>> watch() => store.watchKeys().map((key) => {key});
}

/// The seeded-memory backing: a secondary engine's read-mostly view, its
/// own writes kept only as long as the engine lives.
final class MemoryPrefsBacking implements PrefsBacking {
  /// Serves a copy of [seed]; the caller's map stays untouched.
  new(Map<String, Object?> seed) : _values = Map<String, Object?>.of(seed);

  final Map<String, Object?> _values;

  @override
  Object? read(String key) => _values[key];

  @override
  Map<String, Object?> readAll() => Map<String, Object?>.of(_values);

  @override
  Future<void> write(String key, Object value) async {
    _values[key] = value;
  }

  @override
  Future<void> writeAll(Map<String, Object> values) async {
    _values.addAll(values);
  }

  @override
  Future<void> deleteKeys(Iterable<String> keys) async {
    keys.forEach(_values.remove);
  }

  @override
  Future<void> wipe() async {
    _values.clear();
  }

  @override
  bool contains(String key) => _values.containsKey(key);

  @override
  Future<void> flush() async {}

  @override
  Stream<Set<String>> watch() => const Stream<Set<String>>.empty();
}
