import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:live_lan_sync/src/domain/conflict/conflict.dart' show VersionVector;

/// One generic change the engine exchanges.
///
/// A change is a fact about one entity ("upsert this payload", "this entity
/// was deleted"), produced by the host's business layer into its outbox and
/// applied by the peer's adapter. The engine understands every field except
/// [payload] — that belongs to the business adapters on both ends.
///
/// Identity and idempotency: [operationId] is globally unique, and a peer
/// that has already applied it must answer "already applied" instead of
/// applying again (spec §10.4). [entityId] is stable across devices so both
/// ends agree on *which* thing changed.
final class SyncChange {
  /// One change to one entity.
  const new({
    required this.operationId,
    required this.scope,
    required this.entityType,
    required this.entityId,
    required this.originDeviceId,
    required this.operation,
    required this.schemaVersion,
    required this.revision,
    required this.createdAt,
    this.payload = const <String, Object?>{},
  });

  /// Restores a change from its wire form. Throws when a required field is
  /// missing or malformed; the transport layer surfaces that as a data
  /// validation failure.
  factory fromJson(Map<String, Object?> json) => SyncChange(
    operationId: json['operationId']! as String,
    scope: json['scope']! as String,
    entityType: json['entityType']! as String,
    entityId: json['entityId']! as String,
    originDeviceId: json['originDeviceId']! as String,
    operation: SyncOperation.values.byName(json['operation']! as String),
    schemaVersion: (json['schemaVersion']! as num).toInt(),
    revision: VersionVector.fromJson(json['revision']! as Map<String, Object?>),
    createdAt: DateTime.parse(json['createdAt']! as String),
    payload: switch (json['payload']) {
      final Map<Object?, Object?> payload => payload.cast<String, Object?>(),
      null => <String, Object?>{},
      _ => throw const FormatException('payload must be a JSON object'),
    },
  );

  /// Restores a change from [encode].
  factory decode(String raw) => SyncChange.fromJson(jsonDecode(raw)! as Map<String, Object?>);

  /// Globally unique operation id, the idempotency key.
  final String operationId;

  /// The host-registered scope this change belongs to, e.g. `favorites`.
  final String scope;

  /// The kind of entity inside the scope, e.g. `favorite`.
  final String entityType;

  /// The entity's stable id, identical on every device.
  final String entityId;

  /// The device that produced this change.
  final String originDeviceId;

  /// What happened to the entity.
  final SyncOperation operation;

  /// The payload schema version the producing adapter wrote.
  final int schemaVersion;

  /// The entity's version vector as of this change, the basis for causal
  /// comparison and conflict detection on the receiving end.
  final VersionVector revision;

  /// When the change was produced (informational; never used for ordering).
  final DateTime createdAt;

  /// The business-owned payload, plain JSON only. A delete carries no
  /// payload beyond the tombstone facts.
  final Map<String, Object?> payload;

  /// Whether this change is a tombstone.
  bool get isTombstone => operation == SyncOperation.delete;

  /// The deduplication key: two changes with the same [operationId] are the
  /// same operation and must be applied once.
  String get deduplicationKey => operationId;

  /// The JSON form carried over the wire.
  Map<String, Object?> toJson() => <String, Object?>{
    'operationId': operationId,
    'scope': scope,
    'entityType': entityType,
    'entityId': entityId,
    'originDeviceId': originDeviceId,
    'operation': operation.name,
    'schemaVersion': schemaVersion,
    'revision': revision.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'payload': payload,
  };

  /// The JSON-encoded wire form.
  String encode() => jsonEncode(toJson());

  @override
  String toString() => 'SyncChange($operationId, $scope/$entityId, ${operation.name})';
}

/// What happened to an entity.
enum SyncOperation {
  /// The payload is the entity's current full state.
  upsert,

  /// The entity was deleted; the change is a tombstone.
  delete,
}
