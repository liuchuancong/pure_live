import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitcasting/parsers/twitcasting_failure.dart';
import 'package:live_sites/src/platforms/twitcasting/twitcasting_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// TwitCasting's areas: the homepage's top tabs, and the window of
/// broadcasts each answers.
///
/// The catalog is the one category "TwitCasting"; the areas are read off the
/// homepage. Another area id is a caller error, never an empty page.
final class TwitcastingAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  TwitcastingAreaProvider({required this.site});

  /// The site this capability serves.
  final TwitcastingSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.catalog());
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError('twitcasting'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'twitcasting', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest request = const LivePageRequest(),
  }) async {
    try {
      final page = await site.areaRooms(areaId, page: request.page, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on TwitcastingFailure catch (failure) {
      return left(failure.toLiveSiteError('twitcasting'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'twitcasting', message: '$error', cause: error));
    }
  }
}
