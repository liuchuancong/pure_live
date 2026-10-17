import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart';

import 'package:pure_live/features/backup/web_dav_preferences.dart';

/// Where the WebDAV document is persisted. The document shares the
/// appearance box: one open box, one document per preference group, each
/// versioned in its key.
abstract final class WebDavKeys {
  /// The box every preference group document lives in (`settings.preferences`).
  static const String box = 'settings.preferences';

  /// The WebDAV group key.
  static const String document = 'preferences.webdav.v1';
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
}

/// The user's WebDAV configuration and sync times: one in-memory
/// [WebDavPreferences], persisted as one JSON document through a storage
/// repository — the [appearance store](`AppearanceStore`) idiom. Reading is
/// synchronous once [load] ran; writing goes through [update], which applies
/// the change immediately and returns a future that completes once the
/// document is durable. Writes are debounced and serialized, so a form
/// typing session costs one write, not one per keystroke.
final class WebDavStore {
  /// A store persisting through [repository].
  new({required this.repository, this.saveDebounce = const Duration(milliseconds: 400), this.onError});

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  /// How long a change waits for company before the document is written.
  final Duration saveDebounce;

  /// Reports every failed read or write; null swallows them.
  final void Function(WebDavStoreFailure failure, Object error, StackTrace stack)? onError;

  final StreamController<WebDavPreferences> _controller = StreamController<WebDavPreferences>.broadcast();

  WebDavPreferences _value = const WebDavPreferences();
  Timer? _debounce;
  Future<void> _writeChain = Future<void>.value();
  Completer<void>? _batch;
  Map<String, Object?>? _pending;
  bool _pendingDelete = false;
  bool _disposed = false;

  /// The current preferences: the shipping defaults until [load] runs.
  WebDavPreferences get value => _value;

  /// Emits on every applied change, including [load].
  Stream<WebDavPreferences> get changes => _controller.stream;

  /// Reads the stored document, applying it when it decodes. A document that
  /// cannot be read or decoded leaves [value] as it is and is reported; a
  /// missing document is not a failure, it is simply the first run.
  Future<WebDavPreferences> load() async {
    _checkNotDisposed();
    final Map<dynamic, dynamic>? raw;
    try {
      raw = repository.get(WebDavKeys.document);
    } on Object catch (error, stack) {
      _report(WebDavStoreFailure.read, error, stack);
      return _value;
    }
    if (raw == null) {
      return _value;
    }
    final WebDavPreferences loaded;
    try {
      loaded = WebDavPreferences.fromJson(Map<String, Object?>.from(raw));
    } on Object catch (error, stack) {
      _report(WebDavStoreFailure.decode, error, stack);
      return _value;
    }
    if (loaded != _value) {
      _value = loaded;
      _emit();
    }
    return loaded;
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

/// The booted [WebDavStore].
///
/// The settings box is opened once by the composition root and cached by
/// name in the box manager, so opening it again here answers with the same
/// box — no second open competes for the file lock. The page waits on this
/// provider while the (already warm) box read finishes.
final webDavStoreProvider = FutureProvider<WebDavStore>((ref) async {
  final box = await StorageBoxManager().keyed<Map<dynamic, dynamic>>(WebDavKeys.box);
  final store = WebDavStore(repository: HiveStorageRepository<Map<dynamic, dynamic>>(box: box));
  await store.load();
  ref.onDispose(store.dispose);
  return store;
});
