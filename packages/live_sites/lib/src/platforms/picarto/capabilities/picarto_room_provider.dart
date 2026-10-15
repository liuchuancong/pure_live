import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/picarto/parsers/picarto_failure.dart';
import 'package:live_sites/src/platforms/picarto/picarto_site.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Picarto's rooms: the entry of one channel (detail, master playlist, the
/// broadcast's start and the chat's arguments), and pages of the public
/// directory.
///
/// A room id is the channel name as the platform writes it; anything that is
/// no channel name is not-found, without a request.
final class PicartoRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  PicartoRoomProvider({required this.site});

  /// The site this capability serves.
  final PicartoSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on PicartoFailure catch (failure) {
      return left(failure.toLiveSiteError('picarto'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'picarto', message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.directory(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on PicartoFailure catch (failure) {
      return left(failure.toLiveSiteError('picarto'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'picarto', message: '$error', cause: error));
    }
  }
}
