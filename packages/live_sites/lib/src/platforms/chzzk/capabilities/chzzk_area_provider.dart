import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_manifest.dart';
import 'package:live_sites/src/platforms/chzzk/chzzk_site.dart';
import 'package:live_sites/src/platforms/chzzk/parsers/chzzk_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Chzzk's areas: the platform's own `categories/live` list, returned flat with
/// each area's `categoryType` as its parent.
///
/// The catalog is up to four pages of the platform's own cursor. That list is
/// sorted by viewers, so the same area can repeat between pages and is kept
/// once; the areas past those pages hold one or two lives each and are left out
/// on purpose. An area's rooms are the same cursor list as the site-wide one,
/// asked with the `categoryType` the catalog named for that area — an id the
/// catalog does not know is a caller error, never a guessed path.
final class ChzzkAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  ChzzkAreaProvider({required this.site});

  /// The site this capability serves.
  final ChzzkSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.areas());
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError(chzzkSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: chzzkSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.listing(areaId: areaId, page: request.page, cursor: request.cursor);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore, nextCursor: page.nextCursor));
    } on ChzzkFailure catch (failure) {
      return left(failure.toLiveSiteError(chzzkSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: chzzkSiteId, message: '$error', cause: error));
    }
  }
}
