import 'dart:convert' show jsonDecode, jsonEncode;

/// A persisted trust relationship with one peer, held by the device that
/// enforces it.
///
/// Every grant reads from the holder's side: the record on device A about
/// peer B says what *B may do on A* — read A's scopes, write into A's
/// scopes, exchange files with A — because A is the one checking requests
/// from B (spec §9.4). The record also pins B's TLS certificate
/// fingerprint, verified at pairing and on every connection. Secret key
/// material never lives here — the host's secure credential store keeps
/// it; this record holds only the fingerprint and metadata (spec §7.2,
/// §15.2).
final class DeviceTrust {
  /// A trust relationship with one peer.
  const new({
    required this.deviceId,
    required this.keyFingerprint,
    required this.displayName,
    required this.pairedAt,
    this.lastVerifiedAt,
    this.readScopes = const <String>{},
    this.writeScopes = const <String>{},
    this.filePermissions = const <DeviceFilePermission>{},
    this.canInitiateSync = true,
    this.canAcceptSync = true,
    this.revoked = false,
  });

  /// Restores a trust record persisted through [toJson].
  factory fromJson(Map<String, Object?> json) => DeviceTrust(
    deviceId: json['deviceId']! as String,
    keyFingerprint: json['keyFingerprint']! as String,
    displayName: json['displayName']! as String,
    pairedAt: DateTime.parse(json['pairedAt']! as String),
    lastVerifiedAt: switch (json['lastVerifiedAt']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    readScopes: {...(json['readScopes']! as List<Object?>).cast<String>()},
    writeScopes: {...(json['writeScopes']! as List<Object?>).cast<String>()},
    filePermissions: {
      for (final name in json['filePermissions']! as List<Object?>) DeviceFilePermission.values.byName(name! as String),
    },
    canInitiateSync: json['canInitiateSync']! as bool,
    canAcceptSync: json['canAcceptSync']! as bool,
    revoked: json['revoked']! as bool,
  );

  /// Restores a trust record from [encode].
  factory decode(String raw) => DeviceTrust.fromJson(jsonDecode(raw)! as Map<String, Object?>);

  /// The peer's device id.
  final String deviceId;

  /// The `sha256:` fingerprint of the peer's TLS certificate — its
  /// long-term identity — authenticated during pairing. A later connection
  /// presenting a different certificate is an identity mismatch, never an
  /// update.
  final String keyFingerprint;

  /// The display name recorded at pairing time.
  final String displayName;

  /// When the pairing ceremony completed.
  final DateTime pairedAt;

  /// When this device last successfully verified the peer's identity.
  final DateTime? lastVerifiedAt;

  /// The scopes the peer may read from this device.
  final Set<String> readScopes;

  /// The scopes the peer may write into this device.
  final Set<String> writeScopes;

  /// The file directions this device allows with the peer. Default is the
  /// empty set: pairing grants no file access until the user says so
  /// (spec §9.4).
  final Set<DeviceFilePermission> filePermissions;

  /// Whether this device starts sync tasks with the peer on its own
  /// (outbound policy).
  final bool canInitiateSync;

  /// Whether this device accepts sync tasks the peer starts (inbound
  /// policy).
  final bool canAcceptSync;

  /// Whether the trust relationship has been revoked. A revoked record is
  /// kept so a reconnecting peer is refused with an explicit reason, and so
  /// its tombstones still suppress resurrection of deleted data.
  final bool revoked;

  /// Whether the peer may read [scope] from this device.
  bool allowsRead(String scope) => !revoked && readScopes.contains(scope);

  /// Whether the peer may write [scope] into this device.
  bool allowsWrite(String scope) => !revoked && writeScopes.contains(scope);

  /// Whether this device serves files to the peer (the peer may pull).
  bool get allowsSendFiles => !revoked && filePermissions.contains(DeviceFilePermission.send);

  /// Whether this device accepts files from the peer (the peer may push).
  bool get allowsReceiveFiles => !revoked && filePermissions.contains(DeviceFilePermission.receive);

  /// A copy with [revoked] set: revocation keeps the record for refusal
  /// reasons and tombstone coverage.
  DeviceTrust revoke() => DeviceTrust(
    deviceId: deviceId,
    keyFingerprint: keyFingerprint,
    displayName: displayName,
    pairedAt: pairedAt,
    lastVerifiedAt: lastVerifiedAt,
    readScopes: readScopes,
    writeScopes: writeScopes,
    filePermissions: filePermissions,
    canInitiateSync: false,
    canAcceptSync: false,
    revoked: true,
  );

  /// The JSON form persisted in the host's store.
  Map<String, Object?> toJson() => <String, Object?>{
    'deviceId': deviceId,
    'keyFingerprint': keyFingerprint,
    'displayName': displayName,
    'pairedAt': pairedAt.toIso8601String(),
    'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
    'readScopes': readScopes.toList(),
    'writeScopes': writeScopes.toList(),
    'filePermissions': filePermissions.map((p) => p.name).toList(),
    'canInitiateSync': canInitiateSync,
    'canAcceptSync': canAcceptSync,
    'revoked': revoked,
  };

  /// The JSON-encoded form, for stores that persist whole strings.
  String encode() => jsonEncode(toJson());

  @override
  String toString() =>
      'DeviceTrust($deviceId, ${revoked ? 'revoked' : 'trusted'}, '
      'read:${readScopes.length}, write:${writeScopes.length})';
}

/// The file directions a trust record allows, from the holder's side.
enum DeviceFilePermission {
  /// This device serves files to the peer.
  send,

  /// This device accepts files from the peer.
  receive,
}
