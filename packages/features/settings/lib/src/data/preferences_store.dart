// Module: lib/src/data/preferences_store.dart
// Purpose: Typed, kv-backed application preferences with old-install
// defaults: a missing key keeps the documented default, which is the rule the
// backup/restore and upgrade paths rely on.
// Author: liuchuancong
// Created: 2026-10-10

import 'package:pure_live_storage/pure_live_storage.dart';

/// The preferences keys this store owns. One place, so a typo is a compile
/// error instead of a silently second store.
abstract final class PreferenceKeys {
  static const String firstRunDone = 'settings.first_run_done';
  static const String preferredQuality = 'settings.preferred_quality';
  static const String danmakuEnabledByDefault = 'settings.danmaku_default';
  static const String homeTabOrder = 'settings.home_tab_order';
}

/// Typed preferences over one namespaced kv store. Every read names its
/// default; every write is explicit. No schema registry - the keys above are
/// the schema.
final class PreferencesStore {
  PreferencesStore({required KeyValueStore store}) : _store = _Namespaced(store, 'settings.');

  final _Namespaced _store;

  Future<bool> isFirstRun() async => await _store.read(PreferenceKeys.firstRunDone) == null;

  Future<void> markFirstRunDone() => _store.write(PreferenceKeys.firstRunDone, true);

  /// The player's default quality label, for example '原画' or '高清'. Empty
  /// means the source default.
  Future<String> preferredQuality() async => '${await _store.read(PreferenceKeys.preferredQuality) ?? ''}';

  Future<void> setPreferredQuality(String label) => _store.write(PreferenceKeys.preferredQuality, label);

  Future<bool> danmakuEnabledByDefault() async =>
      await _store.read(PreferenceKeys.danmakuEnabledByDefault) as bool? ?? true;

  Future<void> setDanmakuEnabledByDefault(bool value) => _store.write(PreferenceKeys.danmakuEnabledByDefault, value);

  /// The home tab order as ids, persisted as a JSON string list.
  Future<List<String>> homeTabOrder() async {
    final raw = await _store.read(PreferenceKeys.homeTabOrder);
    if (raw is! String || raw.isEmpty) {
      return const <String>[];
    }
    return raw.split(',');
  }

  Future<void> setHomeTabOrder(List<String> ids) => _store.write(PreferenceKeys.homeTabOrder, ids.join(','));
}

/// The [KeyValueStore] view that prefixes every key with `settings.`.
final class _Namespaced implements KeyValueStore {
  _Namespaced(this._store, this._prefix);

  final KeyValueStore _store;
  final String _prefix;

  String _key(String key) => '$_prefix$key';

  @override
  Future<Object?> read(String key) => _store.read(_key(key));

  @override
  Future<void> write(String key, Object? value) => _store.write(_key(key), value);

  @override
  Future<void> remove(String key) => _store.remove(_key(key));

  @override
  Future<List<String>> keys() async => [
    for (final key in await _store.keys())
      if (key.startsWith(_prefix)) key.substring(_prefix.length),
  ];

  @override
  Future<void> clear() async {
    for (final key in await keys()) {
      await _store.remove('$_prefix$key');
    }
  }
}
