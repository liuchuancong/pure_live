import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_room_provider.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/page/live_page/live_page.dart';
import 'package:live_sites/src/models/page/live_page_request/live_page_request.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/platforms/kugoulive/kugoulive_site.dart';
import 'package:live_sites/src/platforms/kugoulive/parsers/kugoulive_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Kugou Live's rooms: the entry of one room (its info and, while live, its
/// stream answer), and pages of a room list.
///
/// A room id is the room number; anything else is not-found, without a
/// request. A room the platform calls offline is offline, never unknown.
final class KugouliveRoomProvider implements LiveRoomProvider {
  /// Serves [site].
  KugouliveRoomProvider({required this.site});

  /// The site this capability serves.
  final KugouliveSite site;

  @override
  Future<Either<LiveSiteError, LiveRoom>> getRoom(String roomId) => _run(() => site.detail(roomId));

  @override
  Future<Either<LiveSiteError, LivePage<LiveRoom>>> getRooms(LivePageRequest request) => _run(() async {
    final page = await site.directory(request.page);
    return LivePage(items: page.rooms, hasMore: page.hasMore);
  });

  Future<Either<LiveSiteError, T>> _run<T>(Future<T> Function() work) async {
    try {
      return right(await work());
    } on KugouliveFailure catch (failure) {
      return left(failure.toLiveSiteError('kugoulive'));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: 'kugoulive', message: '$error', cause: error));
    }
  }
}
