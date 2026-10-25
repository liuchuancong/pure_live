import 'dart:async';
import 'dart:io';

import 'package:live_storage/src/database/json_store.dart';
import 'package:live_storage/src/database/storage_database.dart';
import 'package:live_storage/src/database/storage_database_opener.dart';
import 'package:path/path.dart' as p;

/// The process's opened namespaces, backed either by the main window's
/// SQLite database or by a clone window's remote projection.
abstract class StorageStores {
  /// A stores instance.
  const new();

  static StorageStores? _instance;

  /// The open stores, or a loud failure when the boot never opened them.
  static StorageStores get instance {
    final instance = _instance;
    if (instance == null) {
      throw StateError('StorageStores.open or attachRemote must run during boot');
    }
    return instance;
  }

  /// Whether a store set is open in this process.
  static bool get isOpen => _instance != null;

  /// The file name under the app's data directory.
  static const String fileName = 'storage.sqlite';

  /// Opens the main window's database under [directory] and installs it.
  static Future<StorageStores> open({required String directory}) async {
    final path = p.join(directory, fileName);
    final database = await openStorageDatabase(path);
    // Force the connection open and the schema on it now, so a broken
    // database fails the boot instead of the first page that reads a key.
    await database.customSelect('SELECT 1').get();
    final stores = LocalStorageStores._(database, path);
    await _replace(stores);
    return stores;
  }

  /// Opens an in-memory database for tests and the example.
  static Future<StorageStores> openInMemory() async {
    final database = openInMemoryStorageDatabase();
    await database.customSelect('SELECT 1').get();
    final stores = LocalStorageStores._(database, ':memory:');
    await _replace(stores);
    return stores;
  }

  /// Installs a clone window's remote projection over [client].
  static Future<StorageStores> attachRemote(RemoteStorageClient client) async {
    final stores = RemoteStorageStores._(client);
    await _replace(stores);
    return stores;
  }

  static Future<void> _replace(StorageStores next) async {
    final previous = _instance;
    _instance = next;
    if (previous != null) {
      await previous.close();
    }
  }

  /// Opens — or returns the already-open — [namespace].
  Future<JsonStore> openStore(String namespace);

  /// The settings namespace's store.
  Future<JsonStore> get settings => openStore('settings');

  /// The namespaces' local changes, for the main window's broadcast. The
  /// clone window has no outgoing changes.
  Stream<StorageChange> get changes;

  /// Applies a committed change received from the main window. A local
  /// store is the authority and ignores this. A remote store answers whether
  /// the projection moved, or that a revision is missing and a snapshot is
  /// needed.
  RemoteChangeOutcome reload(StorageChange change);

  /// Replaces [namespace] from a fresh primary snapshot, when it is open.
  ///
  /// Answers whether the projection moved. A namespace that was never opened
  /// has nothing to reconcile; its first open takes a current snapshot.
  Future<bool> resync(String namespace);

  /// The database file, or `:memory:` in tests; `:remote:` in a clone.
  String get databasePath;

  /// Closes every store and the database. The instance becomes unusable;
  /// a later boot opens a fresh one.
  Future<void> close();

  /// Closes and forgets any process instance; safe when none is open.
  static Future<void> closeInstance() async {
    final current = _instance;
    if (current == null) return;
    await current.close();
  }

  /// Where the database file goes for a data [directory].
  static File databaseFile(String directory) => File(p.join(directory, fileName));
}

/// The main window's SQLite-backed stores.
final class LocalStorageStores extends StorageStores {
  new _(this._database, this.databasePath);

  final StorageDatabase _database;
  final StreamController<StorageChange> _changes = StreamController<StorageChange>.broadcast();
  final Map<String, Future<JsonStore>> _opening = <String, Future<JsonStore>>{};
  final Map<String, JsonStore> _stores = <String, JsonStore>{};

  @override
  final String databasePath;

  @override
  Stream<StorageChange> get changes => _changes.stream;

  @override
  Future<JsonStore> openStore(String namespace) {
    final opened = _stores[namespace];
    if (opened != null) return Future<JsonStore>.value(opened);
    return _opening.putIfAbsent(namespace, () async {
      try {
        final store = await LocalJsonStore.open(_database, namespace, onLocalChange: _changes.add);
        _stores[namespace] = store;
        return store;
      } finally {
        _opening.remove(namespace)?.ignore();
      }
    });
  }

  @override
  RemoteChangeOutcome reload(StorageChange change) {
    // The main window is the writer; its own stores already hold the value.
    return RemoteChangeOutcome.ignored;
  }

  @override
  Future<bool> resync(String namespace) async => false;

  @override
  Future<void> close() async {
    for (final store in _stores.values) {
      await store.dispose();
    }
    _stores.clear();
    _opening.clear();
    await _changes.close();
    await _database.close();
    if (identical(StorageStores._instance, this)) {
      StorageStores._instance = null;
    }
  }
}

/// A clone window's remote projection over the main window's stores.
final class RemoteStorageStores extends StorageStores {
  new _(this._client);

  final RemoteStorageClient _client;
  final Map<String, Future<JsonStore>> _opening = <String, Future<JsonStore>>{};
  final Map<String, JsonStore> _stores = <String, JsonStore>{};

  /// Changes that arrived before their namespace opened. The snapshot the
  /// open fetched may predate them, so they are replayed once it installs.
  /// Kept in order: a revision gap inside the list needs one snapshot, not a
  /// merged delta that hides it.
  final Map<String, List<StorageChange>> _pending = <String, List<StorageChange>>{};

  @override
  final String databasePath = ':remote:';

  @override
  Stream<StorageChange> get changes => const Stream<StorageChange>.empty();

  @override
  Future<JsonStore> openStore(String namespace) {
    final opened = _stores[namespace];
    if (opened != null) return Future<JsonStore>.value(opened);
    return _opening.putIfAbsent(namespace, () async {
      try {
        final store = await RemoteJsonStore.open(_client, namespace);
        _stores[namespace] = store;
        final pending = _pending.remove(namespace);
        if (pending != null) {
          for (final change in pending) {
            if (store.applyChange(change) == RemoteChangeOutcome.gap) {
              await store.refresh();
            }
          }
        }
        return store;
      } finally {
        _opening.remove(namespace)?.ignore();
      }
    });
  }

  @override
  RemoteChangeOutcome reload(StorageChange change) {
    final store = _stores[change.namespace];
    if (store is RemoteJsonStore) {
      return store.applyChange(change);
    }
    // A heartbeat for a namespace nobody opened has nothing to reconcile;
    // the eventual open takes its own current snapshot.
    if (change.values.isEmpty) return RemoteChangeOutcome.ignored;
    // A broadcast that lands while the namespace is still opening cannot be
    // applied yet; the snapshot may have been taken before it. Hold it for
    // the store's install.
    _pending.putIfAbsent(change.namespace, () => <StorageChange>[]).add(change);
    return RemoteChangeOutcome.ignored;
  }

  @override
  Future<bool> resync(String namespace) async {
    final store = _stores[namespace];
    if (store is RemoteJsonStore) return await store.refresh();
    return false;
  }

  @override
  Future<void> close() async {
    for (final store in _stores.values) {
      await store.dispose();
    }
    _stores.clear();
    _opening.clear();
    _pending.clear();
    if (identical(StorageStores._instance, this)) {
      StorageStores._instance = null;
    }
  }
}
