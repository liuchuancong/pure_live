import 'dart:async';

import 'package:hive_box_manager/hive_box_manager.dart';
import 'package:live_storage/src/boxes/storage_box_manager.dart';

// The facade keeps the monolith's SharedPreferences-shaped signatures, so
// the boolean value parameter stays positional.
// ignore_for_file: avoid_positional_boolean_parameters

/// The simple typed settings facade: one string-keyed box, static one-line
/// reads and writes for the ad-hoc flags that do not deserve a repository
/// or a typed document.
///
/// Reads are synchronous and answer from the eager box; writes are awaited
/// puts, or land in a [persistBatch] when one is collecting. Call [init]
/// once after `StorageBootstrap.initialize` — every other member throws
/// before that.
final class StoragePrefs {
  new _();

  /// The box the simple settings live in, alongside
  /// `settings.preferences`.
  static const String boxName = 'settings.kv';

  static late KeyedBox<Object, String> _box;
  static Map<String, Object?>? _writeBatch;

  /// Whether a [persistBatch] is currently collecting writes.
  static bool get isCollectingWrites => _writeBatch != null;

  /// Opens the settings box, replacing any handle a previous
  /// initialization held (so re-initializing after a shutdown works).
  static Future<void> init() async {
    _box = await StorageBoxManager().keyed<Object>(boxName);
  }

  /// Collects the settings writes made by [update] and commits them in
  /// one Hive batch so readers never observe only part of a multi-key
  /// state transition. This is not a transaction for external side
  /// effects.
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
      await _box.putAll(puts).run();
    }
    if (deletes.isNotEmpty) {
      await _box.deleteAll(deletes).run();
    }
    await _box.flush().run();
  }

  /// Returns the raw value stored under [key], or null when absent.
  static Object? getAnyPref(String key) => _get(key);

  /// Stores any encodable [value] under [key]; null removes the entry.
  static Future<bool> setAnyPref(String key, Object? value) async {
    await _put(key, value);
    return true;
  }

  /// Commits related preferences in one Hive batch.
  static Future<void> setPrefs(Map<String, Object> values) async {
    final batch = _writeBatch;
    if (batch != null) {
      batch.addAll(values);
      return;
    }
    await _box.putAll(values).run();
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
  /// The copy matters: Hive returns a fresh `List<dynamic>` after a
  /// restart, so a bare type check would silently drop the stored value.
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
    await _box.delete(key).run();
    return true;
  }

  /// Whether [key] has an entry, including one pending in a write batch.
  static bool containsKey(String key) {
    return (_writeBatch?.containsKey(key) ?? false) || _box.contains(key);
  }

  /// Removes every entry in the settings box.
  static Future<bool> clear() async {
    await _box.clear().run();
    return true;
  }

  /// Waits until all queued settings writes reach disk.
  static Future<void> flush() => _box.flush().run();

  static Object? _get(String key) {
    final batch = _writeBatch;
    return batch != null && batch.containsKey(key) ? batch[key] : _box.get(key).toNullable();
  }

  static Future<void> _put(String key, Object? value) {
    final batch = _writeBatch;
    if (batch != null) {
      batch[key] = value;
      return Future<void>.value();
    }
    return value == null ? _box.delete(key).run() : _box.put(key, value).run();
  }
}
