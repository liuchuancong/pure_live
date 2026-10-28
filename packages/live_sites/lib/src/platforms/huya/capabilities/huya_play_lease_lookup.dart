import 'package:live_sites/src/capabilities/live_play_lease_lookup.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_play_parser.dart';

/// Huya's lease lookup by URL: a signed media address carries its own
/// `wsTime` (and, for a web FLV/HLS, its `seqid` issue time), so the lease is
/// read back without asking the room again.
///
/// A static token or an unsigned replay has nothing bounding it and answers
/// null, exactly as the lines issued for it carry no lease.
final class HuyaPlayLeaseLookup implements LivePlayLeaseLookup {
  /// Creates the lookup.
  const new();

  @override
  LivePlayLease? leaseOf(Uri url) => HuyaPlayParser.lease(url);
}
