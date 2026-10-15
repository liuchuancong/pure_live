import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/liveme/api/liveme_endpoints.dart';
import 'package:live_sites/src/platforms/liveme/liveme_site.dart';
import 'package:live_sites/src/platforms/liveme/parsers/liveme_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// LiveMe's rooms: the entry of one room (the short id's user and broadcast,
/// then the anchor's profile and the signed broadcast), and pages of the
/// featured list.
///
/// A room id is the anchor's short id; anything else is not-found, without a
/// request. The featured pages are the platform's native size, so the
/// caller's page number is honored and its page size is LiveMe's.
final class LivemeRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  LivemeRoomProvider({required this.site});

  /// The site this capability serves.
  final LivemeSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on LivemeFailure catch (failure) {
      return left(failure.toLiveSiteError('liveme'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'liveme', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.featured(page: request.page, pageSize: LivemeEndpoints.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on LivemeFailure catch (failure) {
      return left(failure.toLiveSiteError('liveme'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'liveme', message: '$error', cause: error));
    }
  }
}
