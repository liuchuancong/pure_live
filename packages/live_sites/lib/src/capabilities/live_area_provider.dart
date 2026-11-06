import 'package:fpdart/fpdart.dart';
import 'package:live_net/live_net.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';

/// The areas (categories) a site is browsed by, and the rooms under an area.
///
/// A flat list of [LiveArea] carries the parent grouping in each area's
/// `parentAreaId`/`parentAreaName`, so a caller never has to know each
/// site's nesting depth.
abstract interface class LiveAreaProvider implements LiveSiteCapability {
  /// The site's areas, in the order it presents them.
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas();

  /// A page of rooms under [area] for [request].
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({required LiveArea area, LivePageRequest? request});
}

/// An area listing whose transport answers cancellation (see
/// `live_site_cancellation.dart` for the contract the `cancel` token
/// follows).
///
/// Only the paged room listing is refinable: the area tree itself is a
/// near-static lookup fetched once, not a screen lifetime of calls.
/// Implementing this refines [LiveAreaProvider] with one strengthened
/// method: the optional named parameter satisfies the base member as it is,
/// so a site declares the stronger signature and `capability<T>()` keeps
/// answering for the base type. A site without it is still fetchable — the
/// cancellation entry points fall back to the base call and honour the token
/// by checking it before and after instead of interrupting the transport.
abstract interface class LiveCancellableArea implements LiveAreaProvider {
  /// A page of rooms under [area], aborting the transport once [cancel] is
  /// set.
  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
    CancelToken? cancel,
  });
}
