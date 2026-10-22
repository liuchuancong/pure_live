import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_manifest.dart';
import 'package:live_sites/src/platforms/fc2live/fc2live_site.dart';
import 'package:live_sites/src/platforms/fc2live/parsers/fc2live_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// FC2 Live's areas: the six the site's own filter row offers.
///
/// The platform has no area list to read — its channels carry a category number
/// and the site groups them into these six — so [getAreas] answers without a
/// request, and an area's rooms are that category filtered out of the directory
/// snapshot. The site's "game / work" area holds two category numbers, which is
/// the platform's own grouping rather than a mistake of this adapter. An area
/// id outside those six is a caller error, never an empty list that quietly
/// means "you asked for something that does not exist".
final class Fc2LiveAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  Fc2LiveAreaProvider({required this.site});

  /// The site this capability serves.
  final Fc2LiveSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right(site.areas());

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.listing(areaId: areaId, page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, totalCount: page.totalCount, hasMore: page.hasMore));
    } on Fc2LiveFailure catch (failure) {
      return left(failure.toLiveSiteError(fc2LiveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: fc2LiveSiteId, message: '$error', cause: error));
    }
  }
}
