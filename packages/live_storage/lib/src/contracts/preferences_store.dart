import 'dart:async';

/// A typed key-value store for application settings.
///
/// Values are JSON-encodable scalars or structures (bool, num, String,
/// List, Map). Implementations must be durable where the backing store
/// is durable: a write that completes means the value survives a crash.
///
/// Per the storage spec: do not put tokens or cookies here — those
/// belong to a SecureStore.
abstract interface class PreferencesStore {
  /// Reads the value stored under [key], or null when absent.
  ///
  /// Throws a StorageException on read failure — a broken store never
  /// masquerades as "no value".
  Future<Object?> read(String key);

  /// Writes [value] under [key]; null removes the entry.
  Future<void> write(String key, Object? value);

  /// Removes [key]; a no-op when absent.
  Future<void> remove(String key);

  /// Removes every entry. Used by explicit reset flows only.
  Future<void> clear();

  /// Emits after every committed mutation, for reactive settings UI.
  Stream<void> get changes;
}
