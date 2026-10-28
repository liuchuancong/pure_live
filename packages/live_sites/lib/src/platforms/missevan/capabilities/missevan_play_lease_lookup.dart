import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_room_parser.dart';

/// Missevan's lease lookup by URL: a pull address carries `expires` (Unix
/// seconds), so a held address's lifetime is read back without asking the
/// room again. An HLS address keeps its reconnect requirement, since every
/// playlist fetch is a new request.
///
/// An address past its expiry answers a past lease rather than null, so a
/// stale address reads as dead instead of immortal; an address outside the
/// pull host or without `expires` answers null.
final class MissevanPlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup.
  const new();

  @override
  LivePlayLease? leaseOf(Uri url) => MissevanRoomParser.lease(url.toString());
}
