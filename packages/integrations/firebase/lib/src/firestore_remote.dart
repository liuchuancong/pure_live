// Module: lib/src/firestore_remote.dart
// Purpose: Bind the sync engine's remote port to a Firestore collection, with tombstones, cursors and batch
// limits that match what the database actually allows.
// Author: liuchuancong
// Created: 2026-10-11
//
// Firestore is the pluggable cloud backend docs/services/sync.md names for the sync remote, and this is the
// only place the vendor types are allowed to appear. Two constraints shape the code: a commit batch is capped
// at 500 writes (a push that exceeds it does not slow down, it fails), and a cursor has to be a value the
// query can compare - so it is the highest `updatedAt` seen, which is monotonic per store, not a Firestore
// page token that expires.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pure_live_sync/pure_live_sync.dart';
import 'package:pure_live_utils/pure_live_utils.dart';

/// The field names one sync document carries.
///
/// Written down as constants because a typo in a query string is a silent empty page: the remote answers 200
/// with nothing, the cursor never advances, and the user sees a sync that always reports "up to date".
final class SyncFields {
  const SyncFields._();

  static const String key = 'key';
  static const String updatedAt = 'updatedAt';
  static const String deleted = 'deleted';
  static const String value = 'value';
  static const String writtenAt = 'writtenAt';
}

/// Firestore allows at most 500 writes in one commit.
const int kFirestoreMaxBatchWrites = 500;

/// The default page size a pull asks for.
const int kSyncDefaultPageSize = 200;

/// A [RemoteStore] backed by one Firestore collection.
final class FirestoreSyncRemote implements RemoteStore {
  FirestoreSyncRemote({
    required FirebaseFirestore firestore,
    required this.collection,
    this.isCredentialKey = _neverCredential,
    this.pageSize = kSyncDefaultPageSize,
    this.maxPushRecords = 5 * kFirestoreMaxBatchWrites,
    Clock? clock,
  }) : _firestore = firestore,
       _clock = clock ?? systemClock {
    if (collection.trim().isEmpty) {
      throw ArgumentError.value(collection, 'collection', 'a sync collection path cannot be blank');
    }
    if (pageSize < 1 || pageSize > 1000) {
      throw ArgumentError.value(pageSize, 'pageSize', 'must be between 1 and 1000');
    }
    if (maxPushRecords < 1) {
      throw ArgumentError.value(maxPushRecords, 'maxPushRecords', 'must allow at least one record');
    }
  }

