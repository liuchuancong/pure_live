// Module: lib/src/data/preferences_store.dart
// Purpose: The durable mechanism behind a typed preference key - envelope, namespace, import/export, changes.
// Author: liuchuancong
// Created: 2026-10-10
//
// Spec: docs/architecture/application-portfolio.md section 5 gives this package the mechanism and the apps
// the vocabulary. Everything here is keyed by a consumer-declared PreferenceKey; nothing here knows what a
// quality label or a tab order is.

import 'dart:async';

import 'package:pure_live_storage/pure_live_storage.dart';

import '../domain/preference_key.dart';

/// The envelope version this writer produces.
///
/// A stored value carries its version and codec name because a preference outlives the code that wrote it:
/// without the marker, a type change under the same key name reads as a valid value of the new type.
const int kPreferenceEnvelopeVersion = 1;

/// Typed preferences over one namespaced key-value store.
final class PreferencesStore {
  /// [namespace] ends with its separator and is the only thing separating two apps that share a store file.
  PreferencesStore({required KeyValueStore store, this.namespace = 'settings.'})
    : _store = _PrefixedStore(store, namespace);

  static const String _versionField = 'v';
  static const String _codecField = 'c';
  static const String _valueField = 'value';

  final KeyValueStore _store;

  /// The prefix every key here carries; two apps may share one store file because of it.
  final String namespace;

  final StreamController<PreferenceChange> _changes = StreamController.broadcast();

  /// Rejections seen since construction, newest last. Reads stay non-throwing, so this is how a bad stored
  /// value becomes visible to a diagnostics view instead of vanishing into a default.
  final List<PreferenceRejection> _rejections = <PreferenceRejection>[];

  /// Keys whose stored row was read through [PreferenceKey.upgrade] - a legacy shape, still valid, not yet
  /// rewritten as an envelope. Kept apart from [rejections] because "the disk holds an older document" is not
  /// a failure, and a caller that reports one must not report the other as if it were.
  final Set<String> _upgraded = <String>{};

  bool _disposed = false;

  /// Broadcast stream of writes and resets. A listener that arrives late misses earlier changes by design:
  /// the store is not a log, and a settings screen reads first and subscribes after.
  Stream<PreferenceChange> get changes => _changes.stream;

  List<PreferenceRejection> get rejections => List<PreferenceRejection>.unmodifiable(_rejections);

  /// The keys read through a legacy upgrade since construction, in first-seen order.
  ///
  /// Reported rather than silent because it is the caller's decision what to do: the row still holds the old
  /// shape, so a consumer that wants envelopes everywhere runs a `SchemaMigrator` step and writes them back.
  /// A read never rewrites, because a screen that only came to display a value should not be the thing that
  /// mutates storage.
  List<String> get upgradedKeys => List<String>.unmodifiable(_upgraded);

  /// The stored value, or [PreferenceKey.defaultValue] when nothing valid is stored.
  Future<T> read<T extends Object>(PreferenceKey<T> key) async {
    final decoded = await _decode(key);
    return decoded ?? key.defaultValue;
  }

  /// The stored value, or null when absent or unreadable. A caller that must distinguish "unset" from "set to
  /// the default value" uses this; [read] cannot.
  Future<T?> readIfStored<T extends Object>(PreferenceKey<T> key) => _decode(key);

  Future<void> write<T extends Object>(PreferenceKey<T> key, T value) async {
    if (!_accepts(key, value)) {
      _note(PreferenceRejection(keyName: key.name, failure: PreferenceFailure.invalidValue));
      throw PreferenceException(PreferenceFailure.invalidValue, '${key.name} rejected ${key.codec.name} value');
    }
    await _store.write(key.name, _envelope(key, value));
    _emit(key, value, wasDefault: false);
  }

