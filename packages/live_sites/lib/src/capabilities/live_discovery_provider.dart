import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

/// A site's discovery feed — rooms recommended to the current viewer.
abstract interface class LiveDiscoveryProvider implements LiveSiteCapability {
  /// Fetches a page of recommended rooms.
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request});
}

/// A discovery feed whose transport answers cancellation (see
/// `live_site_cancellation.dart` for the contract the `cancel` token
/// follows).
///
/// Implementing this refines [LiveDiscoveryProvider] with one strengthened
/// method: the optional named parameter satisfies the base member as it is,
/// so a site declares the stronger signature and `capability<T>()` keeps
/// answering for the base type. A site without it is still fetchable — the
/// cancellation entry points fall back to the base call and honour the token
/// by checking it before and after instead of interrupting the transport.
abstract interface class LiveCancellableDiscovery implements LiveDiscoveryProvider {
  /// Fetches a page of recommended rooms, aborting the transport once
  /// [cancel] is set.
  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRecommendedRooms({LivePageRequest? request, CancelToken? cancel});
}
