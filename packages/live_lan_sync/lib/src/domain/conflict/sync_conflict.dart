import 'package:live_lan_sync/src/domain/conflict/version_vector.dart' show VersionRelation, VersionVector;
import 'package:live_lan_sync/src/domain/sync/sync_change.dart';

/// One detected concurrent modification.
///
/// A conflict is a fact to persist and report, not a transient error: the
/// host's store keeps it (spec §15.2) so a UI can list and settle it after
/// a restart. [key] is its stable identity in that store.
final class SyncConflict {
  /// The detected concurrent modification of one entity.
  const new({
    required this.scope,
    required this.entityId,
    required this.local,
    required this.remote,
    required this.relation,
  });

  /// Restores a conflict persisted through [toJson].
  factory fromJson(Map<String, Object?> json) => SyncConflict(
    scope: json['scope']! as String,
    entityId: json['entityId']! as String,
    local: SyncChange.fromJson(json['local']! as Map<String, Object?>),
    remote: SyncChange.fromJson(json['remote']! as Map<String, Object?>),
    relation: VersionRelation.values.byName(json['relation']! as String),
  );

  /// The scope the conflicting entity lives in.
  final String scope;

  /// The entity edited concurrently.
  final String entityId;

  /// This device's version.
  final SyncChange local;

  /// The peer's version.
  final SyncChange remote;

  /// How the two version vectors related when the conflict was detected —
  /// [VersionRelation.concurrent] for a true concurrent edit, or another
  /// relation when an adapter reported an unresolvable semantic clash.
  final VersionRelation relation;

  /// The stable identity of this conflict record: one entity per scope
  /// holds at most one open conflict.
  String get key => '$scope/$entityId';

  /// The current vector of the conflicting entity: the vector the resolved
  /// result must carry forward.
  VersionVector get mergedHead => local.revision.merged(remote.revision);

  /// The JSON form persisted in the host's store.
  Map<String, Object?> toJson() => <String, Object?>{
    'scope': scope,
    'entityId': entityId,
    'local': local.toJson(),
    'remote': remote.toJson(),
    'relation': relation.name,
  };
}