  /// Writes [value] only when nothing valid is stored, and reports whether it did.
  ///
  /// This is the first-run primitive: `read() == default` cannot tell an untouched key from a key the user
  /// set back to the default, and a first-run banner that reappears for that reason is a bug users report.
  Future<bool> putIfAbsent<T extends Object>(PreferenceKey<T> key, T value) async {
    if (await _decode(key) != null) {
      return false;
    }
    await write(key, value);
    return true;
  }

  /// Removes the stored value so the key answers with its default again.
  Future<void> reset<T extends Object>(PreferenceKey<T> key) async {
    await _store.remove(key.name);
    _emit(key, key.defaultValue, wasDefault: true);
  }

  /// Whether a value is stored under [key], without decoding it into the caller's type.
  Future<bool> isStored(PreferenceKeyInfo key) async => (await _store.read(key.name)) != null;

  /// Every stored envelope under the namespace, in the shape [importAll] accepts. Values are the raw
  /// envelopes, so a backup can carry keys this build does not know about.
  Future<Map<String, Object?>> exportAll() async {
    final exported = <String, Object?>{};
    for (final name in await _store.keys()) {
      final raw = await _store.read(name);
      if (raw != null) {
        exported[name] = raw;
      }
    }
    return Map<String, Object?>.unmodifiable(exported);
  }

  /// Restores envelopes produced by [exportAll].
  ///
  /// Each entry is validated against the caller's own key list, because a restore is external input: an
  /// unknown name, a wrong codec or a bad shape is reported per key and the rest still lands. A partial
  /// restore is the useful outcome; an all-or-nothing one is a restore that never happens.
  Future<PreferenceImportReport> importAll(
    Map<String, Object?> envelopes, {
    required Iterable<PreferenceKeyInfo> keys,
    bool overwrite = true,
  }) async {
    final byName = <String, PreferenceKeyInfo>{for (final key in keys) key.name: key};
    var accepted = 0, skipped = 0, rejected = 0;
    final unknown = <String>[];
    for (final entry in envelopes.entries) {
      final key = byName[entry.key];
      if (key == null) {
        unknown.add(entry.key);
        rejected++;
        continue;
      }
      if (!overwrite && (await _store.read(entry.key)) != null) {
        skipped++;
        continue;
      }
      if (!_isEnvelope(entry.value)) {
        _note(PreferenceRejection(keyName: entry.key, failure: PreferenceFailure.unreadableEnvelope));
        rejected++;
        continue;
      }
      // The envelope is stored as it arrived, so the only check possible here is whether it claims the same
      // shape this key reads back; a mismatch would otherwise surface much later as a silent default.
      if ((entry.value as Map)[_codecField] != key.codecName) {
        _note(PreferenceRejection(keyName: entry.key, failure: PreferenceFailure.codecMismatch));
        rejected++;
        continue;
      }
      await _store.write(entry.key, entry.value);
      accepted++;
    }
    return PreferenceImportReport(
      accepted: accepted,
      skipped: skipped,
      rejected: rejected,
      unknownKeys: List<String>.unmodifiable(unknown),
    );
  }

