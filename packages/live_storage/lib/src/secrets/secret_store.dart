import 'dart:async';

import 'package:live_storage/src/secrets/secret_vault.dart';

/// The app's secrets (cookies, passwords), cached in memory over a
/// device-encrypted [SecretVault].
///
/// Everything is read once at [load]; after that reads are synchronous
/// and writes go straight through to the vault. The values never sit on
/// disk in plain text and never travel in backups unless a caller reads
/// them out explicitly.
final class SecretStore {
  new _(this._vault, this._values);

  /// Loads every stored secret into memory.
  static Future<SecretStore> load({required SecretVault vault}) async {
    return SecretStore._(vault, await vault.readAll());
  }

  final SecretVault _vault;
  final Map<String, String> _values;
  final StreamController<String> _changes = StreamController.broadcast();

  /// The plain text of [ref], or null when absent.
  String? value(String ref) => _values[ref];

  /// Whether [ref] currently holds a value.
  bool contains(String ref) => _values.containsKey(ref);

  /// Every stored ref.
  List<String> get refs => List.unmodifiable(_values.keys);

  /// Emits the name of every secret that appeared, changed or disappeared.
  Stream<String> get changes => _changes.stream;

  /// Stores [plain] under [ref], replacing any previous value.
  Future<void> set(String ref, String plain) async {
    final before = _values[ref];
    await _vault.write(ref, plain);
    _values[ref] = plain;
    if (before != plain) {
      _changes.add(ref);
    }
  }

  /// Removes [ref]; a no-op when absent.
  Future<void> remove(String ref) async {
    if (!_values.containsKey(ref)) return;

    await _vault.delete(ref);
    if (_values.remove(ref) != null) {
      _changes.add(ref);
    }
  }
}
