import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show HiveStorageRepository, SecretRefs, SecretStore, StorageBoxManager, StorageRepository;
import 'package:pure_live/app/services/secure_vault.dart' show SecureVault;
import 'package:pure_live/features/backup/web_dav_preferences.dart';

/// Where the WebDAV documents are persisted. The documents share the
/// appearance box: one open box, one document per preference group, each
/// versioned in its key.
abstract final class WebDavKeys {
  /// The box every preference group document lives in (`settings.preferences`).
  static const String box = 'settings.preferences';

  /// The WebDAV group key (v2: the server list; v1 was one config).
  static const String document = 'preferences.webdav.v2';

  /// The superseded single-config key the store migrates from once.
  static const String legacyDocument = 'preferences.webdav.v1';
}

/// What a [WebDavStore.load] or write found wrong. A failure never stops
/// the page: the document keeps whatever value it had and the fact is
/// reported to [WebDavStore.onError].
enum WebDavStoreFailure {
  /// The box read threw.
  read,

  /// A document was stored but did not decode.
  decode,

  /// A document could not be written.
  write,

  /// The secret vault could not be opened (passwords then live only as long
  /// as the process does — the page says so through [WebDavStore.secretsOk]).
  secrets,
}

/// The user's WebDAV servers and their sync times: one in-memory
/// [WebDavPreferences] plus the vault-held passwords, persisted as one JSON
/// document through a storage repository — the appearance-store idiom.
/// Reading is synchronous once [load] ran; writing goes through [update],
/// which applies the change immediately and returns a future that completes
/// once the document is durable. Writes are debounced and serialized, so a
/// form typing session costs one write, not one per keystroke.
///
/// The v1 single-config document migrates on first load: the server is
/// named after its host, the password moves out of the plain document into
/// the vault, and the new key is written at once.
final class WebDavStore {
  /// A store persisting through [repository]; [secrets] is the vault door,
  /// injectable so a test (or a device without one) still gets the document
  /// half.
  new({
    required this.repository,
    Future<SecretStore> Function()? secrets,
    this.saveDebounce = const Duration(milliseconds: 400),
    this.onError,
  }) : _secretsOf = secrets;

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  final Future<SecretStore> Function()? _secretsOf;

  /// How long a change waits for company before the document is written.
  final Duration saveDebounce;

  /// Reports every failed read or write; null swallows them.
  final void Function(WebDavStoreFailure failure, Object error, StackTrace stack)? onError;

  final StreamController<WebDavPreferences> _controller = StreamController<WebDavPreferences>.broadcast();

  WebDavPreferences _value = const WebDavPreferences();
  final Map<String, String> _passwords = {};
  Timer? _debounce;
  Future<void> _writeChain = Future<void>.value();
  Completer<void>? _batch;
  Map<String, Object?>? _pending;
  bool _pendingDelete = false;
  bool _disposed = false;
  Future<SecretStore?>? _secrets;

  /// The current preferences: the shipping defaults until [load] runs.
  WebDavPreferences get value => _value;

  /// Whether the password vault answered at [load] time. Without it a saved
  /// password cannot be read back or written — the server entries still
  /// list, the page just cannot connect until the password is typed again.
  bool get secretsOk => _secretsAvailable;
  bool _secretsAvailable = true;

  /// Emits on every applied change, including [load].
  Stream<WebDavPreferences> get changes => _controller.stream;

  /// The vault password of the server [name], '' when there is none.
  String passwordOf(String name) => _passwords[name] ?? '';

