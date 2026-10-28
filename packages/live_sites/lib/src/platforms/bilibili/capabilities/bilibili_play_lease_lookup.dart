import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_play_parser.dart';

/// Bilibili's lease lookup by URL: a signed media address carries its own
/// `expires`, so a held address's lifetime is read back without asking the
/// room again.
///
/// An address past its expiry answers a past lease rather than null, so a
/// stale address reads as dead instead of immortal; an unsigned address (a
/// static replay) answers null.
final class BilibiliPlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup over [now] (injectable for tests).
  new({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Injectable clock.
  final DateTime Function() now;

  @override
  LivePlayLease? leaseOf(Uri url) => BilibiliPlayParser.lease(url, now().toUtc(), allowExpired: true);
}
