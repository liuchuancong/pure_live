import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_room_parser.dart';

/// CC's lease lookup by URL: a signed media address carries its expiry in
/// `auth_key`, so a held address's lifetime is read back without asking the
/// room again. An HLS address keeps its reconnect requirement, since a new
/// connection needs a fresh signature.
///
/// An address past its expiry answers a past lease rather than null, so a
/// stale address reads as dead instead of immortal; an unsigned address
/// answers null.
final class CcPlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup over [now] (injectable for tests).
  new({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Injectable clock.
  final DateTime Function() now;

  @override
  LivePlayLease? leaseOf(Uri url) => CcRoomParser.lease(url, now().toUtc(), allowExpired: true);
}
