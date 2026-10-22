import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/missevan/api/missevan_endpoints.dart';
import 'package:live_sites/src/platforms/missevan/missevan_manifest.dart';
import 'package:live_sites/src/platforms/missevan/missevan_site.dart';
import 'package:live_sites/src/platforms/missevan/parsers/missevan_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Missevan's rooms: the entry of one room (`live/{id}`, with the pull URLs
/// and the chat arguments), and pages of the recommendations.
///
/// The site's pages are fixed at [MissevanEndpoints.serverPageSize] rows, so
/// a page size only has to be sane (1–[MissevanEndpoints.maxPageSize]) to be
/// served; anything else is a caller error.
final class MissevanRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  MissevanRoomProvider({required this.site});

  /// The site this capability serves.
  final MissevanSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on MissevanFailure catch (failure) {
      return left(failure.toLiveSiteError(missevanSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: missevanSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.directory(request.page, pageSize: request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on MissevanFailure catch (failure) {
      return left(failure.toLiveSiteError(missevanSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: missevanSiteId, message: '$error', cause: error));
    }
  }
}
