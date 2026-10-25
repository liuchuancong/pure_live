import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:live_storage/src/database/storage_database.dart';

/// A namespaced, keyed JSON document store.
///
/// The local implementation reads and writes the process's SQLite database;
/// the remote implementation is the full-app clone's in-memory projection,
/// fed by the main window's snapshots and change broadcasts. Feature
/// repositories depend on this interface, never on SQLite or the window
/// transport.
abstract interface class JsonStore {
  /// The namespace this store reads and writes (`follows`, `history`, …).
  String get namespace;

  /// The value under [key], or null when absent.
  Object? get(String key);

  /// Whether [key] has a value.
  bool contains(String key);

  /// Every key, in insertion order.
  List<String> get keys;

  /// Every value, in insertion order.
  List<Object?> get values;

  /// Every entry, in insertion order.
  Map<String, Object?> get entries;

  /// The number of entries.
  int get length;

  /// Whether the store has no entries.
  bool get isEmpty;

  /// Whether the store has at least one entry.
  bool get isNotEmpty;

  /// Emits after every committed change.
  Stream<void> watch();

  /// Emits the key of every committed change.
  Stream<String> watchKeys();

  /// Stores [value] under [key]; a null [value] deletes the entry.
  Future<void> put(String key, Object? value);

  /// Stores every entry of [values] in one commit.
  Future<void> putAll(Map<String, Object?> values);

  /// Deletes [key]; an absent key is a no-op.
  Future<void> delete(String key);

  /// Deletes every key in [keys]; absent keys are no-ops.
  Future<void> deleteAll(Iterable<String> keys);

  /// Deletes every entry in the namespace.
  Future<void> clear();

  /// Waits until queued writes have been committed.
  Future<void> flush();

  /// Closes the store's change streams.
  Future<void> dispose();
}

/// One committed change set, as the main window broadcasts it.
///
/// A null value means the key was deleted. The values are the new truth;
/// receivers overwrite their projection rather than merging.
final class StorageChange {
  /// A change in [namespace].
  const new({required this.namespace, required this.values, this.revision = 0});

  /// The affected namespace.
  final String namespace;

  /// Key → new JSON value, or null when the key was deleted.
  final Map<String, Object?> values;

  /// The primary's monotonic revision for [namespace].
  ///
  /// Zero is the old/unspecified protocol; a real broadcast always carries
  /// the revision it committed at. A receiver uses it to notice a missed
  /// broadcast and ask for a fresh snapshot instead of applying a delta that
  /// assumes changes it never saw.
  final int revision;
}

/// A namespace as the primary sees it right now.
final class StorageSnapshot {
  /// A snapshot of [values] at [revision].
  const new({required this.values, this.revision = 0});

  /// Every entry in the namespace.
  final Map<String, Object?> values;

  /// The primary's revision for this namespace when the snapshot was read.
  final int revision;
}

/// What a remote projection did with one committed change.
enum RemoteChangeOutcome {
  /// The change belonged to another namespace or the store is disposed.
  ignored,

  /// The revision was already applied; this is a duplicate or an echo.
  unchanged,

  /// The values moved and watchers were notified.
  applied,

  /// A revision is missing. The caller must fetch a fresh snapshot; applying
  /// this delta alone would leave an older key stale.
  gap,
}

/// The clone window's transport to the main window's store.
///
/// Implemented by the app over `desktop_multi_window`; `live_storage` only
/// depends on this seam.
abstract interface class RemoteStorageClient {
  /// Every entry currently in [namespace], with the revision it was read at.
  Future<StorageSnapshot> snapshot(String namespace);

  /// Stores [value] under [namespace]/[key].
  Future<void> put(String namespace, String key, Object? value);

  /// Stores every entry of [values] under [namespace].
  Future<void> putAll(String namespace, Map<String, Object?> values);

  /// Deletes [namespace]/[key].
  Future<void> delete(String namespace, String key);

  /// Deletes every [keys] entry under [namespace].
  Future<void> deleteAll(String namespace, Iterable<String> keys);

  /// Deletes every entry in [namespace].
  Future<void> clear(String namespace);
}

/// The main window's store: SQLite-backed, with a synchronous snapshot.
final class LocalJsonStore implements JsonStore {
  new _(this._database, this.namespace, this._onLocalChange);

  final StorageDatabase _database;
  final void Function(StorageChange change)? _onLocalChange;

