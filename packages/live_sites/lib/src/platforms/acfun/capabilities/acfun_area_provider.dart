import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/acfun/acfun_manifest.dart';
import 'package:live_sites/src/platforms/acfun/acfun_site.dart';
import 'package:live_sites/src/platforms/acfun/parsers/acfun_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// AcFun's areas: the filter tree of `api/channel/list`, and the rooms under
/// one filter.
///
/// The site has one category (its own live page), so the areas come back flat
/// with that as parent; an area id carries the filter type and id together,
/// which is what a directory page needs.
final class AcfunAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  AcfunAreaProvider({required this.site});

  /// The site this capability serves.
  final AcfunSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.areas());
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError(acfunSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: acfunSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.listing(page: request.page, pageSize: request.pageSize, filters: site.filtersFor(areaId));
      return right(LivePage(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on AcfunFailure catch (failure) {
      return left(failure.toLiveSiteError(acfunSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: acfunSiteId, message: '$error', cause: error));
    }
  }
}
