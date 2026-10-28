import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_play_parser.dart';

/// YY's lease lookup by URL: a FLV address carries its expiry in `t` (Unix
/// seconds), so a held address's lifetime is read back without asking the
/// room again. A mobile HLS address names its issue time in `t` instead and
/// has no lease of its own, exactly as its line carries none.
///
/// An FLV address past its expiry answers a past lease rather than null, so
/// a stale address reads as dead instead of immortal.
final class YyPlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup over [now] (injectable for tests).
  new({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Injectable clock.
  final DateTime Function() now;

  @override
  LivePlayLease? leaseOf(Uri url) => YyPlayParser.lease(url, now().toUtc(), allowExpired: true);
}
