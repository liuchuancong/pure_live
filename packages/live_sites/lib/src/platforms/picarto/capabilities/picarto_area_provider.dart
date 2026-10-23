import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_room_parser.dart';
import 'package:live_sites/src/platforms/picarto/picarto_manifest.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Picarto's areas: the one catalog's public directory (the
/// recommendations) and the platform's categories, and the rooms under each.
///
/// The catalog is one category; its id groups every area as the parent.
/// Another area id is a caller error, never an empty page.
final class PicartoAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  PicartoAreaProvider({required this.site});

  /// The site this capability serves.
  final PicartoSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.areas());
    } on PicartoFailure catch (failure) {
      return left(failure.toLiveSiteError(picartoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: picartoSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required String areaId,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final page = await site.directory(
        request.page,
        request.pageSize,
        categoryId: PicartoRoomParser.categoryIdOf(areaId),
      );
      return right(LivePage.of(items: page.rooms, hasMore: page.hasMore));
    } on PicartoFailure catch (failure) {
      return left(failure.toLiveSiteError(picartoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: picartoSiteId, message: '$error', cause: error));
    }
  }
}
