import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';

/// Resolves a platform link — including a short link that must be followed —
/// into its canonical room URL.
abstract interface class LiveLinkResolver implements LiveSiteCapability {
  /// Follows and validates [uri] to its final room URL. A left reports a
  /// network or parse failure, or that the link is not one this site owns.
  Future<Either<LiveSiteError, Uri>> resolve(Uri uri);
}
