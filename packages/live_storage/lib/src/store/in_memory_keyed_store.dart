import 'dart:async';
import 'dart:collection';

import 'package:live_storage/src/contracts/keyed_store.dart';

/// [KeyedStore] over a plain map — for tests and for tables that are
/// intentionally process-local.
///
/// Semantics mirror the durable store: writes settle before returning,
/// `changes` fires per mutation, and removed keys read back as null.
final class InMemoryKeyedStore implements KeyedStore {
  /// An empty store.
  new();

  final HashMap<String, Object?> _values = HashMap<String, Object?>();
  final _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  Future<Object?> read(String key) async => _values[key];

  @override
  Future<Map<String, Object?>> readAll() async => Map<String, Object?>.of(_values);

  @override
  Future<List<String>> keys() async {
    final names = _values.keys.toList()..sort();
    return names;
  }

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
