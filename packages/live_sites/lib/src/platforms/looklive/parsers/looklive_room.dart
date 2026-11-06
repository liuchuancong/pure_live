import 'package:live_sites/live_sites.dart' show LookliveEndpoints;
import 'package:live_sites/src/platforms/looklive/api/looklive_endpoints.dart' show LookliveEndpoints;
import 'package:live_sites/src/platforms/looklive/looklive.dart' show LookliveEndpoints;
import 'package:live_sites/src/platforms/platforms.dart' show LookliveEndpoints;
import 'package:meta/meta.dart';

/// Which list a room belongs to (3.x's `LookLiveKind`): `liveType` 1 is
/// video, 2 is voice.
enum LookLiveKind {
  /// Video (`liveType` 1).
  video,

  /// Voice (`liveType` 2).
  audio,
}

/// A room's state in the room answer (3.x's `LookLiveState`). List cards
/// are always live.
///
/// The values follow LOOK's web client (`look.163.com`): its
/// `LIVE_STATUS_TYPE` is `{NOLIVE: 0, LIVING: 1, FORBID: -10}`; the room page
/// shows "- 直播间已关闭 -" for -1, 0 and -2, and for -4 hides the stream
/// behind "该直播间已涉嫌违规…整改期间直播内容将被屏蔽".
enum LookLiveState {
  /// `liveStatus` 1.
  live,

  /// `liveStatus` 0, -1 or -2 (a closed or upgrading room).
  offline,

  /// `liveStatus` -10 (`FORBID`: the room may not broadcast) or -4 (blocked
  /// while it corrects a violation).
  banned,

  /// Any other `liveStatus`, or none.
  unknown,
}

/// One stream of a room (3.x's `LookLiveVariant`): the HLS playlist
/// (`hlsPullUrl`) or the FLV stream (`httpPullUrl`) on NetEase's CDN, made
/// https.
@immutable
final class LookLiveVariant {
  /// Creates a stream.
  const new({required this.id, required this.format, required this.uri});

  /// The quality id as well: `hls:source` or `flv:source`.
  final String id;

  /// HLS or FLV.
  final LiveStreamKind format;

  /// The address.
  final Uri uri;
}

/// The transport of a [LookLiveVariant], before it is a play line.
enum LiveStreamKind {
  /// The HLS playlist.
  hls,

  /// The FLV stream.
  flv,
}

/// The danmaku (chat) of a live LOOK room: room entry and recording give it
/// from the room answer they already asked for, without another request.
///
/// LOOK's chat is a NetEase Yunxin (网易云信) chatroom: the client asks
/// [LookliveEndpoints.chatAddressPath] for the room's chat servers and joins
/// the chatroom `roomInfo.roomId` anonymously.
@immutable
final class LookLiveDanmakuArgs {
  /// Creates the arguments.
  const new({required this.roomId, required this.chatroomId, this.anonymousMode = false});

  /// The room number (`liveRoomNo`): the chat servers are asked for it.
  final String roomId;

  /// The Yunxin chatroom of the room (`roomInfo.roomId`; not the room
  /// number).
  final String chatroomId;

  /// Whether the room hides its viewers' names (`anonymousMode`): LOOK's
  /// room page then shows a name's first character and `***`.
  final bool anonymousMode;

  @override
  bool operator ==(Object other) =>
      other is LookLiveDanmakuArgs &&
      other.roomId == roomId &&
      other.chatroomId == chatroomId &&
      other.anonymousMode == anonymousMode;

  @override
  int get hashCode => Object.hash(roomId, chatroomId, anonymousMode);

  @override
  String toString() => 'LookLiveDanmakuArgs($roomId, chatroom $chatroomId${anonymousMode ? ', anonymous' : ''})';
}

/// What keeps this client from playing a live room (3.x's restriction):
/// app-only, a ticket, or no usable address; none otherwise.
enum LookLiveBlock {
  /// Not blocked.
  none,

  /// Watchable in LOOK's app only.
  appOnly,

  /// The broadcast needs a ticket.
  paid,

  /// Live without a usable address.
  unplayable,
}

/// A LOOK room (3.x's `LookLiveRoom`): a list card, or the room answer
/// (`room/get/v3`), completed from what was seen before ([enrich]).
///
/// It is also the stream handle a room entry or recording carries: the
/// room's identity, the streamer's account and the broadcast's session, and
/// the streams read at that moment (never stored beyond the run).
@immutable
final class LookLiveRoom {
  /// Creates a room.
  new({
    required this.roomId,
    required this.userId,
    required this.sessionId,
    required this.kind,
    required this.state,
    this.title = '',
    this.nick = '',
    this.avatar = '',
    this.cover = '',
    this.streamType,
    this.popularity,
    this.currentViewers,
    this.startedAt,
    this.hasAddress = false,
    this.mediaChecked = false,
    this.paid,
    this.chatroomId = '',
    this.anonymousMode = false,
    Iterable<LookLiveVariant> variants = const [],
  }) : variants = List.unmodifiable(variants);

  /// The room number (`liveRoomNo`): the room's identity.
  final String roomId;

  /// The streamer's account (`userId`).
  final String userId;

  /// The broadcast (`liveId` of a card, `roomInfo.id` of the room answer).
  final String sessionId;

  /// The title; '' when unknown.
  final String title;

  /// The streamer's name; '' when unknown.
  final String nick;

  /// The streamer's avatar, https; '' when unknown.
  final String avatar;

  /// The cover, https; '' when unknown.
  final String cover;

  /// Video or voice.
  final LookLiveKind kind;

  /// The stream type: `liveStreamType` of the room answer, `type` of a list
  /// card's `liveData` (the lists carry no `liveStreamType`). LOOK's web
  /// client names 1 normal, 6 audio, 12 mobile game, 19 music festival and
  /// 50 multi-person; 50 is a room type the website has no media for.
  final int? streamType;

