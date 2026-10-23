import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/models/play/live_play_lease/live_play_lease.dart';

/// The lease of a held URL, looked up by the URL itself.
///
/// A recorder holds a bare address for hours; whether that address is still
/// worth opening is the lease question — when it should be re-resolved and
/// when it is certain to fail. Platforms that sign short-lived URLs
/// implement this from their signing tables; platforms whose lines never
/// expire do not, and a held URL stays good.
abstract interface class LivePlayLeaseLookup implements LiveSiteCapability {
  /// The lease of [url], or null when the address has no lifetime of its
  /// own.
  LivePlayLease? leaseOf(Uri url);
}
