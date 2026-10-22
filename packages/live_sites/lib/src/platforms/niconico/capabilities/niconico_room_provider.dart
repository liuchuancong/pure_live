import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/niconico/niconico_manifest.dart';
import 'package:live_sites/src/platforms/niconico/niconico_site.dart';
import 'package:live_sites/src/platforms/niconico/parsers/niconico_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Niconico's room feature: the watch page of a program (`lv…`) or a
/// broadcaster (`user/<id>`, `ch<n>`), plus the `common` tab as the default
/// directory.
final class NiconicoRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  NiconicoRoomProvider({required this.site});

  /// The site this capability serves.
  final NiconicoSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError(niconicoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: niconicoSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final result = await site.recent('common', request.page);
      return right(LivePage(items: result.rooms, hasMore: result.hasMore));
    } on NiconicoFailure catch (failure) {
      return left(failure.toLiveSiteError(niconicoSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: niconicoSiteId, message: '$error', cause: error));
    }
  }
}
