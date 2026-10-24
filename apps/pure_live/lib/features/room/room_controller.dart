import 'dart:async' show StreamSubscription, unawaited;

import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/providers/player_providers.dart'
    show createRoomPlayback, playerKernelProvider, roomSourcesOf;
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/history/history_repository.dart' show historyProvider;
import 'package:pure_live/features/shield/shield_repository.dart' show ShieldRules, shieldRulesProvider;

/// How many chat lines the page keeps; older leave first.
const int kRoomChatLimit = 200;

/// What the room page holds: the room as it stands, the qualities and the
/// lines behind the chosen one, the playback's state and handle, and the
/// danmaku the room's chat has delivered.
typedef RoomState = ({
  LiveRoom? room,
  List<LivePlayQuality> qualities,
  List<LivePlayLine> lines,
  LivePlayQuality? quality,
  PlayerCoreState playback,
  PlayerHandle? handle,
  String? error,
});

RoomState _initial() => (
  room: null,
  qualities: const [],
  lines: const [],
  quality: null,
  playback: PlayerCoreState.idle,
  handle: null,
  error: null,
);

/// The room's flying danmaku pipeline, one per open room: the site's
/// session events are accepted into the media_core danmaku controller
/// (whose gate and filters run first), and its sink fans every accepted
/// message into the flame engine (the flying layer) and the chat list at
/// once; the player binding carries pause and seek along.
final class RoomDanmakuPipeline {
  RoomDanmakuPipeline(this.onChat) {
    danmaku = DanmakuController(
      sink: DanmakuFanOutSink(primary: FlameBarrageSink(barrage), overlay: overlay),
    );
  }

  /// The flame engine the flying layer draws with.
  final BarrageController barrage = BarrageController();

  /// The chat list's mirror of the flying layer's source.
  final DanmakuOverlaySession overlay = DanmakuOverlaySession();

  /// The danmaku controller running the reference pipeline's filters.
  late final DanmakuController danmaku;

  /// Where the accepted chat lands (the room state subscribes).
  final void Function(LiveMessage message) onChat;

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

  /// Feeds one accepted site message through the pipeline.
  void accept(LiveMessage message) {
    danmaku.acceptExternal(
      DanmakuMessage(
        type: DanmakuMessageType.chat,
        userName: message.sender?.userName ?? '',
        text: message.text,
        color: message.color == null
            ? DanmakuColor.white
            : DanmakuColor(message.color!.r, message.color!.g, message.color!.b),
        messageId: message.messageId,
      ),
    );
  }

  /// Carries playback pause/seek into the barrage engine.
  void bind(PlayerHandle handle) {
    unawaited(binding?.dispose() ?? Future<void>.value());
    binding = DanmakuPlayerBinding.forHandle(controller: barrage, handle: handle);
    binding!.attach();
  }

  Future<void> dispose() async {
    await danmaku.stop(clearRenderer: false);
    await binding?.dispose();
    barrage.detach();
  }
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

  /// Appends [message], keeping the newest [kRoomChatLimit].
  void add(LiveMessage message) {
    final next = [...state, message];
    state = next.length > kRoomChatLimit ? next.sublist(next.length - kRoomChatLimit) : next;
  }

  /// Clears the list (a new room opens).
  void clear() => state = const [];
}

/// The open room's chat lines.
final roomChatProvider = NotifierProvider<RoomChatController, List<LiveMessage>>(RoomChatController.new);

/// One open live room: its detail, its play plan, the playback over
/// media_core's live controller, and the danmaku session beside it.
///
/// One room plays at a time (the route pushes one page); reopening — the
/// same room or another — resets the state, tears the old playback and
/// danmaku session down, and starts over. The room's identity is not the
/// provider's identity: it is just the room being watched.
final class RoomController extends Notifier<RoomState> {
  LivePlaybackController? _playback;
  StreamSubscription<PlayerCoreState>? _states;
  StreamSubscription<PlayerHandle>? _handles;
  StreamSubscription<LiveMessage>? _chat;
  LiveDanmakuSession? _danmaku;
  RoomDanmakuPipeline? _pipeline;
  // Held for the room's lifetime; the cancel happens in teardown.
  // Held for the room's lifetime; the cancel happens in teardown.
  // ignore: unused_field, cancel_subscriptions, use_late_for_private_fields_and_variables
  StreamSubscription<LiveMessage>? _sessionChat;
  LivePlayQuality? _wantedQuality;

  @override
  RoomState build() {
    ref.onDispose(_teardown);
    return _initial();
  }

  /// Opens the room behind [platform] and [roomId]: detail first, then the
  /// qualities it offers; the first playable line begins playback and the
  /// danmaku session connects. A room that cannot open says why in the
  /// state error field — the page shows it, never a blank.
  Future<void> open({required String platform, required String roomId}) async {
    _teardown();
    state = _initial();
    ref.read(roomChatProvider.notifier).clear();
    final site = ref.read(sitesProvider).getById(platform);
    final roomProvider = site?.capability<LiveRoomProvider>();
    final playbackProvider = site?.capability<LivePlaybackProvider>();
    if (site == null || roomProvider == null || playbackProvider == null) {
      state = _with(error: 'the site has no room or playback capability');
      return;
    }
    final roomAnswer = await roomProvider.getRoom(roomId);
    roomAnswer.match((error) => state = _with(error: error.message), (room) async {
      state = _with(room: room);
      unawaited(_recordHistory(room));
      if (room.broadcast.isLiveNow) {
        final danmakuProvider = site.capability<LiveDanmakuProvider>();
        if (danmakuProvider != null) await _openDanmaku(danmakuProvider, room);
      }
      final qualitiesAnswer = await playbackProvider.getQualities(room: room);
      qualitiesAnswer.match((error) => state = _with(error: error.message), (qualities) async {
        _wantedQuality = qualities.isEmpty ? null : qualities.first;
        state = _with(qualities: qualities, quality: _wantedQuality);
        await _startPlayback(playbackProvider, room);
      });
    });
  }

