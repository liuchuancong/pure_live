import 'dart:async';

/// A change to a keyed table, emitted through [KeyedStore.watch].
final class KeyedEvent {
  /// An event for [key].
  const new({required this.key, required this.deleted, this.value});

  /// The key that changed.
  final String key;

  /// Whether the entry was removed.
  final bool deleted;

  /// The new value; null when [deleted] (a null put is a removal).
  final Object? value;
}

/// A keyed table of JSON documents, modeled after a Hive box.
///
/// One store instance names one table; the caller opens the table
/// through `PureLiveDatabase.openStore` and reads it like a map: the
/// table lives in memory, [get] answers synchronously, [put] and
/// [delete] update the memory first and only complete once the change
/// is durable — a failed write rolls the mirror back, so it never
/// drifts from the table behind this process' own writes. Values are
/// JSON-encodable scalars or structures (bool, num, String, List, Map);
/// putting null removes the entry.
///
/// The interface carries no domain meaning — settings, documents and
/// business records all use these same methods, and everything above
/// them (typing, defaults, shape versioning) belongs to callers.
abstract interface class KeyedStore {
  /// The keys currently present in the table.
  Iterable<String> get keys;

  /// Whether [key] has a value.
  bool containsKey(String key);

  /// Reads the value under [key] from memory.
  ///
  /// Absent keys answer [defaultValue]; a stored value that is not a
  /// [T] throws — a type mismatch is a programming error, not a missing
  /// value.
  T? get<T>(String key, {T? defaultValue});

  /// Writes [value] under [key]; null removes the entry.
  ///
  /// The memory mirror updates immediately; the returned future
  /// completes once the change is durable. On failure the mirror is
  /// rolled back and the error propagates — [get] never claims a write
  /// that did not land.
  Future<void> put(String key, Object? value);

  /// Removes [key]; a no-op when absent.
  Future<void> delete(String key);

  /// Removes every entry in this table, leaving other tables untouched.
  Future<void> clear();

  /// Emits one [KeyedEvent] per committed change; [watch]ing a [key]
  /// filters the stream to that key.
  Stream<KeyedEvent> watch({String? key});
}
