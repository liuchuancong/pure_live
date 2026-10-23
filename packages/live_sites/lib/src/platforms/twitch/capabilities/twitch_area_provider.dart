import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/twitch/parsers/twitch_failure.dart';
import 'package:live_sites/src/platforms/twitch/twitch_manifest.dart';
import 'package:live_sites/src/platforms/twitch/twitch_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Twitch's areas: every category tag walked to its last
/// `BrowsePage_AllDirectories` page, and one `DirectoryPage_Game` page per
/// area.
///
/// Areas come back flat, each carrying its category tag as parent; the game
/// slug `DirectoryPage_Game` needs is the area's `shortName`, remembered while
/// the areas are walked so a caller that pages by area id still resolves it.
final class TwitchAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  TwitchAreaProvider({required this.site});

  /// The site this capability serves.
  final TwitchSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.categories());
    } on TwitchFailure catch (failure) {
      return left(failure.toLiveSiteError(twitchSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitchSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final result = await site.areaRooms(site.slugFor(areaId), request.page, request.pageSize);
      return right(LivePage.of(items: result.rooms, hasMore: result.hasMore));
    } on TwitchFailure catch (failure) {
      return left(failure.toLiveSiteError(twitchSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: twitchSiteId, message: '$error', cause: error));
    }
  }
}