  @override
  final String namespace;

  final Map<String, Object?> _values = <String, Object?>{};
  final Map<String, int> _createdAt = <String, int>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<String> _keyChanges = StreamController<String>.broadcast();
  Future<void> _lastWrite = Future<void>.value();
  int _lastStamp = 0;
  bool _disposed = false;

  /// Opens [namespace] in [database] and loads its snapshot.
  static Future<LocalJsonStore> open(
    StorageDatabase database,
    String namespace, {
    void Function(StorageChange change)? onLocalChange,
  }) async {
    if (namespace.trim().isEmpty) {
      throw ArgumentError.value(namespace, 'namespace', 'Must not be empty.');
    }
    final store = LocalJsonStore._(database, namespace, onLocalChange);
    await store._load();
    return store;
  }

  Future<void> _load() async {
    final rows =
        await (_database.select(_database.jsonEntries)
              ..where((table) => table.namespace.equals(namespace))
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt), (table) => OrderingTerm.asc(table.key)]))
            .get();
    for (final row in rows) {
      final value = jsonDecode(row.valueJson);
      _values[row.key] = value;
      _createdAt[row.key] = row.createdAt;
      if (row.createdAt > _lastStamp) _lastStamp = row.createdAt;
    }
  }

  @override
  Object? get(String key) => _values[key];

  @override
  bool contains(String key) => _values.containsKey(key);

  @override
  List<String> get keys => List<String>.unmodifiable(_values.keys);

  @override
  List<Object?> get values => List<Object?>.unmodifiable(_values.values);

  @override
  Map<String, Object?> get entries => Map<String, Object?>.unmodifiable(_values);

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
  Future<void> put(String key, Object? value) {
    if (value == null) return delete(key);
    return _enqueue(() async {
      _validateKey(key);
      final createdAt = _createdAt[key] ?? _nextStamp();
      final now = DateTime.now().millisecondsSinceEpoch;
      await _database
          .into(_database.jsonEntries)
          .insertOnConflictUpdate(
            JsonEntriesCompanion.insert(
              namespace: namespace,
              key: key,
              valueJson: jsonEncode(value),
              createdAt: createdAt,
              updatedAt: now,
            ),
          );
      _values[key] = value;
      _createdAt[key] = createdAt;
      _notify(key);
      _onLocalChange?.call(StorageChange(namespace: namespace, values: {key: value}));
    });
  }

  @override
  Future<void> putAll(Map<String, Object?> values) {
    if (values.isEmpty) return Future<void>.value();
    return _enqueue(() async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final stamps = <String, int>{};
      final rows = <JsonEntriesCompanion>[];
      final deletes = <String>[];
      for (final entry in values.entries) {
        _validateKey(entry.key);
        if (entry.value == null) {
          // A null in a batch means "remove this key", the same as [put].
          // Skipping it made a remote putAll that carried deletions diverge
          // from the caller's projection.
          if (_values.containsKey(entry.key)) deletes.add(entry.key);
          continue;
        }
        final createdAt = _createdAt[entry.key] ?? _nextStamp();
        stamps[entry.key] = createdAt;
        rows.add(
          JsonEntriesCompanion.insert(
            namespace: namespace,
            key: entry.key,
            valueJson: jsonEncode(entry.value),
            createdAt: createdAt,
            updatedAt: now,
          ),
        );
      }
      if (rows.isEmpty && deletes.isEmpty) return;
      await _database.batch((batch) {
        if (deletes.isNotEmpty) {
          batch.deleteWhere(
            _database.jsonEntries,
            (table) => table.namespace.equals(namespace) & table.key.isIn(deletes),
          );
        }
        if (rows.isNotEmpty) {
          batch.insertAllOnConflictUpdate(_database.jsonEntries, rows);
        }
      });
      final changed = <String, Object?>{};
      for (final key in deletes) {
        _values.remove(key);
        _createdAt.remove(key);
        changed[key] = null;
      }
      for (final entry in values.entries) {
        if (entry.value == null) continue;
        _values[entry.key] = entry.value;
        _createdAt[entry.key] = stamps[entry.key]!;
        changed[entry.key] = entry.value;
      }
      _notifyAll(changed.keys);
      _onLocalChange?.call(StorageChange(namespace: namespace, values: changed));
    });
  }

  @override
  Future<void> delete(String key) {
    return _enqueue(() async {
      _validateKey(key);
      if (!_values.containsKey(key)) return;
      await (_database.delete(
        _database.jsonEntries,
      )..where((table) => table.namespace.equals(namespace) & table.key.equals(key))).go();
      _values.remove(key);
      _createdAt.remove(key);
      _notify(key);
      _onLocalChange?.call(StorageChange(namespace: namespace, values: {key: null}));
    });
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) {
    final wanted = keys.toSet();
    return _enqueue(() async {
      final present = [
        for (final key in wanted)
          if (_values.containsKey(key)) key,
      ];
      if (present.isEmpty) return;
      await (_database.delete(
        _database.jsonEntries,
      )..where((table) => table.namespace.equals(namespace) & table.key.isIn(present))).go();
      for (final key in present) {
        _values.remove(key);
        _createdAt.remove(key);
      }
      _notifyAll(present);
      _onLocalChange?.call(StorageChange(namespace: namespace, values: {for (final key in present) key: null}));
    });
  }

  @override
  Future<void> clear() {
    return _enqueue(() async {
      if (_values.isEmpty) return;
      final removed = _values.keys.toList();
      await (_database.delete(_database.jsonEntries)..where((table) => table.namespace.equals(namespace))).go();
      _values.clear();
      _createdAt.clear();
      _notifyAll(removed);
      _onLocalChange?.call(StorageChange(namespace: namespace, values: {for (final key in removed) key: null}));
    });
  }

  @override
  Future<void> flush() => _lastWrite;

  @override
  Future<void> dispose() async {
    _disposed = true;
    try {
      await _lastWrite;
    } on Object {
      // A failed write already reported to its caller; shutdown still closes.
    }
    await _changes.close();
    await _keyChanges.close();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    if (_disposed) {
      return Future<void>.error(StateError('JsonStore "$namespace" is disposed'));
    }
    final next = _lastWrite.then((_) => operation());
    _lastWrite = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _notify(String key) {
    if (_disposed) return;
    _keyChanges.add(key);
    _changes.add(null);
  }

  void _notifyAll(Iterable<String> keys) {
    if (_disposed) return;
    keys.forEach(_keyChanges.add);
    _changes.add(null);
  }

  int _nextStamp() {
    var stamp = DateTime.now().millisecondsSinceEpoch;
    if (stamp <= _lastStamp) stamp = _lastStamp + 1;
    _lastStamp = stamp;
    return stamp;
  }

  static void _validateKey(String key) {
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'Must not be empty.');
    }
  }
}

