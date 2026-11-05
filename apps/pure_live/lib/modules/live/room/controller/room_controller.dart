import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/app.dart';
import 'package:pure_live/features/account/account_providers.dart' show accountsProvider;
// The settings barrel's DanmakuStyle is the stored look; this file builds
// media_core_danmaku's.
import 'package:pure_live/features/settings/settings.dart' hide DanmakuStyle;
import 'package:pure_live/l10n/translations.dart' as l10n;
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/history/history.dart';
import 'package:pure_live/modules/live/recorder/recorder.dart';
import 'package:pure_live/modules/live/room/chat/gift_chat_filter.dart' show GiftChatFilter;
import 'package:pure_live/modules/live/room/chat/gift_flights.dart' show GiftFlights;
import 'package:pure_live/modules/live/room/chat/gift_text.dart' show giftLineTier;
import 'package:pure_live/modules/live/room/chat/membership_cards.dart' show membershipCard;
import 'package:pure_live/modules/live/room/chat/room_super_chats.dart' show roomSuperChatsProvider;
import 'package:pure_live/modules/live/room/controller/room_open_timing.dart'
    show RoomOpenProxy, RoomOpenStage, RoomOpenTiming, kSlowEntryBudget;
import 'package:pure_live/modules/live/room/player/room_playlist.dart' show roomPlaylistProvider;
import 'package:pure_live/modules/live/shield/shield.dart';

/// How many chat lines the page keeps; older leave first.
const int kRoomChatLimit = 200;

/// How many masked Bilibili nicknames, with no full one among them, make a
/// connection say the room is not reading chat as the account it thinks it
/// is (the reference's `maskedChatsForExpiredLogin`).
const int kRoomMaskedChatsForExpiredLogin = 3;

/// How often an open room's display state is re-read (the reference's
/// sixty-second detail read): long enough that a watched room never costs a
/// platform request more than once a minute, short enough that a broadcast
/// which ended is named before the viewer notices the picture froze.
const Duration kRoomDetailRefreshEvery = Duration(minutes: 1);

/// How the room's chat connection stands, as the chat column reads it.
///
/// The message list alone cannot tell "nobody is talking" from "we never got
/// in", and a hint that fades leaves the panel claiming the first when the
/// second is true.
enum RoomChatStatus { connecting, connected, unsupported, failed }

/// The chat's standing, with the platform's own reason when it [RoomChatStatus.failed].
typedef RoomChat = ({RoomChatStatus status, String? error});

/// What the room page holds: the room as it stands, the qualities and the
/// lines behind the chosen one, the playback's state and handle, and the
/// danmaku the room's chat has delivered.
typedef RoomState = ({
  LiveRoom? room,
  List<LivePlayQuality> qualities,
  List<LivePlayLine> lines,
  int lineIndex,
  LivePlayQuality? quality,
  PlayerCoreState playback,
  PlayerHandle? handle,
  bool audioOnly,
  String? error,
  RoomChat chat,
});

RoomState _initial({bool audioOnly = false}) => (
  room: null,
  qualities: const [],
  lines: const [],
  lineIndex: 0,
  quality: null,
  playback: PlayerCoreState.idle,
  handle: null,
  audioOnly: audioOnly,
  error: null,
  chat: (status: RoomChatStatus.connecting, error: null),
);

/// The viewer's shield as media_core's policy slot: the pipeline's documented
/// order runs the viewer's own blocks first (gate → policy → repeated →
/// similarity → sink), and the policy normalizes entries once, so matching
/// is case-insensitive for free. An off master switch means no policy.
///
/// A word written `/…/` is an expression, and the site package owns that
/// format: it decides which word is one and refuses the ones whose time grows
/// exponentially with the text, because the filter runs on the UI isolate for
/// every message. So the split happens here and the compiled form is handed
/// down, rather than the engine learning to read the viewer's list. Before this
/// the same list blocked a line in the recorder's sidecar and did nothing over
/// the picture, which reads as a shield that only works on files.
DanmakuFilterPolicy _shieldPolicyFor(ShieldRules rules) {
  if (!rules.enabled) return DanmakuFilterPolicy.none;
  final words = <String>[];
  final patterns = <RegExp>[];
  for (final word in rules.keywords) {
    if (!DanmakuBlockPattern.isPattern(word)) {
      words.add(word);
      continue;
    }
    if (DanmakuBlockPattern.compile(word) case final pattern?) patterns.add(pattern);
  }
  return DanmakuFilterPolicy(blockedUsers: rules.users, blockedKeywords: words, blockedPatterns: patterns);
}

/// The controller config for the viewer's fuzzy and repeated filter rules.
/// The gate and timing values stay media_core's tuned defaults.
DanmakuConfig _danmakuConfigFor(DanmakuFilterRules filter, DanmakuRepeatSettings repeat) =>
    DanmakuConfig.defaults.copyWith(
      repeatedFilterEnabled: repeat.enabled,
      repeatedFilterWindow: Duration(seconds: repeat.windowSeconds),
      similarityFilterEnabled: filter.similarityEnabled,
      similarityThreshold: filter.similarityThreshold,
      similarityCacheDuration: Duration(seconds: filter.similarityCacheSeconds),
      similarityMaxCacheSize: filter.similarityMaxCacheSize,
    );

/// The flying layer's engine for a live room: a paused picture must not stop
/// the room's comments — they are a live flow that keeps arriving, so the
/// binding's pause is swallowed here while the stock controller is left to
/// the video player, whose comments follow its own timeline.
final class RoomBarrageController extends BarrageController {
  @override
  void pause() {}
}

/// The room's flying danmaku pipeline, one per open room: the site's
/// session events are accepted into the media_core danmaku controller,
/// whose pipeline (the viewer's shield policy, then the gate and the
/// duplicate/similarity filters) runs first; the sink hands every accepted
/// message to the chat list and the flame engine (the flying layer) at
/// once, and the player binding carries seek along — a paused picture does
/// not stop a live flow.
final class RoomDanmakuPipeline {
  RoomDanmakuPipeline(
    this.onChat, {
    required this.showChatGifts,
    required this.chatGiftsAboveTier,
    required this.showFlyGifts,
    required String Function() streamer,
    required ShieldRules shield,
    required DanmakuFilterRules filter,
    required DanmakuRepeatSettings repeat,
    required bool Function() showFixedTop,
    required bool Function() showFixedBottom,
    required this.onShielded,
  }) : barrage = RoomBarrageController() {
    chatGifts = GiftChatFilter(clock: DateTime.now)..aboveTier = chatGiftsAboveTier();
    danmaku = DanmakuController(
      sink: _ChatMirrorSink(
        onChat: onChat,
        inner: FlameBarrageSink(barrage),
        showFixedTop: showFixedTop,
        showFixedBottom: showFixedBottom,
      ),
      config: _danmakuConfigFor(filter, repeat),
      policy: _shieldPolicyFor(shield),
    );
    // The shield's own verdicts are the ones the room counts: a duplicate or a
    // collapsed repeat is the room's traffic, not something the viewer asked
    // never to see.
    danmaku.onSuppressed = (_, _) => onShielded();
    giftFlights = GiftFlights(
      clock: DateTime.now,
      // Read per gift, so the switch bites the very next one; a gift that
      // started its combo before the switch went off is forgotten by
      // [setFlyGifts].
      emit: (item) {
        if (showFlyGifts()) barrage.send(item);
      },
      streamer: streamer,
    );
  }

  /// The flame engine the flying layer draws with.
  final RoomBarrageController barrage;

  /// The danmaku controller running the reference pipeline's filters.
  late final DanmakuController danmaku;

  /// Where the accepted chat lands (the room state subscribes); `replaceId`
  /// names a gift line a growing combo updates.
  final void Function(LiveMessage message, {String? replaceId}) onChat;

  /// Whether a platform gift gets a chat line (read per gift, so the switch
  /// bites the very next one).
  final bool Function() showChatGifts;

  /// Whether the chat list keeps only valuable gifts (read per gift, so the
  /// switch bites the very next one).
  final bool Function() chatGiftsAboveTier;

  /// Says that the viewer's shield hid a message; the room's
  /// 「本场已屏蔽 {count} 条」 counts these.
  final void Function() onShielded;

  /// Whether the platform's valuable gifts fly over the picture (read per
  /// gift, like the chat switch).
  final bool Function() showFlyGifts;

  /// The gifts that fly over the picture, with the reference's tier, combo
  /// and rate rules.
  late final GiftFlights giftFlights;

  /// The chat list's gift lines under "只显示值钱的礼物".
  late final GiftChatFilter chatGifts;

  /// The player binding carrying pause and seek into the barrage.
  DanmakuPlayerBinding? binding;

  /// Brings the controller's session up over a bridge: the app's own site
  /// session owns the real connection, so the transport only settles the
  /// controller's state machine — after this, the gate, the policy and the
  /// content filters run for every accepted message, and the sink flies
  /// them onto the flame layer and the chat overlay at once.
  Future<void> start({required String platform, required String roomId}) async {
    danmaku.installTransport(_BridgeTransport(platform: platform, roomId: roomId));
    await danmaku.connect(DanmakuRoomRef(platform: platform, roomId: roomId));
  }

  /// Applies the viewer's fuzzy filter and repeated-collapse settings to the
  /// following messages, without reconnecting or forgetting the compared
  /// texts.
  void configure(DanmakuFilterRules filter, DanmakuRepeatSettings repeat) {
    danmaku.updateConfig(_danmakuConfigFor(filter, repeat));
  }

  /// Applies a changed shield rule set to the following messages: the
  /// policy is a plain object the controller swaps in place, so the next
  /// line is judged by the new words without reconnecting.
  ///
  /// The same words are built into a block list for the messages that never
  /// reach the pipeline — a gift is one of them (see [accept]). Without this a
  /// viewer can block a name and still be shown that name's paid line and gift
  /// animation, which reads as the shield being decorative.
  void setShieldPolicy(ShieldRules rules) {
    danmaku.policy = _shieldPolicyFor(rules);
    if (identical(rules, _shieldRules)) return;
    _shieldRules = rules;
    _shieldBlockList = rules.enabled ? DanmakuBlockList.of(users: rules.users, keywords: rules.keywords) : null;
  }

  ShieldRules? _shieldRules;
  DanmakuBlockList? _shieldBlockList;

