import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show SecretStore, SecretVault, StorageRepository;
import 'package:pure_live/features/backup/web_dav_preferences.dart';
import 'package:pure_live/features/backup/web_dav_store.dart';

final class _DocMapRepository implements StorageRepository<Map<dynamic, dynamic>> {
  final Map<String, Map<dynamic, dynamic>> documents = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> watch({String? key}) => _changes.stream;

  @override
  Map<dynamic, dynamic>? get(String key) => documents[key];

  @override
  Map<String, Map<dynamic, dynamic>> getMany(Iterable<String> keys) => {
    for (final key in keys)
      if (documents.containsKey(key)) key: documents[key]!,
  };

  @override
  List<Map<dynamic, dynamic>> getAll() => List.of(documents.values);

  @override
  Map<String, Map<dynamic, dynamic>> getAllEntries() => Map.of(documents);

  @override
  List<String> getAllKeys() => List.of(documents.keys);

  @override
  bool contains(String key) => documents.containsKey(key);

  @override
  bool containsAll(Iterable<String> keys) => keys.every(documents.containsKey);

  @override
  Future<void> save(String key, Map<dynamic, dynamic> value) async {
    documents[key] = value;
    _changes.add(null);
  }

  @override
  Future<void> saveAll(Map<String, Map<dynamic, dynamic>> values) async {
    documents.addAll(values);
    _changes.add(null);
  }

  @override
  Future<bool> insertIfAbsent(String key, Map<dynamic, dynamic> value) async {
    final inserted = !documents.containsKey(key);
    if (inserted) {
      documents[key] = value;
      _changes.add(null);
    }
    return inserted;
  }

  @override
  Future<bool> update(String key, Map<dynamic, dynamic> Function(Map<dynamic, dynamic> current) updater) async {
    if (!documents.containsKey(key)) {
      return false;
    }
    documents[key] = updater(documents[key]!);
    _changes.add(null);
    return true;
  }

  @override
  Future<void> delete(String key) async {
    documents.remove(key);
    _changes.add(null);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    keys.forEach(documents.remove);
    _changes.add(null);
  }

  @override
  Future<int> deleteWhere(bool Function(String key, Map<dynamic, dynamic> value) test) async {
    final doomed = [
      for (final entry in documents.entries)
        if (test(entry.key, entry.value)) entry.key,
    ]..forEach(documents.remove);
    _changes.add(null);
    return doomed.length;
  }

  @override
  int get count => documents.length;

  @override
  bool get isEmpty => documents.isEmpty;

  @override
  bool get isNotEmpty => documents.isNotEmpty;

  @override
  Future<void> clear() async {
    documents.clear();
    _changes.add(null);
  }

  @override
  Future<void> flush() async {}
}

final class _MapVault implements SecretVault {
  final Map<String, String> values = {};

  @override
  Future<Map<String, String>> readAll() async => Map.of(values);

  @override
  Future<void> write(String ref, String plain) async => values[ref] = plain;

  @override
  Future<void> delete(String ref) async => values.remove(ref);
}

Future<WebDavStore> _store({Map<String, Object?>? legacy, _MapVault? vault}) async {
  final repository = _DocMapRepository();
  if (legacy != null) {
    repository.documents[WebDavKeys.legacyDocument] = Map<dynamic, dynamic>.from(legacy);
  }
  final secrets = await SecretStore.load(vault: vault ?? _MapVault());
  final store = WebDavStore(repository: repository, secrets: () async => secrets, saveDebounce: Duration.zero);
  await store.load();
  addTearDown(store.dispose);
  return store;
}

void main() {
  test('the v1 single-config document migrates to one named server', () async {
    final vault = _MapVault();
    final store = await _store(
      vault: vault,
      legacy: <String, Object?>{
        'config': {
          'address': 'https://dav.jianguoyun.com/dav/',
          'username': 'me',
          'password': 'app-pw',
          'directory': 'pure_live',
        },
        'lastBackupAt': DateTime(2026, 10).toUtc().toIso8601String(),
      },
    );
    final server = store.value.activeServer!;
    expect(server.name, 'dav.jianguoyun.com');
    expect(server.directory, 'pure_live');
    expect(server.lastBackupAt, isNotNull);
    // The password lifted out of the plain document into the vault.
    expect(store.passwordOf(server.name), 'app-pw');
    expect(vault.values['webdav/dav.jianguoyun.com'], 'app-pw');
  });

  test('saving a server keeps it active; removing it moves the selection', () async {
    final store = await _store();
    await store.saveServer(
      const WebDavServer(name: 'a', address: 'https://a/dav/', username: 'u'),
      password: 'pa',
    );
    await store.saveServer(
      const WebDavServer(name: 'b', address: 'https://b/dav/', username: 'u'),
      password: 'pb',
    );
    expect(store.value.servers.map((server) => server.name), ['a', 'b']);
    expect(store.value.active, 'b');
    await store.select('a');
    expect(store.value.active, 'a');
    await store.removeServer('a');
    expect(store.value.active, 'b');
    expect(store.passwordOf('a'), isEmpty);
  });

  test('updateActive rewrites the selected server in place', () async {
    final store = await _store();
    await store.saveServer(const WebDavServer(name: 'solo', address: 'https://s/dav/', username: 'u'), password: 'p');
    await store.updateActive((server) => server.copyWith(lastBackupAt: DateTime(2026, 10, 19)));
    expect(store.value.servers.single.lastBackupAt, DateTime(2026, 10, 19));
    expect(store.value.servers.single.name, 'solo');
  });

  test('a stale active name falls back to the first server', () {
    const preferences = WebDavPreferences(
      servers: [WebDavServer(name: 'one', address: 'https://one/dav/', username: 'u')],
      active: 'gone',
    );
    expect(preferences.activeServer!.name, 'one');
  });

  test('updateActive rewrites the selected server in place', () async {
    final store = await _store();
    await store.saveServer(const WebDavServer(name: 'solo', address: 'https://s/dav/', username: 'u'), password: 'p');
    await store.updateActive((server) => server.copyWith(lastBackupAt: DateTime(2026, 10, 19)));
    expect(store.value.servers.single.lastBackupAt, DateTime(2026, 10, 19));
    expect(store.value.servers.single.name, 'solo');
  });

  test('a stale active name falls back to the first server', () {
    const preferences = WebDavPreferences(
      servers: [WebDavServer(name: 'one', address: 'https://one/dav/', username: 'u')],
      active: 'gone',
    );
    expect(preferences.activeServer!.name, 'one');
  });

  test('a secret vault that will not open leaves the store document-only', () async {
    final store = WebDavStore(
      repository: _DocMapRepository(),
      secrets: () => throw StateError('no keychain here'),
      saveDebounce: Duration.zero,
    );
    await store.load();
    expect(store.secretsOk, isFalse);
    await store.saveServer(const WebDavServer(name: 'x', address: 'https://x/dav/', username: 'u'), password: 'p');
    expect(store.value.servers.single.name, 'x');
    // The document kept the server; the password had nowhere to go.
    expect(store.passwordOf('x'), isEmpty);
    await store.dispose();
  });

  test('the document round-trips the server list', () {
    const preferences = WebDavPreferences(
      servers: [WebDavServer(name: 'one', address: 'a', username: 'u', directory: 'd')],
      active: 'one',
    );
    final back = WebDavPreferences.fromJson(preferences.toJson());
    expect(back, preferences);
  });
}