  /// Convenience for the layout this repository uses: `users/<userId>/sync`.
  factory FirestoreSyncRemote.forUser({
    required FirebaseFirestore firestore,
    required String userId,
    bool Function(String key) isCredentialKey = _neverCredential,
    int pageSize = kSyncDefaultPageSize,
    Clock? clock,
  }) {
    final trimmed = userId.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'cannot be blank');
    }
    return FirestoreSyncRemote(
      firestore: firestore,
      collection: 'users/$trimmed/sync',
      isCredentialKey: isCredentialKey,
      pageSize: pageSize,
      clock: clock,
    );
  }

  final FirebaseFirestore _firestore;
  final String collection;
  final Clock _clock;

  /// Keys that hold a credential are never read from or written to the cloud, enforced here as well as in the
  /// engine: a client bug should not be the only thing keeping a token out of someone's database.
  final bool Function(String key) isCredentialKey;

  final int pageSize;

  /// The largest single push. Extra records stay pending locally and go on the next pass rather than being
  /// dropped: a user who deleted a hundred favourites while offline must not lose them to a cap.
  final int maxPushRecords;

  int _droppedOverCap = 0;

  /// Push attempts that exceeded [maxPushRecords] and were truncated.
  int get truncatedPushes => _droppedOverCap;

  @override
  Future<RemoteBatch> fetchSince(SyncCursor cursor) async {
    final after = decodeSyncCursor(cursor);
    final query = _query(after, pageSize);
    final snapshot = await query.get();
    final records = <SyncRecord>[];
    DateTime? newest;
    for (final doc in snapshot.docs) {
      final record = recordFromDocument(doc.id, doc.data());
      if (record == null) {
        continue;
      }
      if (isCredentialKey(record.key)) {
        continue;
      }
      records.add(record);
      if (newest == null || record.updatedAt.isAfter(newest)) {
        newest = record.updatedAt;
      }
    }
    // A short page means the collection is exhausted; a full page means there is at least as much left, and
    // the engine's paged walk will ask again.
    return RemoteBatch(records: records, cursor: encodeSyncCursor(newest));
  }

  /// The commit batch limit is per call, so a large push is split into several.
  Query<Map<String, dynamic>> _query(DateTime? after, int limit) {
    final base = _firestore.collection(collection).orderBy(SyncFields.updatedAt, descending: false);
    if (after == null) {
      return base.limit(limit);
    }
    return base.where(SyncFields.updatedAt, isGreaterThan: Timestamp.fromDate(after)).limit(limit);
  }

  @override
  Future<SyncCursor> push(List<SyncRecord> records) async {
    final allowed = records.where((record) => !isCredentialKey(record.key)).toList(growable: false);
    if (allowed.isEmpty) {
      return SyncCursor.start;
    }
    var batched = allowed;
    if (allowed.length > maxPushRecords) {
      _droppedOverCap++;
      batched = allowed.take(maxPushRecords).toList(growable: false);
    }
    DateTime? newest;
    for (var start = 0; start < batched.length; start += kFirestoreMaxBatchWrites) {
      final slice = batched.skip(start).take(kFirestoreMaxBatchWrites);
      final write = _firestore.batch();
      for (final record in slice) {
        write.set(
          _firestore.doc('$collection/${Uri.encodeComponent(record.key)}'),
          documentFromRecord(record, writtenAt: _clock().toUtc()),
          SetOptions(merge: true),
        );
      }
      await write.commit();
      for (final record in slice) {
        if (newest == null || record.updatedAt.isAfter(newest)) {
          newest = record.updatedAt;
        }
      }
    }
    return encodeSyncCursor(newest);
  }

  /// Removes one key's document. A deletion normally travels as a tombstone; this is for a hard wipe, which is
  /// why the engine never calls it - sync does not delete remotely on its own.
  Future<void> erase(String key) async {
    if (key.trim().isEmpty) {
      return;
    }
    await _firestore.doc('$collection/${Uri.encodeComponent(key)}').delete();
  }

  /// How many documents the collection holds, for a pre-sync "this will take a while" hint.
  Future<int> count() async => (await _firestore.collection(collection).count().get()).count ?? 0;
}

/// A sync document as a flat map, ready for `set`.
Map<String, Object?> documentFromRecord(SyncRecord record, {DateTime? writtenAt}) {
  return <String, Object?>{
    SyncFields.key: record.key,
    SyncFields.updatedAt: Timestamp.fromDate(record.updatedAt.toUtc()),
    SyncFields.deleted: record.deleted,
    // A tombstone carries no value: the deletion must not leave the deleted content behind in the cloud.
    if (!record.deleted) SyncFields.value: record.value,
    if (record.deleted) SyncFields.value: null,
    SyncFields.writtenAt: Timestamp.fromDate((writtenAt ?? record.updatedAt).toUtc()),
  };
}

/// The record inside a document, or null when the document is not one this build understands.
///
/// A malformed row is skipped rather than thrown: one bad document written by an older app version must not
/// stop a user's whole sync, and the engine counts what a page skipped.
SyncRecord? recordFromDocument(String documentId, Map<String, dynamic>? data) {
  if (data == null) {
    return null;
  }
  final key = (data[SyncFields.key] as String?) ?? documentId;
  if (key.trim().isEmpty) {
    return null;
  }
  final stamp = data[SyncFields.updatedAt];
  final at = switch (stamp) {
    final Timestamp value => value.toDate(),
    final int value => DateTime.fromMillisecondsSinceEpoch(value, isUtc: true),
    final String value => DateTime.tryParse(value)?.toUtc(),
    _ => null,
  };
  if (at == null) {
    return null;
  }
  return SyncRecord(
    key: key,
    updatedAt: at.toUtc(),
    value: data[SyncFields.value],
    deleted: data[SyncFields.deleted] == true,
  );
}

/// The cursor token for a moment, or the start token for null.
String encodeCursorToken(DateTime? at) => at == null ? '' : '${at.toUtc().microsecondsSinceEpoch}';

/// The cursor for a moment, as the engine expects it.
SyncCursor encodeSyncCursor(DateTime? at) => SyncCursor(encodeCursorToken(at));

/// The moment a cursor token names, or null for the start.
DateTime? decodeSyncCursor(SyncCursor cursor) {
  final micros = int.tryParse(cursor.token);
  if (micros == null) {
    return null;
  }
  return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
}

bool _neverCredential(String key) => false;