  /// Applies a changed "飞行弹幕显示礼物" choice: turning it off forgets the
  /// combos on their way without flying their ends.
  void setFlyGifts({required bool enabled}) {
    if (!enabled) giftFlights.clear();
  }

  /// Applies the chat list's gift switch: off forgets the combos counted
  /// out of sight.
  void setChatGifts({required bool enabled}) {
    if (!enabled) chatGifts.clear();
  }

  /// Whether the chat list keeps only valuable gifts.
  bool get chatAboveTier => chatGifts.aboveTier;

  /// Applies a changed "只显示值钱的礼物" choice to the next gift.
  set chatAboveTier(bool enabled) => chatGifts.aboveTier = enabled;

  /// Feeds one accepted site message through the pipeline.
  void accept(LiveMessage message) {
    // A gift is a line of its own, never flying chat: the list's switch
    // decides it, and the flying layer's own switch is its own setting.
    if (message.type == LiveMessageType.gift) {
      // The shield is consulted here because a gift never enters the pipeline:
      // the block list is the viewer's own words, and paying for a message is
      // not a way back onto a screen they cleared.
      if ((_shieldRules?.enabled ?? false) && (_shieldBlockList?.blocks(message) ?? false)) return;
      if (showChatGifts()) {
        final line = chatGifts.add(message);
        if (line != null) onChat(line.message, replaceId: line.replaceId);
      }
      if (showFlyGifts()) giftFlights.add(message);
      return;
    }
    final sender = message.sender;
    danmaku.acceptExternal(
      DanmakuMessage(
        type: DanmakuMessageType.chat,
        userName: sender?.userName ?? '',
        userId: sender?.userId ?? '',
        userLevel: sender?.userLevel ?? '',
        fansLevel: sender?.fanBadgeLevel ?? '',
        fansName: sender?.fanBadgeName ?? '',
        text: message.text,
        color: message.color == null
            ? DanmakuColor.white
            : DanmakuColor(message.color!.r, message.color!.g, message.color!.b),
        messageId: message.messageId,
        sentAt: message.sentAt,
        isLocal: message.isLocal,
        // What the platform calls it decides the age the gate applies: a
        // backlog or a resume resend is measured against the replay window,
        // not the live one, or joining a running room shows no history.
        replayed: message.replayed,
      ),
    );
  }

  /// Takes recalled lines off the flying layer.
  ///
  /// The engine answers for both halves of what it holds — the queued backlog
  /// and the text already crossing the picture — so a moderator's delete
  /// reaches a danmaku that has not arrived yet as well as one in mid-flight.
  /// A barrage item carries the platform's message id, the sender's id and the
  /// sender's name, which is the same three things the chat list matches on, so
  /// the two surfaces agree on which line the platform took back.
  void retract(LiveRetraction target) {
    barrage.retractWhere((item) => target.matches(userId: item.userId, userName: item.userName, messageId: item.id));
  }

  /// Carries playback pause/seek into the barrage engine.
  void bind(PlayerHandle handle) {
    unawaited(binding?.dispose() ?? Future<void>.value());
    binding = DanmakuPlayerBinding.forHandle(controller: barrage, handle: handle);
    binding!.attach();
  }

  Future<void> dispose() async {
    await binding?.dispose();
    binding = null;
    giftFlights.dispose();
    await danmaku.dispose();
    barrage.dispose();
  }
}

/// Mirrors the messages the pipeline accepted onto the chat list, then hands
/// them to the flying layer. The list must see exactly what the filters let
/// through, so the mirror sits after them rather than at the site seam; the
/// pinned lanes' switches drop a message from the picture only, never from
/// the list.
final class _ChatMirrorSink implements DanmakuSink {
  const _ChatMirrorSink({
    required this.onChat,
    required this.inner,
    required this.showFixedTop,
    required this.showFixedBottom,
  });

  final void Function(LiveMessage message, {String? replaceId}) onChat;
  final DanmakuSink inner;
  final bool Function() showFixedTop;
  final bool Function() showFixedBottom;

  @override
  void onDanmaku(DanmakuMessage message, {bool immediate = false}) {
    if (message.text.trim().isNotEmpty) {
      onChat(
        LiveMessage.normalized(
          text: message.text,
          sender: MessageSender.of(
            userId: message.userId,
            userName: message.userName,
            userLevel: message.userLevel.isEmpty ? null : message.userLevel,
            fanBadgeLevel: message.fansLevel,
            fanBadgeName: message.fansName,
          ),
          color: LiveMessageColor(message.color.r, message.color.g, message.color.b),
          messageId: message.messageId,
          sentAt: message.sentAt,
          isLocal: message.isLocal,
          // The list marks a re-shown line as 「之前发的」; the flag has to
          // survive the round trip through the pipeline or the gate's replay
          // window lets a backlog in that then claims to be live.
          replayed: message.replayed,
        ),
      );
    }
    final draws = switch (message.style?.placement) {
      DanmakuPlacement.top => showFixedTop(),
      DanmakuPlacement.bottom => showFixedBottom(),
      _ => true,
    };
    if (draws) inner.onDanmaku(message, immediate: immediate);
  }

  @override
  void onAudienceUpdate(DanmakuAudienceUpdate update) => inner.onAudienceUpdate(update);

  @override
  void onSuperChat(DanmakuSuperChat message) => inner.onSuperChat(message);

  @override
  void onNotice(DanmakuNotice notice) => inner.onNotice(notice);

  @override
  void onTransportNotice(String message) => inner.onTransportNotice(message);

  @override
  void onRoomChanged(String? roomId) => inner.onRoomChanged(roomId);

  @override
  void clearRendered() => inner.clearRendered();
}

/// The pipeline's session transport: the bridge. The site's own session
/// carries the real connection, so this one settles ready the moment it
/// starts and carries nothing else — no heartbeat, no socket, nothing to
/// stop. Its only job is to bring the controller's session to connected so
/// accepted messages run the full filter pipeline.
final class _BridgeTransport implements DanmakuTransport {
  const _BridgeTransport({required this.platform, required this.roomId});

  final String platform;
  final String roomId;

  @override
  String get id => 'bridge:$platform:$roomId';

  @override
  bool get isConnected => true;

  @override
  Duration get heartbeatInterval => Duration.zero;

  @override
  Future<void> start({required DanmakuTransportRequest request, required DanmakuTransportListener listener}) async {
    listener.onTransportReady();
  }

  @override
  Future<void> stop() async {}

  @override
  void heartbeat() {}
}

/// The chat list, on its own controller: a busy room's messages land many
/// times a second, and a chat line should never rebuild the player surface
/// beside it. The room controller feeds it; the page reads only this.
final class RoomChatController extends Notifier<List<LiveMessage>> {
  @override
  List<LiveMessage> build() => const [];

  /// Appends [message], keeping the newest [kRoomChatLimit]; with
  /// [replaceId] it replaces that line instead, moving it to the bottom as
  /// a growing combo does.
  void add(LiveMessage message, {String? replaceId}) {
    if (replaceId != null) {
      final index = state.indexWhere((line) => line.messageId == replaceId);
      if (index >= 0) {
        final next = [...state]
          ..removeAt(index)
          ..add(message);
        state = next.length > kRoomChatLimit ? next.sublist(next.length - kRoomChatLimit) : next;
        return;
      }
    }
    final next = [...state, message];
    state = next.length > kRoomChatLimit ? next.sublist(next.length - kRoomChatLimit) : next;
  }

  /// Clears the list (a new room opens).
  void clear() => state = const [];

  /// Puts local danmaku sent in this room before this visit at the top,
  /// oldest first; they are already filtered and do not fly again.
  void replayOldest(Iterable<LiveMessage> messages) {
    final replay = [
      for (final message in messages)
        if (message.text.trim().isNotEmpty) message,
    ];
    if (replay.isEmpty) return;
    final next = [...replay, ...state];
    state = next.length > kRoomChatLimit ? next.sublist(next.length - kRoomChatLimit) : next;
  }

  /// Drops every gift line (the chat gift switch was turned off).
  void removeGifts() {
    if (!state.any((message) => message.type == LiveMessageType.gift)) return;
    state = state.where((message) => message.type != LiveMessageType.gift).toList(growable: false);
  }

  /// Drops the gift lines below "值钱" (the tier switch was turned on).
  void removeNormalTierGifts() {
    bool belowTier(LiveMessage message) {
      if (message.type != LiveMessageType.gift || message.isLocal) return false;
      final gift = message.payload;
      return gift is LiveGift && giftLineTier(gift) == LiveGiftTier.normal;
    }

    if (!state.any(belowTier)) return;
    state = state.where((message) => !belowTier(message)).toList(growable: false);
  }

  /// Takes back what the platform recalled: one line by its id, one viewer's
  /// lines, or the room's chat.
  ///
  /// Only said lines are taken. A gift or a status line stays: the moderator
  /// recalled what somebody typed, not what the room paid to show or what the
  /// session itself announced, and removing those would silently undo two
  /// other viewer settings.
  void retract(LiveRetraction target) {
    bool recalled(LiveMessage line) {
      if (line.type != LiveMessageType.chat) return false;
      final sender = line.sender;
      return target.matches(userId: sender?.userId, userName: sender?.userName, messageId: line.messageId);
    }

    if (!state.any(recalled)) return;
    state = state.where((line) => !recalled(line)).toList(growable: false);
  }
}

/// The open room's chat lines.
final roomChatProvider = NotifierProvider<RoomChatController, List<LiveMessage>>(RoomChatController.new);

/// One line the room raises for the viewer about a login (a Bilibili
/// connection that only sees masked names, a Twitch cookie the server
/// refused). Its `id` rises with every hint, so the same words twice in
/// a row are still a new event for the page's listener.
typedef RoomHint = ({int id, String text});

/// The room's hint channel: the controller has no context to toast with, so
/// it pushes here and the visible page shows it.
final class RoomHintController extends Notifier<RoomHint?> {
  int _lastId = 0;

  @override
  RoomHint? build() => null;

  /// Raises [text] once for the room page to toast.
  void show(String text) => state = (id: ++_lastId, text: text);
}

/// The open room's one-line hints.
final roomHintProvider = NotifierProvider<RoomHintController, RoomHint?>(RoomHintController.new);

