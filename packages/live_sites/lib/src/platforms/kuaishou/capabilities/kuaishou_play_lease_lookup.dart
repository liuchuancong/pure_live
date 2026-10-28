import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/kuaishou/parsers/kuaishou_play_parser.dart';

/// Kuaishou's lease lookup by URL: a signed media address carries its expiry
/// in `txTime`/`wsTime` (or `auth_key`), so a held address's lifetime is read
/// back without asking the room again.
///
/// An address past its expiry answers a past lease rather than null, so a
/// stale address reads as dead instead of immortal; an unsigned address
/// answers null.
final class KuaishouPlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup over [now] (injectable for tests).
  new({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Injectable clock.
  final DateTime Function() now;

  @override
  LivePlayLease? leaseOf(Uri url) => KuaishouPlayParser.lease(url, now().toUtc(), allowExpired: true);
}