  /// Releases the change stream. The store does not own [KeyValueStore] and never closes it.
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _changes.close();
  }

  Future<T?> _decode<T extends Object>(PreferenceKey<T> key) async {
    final raw = await _store.read(key.name);
    if (raw == null) {
      return null;
    }
    if (!_isEnvelope(raw)) {
      // A row this store never wrote is not automatically a corrupt row: it may be the consumer's own older
      // document. The key decides, because only the consumer knows what its data looked like before the
      // envelope - and treating an unreadable-but-known shape as a rejection would drop the user's setting on
      // the floor and let the next write persist the default in its place.
      final legacy = key.upgrade?.call(raw);
      if (legacy == null) {
        _note(
          PreferenceRejection(
            keyName: key.name,
            failure: PreferenceFailure.unreadableEnvelope,
            rawType: '${raw.runtimeType}',
          ),
        );
        return null;
      }
      final upgraded = key.codec.decode(legacy);
      if (upgraded == null) {
        _note(
          PreferenceRejection(
            keyName: key.name,
            failure: PreferenceFailure.unreadableEnvelope,
            rawType: '${legacy.runtimeType}',
          ),
        );
        return null;
      }
      if (!_accepts(key, upgraded)) {
        _note(PreferenceRejection(keyName: key.name, failure: PreferenceFailure.invalidValue));
        return null;
      }
      _upgraded.add(key.name);
      return upgraded;
    }
    final map = raw as Map;
    if (map[_codecField] != key.codec.name) {
      _note(
        PreferenceRejection(
          keyName: key.name,
          failure: PreferenceFailure.codecMismatch,
          rawType: '${map[_codecField]}',
        ),
      );
      return null;
    }
    final value = key.codec.decode(map[_valueField]);
    if (value == null) {
      _note(
        PreferenceRejection(
          keyName: key.name,
          failure: PreferenceFailure.unreadableEnvelope,
          rawType: '${map[_valueField]?.runtimeType}',
        ),
      );
      return null;
    }
    if (!_accepts(key, value)) {
      _note(PreferenceRejection(keyName: key.name, failure: PreferenceFailure.invalidValue));
      return null;
    }
    return value;
  }

  Map<String, Object?> _envelope<T extends Object>(PreferenceKey<T> key, T value) => <String, Object?>{
    _versionField: kPreferenceEnvelopeVersion,
    _codecField: key.codec.name,
    _valueField: key.codec.encode(value),
  };

  bool _isEnvelope(Object? raw) =>
      raw is Map &&
      raw[_versionField] is int &&
      (raw[_versionField] as int) <= kPreferenceEnvelopeVersion &&
      raw.containsKey(_codecField);

  bool _accepts<T extends Object>(PreferenceKey<T> key, T value) => key.validate?.call(value) ?? true;

  void _emit<T extends Object>(PreferenceKey<T> key, T value, {required bool wasDefault}) {
    if (_disposed) {
      return;
    }
    _changes.add(PreferenceChange(keyName: key.name, value: value, wasDefault: wasDefault));
  }

  void _note(PreferenceRejection rejection) {
    _rejections.add(rejection);
    if (_rejections.length > 64) {
      _rejections.removeAt(0);
    }
  }
}

/// The failure type this package throws, so a caller never has to name the storage layer's exceptions.
class PreferenceException implements Exception {
  const PreferenceException(this.failure, this.detail);

  final PreferenceFailure failure;
  final String detail;

  @override
  String toString() => 'PreferenceException(${failure.name}: $detail)';
}

/// What one [PreferencesStore.importAll] did, per entry rather than as a yes/no.
final class PreferenceImportReport {
  const PreferenceImportReport({
    required this.accepted,
    required this.skipped,
    required this.rejected,
    required this.unknownKeys,
  });

  final int accepted;

  /// Present in the store and kept because `overwrite` was false.
  final int skipped;

  final int rejected;

  /// Names the caller has no key for - usually a newer app writing to an older one.
  final List<String> unknownKeys;

  bool get isClean => rejected == 0 && unknownKeys.isEmpty;

  @override
  String toString() =>
      'PreferenceImportReport(accepted: $accepted, skipped: $skipped, rejected: $rejected, unknown: ${unknownKeys.length})';
}

/// The store view that prefixes every key, so two apps can share one file without colliding.
final class _PrefixedStore implements KeyValueStore {
  _PrefixedStore(this._store, this.prefix);

  final KeyValueStore _store;
  final String prefix;

  @override
  Future<Object?> read(String key) => _store.read('$prefix$key');

  @override
  Future<void> write(String key, Object? value) => _store.write('$prefix$key', value);

  @override
  Future<void> remove(String key) => _store.remove('$prefix$key');

  @override
  Future<List<String>> keys() async => [
    for (final key in await _store.keys())
      if (key.startsWith(prefix)) key.substring(prefix.length),
  ];

  @override
  Future<void> clear() async {
    for (final key in await keys()) {
      await _store.remove('$prefix$key');
    }
  }
}
