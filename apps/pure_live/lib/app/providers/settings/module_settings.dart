import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_storage/live_storage.dart' show StoragePrefs;

import 'package:pure_live/app/providers/navigation/module_providers.dart' show selectedModuleProvider;
import 'package:pure_live/shared/shared.dart' show AppModule;

/// One module's settings namespace.
///
/// Every key lives under `m.<module>.<key>`; a module answers its own value
/// first and falls back to the shared key the app stored before the sandbox
/// existed, so upgrading keeps what every module looked like and the first
/// write in a module starts its own copy.
///
/// A write always lands in the namespace of the [module] this instance was
/// built for — not in whichever module happens to be selected when the write
/// resolves — so a page shutting down during a switch cannot leak its cleanup
/// into the next module.
final class ModuleSettings {
  /// The settings of [module].
  const ModuleSettings(this.module);

  /// The module whose namespace these reads and writes use.
  final AppModule module;

  /// The store key this module keeps [key] under.
  String storeKey(String key) => 'm.${module.name}.$key';

  Object? _read(String key) {
    final scoped = StoragePrefs.getAnyPref(storeKey(key));
    if (scoped != null) return scoped;
    return StoragePrefs.getAnyPref(key);
  }

  /// The string under [key], or null.
  String? getString(String key) {
    final value = _read(key);
    return value is String ? value : null;
  }

  /// Stores [value] under [key].
  Future<bool> setString(String key, String value) => StoragePrefs.setString(storeKey(key), value);

  /// The bool under [key], or null.
  bool? getBool(String key) {
    final value = _read(key);
    return value is bool ? value : null;
  }

  /// Stores [value] under [key].
  // The shape mirrors StoragePrefs, whose setters are positional.
  // ignore: avoid_positional_boolean_parameters
  Future<bool> setBool(String key, bool value) => StoragePrefs.setBool(storeKey(key), value);

  /// The int under [key], or null.
  int? getInt(String key) {
    final value = _read(key);
    return value is int ? value : null;
  }

  /// Stores [value] under [key].
  Future<bool> setInt(String key, int value) => StoragePrefs.setInt(storeKey(key), value);

  /// The double under [key], or null.
  double? getDouble(String key) {
    final value = _read(key);
    return value is double ? value : null;
  }

  /// Stores [value] under [key].
  Future<bool> setDouble(String key, double value) => StoragePrefs.setDouble(storeKey(key), value);

  /// The string list under [key], or null.
  List<String>? getStringList(String key) {
    final value = _read(key);
    return value is List ? List<String>.from(value) : null;
  }

  /// Stores [value] under [key].
  Future<bool> setStringList(String key, List<String> value) => StoragePrefs.setStringList(storeKey(key), value);

  /// The raw value under [key], or null.
  Object? getAny(String key) => _read(key);

  /// Stores any encodable [value] under [key].
  Future<bool> setAny(String key, Object? value) => StoragePrefs.setAnyPref(storeKey(key), value);

  /// Whether [key] answers anything.
  bool containsKey(String key) => _read(key) != null;

  /// Removes this module's copy of [key].
  Future<bool> remove(String key) => StoragePrefs.remove(storeKey(key));

  /// Commits related preferences in one transaction, all in this module's
  /// namespace.
  Future<void> setPrefs(Map<String, Object> values) =>
      StoragePrefs.setPrefs({for (final entry in values.entries) storeKey(entry.key): entry.value});
}

/// The selected module's settings namespace; rebuilding when the shell moves
/// to another module is what makes every settings provider read its own copy.
final moduleSettingsProvider = Provider<ModuleSettings>(
  (ref) => ModuleSettings(ref.watch(selectedModuleProvider)),
);