/// What the room's chat column keeps on screen about its own login: the words
/// and the platform whose sign-in would fix them.
typedef RoomChatNotice = ({String siteId, String text});

/// The login notice the chat column wears.
///
/// Not a toast: a viewer who is watching the picture when the room says "your
/// cookie is dead" has usually missed the toast by the time they look back at
/// the chat, and the fix — a minute at the sign-in page — is worth more than
/// the second a toast stays up. The reference keeps a bar above the list for
/// the same reason. It is set where the room can actually tell (a refused
/// Twitch cookie, a Bilibili socket that only sees masked names) and it goes
/// away on its own when the next connection stops looking like that, so an
/// old complaint cannot outlive the login that caused it.
final class RoomChatNoticeController extends Notifier<RoomChatNotice?> {
  @override
  RoomChatNotice? build() => null;

  /// Raises the notice for [siteId] with [text].
  void show(String siteId, String text) {
    final current = state;
    if (current != null && current.siteId == siteId && current.text == text) return;
    state = (siteId: siteId, text: text);
  }

  /// Takes it away: the viewer said they saw it, or a new connection proved the
  /// login good.
  void clear() => state = null;
}

/// The open room's standing login notice.
final roomChatNoticeProvider = NotifierProvider<RoomChatNoticeController, RoomChatNotice?>(
  RoomChatNoticeController.new,
);

/// What one entry into a room cost, stage by stage: the numbers behind "this
/// room opens slowly", kept for the room's own details panel because a viewer
/// is not going to open a log file to answer a question the app asked them.
typedef RoomOpenRecord = ({
  String site,
  String roomId,
  RoomOpenProxy proxy,
  List<RoomOpenStage> stages,
  Duration total,
  bool failed,
});

/// The last entry's timings.
final class RoomOpenRecordController extends Notifier<RoomOpenRecord?> {
  @override
  RoomOpenRecord? build() => null;

  /// Publishes the entry that just ended, measured by [timing].
  void report(RoomOpenTiming timing, {bool failed = false}) {
    state = (
      site: timing.site,
      roomId: timing.roomId,
      proxy: timing.proxy,
      stages: timing.stages,
      total: timing.total,
      failed: failed,
    );
  }

  /// Drops it: the next room has its own numbers, and last visit's would be
  /// read as this one's.
  void clear() => state = null;
}

/// The stage timings of the room's most recent entry.
final roomOpenRecordProvider = NotifierProvider<RoomOpenRecordController, RoomOpenRecord?>(
  RoomOpenRecordController.new,
);

/// One open live room: its detail, its play plan, the playback over
/// media_core's live controller, and the danmaku session beside it.
///
/// One room plays at a time (the route pushes one page); reopening — the
/// same room or another — resets the state, tears the old playback and
/// danmaku session down, and starts over. The room's identity is not the
/// provider's identity: it is just the room being watched.
final class RoomController extends Notifier<RoomState> {
  LivePlaybackController? _playback;
  RoomPlaybackSession? _session;
  RoomPlaybackStandby? _standby;
  StreamSubscription<PlayerCoreState>? _states;
  StreamSubscription<PlayerHandle>? _handles;
  StreamSubscription<PlayerFailure>? _failures;
  StreamSubscription<LiveMessage>? _chat;
  StreamSubscription<GeometryState>? _geometry;

  /// The adapter events that carry the first decoded frame of an entry.
  StreamSubscription<PlayerAdapterEvent>? _frames;

  /// The platform's own "the stored cookie was refused" events, for the site
  /// this room was opened from; cancelled with the room.
  StreamSubscription<void>? _cookieRefusals;

  /// The open room's minute re-read; cancelled with the room.
  Timer? _detailRefresh;

  /// The timer that re-reads the plan when the platform's own address lease
  /// says it has to be rebuilt. See [RoomController._armLeaseRenewal].
  Timer? _leaseRenewal;

  /// How many times a chat the platform refused *for now* is opened again on
  /// the room's own, before the column's 重试 button is left to the viewer.
  static const int _kChatTransientRetries = 3;

  /// The pending automatic chat retry, and how many this room has spent.
  Timer? _chatRetry;
  int _chatAttempts = 0;
  LiveDanmakuSession? _danmaku;
  RoomDanmakuPipeline? _pipeline;

  /// Rises with every teardown, so an open still in flight (its detail,
  /// qualities and lines reads are network awaits) cannot build a session
  /// behind a closed or replaced room: the page is gone, the provider is
  /// not, and an unguarded continuation would play its stream to no one.
  /// The danmaku path has the same gate in [_danmakuCurrent].
  int _openEpoch = 0;

  /// The stopwatch of the entry now in flight, reported once when its picture
  /// arrives or fails, and once more if the viewer walks away from a room that
  /// has been asking longer than [kSlowEntryBudget]: "the room is slow" is
  /// four different faults, and only the numbers say which.
  RoomOpenTiming? _openTiming;

  /// Which way this entry's requests are leaving the machine.
  ///
  /// Recorded with the stages because the same stage number means two
  /// different things depending on it: a ten-second detail behind a proxy that
  /// cannot reach the edge is a network setting, and one that slow going
  /// direct is the platform or the route.
  RoomOpenProxy get _proxyForEntry => switch (ref.read(proxySettingsProvider).mode) {
    ProxyMode.off => RoomOpenProxy.direct,
    ProxyMode.system => RoomOpenProxy.system,
    ProxyMode.manual => RoomOpenProxy.manual,
  };

  /// Writes the entry's line to the log, hands its numbers to the details
  /// panel, and stops measuring.
  ///
  /// An [abandoned] entry reaches the log only: the panel belongs to the room
  /// the viewer stayed in, and the entry they walked away from has no panel
  /// left to show it on.
  void _reportOpenTiming({bool failed = false, bool abandoned = false}) {
    final timing = _openTiming;
    if (timing == null) return;
    _openTiming = null;
    appLog.forCategory('room').info(timing.line(failed: failed, abandoned: abandoned));
    if (abandoned || !ref.mounted) return;
    ref.read(roomOpenRecordProvider.notifier).report(timing, failed: failed);
  }

  /// Rises with every danmaku open the room starts (a platform account change
  /// re-opens it); an answer that arrives after a newer open, a room switch
  /// or a close installs nothing.
  int _danmakuEpoch = 0;

  /// The epoch of the room's first danmaku open while it is still in flight,
  /// else null. A login that lands inside that window (the account pane
  /// applies the stored cookies just as a room opens) has no session to
  /// re-new yet, and must not be lost.
  int? _danmakuOpeningEpoch;

  /// The names this danmaku connection has seen on Bilibili: masked ones
  /// (a guest's view) and full ones, with the hint raised once per connection
  /// ([_nameHintShown]).
  int _maskedChats = 0;
  int _namedChats = 0;
  bool _nameHintShown = false;

  LivePlayQuality? _wantedQuality;

  /// The request the current page asked for, so a detail failure can be
  /// retried even before a room object exists.
  String? _requestedPlatform;
  String? _requestedRoomId;

  /// The audio the viewer set in this room: a replacement engine (a line
  /// switch, a recovery) must come back at the same mute and volume, not at
  /// the engine's defaults.
  bool _muted = false;

  /// The app-wide mute (the reference's `globalVolumeMute`); it overrides
  /// the room's own mute without erasing the viewer's choice.
  bool _globalMute = false;

  /// Whether this room is in ASMR/manual audio-only presentation.
  bool _audioOnly = false;
  double _volume = 1;

  /// The handle the engine configuration went to; a replacement engine (a
  /// line switch, a recovery) gets it again, a repeated event does not.
  PlayerHandle? _preparedHandle;

  /// The most recent engine this room attached, kept apart from the state so
  /// a teardown can silence it even while the provider is being disposed.
  PlayerHandle? _lastHandle;

  /// Read before the provider tree can go away: teardown may not touch ref.
  bool _forceDestroy = false;

  @override
  RoomState build() {
    _forceDestroy = ref.read(playerTuningProvider).forceDestroy;
    _standby = ref.read(roomPlaybackStandbyProvider);
    ref.onDispose(_teardown);
    ref.listen(playerTuningProvider.select((tuning) => tuning.forceDestroy), (_, next) => _forceDestroy = next);
    ref.listen(playerTuningProvider, (previous, next) {
      final handle = state.handle;
      if (handle != null) unawaited(_applyTuning(handle, previous, next));
    });
    ref.listen(playerProxyProvider, (_, _) {
      final playback = _playback;
      if (playback != null) unawaited(playback.updateEngineOptions(_storedEngineOptions()));
    });
    ref.listen(playbackSettingsProvider.select((settings) => settings.hardwareDecoding), (previous, next) {
      if (previous == next) return;
      final playback = _playback;
      if (playback != null) unawaited(playback.updateEngineOptions(_storedEngineOptions()));
    });
    ref.listen(danmakuFilterProvider, (previous, next) {
      if (previous != next) _pipeline?.configure(next, ref.read(danmakuRepeatProvider));
    });
    ref.listen(danmakuRepeatProvider, (previous, next) {
      if (previous != next) _pipeline?.configure(ref.read(danmakuFilterProvider), next);
    });
    ref.listen(shieldRulesProvider, (previous, next) {
      if (previous != next) _pipeline?.setShieldPolicy(next);
    });
    ref.listen(chatShowGiftsProvider, (previous, next) {
      if (previous == next) return;
      _pipeline?.setChatGifts(enabled: next);
      if (!next) ref.read(roomChatProvider.notifier).removeGifts();
    });
    ref.listen(chatGiftsAboveTierProvider, (previous, next) {
      if (previous == next) return;
      final pipeline = _pipeline;
      if (pipeline != null) pipeline.chatAboveTier = next;
      if (next) ref.read(roomChatProvider.notifier).removeNormalTierGifts();
    });
    ref.listen(danmakuShowGiftsProvider, (previous, next) {
      if (previous == next) return;
      _pipeline?.setFlyGifts(enabled: next);
    });
    ref.listen(superChatIncludesMembershipProvider, (previous, next) {
      if (previous == next) return;
      if (!next) ref.read(roomSuperChatsProvider.notifier).removeMembershipCards();
    });
    ref.listen(playbackSettingsProvider.select((settings) => settings.globalMute), (previous, next) {
      if (previous == next) return;
      _globalMute = next;
      state = _with();
      final handle = state.handle;
      if (handle != null) unawaited(_setHandleMute(handle));
    });
    // A platform account changed (signed in, a renewed cookie, signed out).
    // The site adapters already read the new cookies from the store, so only
    // the room's danmaku has to ask for its credentials again — the
    // reference's `secrets.cookieChanges` seam. The playback keeps running.
    ref.listen(accountsProvider, (previous, next) {
      final siteId = state.room?.ref.platform;
      if (siteId == null) return;
      if (_sameCredential(previous?.credentials[siteId], next.credentials[siteId])) return;
      unawaited(_onLoginChanged(siteId));
    });
    return _initial();
  }