/// The clone window's store: an in-memory projection fed by the main
/// window. Reads are synchronous; writes are commands, and the projection
/// changes only when the main window broadcasts the committed change.
final class RemoteJsonStore implements JsonStore {
  new _(this._client, this.namespace, this._values, this._revision);

  final RemoteStorageClient _client;
  final Map<String, Object?> _values;
  int _revision;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  final StreamController<String> _keyChanges = StreamController<String>.broadcast();
  bool _disposed = false;

  /// Opens [namespace] from [client]'s snapshot.
  static Future<RemoteJsonStore> open(RemoteStorageClient client, String namespace) async {
    if (namespace.trim().isEmpty) {
      throw ArgumentError.value(namespace, 'namespace', 'Must not be empty.');
    }
    final snapshot = await client.snapshot(namespace);
    return RemoteJsonStore._(client, namespace, Map<String, Object?>.of(snapshot.values), snapshot.revision);
  }

  /// The primary's revision this projection has applied.
  int get revision => _revision;

  @override
  final String namespace;

  @override
  Object? get(String key) => _values[key];

  @override
  bool contains(String key) => _values.containsKey(key);

  @override
  List<String> get keys => List<String>.unmodifiable(_values.keys);

  @override
  List<Object?> get values => List<Object?>.unmodifiable(_values.values);

  @override
  Map<String, Object?> get entries => Map<String, Object?>.unmodifiable(_values);

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
  Future<void> put(String key, Object? value) async {
    await _client.put(namespace, key, value);
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    _notifyAll([key]);
  }

  @override
  Future<void> putAll(Map<String, Object?> values) async {
    await _client.putAll(namespace, values);
    for (final entry in values.entries) {
      if (entry.value == null) {
        _values.remove(entry.key);
      } else {
        _values[entry.key] = entry.value;
      }
    }
    _notifyAll(values.keys);
  }

