import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_room_parser.dart';

/// Kilakila's lease lookup by URL: a signed media address carries its expiry
/// in `auth_key`'s first field, so a held address's lifetime is read back
/// without asking the room again. An HLS address keeps its reconnect
/// requirement, since every segment is a new request.
///
/// An address past its expiry answers a past lease rather than null, so a
/// stale address reads as dead instead of immortal; an unsigned address
/// answers null.
final class KilakilaPlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup over [now] (injectable for tests).
  new({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Injectable clock.
  final DateTime Function() now;

  @override
  LivePlayLease? leaseOf(Uri url) => KilakilaRoomParser.lease(
    url.toString(),
    issuedAt: now().toUtc(),
    isHls: url.path.toLowerCase().endsWith('.m3u8'),
    allowExpired: true,
  );
}
