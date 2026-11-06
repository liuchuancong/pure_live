import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';

/// What the chat list keeps across the rebuilds a turn, a resize or the
/// fullscreen switch gives it (the reference's RoomViewMemory): the normal
/// layout and the fullscreen are two trees, and the list built in the other
/// tree's place starts here instead of from scratch. The list that leaves
/// writes it on its way out (in its `deactivate`); the one that takes its
/// place reads it only for the room it was saved in.
final class RoomChatListMemory {
  /// Whether the viewer was reading away from the newest line; a following
  /// list saves nothing worth taking (the next one starts at the newest).
  bool paused = false;

  /// The room the memory is from; another room's is not taken.
  String roomKey = '';

  /// The scroll offset from the newest line (the list is reversed).
  double offset = 0;

  /// The first message that had arrived unread, the 「以下为新消息」 mark.
  String? boundaryId;

  /// What had arrived unread.
  int unseen = 0;

  /// The lines the paused list held, oldest first.
  List<LiveMessage> shown = const [];

  /// The feed's count of added lines when [shown] was taken.
  int seen = 0;

  /// The feed's count of removals already applied to [shown].
  int removals = 0;
}

/// Where the chat list leaves its place between the layout's rebuilds; one
/// per window's scope, like the room and its chat themselves.
final roomChatListMemoryProvider = Provider<RoomChatListMemory>((ref) => RoomChatListMemory());