  @override
  Future<void> delete(String key) async {
    await _client.delete(namespace, key);
    _values.remove(key);
    _notifyAll([key]);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    final wanted = keys.toSet();
    await _client.deleteAll(namespace, wanted);
    wanted.forEach(_values.remove);
    _notifyAll(wanted);
  }

  @override
  Future<void> clear() async {
    await _client.clear(namespace);
    final before = _values.keys.toList();
    _values.clear();
    _notifyAll(before);
  }

  @override
  Future<void> flush() async {}

  /// Applies a committed change from the main window.
  ///
  /// Answers whether the projection actually moved. The primary echoes this
  /// window's own committed write back; when the write's response already
  /// updated the projection, that echo compares equal and must not make the
  /// writer rebuild the controller it is editing.
  RemoteChangeOutcome applyChange(StorageChange change) {
    if (_disposed || change.namespace != namespace) return RemoteChangeOutcome.ignored;

    final revision = change.revision;
    if (change.values.isEmpty) {
      // A revision heartbeat: it carries no delta, only the news that a
      // change exists. Anything newer than this projection must be fetched.
      return revision > _revision ? RemoteChangeOutcome.gap : RemoteChangeOutcome.unchanged;
    }

    if (revision > 0) {
      if (revision <= _revision) return RemoteChangeOutcome.unchanged;
      if (revision != _revision + 1) return RemoteChangeOutcome.gap;
      _revision = revision;
    }

    var changed = false;
    for (final entry in change.values.entries) {
      if (entry.value == null) {
        if (_values.containsKey(entry.key)) {
          _values.remove(entry.key);
          changed = true;
        }
      } else if (!_values.containsKey(entry.key) || !_jsonEquals(_values[entry.key], entry.value)) {
        _values[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) _notifyAll(change.values.keys);
    return changed ? RemoteChangeOutcome.applied : RemoteChangeOutcome.unchanged;
  }

  /// Replaces the projection after a missed revision or a reconnect.
  ///
  /// An older snapshot is refused: changes may have arrived while the snapshot
  /// was in flight, and replaying an older view would roll them back.
  Future<bool> refresh() async {
    final snapshot = await _client.snapshot(namespace);
    if (_disposed || snapshot.revision < _revision) return false;
    _revision = snapshot.revision;
    return replaceAll(snapshot.values);
  }

  /// Replaces the projection after a reconnect or an epoch change.
  ///
  /// Only keys whose value actually changed are notified, so a reconciliation
  /// snapshot does not rebuild every list merely because it arrived.
  bool replaceAll(Map<String, Object?> snapshot) {
    if (_disposed) return false;
    final changed = <String>{};
    for (final key in {..._values.keys, ...snapshot.keys}) {
      final had = _values.containsKey(key);
      final has = snapshot.containsKey(key);
      if (had != has || !_jsonEquals(_values[key], snapshot[key])) {
        changed.add(key);
      }
    }
    _values
      ..clear()
      ..addAll(snapshot);
    if (changed.isNotEmpty) _notifyAll(changed);
    return changed.isNotEmpty;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await _changes.close();
    await _keyChanges.close();
  }

  void _notifyAll(Iterable<String> keys) {
    if (_disposed) return;
    keys.forEach(_keyChanges.add);
    _changes.add(null);
  }
}

/// The list-shaped view of a [JsonStore] the IPTV library consumes.
///
/// Its document keys hold one JSON list each; reads hand the list back
/// whole, writes replace it whole.
final class JsonListStore {
  /// Serves [store].
  new(this.store);

  /// The underlying document store.
  final JsonStore store;

  /// The list under [key], or null when absent.
  Object? get(String key) => store.get(key);

  /// Emits after every committed change.
  Stream<void> watch() => store.watch();

  /// Replaces the list under [key].
  Future<void> save(String key, List<Object?> value) => store.put(key, value);
}

/// Deep equality for decoded JSON documents.
///
/// The codec hands maps back with dynamic keys while this store's writes
/// keep the same document shape, so the comparison cannot be `==`: a
/// received echo must compare by value before declaring the projection
/// changed.
bool _jsonEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || !_jsonEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (!_jsonEquals(a[index], b[index])) return false;
    }
    return true;
  }
  return a == b;
}
