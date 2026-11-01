import 'dart:convert' show jsonDecode, jsonEncode;

/// How far one peer has been followed for one scope.
///
/// Cursors are strictly per (peer, scope): device A having delivered its
/// favorites says nothing about device B, and favorites having synced says
/// nothing about settings. A cursor only ever advances after the batch it
/// names has been durably applied — advancing it earlier risks silently
/// losing changes on the next sync (spec §10.3, §15.3).
final class SyncCursor {
  /// A per-peer, per-scope position.
  const new({
    required this.peerDeviceId,
    required this.scope,
    this.localCheckpoint,
    this.remoteCheckpoint,
    this.lastSuccessfulSyncAt,
    this.protocolVersion = 1,
  });

  /// Restores a cursor persisted through [toJson].
  factory fromJson(Map<String, Object?> json) => SyncCursor(
    peerDeviceId: json['peerDeviceId']! as String,
    scope: json['scope']! as String,
    localCheckpoint: switch (json['localCheckpoint']) {
      final String value => value,
      _ => null,
    },
    remoteCheckpoint: switch (json['remoteCheckpoint']) {
      final String value => value,
      _ => null,
    },
    lastSuccessfulSyncAt: switch (json['lastSuccessfulSyncAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    protocolVersion: switch (json['protocolVersion']) {
      final num version => version.toInt(),
      _ => 1,
    },
  );

  /// Restores a cursor from [encode].
  factory decode(String raw) => SyncCursor.fromJson(jsonDecode(raw)! as Map<String, Object?>);

  /// The device this cursor follows.
  final String peerDeviceId;

  /// The scope this cursor tracks.
  final String scope;

  /// How far in *this* device's change log the peer has confirmed
  /// receiving — where pushes to the peer resume.
  final String? localCheckpoint;

  /// How far in the *peer's* change log this device has durably applied —
  /// where pulls from the peer resume.
  final String? remoteCheckpoint;

  /// When the last fully successful exchange completed.
  final DateTime? lastSuccessfulSyncAt;

  /// The protocol version the cursor was written under; a mismatch after an
  /// upgrade forces a fresh manifest comparison.
  final int protocolVersion;

  /// A copy advanced to [remoteCheckpoint], stamped with [at]. Callers pass
  /// the checkpoint only after the batch it names is durably applied.
  SyncCursor advanced({required String remoteCheckpoint, required DateTime at}) => SyncCursor(
    peerDeviceId: peerDeviceId,
    scope: scope,
    localCheckpoint: localCheckpoint,
    remoteCheckpoint: remoteCheckpoint,
    lastSuccessfulSyncAt: at,
    protocolVersion: protocolVersion,
  );

  /// A copy recording that the peer confirmed this device's log through
  /// [localCheckpoint], stamped with [at].
  SyncCursor acknowledged({required String localCheckpoint, required DateTime at}) => SyncCursor(
    peerDeviceId: peerDeviceId,
    scope: scope,
    localCheckpoint: localCheckpoint,
    remoteCheckpoint: remoteCheckpoint,
    lastSuccessfulSyncAt: at,
    protocolVersion: protocolVersion,
  );

  /// The JSON form persisted in the host's store.
  Map<String, Object?> toJson() => <String, Object?>{
    'peerDeviceId': peerDeviceId,
    'scope': scope,
    'localCheckpoint': localCheckpoint,
    'remoteCheckpoint': remoteCheckpoint,
    'lastSuccessfulSyncAt': lastSuccessfulSyncAt?.toIso8601String(),
    'protocolVersion': protocolVersion,
  };

  /// The JSON-encoded form, for stores that persist whole strings.
  String encode() => jsonEncode(toJson());

  @override
  String toString() => 'SyncCursor($peerDeviceId/$scope, remote:$remoteCheckpoint)';
}
