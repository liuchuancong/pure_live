import 'dart:async';

import 'package:hive_box_manager/hive_box_manager.dart';
import 'package:live_storage/src/repository/storage_repository.dart';

/// Implements the generic storage repository over a hive_box_manager
/// keyed box.
///
/// Reads answer from the eager box synchronously — no awaiting a get.
/// Writes serialize per key, so two callers racing on one key cannot
/// interleave their read-modify-write cycles; unrelated keys never wait
/// for each other.
base class HiveStorageRepository<T extends Object> implements StorageRepository<T> {
  /// Creates a repository over the keyed [box].
  new({required this.box});

  /// The underlying hive_box_manager keyed box.
  final KeyedBox<T, String> box;

  final Map<String, Future<void>> _keyQueues = {};

  @override
  Stream<void> watch({String? key}) => box.watch(key: key).map((_) {});

  @override
  Future<void> save(String key, T value) {
    _validateKey(key);
    return _enqueue(key, () => box.put(key, value).run());
  }

  @override
  Future<void> saveAll(Map<String, T> values) async {
    values.keys.forEach(_validateKey);

    if (values.isEmpty) return;

    await box.putAll(values).run();
  }

  @override
  T? get(String key) {
    _validateKey(key);
    return box.get(key).toNullable();
  }

  @override
  Map<String, T> getMany(Iterable<String> keys) {
    final result = <String, T>{};

    for (final key in keys) {
      _validateKey(key);

      final value = box.get(key).toNullable();
      if (value != null) {
        result[key] = value;
      }
    }

    return Map<String, T>.unmodifiable(result);
  }

  @override
  List<T> getAll() => List<T>.unmodifiable(box.values);

  @override
  Map<String, T> getAllEntries() {
    final result = <String, T>{};

    for (final key in box.keys) {
      final value = box.get(key).toNullable();
      if (value != null) {
        result[key] = value;
      }
    }

    return Map<String, T>.unmodifiable(result);
  }

  @override
  List<String> getAllKeys() => List<String>.unmodifiable(box.keys);

  @override
  bool contains(String key) {
    _validateKey(key);
    return box.contains(key);
  }

  @override
  bool containsAll(Iterable<String> keys) {
    for (final key in keys) {
      _validateKey(key);
      if (!box.contains(key)) return false;
    }

    return true;
  }

  @override
  Future<bool> insertIfAbsent(String key, T value) {
    _validateKey(key);

    return _enqueueResult(key, () async {
      if (box.contains(key)) return false;

      await box.put(key, value).run();
      return true;
    });
  }

  @override
  Future<bool> update(String key, T Function(T current) updater) {
    _validateKey(key);

    return _enqueueResult(key, () async {
      final current = box.get(key).toNullable();
      if (current == null) return false;

      await box.put(key, updater(current)).run();
      return true;
    });
  }

  @override
  Future<void> delete(String key) {
    _validateKey(key);
    return _enqueue(key, () => box.delete(key).run());
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    final uniqueKeys = keys.toSet()..forEach(_validateKey);

    if (uniqueKeys.isEmpty) return;

    await box.deleteAll(uniqueKeys).run();
  }

  @override
  Future<int> deleteWhere(bool Function(String key, T value) test) async {
    final keysToDelete = <String>[];

    for (final key in getAllKeys()) {
      final value = get(key);
      if (value != null && test(key, value)) {
        keysToDelete.add(key);
      }
    }

    await deleteAll(keysToDelete);
    return keysToDelete.length;
  }

  @override
  int get count => box.length;

  @override
  bool get isEmpty => box.isEmpty;

  @override
  bool get isNotEmpty => box.isNotEmpty;

  @override
  Future<void> clear() async {
    if (box.isEmpty) return;

    await box.clear().run();
  }

  @override
  Future<void> flush() => box.flush().run();

  Future<void> _enqueue(String key, Future<void> Function() operation) {
    return _enqueueResult(key, () async {
      await operation();
    });
  }

  Future<R> _enqueueResult<R>(String key, Future<R> Function() operation) {
    final previous = _keyQueues[key] ?? Future<void>.value();
    final completer = Completer<R>();

    final next = previous.then<void>(
      (_) async {
        try {
          completer.complete(await operation());
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      },
      onError: (Object _, StackTrace _) async {
        try {
          completer.complete(await operation());
        } catch (error, stackTrace) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    _keyQueues[key] = next;

    unawaited(
      next.whenComplete(() async {
        if (identical(_keyQueues[key], next)) {
          await _keyQueues.remove(key);
        }
      }),
    );

    return completer.future;
  }

  void _validateKey(String key) {
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'Must not be empty.');
    }
  }
}
