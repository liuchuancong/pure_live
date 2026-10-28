import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_super_chat_feed.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_manifest.dart';
import 'package:live_sites/src/platforms/bilibili/bilibili_site.dart';
import 'package:live_sites/src/platforms/bilibili/capabilities/bilibili_room_provider.dart';
import 'package:live_sites/src/platforms/bilibili/parsers/bilibili_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Bilibili's super chat board (`av/v1/SuperChat/getMessageList`): the paid
/// messages the room page lists besides the ones the danmaku stream carried.
///
/// The board is keyed by the canonical long room id; a room that already went
/// through the room provider carries it in the stream handle, and one from a
/// stored list falls back to the id the site remembers.
final class BilibiliSuperChatFeedProvider implements LiveSuperChatFeed {
  /// Serves [site]; [rooms] is the read path this capability shares.
  BilibiliSuperChatFeedProvider({required this.site, required this.rooms});

  /// The site this capability serves.
  final BilibiliSite site;

  /// The room provider whose super chat read this capability exposes.
  final BilibiliRoomProvider rooms;

  @override
  Future<Either<LiveSiteError, List<LiveSuperChatMessage>>> getSuperChatMessages({required LiveRoom room}) async {
    final id = switch (room.runtime.streamHandle) {
      final BilibiliRoomData data => data.longId,
      _ => room.ref.roomId,
    };
    try {
      return right(await rooms.superChats(id));
    } on BilibiliFailure catch (failure) {
      return left(failure.toLiveSiteError(bilibiliSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: bilibiliSiteId, message: '$error', cause: error));
    }
  }
}
