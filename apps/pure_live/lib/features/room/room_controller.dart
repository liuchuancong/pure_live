import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/providers/player_providers.dart'
    show createRoomPlayback, playerKernelProvider, roomSourcesOf;
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/history/history_repository.dart' show historyProvider;

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
  List<LiveMessage> chat,
  String? error,
});

RoomState _initial() => (
  room: null,
  qualities: const [],
  lines: const [],
  quality: null,
  playback: PlayerCoreState.idle,
  handle: null,
  chat: const [],
  error: null,
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
  StreamSubscription<PlayerCoreState>? _states;
  StreamSubscription<PlayerHandle>? _handles;
  StreamSubscription<LiveMessage>? _chat;
  LiveDanmakuSession? _danmaku;
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
    final site = ref.read(sitesProvider).getById(platform);
    final roomProvider = site?.capability<LiveRoomProvider>();
    final playbackProvider = site?.capability<LivePlaybackProvider>();
    if (site == null || roomProvider == null || playbackProvider == null) {
      state = _with(error: 'the site has no room or playback capability');
      return;
    }
    final roomAnswer = await roomProvider.getRoom(roomId);
    roomAnswer.match(
      (error) => state = _with(error: error.message),
      (room) async {
        state = _with(room: room);
        unawaited(_recordHistory(room));
        if (room.broadcast.isLiveNow) {
          final danmakuProvider = site.capability<LiveDanmakuProvider>();
          if (danmakuProvider != null) await _openDanmaku(danmakuProvider, room);
        }
        final qualitiesAnswer = await playbackProvider.getQualities(room: room);
        qualitiesAnswer.match(
          (error) => state = _with(error: error.message),
          (qualities) async {
            _wantedQuality = qualities.isEmpty ? null : qualities.first;
            state = _with(qualities: qualities, quality: _wantedQuality);
            await _startPlayback(playbackProvider, room);
          },
        );
      },
    );
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

  /// Whether the room is followed right now.
  bool get followed {
    final room = state.room;
    if (room == null) return false;
    final key = room.ref.identityKey;
    return ref.read(followsProvider).rooms.any((followed) => followed.ref.identityKey == key);
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
    linesAnswer.match(
      (error) => state = _with(error: error.message),
      (lines) async {
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
        });
        await playback.play(
          LiveSourceRequest(sources: roomSourcesOf(lines), title: room.content.title, allowEngineFallback: true),
        );
      },
    );
  }

  Future<void> _openDanmaku(LiveDanmakuProvider provider, LiveRoom room) async {
    final sessionAnswer = await provider.createSession(room: room);
    sessionAnswer.match(
      (error) => state = _with(error: error.message),
      (session) async {
        _danmaku = session;
        await session.connect();
        _chat = session.events.listen(_onMessage);
      },
    );
  }

  void _onMessage(LiveMessage message) {
    final chat = [...state.chat, message];
    state = _with(chat: chat.length > kRoomChatLimit ? chat.sublist(chat.length - kRoomChatLimit) : chat);
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
    List<LiveMessage>? chat,
    String? error,
  }) => (
    room: room ?? state.room,
    qualities: qualities ?? state.qualities,
    lines: lines ?? state.lines,
    quality: quality ?? state.quality,
    playback: playback ?? state.playback,
    handle: handle ?? state.handle,
    chat: chat ?? state.chat,
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
  }
}

/// The open room's state (one room at a time; the route owns the page).
final roomProvider = NotifierProvider<RoomController, RoomState>(RoomController.new);
