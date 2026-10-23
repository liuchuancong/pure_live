import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/yy/parsers/yy_failure.dart';
import 'package:live_sites/src/platforms/yy/yy_manifest.dart';
import 'package:live_sites/src/platforms/yy/yy_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// YY's areas: the catalog's categories and their areas, flat, each with its
/// parent named; and the rooms under one area.
///
/// The areas are read once per `getAreas` call (the header, then one
/// `getCategory` a category); an area's listing module is read from its page
/// when its rooms are first asked for. An area id outside the catalog is a
/// caller error, never an empty page.
final class YyAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  YyAreaProvider({required this.site});

  /// The site this capability serves.
  final YySite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.areas());
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError(yySiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: yySiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getAreaRooms({
    required LiveArea area,
    LivePageRequest? request,
  }) async {
    request ??= LivePageRequest();
    try {
      final rooms = await site.areaRooms(area.areaId, page: request.page, pageSize: request.pageSize);
      return right(LivePage.of(items: rooms));
    } on YyFailure catch (failure) {
      return left(failure.toLiveSiteError(yySiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: yySiteId, message: '$error', cause: error));
    }
  }
}