  /// Opens the room behind [platform] and [roomId]: detail first, then the
  /// qualities it offers; the first playable line begins playback. The
  /// danmaku session opens beside that, never before it. A room that cannot
  /// open says why in the state error field — the page shows it, never a blank.
  Future<void> open({required String platform, required String roomId, LiveRoom? known}) async {
    // A room that is already playing for this very page is adopted, not
    // reopened: the floating player hands the live handle back when its
    // window returns, and tearing it down would restart the stream, drop the
    // danmaku session and show a black frame for the length of a fresh
    // handshake. Only a healthy handle whose room matches is adopted — a
    // failed or stopped room takes the full path.
    final existing = state;
    final sameRoom = existing.room?.ref.platform == platform && existing.room?.ref.roomId == roomId;
    if (sameRoom && existing.handle != null && existing.error == null) {
      _requestedPlatform = platform;
      _requestedRoomId = roomId;
      return;
    }
    _requestedPlatform = platform;
    _requestedRoomId = roomId;
    _teardown();
    _openTiming = RoomOpenTiming(site: platform, roomId: roomId, proxy: _proxyForEntry);
    // Last visit's numbers describe last visit's room.
    ref.read(roomOpenRecordProvider.notifier).clear();
    final epoch = _openEpoch;
    ref.read(roomSuperChatsProvider.notifier).clear();
    final settings = ref.read(playbackSettingsProvider);
    // ASMR is an Android-only automatic audio-only entry (the reference's
    // `enableAsmrSleepMode`); the room page starts its sleep timer beside it.
    _audioOnly = !kIsWeb && defaultTargetPlatform == TargetPlatform.android && settings.asmrSleepMode;
    state = _initial(audioOnly: _audioOnly);
    _muted = settings.muted;
    _globalMute = settings.globalMute;
    _volume = ref.read(playbackSettingsProvider.notifier).volume;
    _preparedHandle = null;
    ref.read(roomChatProvider.notifier).clear();
    ref.read(roomShieldCountProvider.notifier).reset();
    final site = ref.read(sitesProvider).getById(platform);
    final roomProvider = site?.capability<LiveRoomProvider>();
    final playbackProvider = site?.capability<LivePlaybackProvider>();
    if (site == null || roomProvider == null || playbackProvider == null) {
      state = _with(error: 'the site has no room or playback capability');
      _reportOpenTiming(failed: true);
      return;
    }
    // B-7: the platform says in its own words when it threw the stored cookie
    // out and carried on anonymously. That is a typed event from the site, so
    // the room listens to it instead of recognising the chat's notice by its
    // exact sentence — the socket's notice only told about the danmaku, and a
    // refused playback cookie said nothing to the viewer at all.
    final refusals = site.capability<LiveCookieRefusalFeed>();
    _cookieRefusals = refusals?.cookieRefusals.listen((_) => _onCookieRefused(platform));
    // The card the viewer picked draws the first frame; the platform's
    // detail answer replaces it below.
    if (known != null) state = _with(room: known);
    final roomAnswer = await roomProvider.getRoom(roomId);
    unawaited(
      roomAnswer.match(
        (error) async {
          if (epoch != _openEpoch) return;
          state = _with(error: error.message);
          _reportOpenTiming(failed: true);
        },
        (detail) async {
          if (epoch != _openEpoch) return;
          _openTiming?.markDetail();
          final room = _fillTitleFromKnown(detail);
          state = _with(room: room);
          _armDetailRefresh();
          unawaited(_recordHistory(room));
          unawaited(_loadSuperChats(room));
          // Chat runs beside the stream, never ahead of it: one danmaku
          // handshake gets its whole budget (10 s on a Douyin edge this network
          // cannot reach), and awaiting it here made the viewer wait that out
          // for the first frame.
          final danmakuProvider = site.capability<LiveDanmakuProvider>();
          if (room.broadcast.isLiveNow && danmakuProvider != null) {
            unawaited(_openDanmaku(danmakuProvider, room));
          } else {
            // A replay, or a platform that carries no chat: the column names
            // that instead of showing an empty list that reads as a quiet room.
            state = _with(chat: (status: RoomChatStatus.unsupported, error: null));
          }
          final qualitiesAnswer = await playbackProvider.getQualities(room: room);
          unawaited(
            qualitiesAnswer.match(
              (error) async {
                if (epoch != _openEpoch) return;
                state = _with(error: error.message);
                _reportOpenTiming(failed: true);
              },
              (qualities) async {
                if (epoch != _openEpoch) return;
                _openTiming?.markQualities();
                _wantedQuality = _pickQuality(qualities);
                state = _with(qualities: qualities, quality: _wantedQuality);
                await _startPlayback(playbackProvider, room);
              },
            ),
          );
        },
      ),
    );
  }

  /// The room as this app already knows it: the list it was opened from, a
  /// follow, or the watch record. A detail whose platform page carries no
  /// title falls back to it below.
  LiveRoom? _knownRoomOf(String platform, String roomId) {
    final normalized = platform.trim().toLowerCase();
    for (final room in _knownRooms()) {
      if (room.ref.platform == normalized && room.ref.roomId == roomId.trim()) return room;
    }
    return null;
  }

  Iterable<LiveRoom> _knownRooms() sync* {
    final playlist = ref.read(roomPlaylistProvider)?.rooms;
    if (playlist != null) yield* playlist;
    yield* ref.read(followsProvider).rooms;
    for (final (room, _) in ref.read(historyProvider).records) {
      yield room;
    }
  }

  /// [detail] with its title filled from what the app already knows of the
  /// room when the platform's room page carries none (Kuaishou's page has
  /// no broadcast title, only its list cards do): the card the room was
  /// opened from (the playlist), the follow, or the watch record — the
  /// reference's rule of entering from a card keeping the card's title. A
  /// detail with its own title is left as it is.
  LiveRoom _fillTitleFromKnown(LiveRoom detail) {
    if (detail.content.title.trim().isNotEmpty) return detail;
    final title = _knownRoomOf(detail.ref.platform, detail.ref.roomId)?.content.title.trim() ?? '';
    if (title.isEmpty) return detail;
    return detail.rebuild((b) => b.content = detail.content.rebuild((c) => c.title = title).toBuilder());
  }

  /// Switches the quality: the plan is re-read at the new quality and
  /// playback starts over from its first line - unless the platform answers
  /// with the media that is already playing, which is a tier it cannot serve
  /// (see [isSamePlayPlan]); then only the label moves.
  Future<void> selectQuality(LivePlayQuality quality) async {
    final room = state.room;
    final playbackProvider = _playbackCapabilityOf(room);
    if (room == null || playbackProvider == null) return;
    _wantedQuality = quality;
    state = _with(quality: quality, lineIndex: 0);
    await _startPlayback(playbackProvider, room, keepPlayingWhenUnchanged: true);
  }

  /// Moves playback to the line at [index] without re-reading the plan.
  Future<void> selectLine(int index) async {
    state = _with(lineIndex: index);
    await _playback?.switchLine(index);
    // Each line carries its own lease, so the timer is the new line's.
    _armLeaseRenewal();
  }

  /// The recovery button: the live controller's retry.
  Future<void> retry() async {
    final playback = _playback;
    if (playback != null && state.room != null) {
      await playback.retry();
      return;
    }
    final platform = _requestedPlatform;
    final roomId = _requestedRoomId;
    if (platform != null && roomId != null) {
      await open(platform: platform, roomId: roomId, known: state.room);
    }
  }

  /// Re-reads the room's display state without tearing playback down: the
  /// site's own refresh read is sparse, so the stored room keeps what it
  /// already knew and takes the new status, figures and text. A listener
  /// holding an offline room learns the streamer is back without losing
  /// the room's identity; a platform without a refresh read replays the
  /// detail request only when nothing is playing.
  ///
  /// [manual] is the viewer's own press. The minute-by-minute re-read passes
  /// false, and that changes two things: one network turn that did not answer
  /// must not put a failure overlay over a stream that is still playing, and a
  /// tick must never rebuild the player. A background read that fell through to
  /// [open] would start playback on its own, once a minute, in a room the viewer
  /// is only watching.
  Future<void> refreshRoom({bool manual = true}) async {
    final room = state.room;
    final platform = _requestedPlatform;
    final roomId = _requestedRoomId;
    if (room == null || platform == null || roomId == null) return;
    final capability = ref.read(sitesProvider).getById(platform)?.capability<LiveRoomRefresh>();
    if (capability == null) {
      if (manual && state.handle == null) await open(platform: platform, roomId: roomId);
      return;
    }
    final answer = await capability.getRoomForRefresh(roomId: roomId);
    if (!ref.mounted) return;
    answer.match((error) {
      if (manual) state = _with(error: error.message);
    }, (fresh) => state = _with(room: room.mergedWith(fresh)));
  }

  /// The minute-by-minute re-read of the open room's figures, status and text.
  ///
  /// A room left open on a desktop is watched, not visited: without this the
  /// title, the cover and the audience a platform rewrites mid-broadcast stay
  /// as they were when the room was entered, and a streamer who stopped is only
  /// learned when the viewer asks.
  void _armDetailRefresh() {
    _detailRefresh?.cancel();
    _detailRefresh = Timer.periodic(kRoomDetailRefreshEvery, (_) => unawaited(refreshRoom(manual: false)));
  }

  /// Pauses (the sleep timer's stop; never resumes a paused room).
  Future<void> pause() async {
    await _playback?.pause();
  }

  /// Pauses or resumes.
  Future<void> togglePlayPause() async {
    await _playback?.togglePlayPause();
  }

