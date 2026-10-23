import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_super_chat_feed.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';
import 'package:live_sites/src/platforms/huya/huya_manifest.dart';
import 'package:live_sites/src/platforms/huya/huya_site.dart';
import 'package:live_sites/src/platforms/huya/parsers/huya_failure.dart';

// Platform-internal code: constructor-name and doc verbosity rules that
// govern the public surface are relaxed here.
// ignore_for_file: unnecessary_type_name_in_constructor

/// Huya's headline message board (`wupui.getHeadLineMessageBoard`): the paid
/// notices that sit above the chat.
///
/// The board is keyed by the room's top channel id. A live room's danmaku
/// handle already carries it; an offline or freshly keyed one is read from
/// the room page. A room without a channel (topSid 0) has no board.
final class HuyaSuperChatFeedProvider implements LiveSuperChatFeed {
  /// Serves [site].
  HuyaSuperChatFeedProvider({required this.site});

  /// The site this capability serves.
  final HuyaSite site;

  @override
  Future<Either<LiveSiteError, List<LiveSuperChatMessage>>> getSuperChatMessages({required LiveRoom room}) async {
    final int topSid;
    if (room.runtime.danmakuHandle case final HuyaDanmakuArgs args) {
      topSid = args.topSid;
    } else {
      try {
        topSid = (await site.detailRoom(room.ref.roomId)).topSid;
      } on HuyaFailure catch (failure) {
        return left(failure.toLiveSiteError(huyaSiteId));
      } on Object catch (error) {
        return left(LiveSiteError.unexpected(siteId: huyaSiteId, message: '$error', cause: error));
      }
    }
    if (topSid <= 0) return right(const []);
    try {
      return right(await site.superChatBoard(topSid));
    } on HuyaFailure catch (failure) {
      return left(failure.toLiveSiteError(huyaSiteId));
    } on Object catch (error) {
      return left(LiveSiteError.unexpected(siteId: huyaSiteId, message: '$error', cause: error));
    }
  }
}
