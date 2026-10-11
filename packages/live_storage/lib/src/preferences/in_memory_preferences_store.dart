import 'dart:async';
import 'dart:collection';

import 'package:live_storage/src/contracts/preferences_store.dart';

/// [PreferencesStore] over a plain map — for tests and for settings that
/// are intentionally process-local.
///
/// Semantics mirror the durable store: writes settle before returning,
/// `changes` fires per mutation, and removed keys read back as null.
final class InMemoryPreferencesStore implements PreferencesStore {
  /// An empty store.
  new();

  final HashMap<String, Object?> _values = HashMap<String, Object?>();
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Object?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, Object? value) async {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    _changes.add(null);
  }

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
    _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _values.clear();
    _changes.add(null);
  }
}