  /// Reads the stored document (and the legacy v1), applying what decodes.
  /// A document that cannot be read or decoded leaves [value] as it is and
  /// is reported; a missing document is not a failure, it is the first run.
  Future<WebDavPreferences> load() async {
    _checkNotDisposed();
    final Map<dynamic, dynamic>? raw;
    try {
      raw = repository.get(WebDavKeys.document);
    } on Object catch (error, stack) {
      _report(WebDavStoreFailure.read, error, stack);
      return _value;
    }
    var loaded = const WebDavPreferences();
    if (raw == null) {
      loaded = await _migrateLegacy() ?? loaded;
    } else {
      try {
        loaded = WebDavPreferences.fromJson(Map<String, Object?>.from(raw));
      } on Object catch (error, stack) {
        _report(WebDavStoreFailure.decode, error, stack);
        return _value;
      }
    }
    await _readPasswords(loaded.servers.map((server) => server.name));
    if (loaded != _value || _passwords.isNotEmpty) {
      _value = loaded;
      _emit();
    }
    return _value;
  }

  /// The one-time v1 → v2 lift; null when there is no legacy document.
  Future<WebDavPreferences?> _migrateLegacy() async {
    final Map<dynamic, dynamic>? legacy;
    try {
      legacy = repository.get(WebDavKeys.legacyDocument);
    } on Object {
      return null;
    }
    if (legacy == null) {
      return null;
    }
    final config = legacy['config'];
    if (config is! Map) {
      return null;
    }
    final address = config['address']?.toString() ?? '';
    final name = _hostOf(address);
    if (name.isEmpty) {
      return null;
    }
    final server = WebDavServer(
      name: name,
      address: address,
      username: config['username']?.toString() ?? '',
      directory: config['directory']?.toString() ?? '',
      lastBackupAt: switch (legacy['lastBackupAt']) {
        final String at => DateTime.tryParse(at),
        _ => null,
      },
      lastRestoreAt: switch (legacy['lastRestoreAt']) {
        final String at => DateTime.tryParse(at),
        _ => null,
      },
    );
    final password = config['password']?.toString() ?? '';
    if (password.isNotEmpty) {
      await _writePassword(name, password);
    }
    final migrated = WebDavPreferences(servers: [server], active: name);
    try {
      await repository.save(WebDavKeys.document, migrated.toJson());
    } on Object catch (error, stack) {
      _report(WebDavStoreFailure.write, error, stack);
    }
    return migrated;
  }

  static String _hostOf(String address) {
    final uri = Uri.tryParse(address.trim());
    return uri == null ? '' : uri.host;
  }

  /// Applies [transform] to the preferences and persists the result. The
  /// returned future completes once the change is durable.
  Future<void> update(WebDavPreferences Function(WebDavPreferences preferences) transform) {
    _checkNotDisposed();
    final fresh = transform(_value);
    if (fresh == _value) {
      return Future<void>.value();
    }
    _value = fresh;
    _emit();
    _pending = fresh.toJson();
    _pendingDelete = false;
    return _debounced();
  }

  /// Adds or replaces the entry [server] (by name) and makes it active; the
  /// password, when given, goes to the vault immediately.
  Future<void> saveServer(WebDavServer server, {String? password}) async {
    _checkNotDisposed();
    if (password != null && password.isNotEmpty) {
      await _writePassword(server.name, password);
    }
    await update((preferences) {
      final servers = [
        for (final existing in preferences.servers)
          if (existing.name != server.name) existing else server,
        if (!preferences.servers.any((existing) => existing.name == server.name)) server,
      ];
      // The replaced entry keeps its position; a new one joins the end.
      final ordered = preferences.servers.any((existing) => existing.name == server.name)
          ? [
              for (final existing in preferences.servers)
                if (existing.name == server.name) server else existing,
            ]
          : [...servers.where((entry) => entry.name != server.name), server];
      return preferences.copyWith(servers: ordered, active: server.name);
    });
  }

  /// Takes the server out of the list, its password out of the vault, and
  /// moves the selection to the first survivor (or off, when none is left).
  Future<void> removeServer(String name) async {
    _checkNotDisposed();
    final secrets = await _openSecrets();
    await secrets?.remove(SecretRefs.webdav(name));
    _passwords.remove(name);
    await update((preferences) {
      final servers = [
        for (final server in preferences.servers)
          if (server.name != name) server,
      ];
      final active = preferences.active == name ? (servers.isEmpty ? null : servers.first.name) : preferences.active;
      return preferences.copyWith(servers: servers, active: active, clearActive: active == null);
    });
  }

