import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_discovery_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/niconico/niconico_manifest.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Niconico's discovery feed: the `common` recent-program tab, the platform's
/// front page listing.
final class NiconicoDiscoveryProvider implements LiveDiscoveryProvider {
  /// Serves [site].
  NiconicoDiscoveryProvider({required this.site});

  /// The site this capability serves.
  final NiconicoSite site;

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final result = await site.recent('common', request.page);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError(niconicoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: niconicoSiteId, message: '$error', cause: error));
    }
  }
}