  /// The state.
  final LookLiveState state;

  /// The list's heat (`popularity`); null when unknown.
  final int? popularity;

  /// The list's current viewers (`onlineNumber`); null when unknown.
  final int? currentViewers;

  /// When the broadcast started (`roomInfo.startTime`, epoch milliseconds),
  /// for a live room answer; null otherwise (the lists do not say).
  final DateTime? startedAt;

  /// Whether the answer or card carries a stream address (`hlsPullUrl` or
  /// `httpPullUrl` text, valid or not), read at every depth: a refresh
  /// tells an app-only room from one with streams without reading them.
  final bool hasAddress;

  /// Whether [variants] were read from this answer's addresses: a list card,
  /// or a live room answer at room entry and recording.
  final bool mediaChecked;

  /// Whether the broadcast needs a ticket: the room answer's `feeInfo.fee`
  /// without a `sessionKey` (a bought ticket; never for an anonymous
  /// client). Null for a list card (the lists do not say).
  final bool? paid;

  /// The room's Yunxin chatroom (`roomInfo.roomId` of the room answer); ''
  /// for a list card or an answer without one.
  final String chatroomId;

  /// Whether the room answer says the room hides its viewers' names
  /// (`anonymousMode`); false for a list card.
  final bool anonymousMode;

  /// The streams, HLS first: a list card's, or a live room's at room entry
  /// and recording; empty otherwise. An address that fails the checks is
  /// left out.
  final List<LookLiveVariant> variants;

  /// The chat of this room: a live room answer with a chatroom; null
  /// otherwise (a list card, a room that is not live).
  LookLiveDanmakuArgs? get danmakuArgs => state == LookLiveState.live && chatroomId.isNotEmpty
      ? LookLiveDanmakuArgs(roomId: roomId, chatroomId: chatroomId, anonymousMode: anonymousMode)
      : null;

  /// Whether this room is watchable in LOOK's app only: stream type 50
  /// without streams, and without any address in the answer, so a refresh
  /// (which reads no streams) tells it too.
  bool get isAppOnly => streamType == 50 && !hasAddress && variants.isEmpty;

  /// What keeps this client from playing a live room: app-only, a ticket,
  /// or no usable address (unplayable); none otherwise. Not live: none,
  /// except null for an unknown state; a list card that can be played says
  /// null, as it does not tell tickets.
  LookLiveBlock? get block => switch (state) {
    LookLiveState.unknown => null,
    LookLiveState.live when isAppOnly => LookLiveBlock.appOnly,
    LookLiveState.live when paid ?? false => LookLiveBlock.paid,
    LookLiveState.live when variants.isEmpty && (mediaChecked || !hasAddress) => LookLiveBlock.unplayable,
    LookLiveState.live when paid == null => null,
    _ => LookLiveBlock.none,
  };

  /// This answer with what it lacks taken from [known], the last card or
  /// answer of the same room (3.x's `enrich`): the account, names and
  /// images while empty, the stream type while unknown; the audience of the
  /// same broadcast while this answer is live (an ended room keeps none of
  /// the card's figures); and that broadcast's streams while this live
  /// answer has none (unless the stream type is 50). State, kind, start,
  /// addresses, ticket and chat stay this answer's.
  LookLiveRoom enrich(LookLiveRoom known) {
    final sameSession = sessionId.isNotEmpty && sessionId == known.sessionId;
    final live = state == LookLiveState.live;
    final effectiveStreamType = streamType ?? known.streamType;
    final keepKnownVariants =
        variants.isEmpty && sameSession && live && known.state == LookLiveState.live && effectiveStreamType != 50;
    return LookLiveRoom(
      roomId: roomId,
      userId: userId.isEmpty ? known.userId : userId,
      sessionId: sessionId,
      title: title.isEmpty ? known.title : title,
      nick: nick.isEmpty ? known.nick : nick,
      avatar: avatar.isEmpty ? known.avatar : avatar,
      cover: cover.isEmpty ? known.cover : cover,
      kind: kind,
      streamType: effectiveStreamType,
      state: state,
      popularity: popularity ?? (sameSession && live ? known.popularity : null),
      currentViewers: currentViewers ?? (sameSession && live ? known.currentViewers : null),
      startedAt: startedAt,
      hasAddress: hasAddress,
      mediaChecked: mediaChecked,
      paid: paid,
      chatroomId: chatroomId,
      anonymousMode: anonymousMode,
      variants: keepKnownVariants ? known.variants : variants,
    );
  }

  /// Why this room cannot be played, or null, with the reason: not live
  /// (offline, banned, unknown), app-only, a ticket, or no streams.
  String? get unavailableReason => switch (state) {
    LookLiveState.live when isAppOnly => '$roomId is watchable in the LOOK app only',
    LookLiveState.live when paid ?? false => '$roomId needs a ticket (feeInfo.fee)',
    LookLiveState.live when variants.isEmpty => '$roomId is live without streams',
    LookLiveState.live => null,
    LookLiveState.banned => '$roomId is banned by LOOK',
    _ => '$roomId is ${state.name}',
  };
}

/// One page of a recommendation list (3.x's `LookLivePage`).
@immutable
final class LookLivePage {
  /// Creates a page.
  new({required Iterable<LookLiveRoom> rooms, required this.hasMore}) : rooms = List.unmodifiable(rooms);

  /// An empty last page.
  static final LookLivePage empty = LookLivePage(rooms: const [], hasMore: false);

  /// The rooms, in list order, each room once.
  final List<LookLiveRoom> rooms;

  /// Whether the list has another page (`hasMore`).
  final bool hasMore;
}
