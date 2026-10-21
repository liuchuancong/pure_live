import 'dart:async';

import 'package:live_storage/live_storage.dart' show StorageRepository;

import 'package:pure_live/system/theme/appearance_preferences/appearance_preferences.dart';

/// Where the appearance document is persisted.
///
/// One document per preference group, versioned in its key: a reshaped
/// document gets `.v2` plus a migration that reads the old key, so a stale or
/// broken appearance only ever resets the appearance and never another group's
/// settings.
abstract final class AppearanceKeys {
  /// The box every preference group document lives in (`settings.preferences`).
  static const String box = 'settings.preferences';

  /// The appearance group key.
  static const String document = 'preferences.appearance.v1';
}

/// What a [AppearanceStore.load] or write found wrong.
///
/// A failure never stops the app: the affected document keeps whatever value
/// it had, but the fact is recorded in [AppearanceStore.failures] and handed
/// to [AppearanceStore.onError] rather than swallowed.
enum AppearanceFailure {
  /// The box read threw.
  read,

  /// A document was stored but is not a JSON object.
  shape,

  /// A JSON object was stored but did not decode.
  decode,

  /// A document was built but could not be written.
  write,
}

/// The user's appearance: one in-memory [AppearancePreferences], persisted as
/// one JSON document through a storage repository.
///
/// Reading is synchronous — every reader sees [value] and watches [changes] —
/// so the theme resolves before the first frame. Writing goes through
/// [update], which applies the change to [value] immediately (listeners, and
/// with them the whole UI, re-skin before any disk work) and returns a future
/// that completes once the change is durable. Writes are debounced and
/// serialized, so dragging the font-scale slider across its range costs one
/// document write, not one per frame.
final class AppearanceStore {
  /// A store persisting through [repository].
  new({required this.repository, this.saveDebounce = const Duration(milliseconds: 400), this.onError});

  /// The repository the document is persisted in.
  final StorageRepository<Map<dynamic, dynamic>> repository;

  /// How long a change waits for company before the document is written.
  final Duration saveDebounce;

  /// Reports every failed read or write; null swallows them, and the
  /// composition root installs a logger.
  final void Function(AppearanceFailure failure, Object error, StackTrace stack)? onError;
  final StreamController<AppearancePreferences> _controller = StreamController<AppearancePreferences>.broadcast();

  AppearancePreferences _value = const AppearancePreferences();
  Timer? _debounce;
  Future<void> _writeChain = Future<void>.value();
  Completer<void>? _batch;
  Map<String, Object?>? _pending;
  bool _pendingDelete = false;
  bool _disposed = false;

  /// The current appearance: the shipping defaults until [load] runs.
  AppearancePreferences get value => _value;

  /// What the last [load] found wrong, empty when it found nothing.
  List<AppearanceFailure> get failures => List<AppearanceFailure>.unmodifiable(_failures);
  final List<AppearanceFailure> _failures = [];

  /// Emits on every applied change, including [load] and [reset].
  Stream<AppearancePreferences> get changes => _controller.stream;

  /// Reads the stored document, applying it when it decodes.
  ///
  /// A document that cannot be read or decoded leaves [value] as it is and is
  /// recorded in [failures]; a missing document is not a failure, it is simply
  /// the first run.
  Future<AppearancePreferences> load() async {
    _checkNotDisposed();
    _failures.clear();
    final Map<dynamic, dynamic>? raw;
    try {
      raw = repository.get(AppearanceKeys.document);
    } on Object catch (error, stack) {
      _report(AppearanceFailure.read, error, stack);
      return _value;
    }
    if (raw == null) {
      return _value;
    }
    final AppearancePreferences loaded;
    try {
      loaded = AppearancePreferences.fromJson(Map<String, Object?>.from(raw));
    } on Object catch (error, stack) {
      _report(AppearanceFailure.decode, error, stack);
      return _value;
    }
    if (loaded != _value) {
      _value = loaded;
      _emit();
    }
    return loaded;
  }

  /// Applies [transform] to the appearance and persists the result.
  ///
  /// The returned future completes once the change is durable.
  Future<void> update(AppearancePreferences Function(AppearancePreferences appearance) transform) {
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

  /// Writes the pending document now instead of waiting for the debounce:
  /// before the app exits, and after a change the user must not lose.
  Future<void> flush() {
    _debounce?.cancel();
    _debounce = null;
    return _drain();
  }

  /// Restores the defaults and removes the stored document.
  Future<void> reset() {
    _checkNotDisposed();
    if (_value != const AppearancePreferences()) {
      _value = const AppearancePreferences();
      _emit();
    }
    _pending = null;
    _pendingDelete = true;
    _debounce?.cancel();
    _debounce = null;
    return _drain();
  }

  /// Flushes any pending write and closes the store; later [load], [update]
  /// and [reset] throw, [value] and [changes] stay readable.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await flush();
    await _controller.close();
  }

  /// Arms the debounce and answers with the durability future of the batch
  /// this change belongs to.
  Future<void> _debounced() {
    _debounce?.cancel();
    _debounce = Timer(saveDebounce, () => unawaited(_drain()));
    return (_batch ??= Completer<void>()).future;
  }

  /// Serializes whatever is pending behind any write already in flight.
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
          await repository.delete(AppearanceKeys.document);
        } else if (document != null) {
          await repository.save(AppearanceKeys.document, document);
        }
      } on Object catch (error, stack) {
        _report(AppearanceFailure.write, error, stack);
      }
    });
    return _writeChain.whenComplete(() {
      if (!batch.isCompleted) {
        batch.complete();
      }
      _batch = null;
    });
  }

  void _report(AppearanceFailure failure, Object error, StackTrace stack) {
    _failures.add(failure);
    onError?.call(failure, error, stack);
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_value);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('AppearanceStore was disposed');
    }
  }
}
