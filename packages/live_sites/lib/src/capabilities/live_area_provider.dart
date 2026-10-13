import 'package:fpdart/fpdart.dart';
import 'package:live_sites/live_sites.dart';

/// The areas (categories) a site is browsed by, and the rooms under an area.
///
/// A flat list of [LiveArea] carries the parent grouping in each area's
/// `areaType`/`typeName`, so a caller never has to know each site's nesting
/// depth.
abstract interface class LiveAreaProvider implements LiveSiteCapability {
  /// The site's areas, in the order it presents them.
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas();

  /// A page of rooms under [areaId] for [request].
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  });
}
