import 'dart:async';

import 'package:live_preferences/src/model/appearance_preferences.dart';
import 'package:live_preferences/src/model/danmaku_preferences.dart';
import 'package:live_preferences/src/model/library_preferences.dart';
import 'package:live_preferences/src/model/playback_preferences.dart';
import 'package:live_preferences/src/model/preferences.dart';
import 'package:live_preferences/src/model/tv_preferences.dart';
import 'package:live_preferences/src/model/window_preferences.dart';
import 'package:live_storage/live_storage.dart';

/// What a [PreferencesService.load] found wrong with the stored documents.
///
/// The load itself never fails: a preference document that cannot be
/// decoded must not keep the app from starting, so the affected group
/// keeps its defaults — but the failure is reported here and through the
/// service's `onError`, never silently.
final class PreferencesLoadReport {
  /// A report of [decodeFailures].
  const new({this.decodeFailures = const <String>[]});

  /// Group keys whose document was present but did not decode.
  final List<String> decodeFailures;

  /// Whether every stored document decoded.
  bool get isClean => decodeFailures.isEmpty;
}

/// The user's preferences: one in-memory [Preferences] value, persisted
/// group by group through a [KeyedStore].
///
/// Reading is synchronous — every reader sees [value] and watches
/// [changes]; writing goes through the `update*` methods, which apply the
/// change to [value] immediately (listeners see it before any disk work)
/// and return a future that completes once the change is durable. Writes
/// are debounced and serialized, so a slider dragged across its range
/// costs one document write, not one per frame.
final class PreferencesService {
  /// A service persisting through [store].
  ///
  /// [initial] is the value before [load] runs — the shipping defaults by
  /// default, so the UI can build immediately at start-up.
  /// [onError] receives every failed store operation with its group key;
  /// the default swallows them, callers install a logger.
  new({
    required this.store,
    Preferences initial = Preferences.defaults,
    this.saveDebounce = const Duration(milliseconds: 400),
    this.onError,
  }) : _value = initial;

  /// The store the groups are persisted in.
  final KeyedStore store;

  /// How long a change waits for company before its group is written.
  final Duration saveDebounce;

  /// Reports every failed store operation with its group key; null
  /// swallows them, callers install a logger.
  final void Function(String key, Object error, StackTrace stack)? onError;
  final StreamController<Preferences> _controller = StreamController<Preferences>.broadcast();

  Preferences _value;
  Timer? _debounce;
  Future<void> _writeChain = Future<void>.value();
  Completer<void>? _batch;
  bool _disposed = false;

  /// The pending documents by group key; null means "remove the key".
  final Map<String, Map<String, Object?>?> _pending = {};

  /// The current preferences. Never null; the defaults before [load].
  Preferences get value => _value;

  /// Emits on every applied change, including [load] and [reset].
  Stream<Preferences> get changes => _controller.stream;

  /// Applies the stored group documents on top of the current value.
  ///
  /// Groups that fail to decode keep their current value. Emits
  /// [changes] when anything was applied.
  Future<PreferencesLoadReport> load() async {
    _checkNotDisposed();
    final decodeFailures = <String>[];
    var loaded = _value;
    for (final key in PreferencesKeys.all) {
      final raw = store.get<Object?>(key);
      if (raw == null) {
        continue;
      }
      if (raw is! Map) {
        decodeFailures.add(key);
        onError?.call(key, const FormatException('preference document is not a JSON object'), StackTrace.current);
        continue;
      }
      final json = Map<String, Object?>.from(raw);
      try {
        loaded = _applyGroup(loaded, key, json);
      } on Object catch (error, stack) {
        decodeFailures.add(key);
        onError?.call(key, error, stack);
      }
    }
    if (loaded != _value) {
      _value = loaded;
      _emit();
    }
    return PreferencesLoadReport(decodeFailures: decodeFailures);
  }

  /// Applies [transform] to the root and persists whichever groups changed.
  ///
  /// The returned future completes once those groups are durable.
  Future<void> update(Preferences Function(Preferences) transform) {
    _checkNotDisposed();
    final fresh = transform(_value);
    if (fresh == _value) {
      return Future<void>.value();
    }
    final previous = _value;
    _value = fresh;
    _emit();
    if (fresh.playback != previous.playback) {
      _pending[PreferencesKeys.playback] = fresh.playback.toJson();
    }
    if (fresh.danmaku != previous.danmaku) {
      _pending[PreferencesKeys.danmaku] = fresh.danmaku.toJson();
    }
    if (fresh.library != previous.library) {
      _pending[PreferencesKeys.library] = fresh.library.toJson();
    }
    if (fresh.tv != previous.tv) {
      _pending[PreferencesKeys.tv] = fresh.tv.toJson();
    }
    if (fresh.window != previous.window) {
      _pending[PreferencesKeys.window] = fresh.window.toJson();
    }
    if (fresh.appearance != previous.appearance) {
      _pending[PreferencesKeys.appearance] = fresh.appearance.toJson();
    }
    return _schedule();
  }