  /// Switches the quality: the plan is re-read at the new quality and
  /// playback starts over from its first line.
  Future<void> selectQuality(LivePlayQuality quality) async {
    final room = state.room;
    final playbackProvider = _playbackCapabilityOf(room);
    if (room == null || playbackProvider == null) return;
    _wantedQuality = quality;
    state = _with(quality: quality);
    await _startPlayback(playbackProvider, room);
  }

  /// Moves playback to the line at [index] without re-reading the plan.
  Future<void> selectLine(int index) async {
    await _playback?.switchLine(index);
  }

  /// The recovery button: the live controller's retry.
  Future<void> retry() async {
    await _playback?.retry();
  }

  /// Pauses or resumes.
  Future<void> togglePlayPause() async {
    await _playback?.togglePlayPause();
  }

  /// The flying danmaku pipeline the page draws with (the flame widget's
  /// controller); null until the room's danmaku session opened.
  BarrageController? get barrage => _pipeline?.barrage;

  /// The pipeline's overlay session the chat list mirrors.
  DanmakuOverlaySession? get overlay => _pipeline?.overlay;

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
    try {
      await sending.send(word);
      // The local echo: what the viewer sent flies at once, in the theme's
      // own voice rather than waiting for a platform round trip.
      _pipeline?.accept(
        LiveMessage.normalized(
          messageId: 'local-${DateTime.now().microsecondsSinceEpoch}',
          text: word,
          isLocal: true,
        ),
      );
      return null;
    } on Object catch (error) {
      return error.toString();
    }
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

  Future<void> _startPlayback(LivePlaybackProvider capability, LiveRoom room) async {
    final linesAnswer = await capability.getLines(room: room, quality: _wantedQuality);
    linesAnswer.match((error) => state = _with(error: error.message), (lines) async {
      if (lines.isEmpty) {
        state = _with(lines: const [], error: 'the room has nothing to play');
        return;
      }
      state = _with(lines: lines);
      final playback =
          _playback ??
          createRoomPlayback(
            kernel: ref.read(playerKernelProvider),
            onLinesNeeded: () => capability
                .getLines(room: room, quality: _wantedQuality)
                .then((answer) => answer.fold((_) => const <LivePlayLine>[], (fresh) => fresh)),
          );
      _playback ??= playback;
      _states ??= playback.onStateChanged.listen((playback_) {
        state = _with(playback: playback_);
      });
      _handles ??= playback.onHandleChanged.listen((handle) {
        state = _with(handle: handle);
        // The player's pause and seek carry into the flying layer.
        _pipeline?.bind(handle);
      });
      await playback.play(
        LiveSourceRequest(sources: roomSourcesOf(lines), title: room.content.title, allowEngineFallback: true),
      );
    });
  }

  Future<void> _openDanmaku(LiveDanmakuProvider provider, LiveRoom room) async {
    final sessionAnswer = await provider.createSession(room: room);
    sessionAnswer.match((error) => state = _with(error: error.message), (session) async {
      _danmaku = session;
      await session.connect();
      // The pipeline (the flying layer over the site session) starts with
      // the session: the bridge settles the controller, every site message
      // runs the shield first, and what passes flies and lands in the chat
      // list at once.
      final pipeline = RoomDanmakuPipeline(ref.read(roomChatProvider.notifier).add);
      _pipeline = pipeline;
      await pipeline.start(platform: room.ref.platform, roomId: room.ref.roomId);
      _chat = session.events.listen(_onSiteMessage);
      // The page reads the pipeline's barrage engine through the notifier;
      // this rebuild is what picks it up the moment it exists.
      state = _with();
    });
  }

  /// One site message: the shield's word, then the pipeline's own filters.
  void _onSiteMessage(LiveMessage message) {
    if (_shielded(message)) return;
    _pipeline?.accept(message);
  }

  /// Whether the shield drops [message]: the settings surface's rules,
  /// read per message (a change there takes effect on the very next line).
  bool _shielded(LiveMessage message) {
    final rules = ref.read(shieldRulesProvider);
    return _shielded_(message, rules);
  }

  static bool _shielded_(LiveMessage message, ShieldRules rules) {
    if (!rules.enabled) return false;
    final sender = message.sender?.userName;
    if (sender != null && rules.users.contains(sender)) return true;
    for (final keyword in rules.keywords) {
      if (keyword.isNotEmpty && message.text.contains(keyword)) return true;
    }
    return false;
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
    LivePlayQuality? quality,
    PlayerCoreState? playback,
    PlayerHandle? handle,
    String? error,
  }) => (
    room: room ?? state.room,
    qualities: qualities ?? state.qualities,
    lines: lines ?? state.lines,
    quality: quality ?? state.quality,
    playback: playback ?? state.playback,
    handle: handle ?? state.handle,
    error: error,
  );

  void _teardown() {
    unawaited(_states?.cancel() ?? Future<void>.value());
    unawaited(_handles?.cancel() ?? Future<void>.value());
    unawaited(_chat?.cancel() ?? Future<void>.value());
    _states = null;
    _handles = null;
    _chat = null;
    unawaited(_playback?.dispose() ?? Future<void>.value());
    _playback = null;
    unawaited(_danmaku?.disconnect() ?? Future<void>.value());
    unawaited(_danmaku?.dispose() ?? Future<void>.value());
    _danmaku = null;
    unawaited(_pipeline?.dispose() ?? Future<void>.value());
    _pipeline = null;
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
