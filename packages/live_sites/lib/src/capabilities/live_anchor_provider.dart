import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/anchor/live_anchor/live_anchor.dart';

/// Anchor (streamer) lookup a site may support.
abstract interface class LiveAnchorProvider implements LiveSiteCapability {
  /// Fetches an anchor by their platform-specific [anchorId].
  Future<Either<LiveSiteError, LiveAnchor>> getAnchor(String anchorId);
}
