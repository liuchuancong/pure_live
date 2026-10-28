import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_room_parser.dart';

/// Kugou Live's lease lookup by URL: a signed media address carries its
/// `txTime` (hex Unix seconds), so a held address's lifetime is read back
/// without asking the room again.
///
/// An address past its `txTime` answers a past lease rather than null, so a
/// stale address reads as dead instead of immortal; an unsigned address
/// answers null.
final class KugoulivePlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup.
  const new();

  @override
  LivePlayLease? leaseOf(Uri url) => KugouliveRoomParser.lease(url);
}
