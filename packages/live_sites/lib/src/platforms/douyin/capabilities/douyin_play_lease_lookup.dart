import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/douyin/parsers/douyin_play_parser.dart';

/// Douyin's lease lookup by URL: a play address names an absolute expiry in
/// `expire`/`volcTime`, `wsTime + keeptime` or `t` beside `k`, so a held
/// address's lifetime is read back without asking the room again.
///
/// An address past its expiry answers a past lease rather than null, so a
/// stale address reads as dead instead of immortal; an unsigned address
/// answers null.
final class DouyinPlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup.
  const new();

  @override
  LivePlayLease? leaseOf(Uri url) => DouyinPlayParser.leaseOf(url);
}