  /// Mutes or unmutes, remembering the choice for the next engine.
  ///
  /// An unmute from the player while the app-wide mute is on clears that
  /// setting: otherwise the button would look alive and do nothing.
  Future<void> setMuted({required bool value}) async {
    if (!value && _globalMute) {
      _globalMute = false;
      unawaited(ref.read(playbackSettingsProvider.notifier).setGlobalMute(value: false));
    }
    _muted = value;
    // Mute is not on the transport stream; a state echo rebuilds the bar's
    // icon now rather than on the next unrelated event.
    state = _with();
    final handle = state.handle;
    if (handle != null) await _setHandleMute(handle);
  }

  /// The audio the room holds (and hands every replacement engine), after
  /// the app-wide mute has had its say.
  bool get muted => _muted || _globalMute;

  /// Whether the picture is replaced by the audio-only cover.
  bool get audioOnly => _audioOnly;

  /// Switches audio-only mode now and for every replacement engine.
  Future<void> setAudioOnly({required bool value}) async {
    if (_audioOnly == value) return;
    _audioOnly = value;
    state = _with(audioOnly: value);
    final handle = state.handle;
    if (handle == null) return;
    try {
      await handle.setAudioOnly(audioOnly: value);
    } on Object {
      // A refused mode is not a playback failure; the cover still follows.
    }
  }

  Future<void> _setHandleMute(PlayerHandle handle) async {
    try {
      await handle.setMute(muted: _muted || _globalMute);
    } on Object {
      // A preference the engine refused is not a playback failure.
    }
  }

  /// The volume the room holds.
  double get volume => _volume;

