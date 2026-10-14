import 'dart:async';
import 'dart:convert';

import 'package:live_record_core/src/record_task.dart';

/// Where tasks are kept, so a later launch can finish what this one started.
abstract interface class RecordStore {
  /// Every stored task, oldest first.
  Future<List<RecordTask>> loadAll();

  /// Writes [task], replacing any earlier record of it.
  Future<void> save(RecordTask task);

  /// Forgets [taskId]. Does not touch its files.
  Future<void> remove(String taskId);
}

/// The bytes behind a store, injected so the ledger is testable without a
/// filesystem and so a host can keep its tasks in Hive, a database or a file
/// directory without this package knowing which.
abstract interface class RecordSlotIo {
  /// Reads a slot, or null when it holds nothing readable.
  Future<String?> read(String key);

  /// Writes a slot, replacing what was there.
  Future<void> write(String key, String value);

  /// Deletes a slot.
  Future<void> delete(String key);

  /// Every slot key.
  Future<List<String>> keys();
}

/// One JSON document per task, through [RecordSlotIo].
///
/// The task's id is the key, so a write is an update rather than an append, and a
/// document that fails to parse is skipped instead of aborting the load: one
/// half-written record from a power cut must not cost the viewer every other
/// recording they have pending.
final class RecordJsonStore implements RecordStore {
  /// Creates a store over [io].
  const new(this.io);

  /// Where the documents live.
  final RecordSlotIo io;

  @override
  Future<List<RecordTask>> loadAll() async {
    final tasks = <RecordTask>[];

    for (final key in await io.keys()) {
      final raw = await io.read(key);

      if (raw == null || raw.isEmpty) {
        continue;
      }

      final task = _decode(raw);

      if (task != null) {
        tasks.add(task);
      }
    }

    tasks.sort((left, right) => left.createdAt.compareTo(right.createdAt));

    return List<RecordTask>.unmodifiable(tasks);
  }

  @override
  Future<void> save(RecordTask task) => io.write(_key(task.taskId), jsonEncode(task.toJson()));

  @override
  Future<void> remove(String taskId) => io.delete(_key(taskId));

  String _key(String taskId) => '$taskId.json';

  RecordTask? _decode(String raw) {
    try {
      final document = jsonDecode(raw);

      if (document is! Map) {
        return null;
      }

      return RecordTask.fromJson(document.cast<String, Object?>());
    } on FormatException {
      return null;
    }
  }
}
