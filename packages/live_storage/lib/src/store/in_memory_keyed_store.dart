import 'dart:async';
import 'dart:collection';

import 'package:live_storage/src/contracts/keyed_store.dart';

/// [KeyedStore] over a plain map — for tests and for tables that are
/// intentionally process-local.
///
/// Semantics mirror the durable store: reads answer from memory, puts
/// settle before returning, and every committed change emits a
/// [KeyedEvent].
final class InMemoryKeyedStore implements KeyedStore {
  /// An empty store.
  new();

  final HashMap<String, Object?> _values = HashMap<String, Object?>();
  final _changes = StreamController<KeyedEvent>.broadcast();

  @override
  Iterable<String> get keys => _values.keys;

  @override
  bool containsKey(String key) => _values.containsKey(key);

  @override
  T? get<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    if (value == null) {
      return defaultValue;
    }
    return value as T;
  }

  @override
  Future<void> put(String key, Object? value) async {
    if (value == null) {
      await delete(key);
      return;
    }
    _values[key] = value;
    _changes.add(KeyedEvent(key: key, deleted: false, value: value));
  }

  @override
  Future<void> delete(String key) async {
    if (!_values.containsKey(key)) {
      return;
    }
    _values.remove(key);
    _changes.add(KeyedEvent(key: key, deleted: true));
  }

  @override
  Future<void> clear() async {
    final removed = List<String>.of(_values.keys);
    _values.clear();
    for (final key in removed) {
      _changes.add(KeyedEvent(key: key, deleted: true));
    }
  }

  @override
  Stream<KeyedEvent> watch({String? key}) =>
      key == null ? _changes.stream : _changes.stream.where((event) => event.key == key);
}
