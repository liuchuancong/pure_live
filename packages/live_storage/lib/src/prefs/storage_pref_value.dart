import 'dart:async';
import 'dart:convert';

import 'package:live_storage/src/prefs/storage_prefs.dart';

// The factories keep the monolith's bridge-shaped signatures, so the
// fallback boolean stays positional.
// ignore_for_file: avoid_positional_boolean_parameters

/// A write-through reactive value: assigning [v] updates memory, persists
/// through [StoragePrefs] and notifies listeners synchronously.
///
/// The plain-Dart stand-in for the monolith's GetX `Rx` bridging — wire
/// listeners into Riverpod providers or UI state by hand.
final class PrefValue<T> {
  /// Creates a value starting at [initialValue], persisted through
  /// [persist] on every assignment.
  new(T initialValue, {required this.persist}) : _value = initialValue;

  /// Persists a value; the assignment's write-through step.
  final Future<bool> Function(T value) persist;
  T _value;
  final List<void Function(T value)> _listeners = [];

  /// The current value.
  T get v => _value;

  /// Sets the value, persists it and notifies listeners synchronously,
  /// in that order — a failed disk write never blocks or misorders the
  /// notification.
  set v(T newValue) {
    _value = newValue;
    unawaited(persist(newValue));
    for (final listener in List.of(_listeners)) {
      listener(newValue);
    }
  }

  /// Registers [listener] for every assignment of [v].
  void listen(void Function(T value) listener) {
    _listeners.add(listener);
  }

  /// Unregisters a listener added by [listen].
  void removeListener(void Function(T value) listener) {
    _listeners.remove(listener);
  }
}

/// A bool-backed [PrefValue], seeded from storage with [fallback].
PrefValue<bool> prefBool(String key, bool fallback) {
  return PrefValue<bool>(StoragePrefs.getBool(key) ?? fallback, persist: (value) => StoragePrefs.setBool(key, value));
}

/// An int-backed [PrefValue], seeded from storage with [fallback].
PrefValue<int> prefInt(String key, int fallback) {
  return PrefValue<int>(StoragePrefs.getInt(key) ?? fallback, persist: (value) => StoragePrefs.setInt(key, value));
}

/// A double-backed [PrefValue], seeded from storage with [fallback].
PrefValue<double> prefDouble(String key, double fallback) {
  return PrefValue<double>(
    StoragePrefs.getDouble(key) ?? fallback,
    persist: (value) => StoragePrefs.setDouble(key, value),
  );
}

/// A string-backed [PrefValue], seeded from storage with [fallback].
PrefValue<String> prefString(String key, String fallback) {
  return PrefValue<String>(
    StoragePrefs.getString(key) ?? fallback,
    persist: (value) => StoragePrefs.setString(key, value),
  );
}

/// A string-list-backed [PrefValue], seeded from storage with [fallback].
PrefValue<List<String>> prefStringList(String key, List<String> fallback) {
  return PrefValue<List<String>>(
    StoragePrefs.getStringList(key) ?? List<String>.of(fallback),
    persist: (value) => StoragePrefs.setStringList(key, value),
  );
}

/// A JSON-object-backed [PrefValue], stored as a string and seeded from
/// storage with [fallback]; a corrupt document keeps the fallback.
PrefValue<T> prefObject<T>(
  String key,
  T fallback, {
  required T Function(Map<String, Object?> json) fromJson,
  required Map<String, Object?> Function(T value) toJson,
}) {
  var initial = fallback;

  final json = StoragePrefs.getString(key);
  if (json != null && json.isNotEmpty) {
    try {
      initial = fromJson(Map<String, Object?>.from(jsonDecode(json) as Map));
    } on Object {
      // A corrupt document keeps the fallback.
    }
  }

  return PrefValue<T>(initial, persist: (value) => StoragePrefs.setString(key, jsonEncode(toJson(value))));
}