  /// Points the page at [name]; an unknown name is refused quietly.
  Future<void> select(String name) async {
    if (!_value.servers.any((server) => server.name == name)) {
      return;
    }
    await update((preferences) => preferences.copyWith(active: name));
  }

  /// Rewrites the active server through [transform] (the sync-time stamps
  /// and the edit-in-place of a connected server).
  Future<void> updateActive(WebDavServer Function(WebDavServer server) transform) async {
    final active = _value.activeServer;
    if (active == null) {
      return;
    }
    await saveServer(transform(active));
  }

  /// Writes the pending document now instead of waiting for the debounce.
  Future<void> flush() {
    _debounce?.cancel();
    _debounce = null;
    return _drain();
  }

  /// Flushes any pending write and closes the store.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await flush();
    await _controller.close();
  }

  Future<void> _readPasswords(Iterable<String> names) async {
    final secrets = await _openSecrets();
    if (secrets == null) {
      return;
    }
    for (final name in names) {
      final stored = secrets.value(SecretRefs.webdav(name));
      if (stored != null && stored.isNotEmpty) {
        _passwords[name] = stored;
      }
    }
  }

  Future<void> _writePassword(String name, String password) async {
    final secrets = await _openSecrets();
    if (secrets == null) {
      return;
    }
    _passwords[name] = password;
    await secrets.set(SecretRefs.webdav(name), password);
  }

  /// The one vault handle of this store; a door that will not open is
  /// reported once and answers [secretsOk] false from then on.
  Future<SecretStore?> _openSecrets() => _secrets ??= () async {
    final open = _secretsOf;
    if (open == null) {
      _secretsAvailable = false;
      return null;
    }
    try {
      return await open();
    } on Object catch (error, stack) {
      _report(WebDavStoreFailure.secrets, error, stack);
      _secretsAvailable = false;
      return null;
    }
  }();

  Future<void> _debounced() {
    _debounce?.cancel();
    _debounce = Timer(saveDebounce, () => unawaited(_drain()));
    return (_batch ??= Completer<void>()).future;
  }

  Future<void> _drain() {
    if (_pending == null && !_pendingDelete) {
      return Future<void>.value();
    }
    final batch = _batch ??= Completer<void>();
    _writeChain = _writeChain.then((_) async {
      final document = _pending;
      final shouldDelete = _pendingDelete;
      _pending = null;
      _pendingDelete = false;
      try {
        if (shouldDelete) {
          await repository.delete(WebDavKeys.document);
        } else if (document != null) {
          await repository.save(WebDavKeys.document, document);
        }
      } on Object catch (error, stack) {
        _report(WebDavStoreFailure.write, error, stack);
      }
    });
    return _writeChain.whenComplete(() {
      if (!batch.isCompleted) {
        batch.complete();
      }
      _batch = null;
    });
  }

  void _report(WebDavStoreFailure failure, Object error, StackTrace stack) => onError?.call(failure, error, stack);

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_value);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('WebDavStore was disposed');
    }
  }
}

/// The booted [WebDavStore]: the document from the preferences box, the
/// passwords from the device secret vault. The box is opened once by the
/// composition root and cached by name, so opening it again here answers
/// with the same box — no second open competes for the file lock; the
/// vault read is the same one the login repository walks.
final webDavStoreProvider = FutureProvider<WebDavStore>((ref) async {
  final box = await StorageBoxManager().keyed<Map<dynamic, dynamic>>(WebDavKeys.box);
  // A keychain this process cannot open leaves the store document-only;
  // secretsOk says so and the page asks for the password again.
  final store = WebDavStore(
    repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box),
    secrets: () => SecretStore.load(vault: SecureVault()),
  );
  await store.load();
  ref.onDispose(store.dispose);
  return store;
});
