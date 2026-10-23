import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/seventeenlive/parsers/seventeenlive_failure.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_manifest.dart';
import 'package:live_sites/src/platforms/seventeenlive/seventeenlive_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// 17LIVE's areas: the website's three recommendation regions, Japan, Taiwan and
/// Hong Kong, listed under the one `地区` category and built without a request.
///
/// An area's rooms are the recommendation sections of that region — the same
/// cursor list as the recommendations, asked with the region's `region` code.
/// An id the catalog does not have is a caller error, never a guessed region.
final class SeventeenLiveAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  SeventeenLiveAreaProvider({required this.site});

  /// The site this capability serves.
  final SeventeenLiveSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async => right(site.areas());

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final region = site.regionOf(area.areaId);
      final page = await site.directory(
        region: region,
        page: request.page,
        cursor: request.cursor,
        pageSize: request.pageSize,
      );
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on SeventeenLiveFailure catch (failure) {
      return left(failure.toLiveSiteError(seventeenliveSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: seventeenliveSiteId, message: '$error', cause: error));
    }
  }
}
