import 'package:live_lan_sync/src/domain/protocol/lan_sync_protocol.dart';

/// Security parameters.
///
/// The non-negotiables are deliberately *not* configuration: pairing is
/// always required, traffic is always encrypted, and discovered devices are
/// never auto-trusted. What a host tunes here is only how strict the
/// pairing ceremony is and which protocol versions it accepts.
final class LanSyncSecurityConfig {
  /// The security defaults.
  const new({
    this.pairingCodeTtl = const Duration(minutes: 3),
    this.maxPairingAttempts = 5,
    this.rateLimitWindow = const Duration(minutes: 1),
    this.allowedProtocolVersions = const <int>{LanSyncProtocol.current},
    this.maxPendingPairingSessions = 4,
  });

  /// How long a pairing session (and the short authentication string the
  /// two users compare) stays valid, and how long a pairing window opened
  /// without an explicit duration stays open.
  final Duration pairingCodeTtl;

  /// The failed pairing attempts allowed per device before it is locked out
  /// for [rateLimitWindow].
  final int maxPairingAttempts;

  /// The window the pairing and request rate limits apply over.
  final Duration rateLimitWindow;

  /// The protocol versions this device accepts during negotiation. An empty
  /// set fails validation: a device that accepts nothing must not serve.
  final Set<int> allowedProtocolVersions;

  /// The most pairing sessions a responder keeps open at once; further
  /// challenges are refused until one finishes (spec §21: bounded queues).
  final int maxPendingPairingSessions;

  /// Returns the human-readable problems with this configuration, or an
  /// empty list when it is usable as is.
  List<String> validate() {
    final problems = <String>[];
    if (pairingCodeTtl <= Duration.zero) {
      problems.add('security.pairingCodeTtl must be positive');
    }
    if (pairingCodeTtl > const Duration(minutes: 10)) {
      problems.add('security.pairingCodeTtl must stay at or under 10 minutes');
    }
    if (maxPairingAttempts < 1) {
      problems.add('security.maxPairingAttempts must be at least 1');
    }
    if (rateLimitWindow <= Duration.zero) {
      problems.add('security.rateLimitWindow must be positive');
    }
    if (allowedProtocolVersions.isEmpty) {
      problems.add('security.allowedProtocolVersions must not be empty');
    }
    if (maxPendingPairingSessions < 1) {
      problems.add('security.maxPendingPairingSessions must be at least 1');
    }
    return problems;
  }
}
