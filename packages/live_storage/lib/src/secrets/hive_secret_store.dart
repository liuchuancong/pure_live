import 'dart:async';
import 'dart:typed_data';

import 'package:hive_box_manager/hive_box_manager.dart';
import 'package:live_storage/src/secrets/secret_cipher.dart';

/// Sealed secrets in a Hive box: cookies and passwords that must not sit
/// on disk in plain text. The box holds only ciphertext; the device-bound
/// [SecretCipher] opens it once at [load], after which reads are
/// synchronous.
///
/// A value that cannot be opened (another device, a reinstall, a lost
/// key) counts as signed out: it stays in [unreadable] and its sealed
/// bytes stay until the name is written again.
final class HiveSecretStore {
  new _(this._box, this._cipher, this._values, this.unreadable);

  /// Opens every stored secret through [cipher].
  static Future<HiveSecretStore> load({required KeyedBox<Uint8List, String> box, required SecretCipher cipher}) async {
    final values = <String, String>{};
    final unreadable = <String>{};

    for (final ref in box.keys) {
      final sealed = box.get(ref).toNullable();
      if (sealed == null) continue;
      try {
        values[ref] = await cipher.open(ref, sealed);
      } on Object {
        unreadable.add(ref);
      }
    }

    return HiveSecretStore._(box, cipher, values, unreadable);
  }

  final KeyedBox<Uint8List, String> _box;
  final SecretCipher _cipher;
  final Map<String, String> _values;

  /// Refs whose sealed value could not be opened.
  final Set<String> unreadable;

  final StreamController<String> _changes = StreamController.broadcast();

  /// The plain text of [ref], or null when absent or unreadable.
  String? value(String ref) => _values[ref];

  /// Whether [ref] currently holds a readable value.
  bool contains(String ref) => _values.containsKey(ref);

  /// Emits the name of every secret that appeared, changed or disappeared.
  Stream<String> get changes => _changes.stream;

  /// Seals [plain] under [ref], replacing any previous value.
  Future<void> set(String ref, String plain) async {
    final sealed = await _cipher.seal(ref, plain);
    await _box.put(ref, sealed).run();

    final before = _values[ref];
    _values[ref] = plain;
    if (unreadable.remove(ref) || before != plain) {
      _changes.add(ref);
    }
  }

  /// Removes [ref]; a no-op when absent.
  Future<void> remove(String ref) async {
    if (!_box.contains(ref)) return;

    await _box.delete(ref).run();
    _values.remove(ref);
    if (unreadable.remove(ref)) {
      _changes.add(ref);
    }
  }
}
