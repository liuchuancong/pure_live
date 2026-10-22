import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_manifest.dart';
import 'package:live_sites/src/platforms/kilakila/kilakila_site.dart';
import 'package:live_sites/src/platforms/kilakila/parsers/kilakila_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// KilaKila's rooms: the entry of one anchor (profile, then its current
/// broadcast with the pull URLs), and pages of the hot timeline.
///
/// A room id is the anchor's uid; anything else is not-found, without a
/// request. An anchor the platform says has no broadcast, or whose broadcast
/// ended, is offline, never unknown.
final class KilakilaRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  KilakilaRoomProvider({required this.site});

  /// The site this capability serves.
  final KilakilaSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) async {
    try {
      return right(await site.detail(roomId));
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError(kilakilaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kilakilaSiteId, message: '$error', cause: error));
    }
  }

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) async {
    try {
      final page = await site.timeline(request.page, request.pageSize);
      return right(LivePage(items: page.rooms, hasMore: page.hasMore));
    } on KilakilaFailure catch (failure) {
      return left(failure.toLiveSiteError(kilakilaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: kilakilaSiteId, message: '$error', cause: error));
    }
  }
}