  /// Sets the volume, remembering it for the next engine.
  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    _volume = clamped;
    await state.handle?.setVolume(clamped);
  }

  /// Stops the room: playback released, the danmaku session closed, the
  /// state empty. The page calls this when it leaves the route; the room's
  /// provider outlives a page on purpose so a rebuild does not restart the
  /// stream, which is exactly why the page must say when it is done.
  Future<void> close() async {
    _teardown();
    state = _initial();
    ref.read(roomChatProvider.notifier).clear();
    ref.read(roomShieldCountProvider.notifier).reset();
    ref.read(roomSuperChatsProvider.notifier).clear();
  }

  /// Stops the room as its page leaves: the picture goes quiet now, the state
  /// writes wait for the frame.
  ///
  /// [close] clears the state in place, which a leaving page may not do: the
  /// route unmounts while the tree is being torn down, and Riverpod rejects a
  /// notification in that phase. Only the writes move, because the stream must
  /// not be heard over the page that follows. The write re-checks the room —
  /// a room opened meanwhile owns the state and the chat now.
  void closeFromPage() {
    final leavingKey = state.room?.identityKey;
    _teardown();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!ref.mounted) return;
      if (state.room?.identityKey != leavingKey) return;
      state = _initial();
      ref.read(roomChatProvider.notifier).clear();
      ref.read(roomShieldCountProvider.notifier).reset();
      ref.read(roomSuperChatsProvider.notifier).clear();
    });
  }

  /// Lands the viewer's current audio on a freshly attached engine; a line
  /// switch or recovery must not unmute or reset the volume.
  Future<void> _applyAudioPreferences(PlayerHandle handle) async {
    try {
      await handle.setVolume(_volume);
      await handle.setMute(muted: _muted || _globalMute);
      await handle.setAudioOnly(audioOnly: _audioOnly);
    } on Object {
      // A preference the engine refused is not a playback failure.
    }
  }

  /// The engine options this room keeps for every line, engine fallback and
  /// recovery: hardware decoding and the player proxy. The shader chain is
  /// applied on each handle separately.
  List<EngineOption> _storedEngineOptions() => playerStoredEngineOptions(
    hardwareDecoding: ref.read(playbackSettingsProvider).hardwareDecoding,
    tuning: ref.read(playerTuningProvider),
    proxy: ref.read(playerProxyProvider),
  );

  /// Sends the engine configuration to a handle once: the decoder choice and
  /// the player proxy (mpv property writes, so they take effect on the
  /// running engine). A replacement handle gets all of them again; a saved
  /// proxy must route the very first request, not wait for a settings change.
  Future<void> _applyEnginePreferences(PlayerHandle handle) async {
    if (identical(_preparedHandle, handle)) return;
    _preparedHandle = handle;
    try {
      await handle.applyEngineOptions(_storedEngineOptions());
    } on Object {
      // A preference the engine refused is not a playback failure.
    }
  }

  /// Applies a changed tuning/proxy choice to the running engine. A video
  /// or audio output change needs a new render context, so the engine is
  /// rebuilt after the options are recorded; everything else applies live.
  Future<void> _applyTuning(PlayerHandle handle, PlayerTuning? previous, PlayerTuning next) async {
    try {
      final settings = ref.read(playbackSettingsProvider);
      final options = playerTuningOptions(
        tuning: next,
        hardwareDecoding: settings.hardwareDecoding,
        proxy: ref.read(playerProxyProvider),
      );
      if (previous != null) options.addAll(playerPresetTransitionOptions(previous, next));
      await handle.applyEngineOptions(options);
      if (previous != null && playerOutputChanged(previous, next)) {
        await handle.rebuildEngine(reason: 'video output settings changed');
      }
    } on Object {
      // A preference the engine refused is not a playback failure.
    }
  }

  /// The flying danmaku pipeline the page draws with (the flame widget's
  /// controller); null until the room's danmaku session opened.
  BarrageController? get barrage => _pipeline?.barrage;

  /// Whether the room is followed right now.
  bool get followed {
    final room = state.room;
    if (room == null) return false;
    final key = room.ref.identityKey;
    return ref.read(followsProvider).rooms.any((followed) => followed.ref.identityKey == key);
  }

  /// Whether the room's chat accepts a posted message (the session's own
  /// capability; most platforms listen only).
  bool get canSendDanmaku => _danmaku is LiveDanmakuSending;

  /// Posts [text] to the room's chat. The message flies locally the moment
  /// the platform accepts it (the session's own echo, when it sends one,
  /// is caught by the pipeline's duplicate gate).
  Future<String?> sendDanmaku(String text) async {
    final session = _danmaku;
    final word = text.trim();
    if (session == null || session is! LiveDanmakuSending || word.isEmpty) {
      return 'cannot send';
    }
    final sending = session as LiveDanmakuSending;
    // Read before the await: a room that closes mid-send must not lose the
    // echo it already accepted, nor read a disposed ref after it.
    final identity = _localSender();
    try {
      await sending.send(word);
      // The local echo: what the viewer sent flies at once, in the theme's
      // own voice rather than waiting for a platform round trip. It carries
      // the signed-in name, so the viewer's own line reads like any other
      // rather than as an anonymous one.
      _pipeline?.accept(
        LiveMessage.normalized(
          messageId: 'local-${DateTime.now().microsecondsSinceEpoch}',
          text: word,
          sender: identity,
          isLocal: true,
        ),
      );
      return null;
    } on Object catch (error) {
      return error.toString();
    }
  }

  /// The viewer's own identity for the local echo: the signed-in account of
  /// this room's platform; null when the room's chat runs anonymously, where
  /// the platform says nothing about the viewer either.
  MessageSender? _localSender() {
    final siteId = state.room?.ref.platform;
    if (siteId == null) return null;
    final credential = ref.read(accountsProvider).credentials[siteId];
    final name = credential?.nickname?.trim() ?? '';
    if (name.isEmpty) return null;
    return MessageSender.normalized(userId: credential?.userId ?? '', userName: name);
  }

  /// Disconnects the room's site danmaku while the app is in the background;
  /// the session stays reusable and [resumeDanmakuConnection] reconnects it.
  Future<void> pauseDanmakuConnection() async {
    final session = _danmaku;
    if (session == null) return;
    try {
      await session.disconnect();
    } on Object {
      // A connection that is already gone needs no pause.
    }
  }

  /// Reconnects the session paused by [pauseDanmakuConnection].
  Future<void> resumeDanmakuConnection() async {
    final session = _danmaku;
    if (session == null) return;
    try {
      await session.connect();
    } on Object {
      // The next room open retries; background return is not a failure path.
    }
  }

  /// The room's recording identity (`platform:roomId`), or null before the
  /// room opens.
  String? get recordingId => state.room?.ref.identityKey;

  /// Whether the recorder engine is capturing this room right now.
  bool get isRecording {
    final id = recordingId;
    return id != null && ref.read(recorderEngineProvider).isRecording(id);
  }

  /// Starts or stops the room's recording; answers the engine's reason when
  /// the action failed, null on success.
  Future<String?> toggleRecording() async {
    final id = recordingId;
    final room = state.room;
    if (id == null || room == null) return 'no room';
    final engine = ref.read(recorderEngineProvider);
    if (engine.isRecording(id)) return await engine.stop(id);
    final line = state.lines.isEmpty ? null : state.lines[state.lineIndex.clamp(0, state.lines.length - 1)];
    if (line == null) return 'the room has no line to record';
    final capability = _playbackCapabilityOf(room);
    // The reference's default recording quality: ask for that stream when
    // the platform offers it, otherwise keep the line the viewer is on.
    final wanted = ref.read(recordingSettingsProvider).defaultQuality;
    LivePlayQuality? recordQuality;
    var recordLine = line;
    if (wanted.isNotEmpty && wanted != state.quality?.label) {
      for (final quality in state.qualities) {
        if (quality.label == wanted) {
          recordQuality = quality;
          break;
        }
      }
      if (recordQuality != null && capability != null) {
        final answer = await capability.getLines(room: room, quality: recordQuality);
        answer.match((_) {}, (lines) {
          if (lines.isNotEmpty) recordLine = lines.first;
        });
      }
    }
    final task = RecordingTask(
      id: id,
      platform: room.ref.platform,
      roomId: room.ref.roomId,
      roomTitle: room.content.title,
      quality: recordQuality?.label ?? state.quality?.label ?? '',
      state: RecordingTaskState.stopped,
      startedAt: DateTime.now().toUtc(),
    );
    final danmaku = ref.read(sitesProvider).getById(room.ref.platform)?.capability<LiveDanmakuProvider>();
    // The engine re-mints the room's address itself when the take drops, so the
    // recording does not depend on this page still holding the room.
    return await engine.start(task, recordLine, room: room, danmaku: danmaku);
  }

  /// Follows or unfollows the room.
  Future<void> toggleFollow() async {
    final room = state.room;
    if (room == null) return;
    final key = room.ref.identityKey;
    if (followed) {
      await ref.read(followsProvider.notifier).remove(key);
    } else {
      await ref.read(followsProvider.notifier).add(room);
    }
    // The follow state lives in another controller; wake a rebuild.
    state = _with();
  }

  /// The quality a room opens on: the viewer's preferred tier at an exact
  /// label, or the nearest tier by position when the site spells them
  /// differently (the reference's ratio).
  LivePlayQuality? _pickQuality(List<LivePlayQuality> qualities) {
    if (qualities.isEmpty) return null;
    final settings = ref.read(playbackSettingsProvider);
    final cellular = ref.read(networkTypeProvider.notifier).usesCellular;
    final index = preferredQualityIndex(
      qualities.map((quality) => quality.label),
      cellular ? settings.preferredQualityCellular : settings.preferredQuality,
    );
    return qualities[index];
  }

  /// The lines to play, with the tier the platform says it served when it
  /// says so.
  ///
  /// A site that can confirm its answer is asked for the plan rather than the
  /// bare line list, because the ask and the answer differ: an anonymous
  /// request is quietly downgraded on several platforms, and a room naming
  /// "1080P" over a 720P picture is a lie the viewer can only catch by
  /// squinting. A plan that cannot be read falls back to the plain line read —
  /// what the room did before a platform could confirm anything — so the
  /// confirmation never costs the stream its only route to a URL.
  Future<({List<LivePlayLine> lines, LivePlayQuality? served, LiveSiteError? error})> _resolveLines(
    LivePlaybackProvider capability,
    LiveRoom room,
  ) async {
    final asked = _wantedQuality;
    if (asked != null) {
      if (capability case final LivePlaybackPlanResolver resolver) {
        final plan = await resolver.resolvePlan(room: room, quality: asked);
        final read = plan.match<({List<LivePlayLine> lines, LivePlayQuality? served})?>(
          (_) => null,
          (value) => (
            lines: value.lines.toList(growable: false),
            served: resolveServedPlayQuality(plan: value, qualities: state.qualities, requested: asked),
          ),
        );
        if (read != null) return (lines: read.lines, served: read.served, error: null);
      }
    }
    final plain = await capability.getLines(room: room, quality: asked);
    return await plain.match(
      (error) => (lines: const <LivePlayLine>[], served: null, error: error),
      (lines) => (lines: lines, served: null, error: null),
    );
  }

  /// Names the tier that is actually playing.
  ///
  /// A served tier the list already holds is simply selected; one the list
  /// never offered takes the asked entry's place, so the picker keeps one
  /// entry per ask instead of growing a tier the viewer cannot ask for again.
  void _showServedQuality(LivePlayQuality served) {
    final asked = _wantedQuality;
    if (asked == null) return;
    final at = state.qualities.indexWhere((quality) => isSamePlayTier(quality, asked));
    if (at < 0) return;
    final current = state.qualities[at];
    if (isSamePlayTier(current, served)) return;
    final qualities = [...state.qualities]..[at] = served;
    _wantedQuality = served;
    state = _with(qualities: List<LivePlayQuality>.unmodifiable(qualities), quality: served);
  }

  /// The room's controller: the parked one when the engine still matches,
  /// otherwise a new session. Its recovery callbacks follow whichever room
  /// is playing, because a parked session is reused by another room.
  LivePlaybackController _openSession(LivePlaybackProvider capability, LiveRoom room) {
    final backendId = ref.read(playerKernelBackendProvider).id;
    final session =
        _standby?.take(backendId: backendId) ??
        RoomPlaybackSession(kernel: ref.read(playerKernelProvider), backendId: backendId);
    _session = session
      ..lineResolver = () => capability
          .getLines(room: room, quality: _wantedQuality)
          .then((answer) => answer.fold((_) => const <LivePlayLine>[], (fresh) => fresh));
    return session.playback;
  }

  /// Stops a leaving room's playback and, unless the viewer asked for a hard
  /// stop, leaves the stopped session for the next room.
  Future<void> _park(RoomPlaybackSession session) async {
    try {
      await session.playback.close();
    } on Object {
      await session.dispose();
      return;
    }
    final standby = _standby;
    if (standby == null) {
      await session.dispose();
      return;
    }
    standby.keep(session);
  }

  Future<void> _startPlayback(
    LivePlaybackProvider capability,
    LiveRoom room, {
    bool keepPlayingWhenUnchanged = false,
  }) async {
    final epoch = _openEpoch;
    final resolved = await _resolveLines(capability, room);
    if (resolved.error case final error?) {
      if (epoch == _openEpoch) {
        state = _with(error: error.message);
        _reportOpenTiming(failed: true);
      }
      return;
    }
    if (epoch != _openEpoch) return;
    final lines = resolved.lines;
    if (lines.isEmpty) {
      state = _with(lines: const [], error: 'the room has nothing to play');
      _reportOpenTiming(failed: true);
      return;
    }
    // The platform's own word about what it served outranks the tier the room
    // asked for.
    if (resolved.served case final served?) _showServedQuality(served);
    // A tier the platform cannot serve comes back as the media already
    // loaded: Steam lists one quality per variant of its master and answers
    // every one with the master itself, because its variants carry no audio
    // of their own. Re-opening that would cost the viewer a re-buffer for a
    // label, so the ask stops here. Only a quality change may say this: a
    // lease rebuild asks for a fresh address and has to reach the engine
    // even when the platform answers with the old one.
    if (keepPlayingWhenUnchanged && state.playback.playing && isSamePlayPlan(state.lines, lines)) return;
    _openTiming?.markLines();
    state = _with(lines: lines);
    final playback = _playback ??= _openSession(capability, room);
    _states ??= playback.onStateChanged.listen((playback_) {
      state = _with(playback: playback_);
      // The engine holding an opened input - the split between the CDN's time
      // and the decoder's. `ready` alone is not it: the adapter is ready once
      // it is initialised, before any media; `hasSource` is set when the open
      // returns. See RoomOpenTiming.markOpened.
      if (playback_.ready && playback_.hasSource) _openTiming?.markOpened();
      // The entry's line is written the first time the room says it is
      // playing, which is the number the viewer waits for.
      if (playback_.playing && (_openTiming?.markPlaying() ?? false)) _reportOpenTiming();
    });
    _failures ??= playback.onError.listen((failure) {
      state = _with(error: failure.message ?? failure.code.name);
      _reportOpenTiming(failed: true);
    });
    _handles ??= playback.onHandleChanged.listen((handle) {
      _lastHandle = handle;
      state = _with(handle: handle, lineIndex: _playback?.sourceIndex ?? state.lineIndex);
      _watchVideoSize(handle);
      _watchFirstFrame(handle);
      // The player's pause and seek carry into the flying layer; the
      // viewer's current audio follows every engine, the decoder choice
      // goes to the first one.
      _pipeline?.bind(handle);
      unawaited(_applyAudioPreferences(handle));
      unawaited(_applyEnginePreferences(handle));
      // The line the engine actually took may not be the one asked for;
      // its lease is the one that has to be watched.
      _armLeaseRenewal();
    });
    // Marked before the wait: `play` returns once the engine has opened the
    // input, so asking and hearing about it are the two ends of the segment
    // `opened` then splits.
    _openTiming?.markRequested();
    await playback.play(
      LiveSourceRequest(
        sources: roomSourcesOf(
          lines,
          title: room.content.title,
          artist: room.anchor?.name,
          artUri: room.content.coverUrl,
        ),
        title: room.content.title,
        allowEngineFallback: true,
        engineOptions: _storedEngineOptions(),
      ),
      preferredBackend: ref.read(playerKernelBackendProvider).id,
    );
    _armLeaseRenewal();
  }

  /// Re-reads the plan when the platform said its address must be rebuilt.
  ///
  /// A handful of platforms hand out a stream URL with a deadline and say the
  /// connection has to be rebuilt rather than resumed — chzzk, Douyu, FC2 and
  /// PandaLive among them, each through its own lease. Until now that notice
  /// went unread: the room kept playing until the address actually died and the
  /// engine's recovery asked for a fresh plan, which is a stall the platform had
  /// already announced. Re-opening at the lease's own moment turns that stall
  /// into a seam no one sees.
  ///
  /// Nothing else is armed, and that is deliberate. A stream that can resume —
  /// an FLV whose signature expires while the socket stays up — is left alone,
  /// because re-opening it on a timer manufactures exactly the gap this change
  /// exists to close.
  void _armLeaseRenewal() {
    _leaseRenewal?.cancel();
    _leaseRenewal = null;
    final room = state.room;
    final capability = _playbackCapabilityOf(room);
    if (room == null || capability == null) return;
    final lines = state.lines;
    if (lines.isEmpty) return;
    final index = state.lineIndex.clamp(0, lines.length - 1);
    final lease = lines[index].lease;
    if (lease == null || !lease.requiresReconnect) return;
    final epoch = _openEpoch;
    final wait = lease.refreshAt.difference(DateTime.now());
    // A lease already past — a late answer, a clock that moved — is re-read on
    // the next beat rather than looping here.
    final delay = wait < const Duration(seconds: 5) ? const Duration(seconds: 5) : wait;
    _leaseRenewal = Timer(delay, () {
      if (!ref.mounted || epoch != _openEpoch) return;
      unawaited(_startPlayback(capability, room));
    });
  }

  /// Feeds the stream's own shape to the presentation drivers.
  ///
  /// Both drivers read it as their window shape: Android's system PiP refuses
  /// to open without a video size at all, and the desktop compact window
  /// would fall back to a fixed landscape box, so a portrait stream would sit
  /// letterboxed inside the wrong rectangle and its remembered placement
  /// would be read from the landscape slot.
  void _watchVideoSize(PlayerHandle handle) {
    unawaited(_geometry?.cancel() ?? Future<void>.value());
    // The controller's state stream replays its current value to a new
    // listener, so a stream that already reported its size is fed at once.
    _geometry = handle.geometryController.state.listen((state) {
      final size = state.geometry.videoSize;
      if (size.width <= 0 || size.height <= 0) return;
      ref.read(fullscreenDriverProvider).onVideoSize(size.width, size.height);
      ref.read(pipDriverProvider).onVideoSize(size.width, size.height);
    });
  }

  /// The entry's first frame, from the only event that means it: the backend
  /// reporting a decoded video frame.
  ///
  /// The picture's geometry is not that. `videoSizeChanged` says the stream has
  /// a size, which the demuxer learns while it is still probing — marking the
  /// frame there hands the decoder's seconds to the network column and hides
  /// the very split this measurement exists to make. A backend that cannot
  /// report frames leaves the field as `-` rather than guessing.
  void _watchFirstFrame(PlayerHandle handle) {
    unawaited(_frames?.cancel() ?? Future<void>.value());
    _frames = handle.adapterEvents.listen((event) {
      if (event case PlayerAdapterVideoFrameProgress()) _openTiming?.markFirstFrame();
    });
  }

  Future<void> _openDanmaku(LiveDanmakuProvider provider, LiveRoom room) async {
    final epoch = _danmakuEpoch;
    _danmakuOpeningEpoch = epoch;
    _setChat(RoomChatStatus.connecting);
    try {
      final sessionAnswer = await provider.createSession(room: room);
      await sessionAnswer.match((error) async {
        // A chat connection that will not open is not a room that will not
        // open: the picture stays on screen and only a hint says what is
        // missing (an error field would replace it).
        if (!_danmakuCurrent(epoch, room)) return;
        // The hint still fires (it is the room's own voice about what is
        // missing), and the standing outlives it: the column keeps saying so
        // with a way to try again after the hint has gone.
        _setChat(RoomChatStatus.failed, error: error.message);
        // A refused login names its own answer; the platform's diagnostic
        // sentence only helps a viewer who can read a raw log line.
        ref
            .read(roomHintProvider.notifier)
            .show(
              error.cookieSuspect
                  ? l10n.t.room.chatCookieExpired
                  : l10n.t.room.danmakuConnectFailed(reason: error.message),
            );
        _armChatRetry(error, provider, room);
      }, (session) => _installDanmaku(session, room, epoch: epoch));
    } finally {
      // Only this open's own marker: a room switch already put its open there.
      if (_danmakuOpeningEpoch == epoch) _danmakuOpeningEpoch = null;
    }
  }

  /// Opens a chat the platform refused *for now* again by itself.
  ///
  /// A blip on the way to the danmaku credentials used to leave the column on
  /// its failure state until the viewer noticed the 重试 button — for a socket
  /// that failed for two seconds, that is a room with no chat for the rest of
  /// the visit. The platform's own classification decides: a transient answer
  /// (a transport failure, a throttle) is worth another attempt after the wait
  /// it asked for, and anything else — no such room, no such capability, a body
  /// that broke the spec — is not, because retrying those only spends the quota
  /// the next real request needs.
  ///
  /// Bounded, so a platform that says "transient" forever does not get an
  /// unlimited number of tries; past the bound the button is the only way back,
  /// which is where a viewer who has been waiting expects to find it.
  void _armChatRetry(LiveSiteError error, LiveDanmakuProvider provider, LiveRoom room) {
    if (!error.isTransient || _chatAttempts >= _kChatTransientRetries) return;
    _chatAttempts++;
    // A throttle without a named wait is given more room than a socket that
    // blinked: the first says the site wants quiet, the second says nothing.
    final wait =
        error.retryAfter ??
        (error is LiveSiteRateLimitError ? const Duration(seconds: 15) : Duration(seconds: 2 * _chatAttempts));
    final epoch = _danmakuEpoch;
    _chatRetry?.cancel();
    _chatRetry = Timer(wait, () {
      // A newer open (a login change, another room) owns the chat now.
      if (!ref.mounted || epoch != _danmakuEpoch) return;
      if (state.room?.ref != room.ref) return;
      unawaited(_openDanmaku(provider, room));
    });
  }

  /// The viewer's login for [siteId] changed while this room is showing: the
  /// room re-reads its danmaku credentials over the new login and connects
  /// again, so the names come as the account sees them. Only the room's own
  /// platform answers, and only while its chat is open or being opened — an
  /// offline room, a closed page or another platform's change leave it alone.
  Future<void> _onLoginChanged(String siteId) async {
    if (!ref.mounted) return;
    final room = state.room;
    if (room == null || room.ref.platform != siteId) return;
    if (_pipeline == null && _danmakuOpeningEpoch == null) return;
    final provider = _danmakuCapabilityOf(siteId);
    if (provider == null) return;
    await _reopenDanmaku(room, provider);
  }

  /// The room's danmaku over the login the site now carries: a fresh session
  /// is read (the platform hands out its danmaku credentials to the request,
  /// which is what a new login changes) and connected before the running one
  /// leaves, so a credential the platform refuses costs the viewer nothing —
  /// the old chat stays up rather than a gap where a reconnect failed.
  Future<void> _reopenDanmaku(LiveRoom room, LiveDanmakuProvider provider) async {
    final epoch = ++_danmakuEpoch;
    final answer = await provider.createSession(room: room);
    final session = answer.match<LiveDanmakuSession?>((error) {
      // The old chat is still up at this point, so the room does not lose
      // its voice; but the new credentials were refused, and the column must
      // say that rather than go quiet on a stale connection.
      if (_danmakuCurrent(epoch, room)) _setChat(RoomChatStatus.failed, error: error.message);
      return null;
    }, (created) => created);
    if (session == null) return;
    if (!_danmakuCurrent(epoch, room)) {
      unawaited(session.dispose());
      return;
    }
    await _installDanmaku(session, room, epoch: epoch);
  }

  /// Installs [session] as the room's danmaku: retire whatever session and
  /// pipeline the room held, and start the pipeline beside the new one. The
  /// platforms' `createSession` already connected it — connecting again would
  /// tear the socket down and re-handshake, and a session that rotates its
  /// edges (douyin, bilibili) would land on another host and drop what the
  /// first connection already received. The player is not touched — only the
  /// pipeline's own binding to the handle is remade, so pause and seek keep
  /// carrying into the flying layer.
  /// Every await checks [_danmakuCurrent], so a room that closed or moved on
  /// mid-flight installs nothing.
  Future<void> _installDanmaku(LiveDanmakuSession session, LiveRoom room, {required int epoch}) async {
    if (!_danmakuCurrent(epoch, room)) {
      unawaited(session.dispose());
      return;
    }
    await _closeDanmaku();
    if (!_danmakuCurrent(epoch, room)) {
      unawaited(session.dispose());
      return;
    }
    _danmaku = session;
    // The chat's handshake is over: it runs beside the picture, but its wait
    // is the number a viewer most often reads as "the room is slow".
    _openTiming?.markChat();
    // The name and cookie hints are per connection: a masked run before a
    // login change must not silence the one after it.
    _maskedChats = 0;
    _namedChats = 0;
    _nameHintShown = false;
    // The next connection either shows full names — in which case the notice
    // was about a login that has since been fixed — or re-raises it once the
    // masked run is long enough. Either way an old one must not stay up.
    if (ref.mounted) ref.read(roomChatNoticeProvider.notifier).clear();
    // A chat that got in spends its retries again from zero.
    _chatAttempts = 0;
    // The pipeline (the flying layer over the site session) starts with
    // the session: the bridge settles the controller, every site message
    // runs the pipeline's shield policy and filters, and what passes
    // flies and lands in the chat list at once.
    final pipeline = RoomDanmakuPipeline(
      ref.read(roomChatProvider.notifier).add,
      showChatGifts: () => ref.read(chatShowGiftsProvider),
      chatGiftsAboveTier: () => ref.read(chatGiftsAboveTierProvider),
      showFlyGifts: () => ref.read(danmakuShowGiftsProvider),
      streamer: () => room.anchor?.name ?? '',
      shield: ref.read(shieldRulesProvider),
      filter: ref.read(danmakuFilterProvider),
      repeat: ref.read(danmakuRepeatProvider),
      showFixedTop: () => ref.read(danmakuFixedTopProvider),
      showFixedBottom: () => ref.read(danmakuFixedBottomProvider),
      onShielded: _countShielded,
    );
    _pipeline = pipeline;
    await pipeline.start(platform: room.ref.platform, roomId: room.ref.roomId);
    if (!_danmakuCurrent(epoch, room)) {
      // This install lost: what it already opened (pipeline and session)
      // leaves together, the room's own teardown of them.
      await _closeDanmaku();
      return;
    }
    _chat = session.events.listen(_onSiteMessage);
    _setChat(RoomChatStatus.connected);
    final handle = state.handle;
    if (handle != null) pipeline.bind(handle);
    // The page reads the pipeline's barrage engine through the notifier;
    // this rebuild is what picks it up the moment it exists.
    state = _with();
  }

  /// Publishes the chat's standing to the column. A refused chat leaves the
  /// picture alone, so this is the only place that knows it happened.
  void _setChat(RoomChatStatus status, {String? error}) {
    if (!ref.mounted) return;
    state = _with(chat: (status: status, error: error));
  }

  /// Tries the chat's handshake again over the room's own platform: a network
  /// that was down when the room opened, or credentials the platform just
  /// started to accept. The picture is not touched.
  Future<void> retryChat() async {
    final room = state.room;
    if (room == null) return;
    final provider = _danmakuCapabilityOf(room.ref.platform);
    if (provider == null) {
      _setChat(RoomChatStatus.unsupported);
      return;
    }
    await _openDanmaku(provider, room);
  }

  /// Whether the danmaku open of [epoch] still owns the page: the provider is
  /// alive (a room being disposed is not reconnected), no newer open started,
  /// and [room] is still the room being watched.
  bool _danmakuCurrent(int epoch, LiveRoom room) =>
      ref.mounted && epoch == _danmakuEpoch && state.room?.ref == room.ref;

  /// Retires the room's danmaku session and pipeline only: the playback, its
  /// handle and the recorder keep running exactly as they were.
  Future<void> _closeDanmaku() async {
    unawaited(_chat?.cancel() ?? Future<void>.value());
    _chat = null;
    final pipeline = _pipeline;
    final session = _danmaku;
    _pipeline = null;
    _danmaku = null;
    if (pipeline != null) await pipeline.dispose();
    if (session == null) return;
    try {
      await session.disconnect();
    } on Object {
      // A connection that is already gone needs no goodbye.
    }
    await session.dispose();
  }

  /// The room's platform's danmaku capability, or null when it has none.
  LiveDanmakuProvider? _danmakuCapabilityOf(String siteId) =>
      ref.read(sitesProvider).getById(siteId)?.capability<LiveDanmakuProvider>();

  /// Whether two snapshots of a platform account are the same login: the
  /// credential object has no value equality of its own, and the pane
  /// republishes its whole map on every store event, so the room compares
  /// what a danmaku connection actually depends on.
  bool _sameCredential(LiveCredential? before, LiveCredential? after) {
    if (identical(before, after)) return true;
    if (before == null || after == null) return false;
    if (before.siteId != after.siteId ||
        before.userId != after.userId ||
        before.nickname != after.nickname ||
        before.avatar != after.avatar ||
        before.expiry != after.expiry ||
        before.cookies.length != after.cookies.length) {
      return false;
    }
    for (final entry in before.cookies.entries) {
      if (after.cookies[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// One site message: the content blocks (纯表情 / 超长, the reference's
  /// 屏蔽页), then the super chat board and the pipeline. The viewer's
  /// shield (keywords, users) runs inside the pipeline as media_core's own
  /// policy slot, ahead of the duplicate and similarity filters — so a
  /// shielded viewer's paid super chat still reaches the board.
  void _onSiteMessage(LiveMessage message) {
    if (message.type == LiveMessageType.chat) _trackBilibiliNames(message);
    // A retraction says nothing, so it leaves before the pipeline: the shape
    // check would drop an empty line, the text filters have nothing to judge,
    // and what it names is already on screen. It is an instruction about the
    // earlier messages, and both surfaces act on it.
    if (message.type == LiveMessageType.retraction) {
      if (message.payload case final LiveRetraction target) _retract(target);
      return;
    }
    if (_shapeBlocked(message)) {
      _countShielded();
      return;
    }
    _collectSuperChat(message);
    _pipeline?.accept(message);
  }

  /// Applies a platform retraction: the list drops the lines it names, and the
  /// flying layer drops them too, queued or mid-flight.
  void _retract(LiveRetraction target) {
    if (!ref.mounted) return;
    ref.read(roomChatProvider.notifier).retract(target);
    _pipeline?.retract(target);
  }

  /// The notice a refused cookie earns: the standing bar over the column it
  /// concerns, with the way to renew it. The site reports each cookie once, so
  /// this is not a toast to count down — and the chat keeps running,
  /// anonymously, which is why the room does not fail.
  void _onCookieRefused(String siteId) {
    if (!ref.mounted) return;
    ref.read(roomChatNoticeProvider.notifier).show(siteId, l10n.t.room.cookieRefused);
  }

  /// B06: what Bilibili's names say about this connection. A guest's socket
  /// gets every nickname masked (`观***`), and a stored login that the platform
  /// no longer accepts looks exactly the same from here: [kRoomMaskedChatsForExpiredLogin]
  /// masked names with no full one among them. One hint per connection; the
  /// package's own mask test decides, nothing is guessed.
  void _trackBilibiliNames(LiveMessage message) {
    if (_nameHintShown || state.room?.ref.platform != SiteIds.bilibili) return;
    final name = message.sender?.userName.trim() ?? '';
    if (name.isEmpty) return;
    if (!BilibiliDanmakuProtocol.isMaskedName(name)) {
      // A full name answers the question: this connection sees names, so
      // there is nothing to tell.
      _namedChats++;
      return;
    }
    _maskedChats++;
    if (_maskedChats < kRoomMaskedChatsForExpiredLogin || _namedChats > 0) return;
    _nameHintShown = true;
    if (!ref.mounted) return;
    final signedIn = ref.read(accountsProvider).credentials[SiteIds.bilibili] != null;
    // Both readings end in the same place: a sign-in, or a cookie worth
    // pasting. The words differ because what the viewer has to do differs.
    final signedInText = l10n.t.room.bilibiliLoginExpired;
    final guestText = l10n.t.room.bilibiliGuestNames;
    ref.read(roomChatNoticeProvider.notifier).show(SiteIds.bilibili, signedIn ? signedInText : guestText);
  }

  /// Sends the paid messages to the board: the platform's own super chats
  /// and, while "上舰和开会员进醒目留言" is on, a card for a subscription
  /// gift, a subscription notice or a membership join.
  void _collectSuperChat(LiveMessage message) {
    final board = ref.read(roomSuperChatsProvider.notifier);
    if (message.type == LiveMessageType.superChat && message.payload is LiveSuperChatMessage) {
      board.add(message.payload! as LiveSuperChatMessage);
      return;
    }
    if (!ref.read(superChatIncludesMembershipProvider)) return;
    final card = membershipCard(message, platform: state.room?.ref.platform ?? '', now: DateTime.now());
    if (card != null) board.add(card);
  }

  /// Re-reads the platform's super chat board on the viewer's request (the
  /// page's retry); the cards that arrived live stay while it reads.
  Future<void> reloadSuperChats() async {
    final room = state.room;
    if (room != null) await _loadSuperChats(room);
  }

  Future<void> _loadSuperChats(LiveRoom room) async {
    final capability = ref.read(sitesProvider).getById(room.ref.platform)?.capability<LiveSuperChatFeed>();
    if (capability == null) return;
    final board = ref.read(roomSuperChatsProvider.notifier)..beginLoad();
    final answer = await capability.getSuperChatMessages(room: room);
    if (!ref.mounted || state.room?.ref != room.ref) return;
    answer.match((error) => board.fail(error.message), board.addAll);
  }

  /// Whether the reference's content blocks drop [message]: emoticon-only
  /// and over-long, each behind its own switch, read per message so a
  /// change on the shield page bites the very next line. The viewer's own
  /// echo is never blocked.
  bool _shapeBlocked(LiveMessage message) => danmakuShapeBlockedByRules(message, ref.read(danmakuFilterProvider));

  /// One more line the viewer's shield hid, for 「本场已屏蔽 N 条」.
  void _countShielded() {
    if (!ref.mounted) return;
    ref.read(roomShieldCountProvider.notifier).add();
  }

  Future<void> _recordHistory(LiveRoom room) async {
    await ref.read(historyProvider.notifier).record(room);
  }

  LivePlaybackProvider? _playbackCapabilityOf(LiveRoom? room) {
    if (room == null) return null;
    return ref.read(sitesProvider).getById(room.ref.platform)?.capability<LivePlaybackProvider>();
  }

  /// The state with any field replaced; the record's honest copy.
  RoomState _with({
    LiveRoom? room,
    List<LivePlayQuality>? qualities,
    List<LivePlayLine>? lines,
    int? lineIndex,
    LivePlayQuality? quality,
    PlayerCoreState? playback,
    PlayerHandle? handle,
    bool? audioOnly,
    String? error,
    RoomChat? chat,
  }) => (
    room: room ?? state.room,
    qualities: qualities ?? state.qualities,
    lines: lines ?? state.lines,
    lineIndex: lineIndex ?? state.lineIndex,
    quality: quality ?? state.quality,
    playback: playback ?? state.playback,
    handle: handle ?? state.handle,
    audioOnly: audioOnly ?? state.audioOnly,
    error: error,
    chat: chat ?? state.chat,
  );

  void _teardown() {
    // The stream goes quiet before anything else: the release below is queued
    // behind whatever the playback is doing (an open still dialling a dead
    // line takes its whole budget), and the last room must not be heard over
    // the next page while that queue drains.
    _silence(_lastHandle);
    // Nothing a closing room has in flight may install itself afterwards.
    _openEpoch++;
    _danmakuEpoch++;
    _danmakuOpeningEpoch = null;
    // An entry the viewer left before its picture arrived used to report
    // nothing, on the reasoning that its numbers describe a wait nobody sat
    // through. Past [kSlowEntryBudget] that reasoning hides exactly the case
    // the task is about: a room so slow the viewer gave up, with nothing
    // failed and no first frame to blame. Below it, a tap through a list is
    // browsing, and it stays out of the log.
    final timing = _openTiming;
    if (timing != null && timing.total >= kSlowEntryBudget) _reportOpenTiming(abandoned: true);
    _openTiming = null;
    unawaited(_states?.cancel() ?? Future<void>.value());
    unawaited(_handles?.cancel() ?? Future<void>.value());
    unawaited(_failures?.cancel() ?? Future<void>.value());
    unawaited(_chat?.cancel() ?? Future<void>.value());
    unawaited(_geometry?.cancel() ?? Future<void>.value());
    unawaited(_frames?.cancel() ?? Future<void>.value());
    _frames = null;
    unawaited(_cookieRefusals?.cancel() ?? Future<void>.value());
    _cookieRefusals = null;
    _states = null;
    _handles = null;
    _failures = null;
    _chat = null;
    _geometry = null;
    _detailRefresh?.cancel();
    _detailRefresh = null;
    if (ref.mounted) ref.read(roomChatNoticeProvider.notifier).clear();
    _leaseRenewal?.cancel();
    _leaseRenewal = null;
    _chatRetry?.cancel();
    _chatRetry = null;
    _chatAttempts = 0;
    final session = _session;
    _session = null;
    _playback = null;
    if (session != null) {
      if (_forceDestroy) {
        unawaited(session.dispose());
      } else {
        unawaited(_park(session));
      }
    }
    _preparedHandle = null;
    _lastHandle = null;
    unawaited(_closeDanmaku());
  }

  /// Silences a handle the moment the room lets it go: mute first — it takes
  /// effect at once — then pause. Both are fire-and-forget; a handle already
  /// being released is silent by definition, so a refusal needs no answer.
  static void _silence(PlayerHandle? handle) {
    if (handle == null) return;
    unawaited(() async {
      try {
        await handle.setMute(muted: true);
      } on Object {
        // Already gone.
      }
      try {
        await handle.pause();
      } on Object {
        // Already gone.
      }
    }());
  }
}

/// The open room's state (one room at a time; the route owns the page).
final roomProvider = NotifierProvider<RoomController, RoomState>(RoomController.new);

/// The open room's flying danmaku engine (the flame widget's controller);
/// null until the room's danmaku pipeline exists.
final barrageProvider = Provider<BarrageController?>((ref) {
  ref.watch(roomProvider);
  return ref.read(roomProvider.notifier).barrage;
});
