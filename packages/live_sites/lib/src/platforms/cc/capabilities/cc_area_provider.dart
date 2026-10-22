import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_area_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/area/live_area/live_area.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/cc/cc_manifest.dart';
import 'package:live_sites/src/platforms/cc/cc_site.dart';
import 'package:live_sites/src/platforms/cc/parsers/cc_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// CC's areas: the mobile site's catalog (the categories' game areas), with
/// 3.x's official entries beside it, and the rooms under each game area.
///
/// The catalog request failing fails the areas; the official entries failing
/// only leaves them out. Another area id — an official entry is one — is a
/// caller error, never an empty page.
final class CcAreaProvider implements LiveAreaProvider {
  /// Serves [site].
  CcAreaProvider({required this.site});

  /// The site this capability serves.
  final CcSite site;

  @override
  Future<Either<LiveSiteError, List<LiveArea>>> getAreas() async {
    try {
      return right(await site.areas());
    } on CcFailure catch (failure) {
      return left(failure.toLiveSiteError(ccSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: ccSiteId, message: '$error', cause: error));
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
    } on CcFailure catch (failure) {
      return left(failure.toLiveSiteError(ccSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: ccSiteId, message: '$error', cause: error));
    }
  }
}
