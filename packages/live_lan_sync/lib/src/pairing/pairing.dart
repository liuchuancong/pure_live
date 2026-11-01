/// Device identity, the pairing ceremony and trust management (spec §9).
///
/// Pairing follows Bluetooth Secure Simple Pairing's numeric comparison
/// over TLS: X25519 key agreement, a responder commitment, a six-digit
/// short authentication string both users compare, HKDF-derived pairing
/// secrets and mutual key confirmation. `PairingResponder` is the side
/// whose user opened a pairing window; `PairingInitiator` is the side that
/// asks. `DeviceTrustService` manages trust afterwards.
library;

export 'device_trust_service.dart';
export 'fingerprint.dart';
export 'local_device_identity.dart';
export 'pairing_initiator.dart';
export 'pairing_outcome.dart';
export 'pairing_protocol.dart';
export 'pairing_rate_limiter.dart';
export 'pairing_responder.dart';
