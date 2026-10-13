import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/live_page/live_page.dart';
import 'package:live_sites/src/models/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/live_room/live_room.dart';

/// A site's discovery feed — rooms recommended to the current viewer.
abstract interface class LiveDiscoveryProvider implements LiveSiteCapability {
  /// Fetches a page of recommended rooms.
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({
    LivePageRequest request = const LivePageRequest(),
  });
}
