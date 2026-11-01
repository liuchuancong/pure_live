import 'package:live_lan_sync/src/domain/device/device.dart' show DeviceTrust;

/// How a pairing ceremony ended.
sealed class PairingOutcome {
  /// How a pairing ceremony ended.
  const new();
}

/// The ceremony succeeded; the trust record and the pairing secret are
/// persisted already.
final class PairingCompleted extends PairingOutcome {
  /// The ceremony succeeded.
  const new(this.trust);

  /// The newly established trust relationship.
  final DeviceTrust trust;
}

/// The ceremony failed for [reason]; nothing was written.
final class PairingFailed extends PairingOutcome {
  /// The ceremony failed.
  const new(this.reason, this.message);

  /// The stable failure classification the host UI switches on.
  final PairingFailureReason reason;

  /// A safe, user-presentable description.
  final String message;
}

/// Why a pairing ceremony failed.
enum PairingFailureReason {
  /// The session id is unknown (never issued, or the responder restarted).
  unknownSession,

  /// The session outlived its lifetime before both users confirmed.
  sessionExpired,

  /// The other device's key confirmation did not verify: it derived a
  /// different secret, so someone tampered with the exchange.
  keyConfirmationFailed,

  /// This device's user declined after comparing the codes.
  rejectedByUser,

  /// The other device's user declined.
  rejectedByPeer,

  /// The device id is already paired with a different certificate — an
  /// identity anomaly, never an automatic overwrite.
  identityTaken,
}
