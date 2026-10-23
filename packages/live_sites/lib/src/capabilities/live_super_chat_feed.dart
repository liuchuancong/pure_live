import 'package:fpdart/fpdart.dart';
import 'package:live_sites/src/capabilities/live_site_capability.dart';
import 'package:live_sites/src/core/live_site_error.dart';
import 'package:live_sites/src/models/room/live_room/live_room.dart';
import 'package:live_sites/src/models/super_chat/live_super_chat_message/live_super_chat_message.dart';

/// The room's super chat board, for platforms that poll it.
///
/// Most platforms deliver super chats through the danmaku stream alone and
/// never implement this; the board is the platforms whose paid messages
/// also sit in a list a page shows (bilibili, douyu, huya). Whether a
/// platform has super chats at all is a fact the runtime info carries
/// (`LiveSiteRuntimeInfo.hasSuperChats`), so an empty list from such a
/// platform says the room has none, not "they will show up here".
abstract interface class LiveSuperChatFeed implements LiveSiteCapability {
  /// The super chats currently showing on [room]'s board, newest last. A
  /// left names why the board could not be read.
  Future<Either<LiveSiteError, List<LiveSuperChatMessage>>> getSuperChatMessages({required LiveRoom room});
}
