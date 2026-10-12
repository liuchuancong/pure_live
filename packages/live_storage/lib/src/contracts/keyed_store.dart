import 'dart:async';

/// A keyed table of JSON documents.
///
/// One store instance names one table; the caller picks the table, this
/// package only defines how rows behave. Values are JSON-encodable
/// scalars or structures (bool, num, String, List, Map) and round-trip
/// through the store unchanged. Writing null removes the entry, so
/// "absent" and "deleted" share one path.
///
/// The interface carries no domain meaning — settings, documents and
/// business records all use these same methods, and everything above
/// them (typing, defaults, shape versioning) belongs to callers.
abstract interface class KeyedStore {
  /// Reads the value stored under [key], or null when absent.
  ///
  /// Throws a StorageException on read failure — a broken store never
  /// masquerades as "no value".
  Future<Object?> read(String key);

  /// Reads every entry in the table, in key order.
  Future<Map<String, Object?>> readAll();

  /// The keys present in the table, in key order.
  Future<List<String>> keys();

  /// Writes [value] under [key], replacing any previous entry; null
  /// removes the entry.
  Future<void> write(String key, Object? value);

  /// Removes [key]; a no-op when absent.
  Future<void> remove(String key);

  /// Removes every entry in this table, leaving other tables untouched.
  Future<void> clear();

  /// Emits after every committed mutation of this table, for reactive
  /// readers.
  Stream<void> get changes;
}
