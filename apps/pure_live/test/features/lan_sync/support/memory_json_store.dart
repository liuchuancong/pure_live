import 'dart:async' show StreamController;

import 'package:live_storage/live_storage.dart';

/// An in-memory [JsonStore] for tests: real KV semantics with putAll as one
/// commit, mirroring LocalJsonStore's observable behaviour without a
/// database.
final class MemoryJsonStore implements JsonStore {
  MemoryJsonStore([this.namespace = 'memory']);

  @override
  final String namespace;

  final Map<String, Object?> _values = <String, Object?>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<String> _keyChanges = StreamController<String>.broadcast();

  @override
  Object? get(String key) => _values[key];

  @override
  bool contains(String key) => _values.containsKey(key);

  @override
  List<String> get keys => List.unmodifiable(_values.keys);

  @override
  List<Object?> get values => List.unmodifiable(_values.values);

  @override
  Map<String, Object?> get entries => Map.unmodifiable(_values);

  @override
  int get length => _values.length;

  @override
  bool get isEmpty => _values.isEmpty;

  @override
  bool get isNotEmpty => _values.isNotEmpty;

  @override
  Stream<void> watch() => _changes.stream;

  @override
  Stream<String> watchKeys() => _keyChanges.stream;

  @override
  Future<void> put(String key, Object? value) => putAll({key: value});

  @override
  Future<void> putAll(Map<String, Object?> values) async {
    for (final MapEntry(:key, :value) in values.entries) {
      if (value == null) {
        _values.remove(key);
        _keyChanges.add(key);
      } else {
        _values[key] = value;
        _keyChanges.add(key);
      }
    }
    if (values.isNotEmpty) _changes.add(null);
  }

  @override
  Future<void> delete(String key) => deleteAll([key]);

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    var removed = false;
    for (final key in keys) {
      if (_values.remove(key) != null) {
        _keyChanges.add(key);
        removed = true;
      }
    }
    if (removed) _changes.add(null);
  }

  @override
  Future<void> clear() async {
    _values.clear();
    _changes.add(null);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> dispose() async {
    await _changes.close();
    await _keyChanges.close();
  }
}