  /// Applies [transform] to the playback group.
  Future<void> updatePlayback(PlaybackPreferences Function(PlaybackPreferences) transform) =>
      update((preferences) => preferences.copyWith(playback: transform(preferences.playback)));

  /// Applies [transform] to the danmaku group.
  Future<void> updateDanmaku(DanmakuPreferences Function(DanmakuPreferences) transform) =>
      update((preferences) => preferences.copyWith(danmaku: transform(preferences.danmaku)));

  /// Applies [transform] to the library group.
  Future<void> updateLibrary(LibraryPreferences Function(LibraryPreferences) transform) =>
      update((preferences) => preferences.copyWith(library: transform(preferences.library)));

  /// Applies [transform] to the TV group.
  Future<void> updateTv(TvPreferences Function(TvPreferences) transform) =>
      update((preferences) => preferences.copyWith(tv: transform(preferences.tv)));

  /// Applies [transform] to the floating window group.
  Future<void> updateWindow(WindowPreferences Function(WindowPreferences) transform) =>
      update((preferences) => preferences.copyWith(window: transform(preferences.window)));

  /// Applies [transform] to the appearance group.
  Future<void> updateAppearance(AppearancePreferences Function(AppearancePreferences) transform) =>
      update((preferences) => preferences.copyWith(appearance: transform(preferences.appearance)));

  /// Writes every pending document now, instead of waiting for the
  /// debounce; used before the app exits and after a critical change.
  Future<void> flush() {
    _debounce?.cancel();
    _debounce = null;
    return _flush();
  }

  /// Restores [Preferences.defaults] and removes the stored documents.
  Future<void> reset() {
    _checkNotDisposed();
    for (final key in PreferencesKeys.all) {
      _pending[key] = null;
    }
    if (_value != Preferences.defaults) {
      _value = Preferences.defaults;
      _emit();
    }
    _debounce?.cancel();
    _debounce = null;
    return _flush();
  }

  /// Flushes pending writes and closes the service.
  ///
  /// Later calls to [update], [load] or [reset] throw a [StateError];
  /// [value] and [changes] stay readable.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _debounce?.cancel();
    _debounce = null;
    await _flush();
    _batch?.complete();
    _batch = null;
    await _controller.close();
  }

  /// The group `key` names, re-read with `json` and folded into `loaded`.
  Preferences _applyGroup(Preferences loaded, String key, Map<String, Object?> json) => switch (key) {
    PreferencesKeys.playback => loaded.copyWith(playback: PlaybackPreferences.fromJson(json)),
    PreferencesKeys.danmaku => loaded.copyWith(danmaku: DanmakuPreferences.fromJson(json)),
    PreferencesKeys.library => loaded.copyWith(library: LibraryPreferences.fromJson(json)),
    PreferencesKeys.tv => loaded.copyWith(tv: TvPreferences.fromJson(json)),
    PreferencesKeys.window => loaded.copyWith(window: WindowPreferences.fromJson(json)),
    PreferencesKeys.appearance => loaded.copyWith(appearance: AppearancePreferences.fromJson(json)),
    _ => loaded,
  };

  /// Arms the debounce and hands the caller the batch's durability future.
  Future<void> _schedule() {
    final batch = _batch ??= Completer<void>();
    _debounce?.cancel();
    _debounce = Timer(saveDebounce, _flush);
    return batch.future;
  }

  /// Serializes the pending documents behind any write still in flight.
  Future<void> _flush() {
    if (_pending.isEmpty) {
      final batch = _batch;
      _batch = null;
      if (batch != null && !batch.isCompleted) {
        batch.complete();
      }
      return Future<void>.value();
    }
    final documents = Map<String, Map<String, Object?>?>.of(_pending);
    _pending.clear();
    final batch = _batch;
    _batch = null;
    _writeChain = _writeChain.then((_) async {
      for (final MapEntry(:key, value: json) in documents.entries) {
        try {
          await store.put(key, json);
        } on Object catch (error, stack) {
          onError?.call(key, error, stack);
        }
      }
    });
    return _writeChain.whenComplete(() {
      if (batch != null && !batch.isCompleted) {
        batch.complete();
      }
    });
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_value);
    }
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('PreferencesService was disposed');
    }
  }
}
