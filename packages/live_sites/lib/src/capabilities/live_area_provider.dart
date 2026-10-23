import 'package:fpdart/fpdart.dart';
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
