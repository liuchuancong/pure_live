/// One scope as a device offers it to one peer, exchanged before any batch
/// moves (spec §10.3 steps 2–4).
///
/// The answering device states its payload schema version, how far its
/// change log for the scope reaches, and what the asking peer may do with
/// the scope here — read it (pull) and write into it (push) — as its own
/// trust record for that peer grants.
final class SyncManifest {
  /// A scope's offer to one peer.
  const new({
    required this.scope,
    required this.schemaVersion,
    required this.latestSequence,
    required this.canRead,
    required this.canWrite,
  });

  /// Restores a manifest from its wire form.
  factory fromJson(Map<String, Object?> json) => SyncManifest(
    scope: json['scope']! as String,
    schemaVersion: (json['schemaVersion']! as num).toInt(),
    latestSequence: (json['latestSequence']! as num).toInt(),
    canRead: json['canRead'] == true,
    canWrite: json['canWrite'] == true,
  );

  /// The scope this manifest describes.
  final String scope;

  /// The payload schema version the answering device's adapter speaks.
  final int schemaVersion;

  /// The highest sequence in the answering device's change log for the
  /// scope; 0 when the log is empty.
  final int latestSequence;

  /// Whether the asking peer may pull the scope.
  final bool canRead;

  /// Whether the asking peer may push into the scope.
  final bool canWrite;

  /// The wire form.
  Map<String, Object?> toJson() => <String, Object?>{
    'scope': scope,
    'schemaVersion': schemaVersion,
    'latestSequence': latestSequence,
    'canRead': canRead,
    'canWrite': canWrite,
  };

  @override
  String toString() => 'SyncManifest($scope, v$schemaVersion, #$latestSequence, read: $canRead, write: $canWrite)';
}
