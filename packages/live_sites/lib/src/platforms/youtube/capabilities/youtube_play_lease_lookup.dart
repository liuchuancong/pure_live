import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/youtube/parsers/youtube_play_parser.dart';

/// YouTube's lease lookup by URL: a media address carries its `expire`
/// (a query parameter, or an `/expire/<seconds>/` path element), so a held
/// address's lifetime is read back without asking the room again.
///
/// An address past its expiry answers a past lease rather than null, so a
/// stale address reads as dead instead of immortal; an address without an
/// expiry (an HLS/DASH master, a progressive file without one) answers null.
final class YoutubePlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup over [now] (injectable for tests).
  new({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Injectable clock.
  final DateTime Function() now;

  @override
  LivePlayLease? leaseOf(Uri url) => YoutubePlayParser.lease(url, now().toUtc(), allowExpired: true);
}
