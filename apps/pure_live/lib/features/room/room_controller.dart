import 'dart:async' show StreamSubscription, unawaited;

import 'package:flame_barrage/flame_barrage.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_sites/live_sites.dart';
import 'package:media_core/media_core.dart';
import 'package:media_core_danmaku/media_core_danmaku.dart';
import 'package:media_core_live/media_core_live.dart';
import 'package:pure_live/app/providers/network_type_provider.dart' show networkTypeProvider;
import 'package:pure_live/app/providers/player_backend_providers.dart' show playerKernelBackendProvider;
import 'package:pure_live/app/providers/player_providers.dart'
    show RoomPlaybackSession, RoomPlaybackStandby, playerKernelProvider, roomPlaybackStandbyProvider, roomSourcesOf;
import 'package:pure_live/app/providers/sites_providers.dart' show sitesProvider;
import 'package:pure_live/features/favorites/follow_repository.dart' show followsProvider;
import 'package:pure_live/features/history/history_repository.dart' show historyProvider;
import 'package:pure_live/features/recorder/recorder_engine.dart' show recorderEngineProvider;
import 'package:pure_live/features/recorder/recording_settings.dart' show recordingSettingsProvider;
import 'package:pure_live/features/recorder/recording_task.dart' show RecordingTask, RecordingTaskState;
import 'package:pure_live/features/room/gift_chat_filter.dart' show GiftChatFilter;
import 'package:pure_live/features/room/gift_flights.dart' show GiftFlights;
import 'package:pure_live/features/room/gift_text.dart' show giftLineTier;
import 'package:pure_live/features/room/membership_cards.dart' show membershipCard;
import 'package:pure_live/features/room/room_super_chats.dart' show roomSuperChatsProvider;
import 'package:pure_live/features/settings/chat_display_settings.dart'
    show chatGiftsAboveTierProvider, chatShowGiftsProvider;
import 'package:pure_live/features/settings/danmaku_repeat_provider.dart'
    show DanmakuRepeatSettings, danmakuRepeatProvider;
import 'package:pure_live/features/settings/danmaku_show_gifts_provider.dart' show danmakuShowGiftsProvider;
import 'package:pure_live/features/settings/danmaku_style_providers.dart'
    show DanmakuPausedBehavior, danmakuPausedBehaviorProvider;
import 'package:pure_live/features/settings/local_interaction_settings.dart'
    show LocalDanmakuPlacement, localInteractionProvider;
import 'package:pure_live/features/settings/playback_settings_providers.dart'
    show playbackSettingsProvider, preferredQualityIndex;
import 'package:pure_live/features/settings/player_tuning.dart'
    show
        PlayerTuning,
        playerOutputChanged,
        playerPresetTransitionOptions,
        playerProxyProvider,
        playerStoredEngineOptions,
        playerTuningOptions,
        playerTuningProvider;
import 'package:pure_live/features/settings/super_chat_settings.dart' show superChatIncludesMembershipProvider;
import 'package:pure_live/features/shield/danmaku_filter_settings.dart'
    show DanmakuFilterRules, danmakuFilterProvider, danmakuShapeBlockedByRules;
import 'package:pure_live/features/shield/shield_repository.dart' show ShieldRules, shieldRulesProvider;
import 'package:pure_live/shared/player/super_resolution.dart'
    show SuperResolutionMode, superResolutionModeProvider, superResolutionOption;

/// How many chat lines the page keeps; older leave first.
const int kRoomChatLimit = 200;

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
);

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

/// The flying layer's engine with "暂停时的弹幕" applied to the player's
/// pause: by default the messages stand with the picture; with "continue"
/// the engine keeps running, so the ones on screen and the ones arriving
/// keep moving. The binding is the only caller of pause/resume.
final class RoomBarrageController extends BarrageController {
  RoomBarrageController({required DanmakuPausedBehavior behavior})
    : _pauseWithPlayback = behavior == DanmakuPausedBehavior.pause;

  bool _pauseWithPlayback;
  bool _playbackPaused = false;

  /// Applies a changed choice to a picture that is already paused, so the
  /// message flow changes direction without waiting for a resume.
  void setBehavior(DanmakuPausedBehavior behavior) {
    final value = behavior == DanmakuPausedBehavior.pause;
    if (_pauseWithPlayback == value) return;
    _pauseWithPlayback = value;
    if (!_playbackPaused) return;
    if (value) {
      super.pause();
    } else {
      super.resume();
    }
  }

  @override
  void pause() {
    _playbackPaused = true;
    if (_pauseWithPlayback) super.pause();
  }

  @override
  void resume() {
    _playbackPaused = false;
    super.resume();
  }
}

/// The room's flying danmaku pipeline, one per open room: the site's
/// session events are accepted into the media_core danmaku controller
/// (whose gate and filters run first), and its sink fans every accepted
/// message into the flame engine (the flying layer) and the chat list at
/// once; the player binding carries pause and seek along.
final class RoomDanmakuPipeline {
  RoomDanmakuPipeline(
    this.onChat, {
    required this.showChatGifts,
    required this.chatGiftsAboveTier,
    required this.showFlyGifts,
    required String Function() streamer,
    required DanmakuFilterRules filter,
    required DanmakuRepeatSettings repeat,
    required DanmakuPausedBehavior pausedBehavior,
  }) : barrage = RoomBarrageController(behavior: pausedBehavior) {
    chatGifts = GiftChatFilter(clock: DateTime.now)..aboveTier = chatGiftsAboveTier();
    danmaku = DanmakuController(
      sink: DanmakuFanOutSink(
        primary: _ChatMirrorSink(onChat: onChat, inner: FlameBarrageSink(barrage)),
        overlay: overlay,
      ),
      config: _danmakuConfigFor(filter, repeat),
    );
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

  /// The chat list's mirror of the flying layer's source.
  final DanmakuOverlaySession overlay = DanmakuOverlaySession();

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

  /// Applies a changed "暂停时的弹幕" choice to the running layer.
  void setPausedBehavior(DanmakuPausedBehavior behavior) => barrage.setBehavior(behavior);

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
      if (showChatGifts()) {
        final line = chatGifts.add(message);
        if (line != null) onChat(line.message, replaceId: line.replaceId);
      }
      if (showFlyGifts()) giftFlights.add(message);
      return;
    }
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
    await binding?.dispose();
    binding = null;
    giftFlights.dispose();
    await danmaku.dispose();
    barrage.dispose();
    await overlay.dispose();
  }
}

/// Mirrors the messages the pipeline accepted onto the chat list, then hands
/// them to the flying layer. The list must see exactly what the filters let
/// through, so the mirror sits after them rather than at the site seam.
final class _ChatMirrorSink implements DanmakuSink {
  const _ChatMirrorSink({required this.onChat, required this.inner});

  final void Function(LiveMessage message, {String? replaceId}) onChat;
  final DanmakuSink inner;

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
        ),
      );
    }
    inner.onDanmaku(message, immediate: immediate);
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
        final next = [...state]..removeAt(index)..add(message);
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
  RoomPlaybackSession? _session;
  RoomPlaybackStandby? _standby;
  StreamSubscription<PlayerCoreState>? _states;
  StreamSubscription<PlayerHandle>? _handles;
  StreamSubscription<PlayerFailure>? _failures;
  StreamSubscription<LiveMessage>? _chat;
  LiveDanmakuSession? _danmaku;
  RoomDanmakuPipeline? _pipeline;

  /// The local interaction's own echo layer: no player pause binding, so a
  /// local message keeps flying when the platform's danmaku are paused.
  final BarrageController _localBarrage = BarrageController();

  /// The local echo layer's engine.
  BarrageController get localBarrage => _localBarrage;
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

  /// Read before the provider tree can go away: teardown may not touch ref.
  bool _forceDestroy = false;

  @override
  RoomState build() {
    _forceDestroy = ref.read(playerTuningProvider).forceDestroy;
    _standby = ref.read(roomPlaybackStandbyProvider);
    ref
      ..onDispose(_teardown)
      ..onDispose(_localBarrage.dispose);
    ref.listen(playerTuningProvider.select((tuning) => tuning.forceDestroy), (_, next) => _forceDestroy = next);
    // A super-resolution choice applies to the live handle at once; the
    // next handle also reads it in `_applyEnginePreferences`.
    ref.listen(superResolutionModeProvider, (_, mode) {
      final handle = state.handle;
      if (handle != null) unawaited(_applySuperResolution(handle, mode));
    });
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
    ref.listen(danmakuPausedBehaviorProvider, (previous, next) {
      if (previous == next) return;
      _pipeline?.setPausedBehavior(next);
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
    return _initial();
  }

  /// Opens the room behind [platform] and [roomId]: detail first, then the
  /// qualities it offers; the first playable line begins playback and the
  /// danmaku session connects. A room that cannot open says why in the
  /// state error field — the page shows it, never a blank.
  Future<void> open({required String platform, required String roomId}) async {
    _requestedPlatform = platform;
    _requestedRoomId = roomId;
    _teardown();
    ref.read(localInteractionProvider.notifier).stopWatch();
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
      unawaited(_loadSuperChats(room));
      _resumeLocalInteraction(room);
      if (room.broadcast.isLiveNow) {
        final danmakuProvider = site.capability<LiveDanmakuProvider>();
        if (danmakuProvider != null) await _openDanmaku(danmakuProvider, room);
      }
      final qualitiesAnswer = await playbackProvider.getQualities(room: room);
      qualitiesAnswer.match((error) => state = _with(error: error.message), (qualities) async {
        _wantedQuality = _pickQuality(qualities);
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
    state = _with(quality: quality, lineIndex: 0);
    await _startPlayback(playbackProvider, room);
  }

  /// Moves playback to the line at [index] without re-reading the plan.
  Future<void> selectLine(int index) async {
    state = _with(lineIndex: index);
    await _playback?.switchLine(index);
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
      await open(platform: platform, roomId: roomId);
    }
  }

  /// Re-reads the room's display state without tearing playback down: the
  /// site's own refresh read is sparse, so the stored room keeps what it
  /// already knew and takes the new status, figures and text. A listener
  /// holding an offline room learns the streamer is back without losing
  /// the room's identity; a platform without a refresh read replays the
  /// detail request only when nothing is playing.
  Future<void> refreshRoom() async {
    final room = state.room;
    final platform = _requestedPlatform;
    final roomId = _requestedRoomId;
    if (room == null || platform == null || roomId == null) return;
    final capability = ref.read(sitesProvider).getById(platform)?.capability<LiveRoomRefresh>();
    if (capability == null) {
      if (state.handle == null) await open(platform: platform, roomId: roomId);
      return;
    }
    final answer = await capability.getRoomForRefresh(roomId: roomId);
    if (!ref.mounted) return;
    answer.match(
      (error) => state = _with(error: error.message),
      (fresh) => state = _with(room: room.mergedWith(fresh)),
    );
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
    ref.read(localInteractionProvider.notifier).stopWatch();
    state = _initial();
    ref.read(roomChatProvider.notifier).clear();
    ref.read(roomSuperChatsProvider.notifier).clear();
  }

  /// Starts the local watch clock and puts this room's last-day local danmaku
  /// back at the top of the chat list, when the interaction asks for it.
  void _resumeLocalInteraction(LiveRoom room) {
    final local = ref.read(localInteractionProvider);
    if (!local.enabled) return;
    ref.read(localInteractionProvider.notifier).startWatch();
    if (!local.replayOnEnter) return;
    final controller = ref.read(localInteractionProvider.notifier);
    final chats = controller.replayChatsFor(room.ref.platform, room.ref.roomId);
    if (chats.isEmpty) return;
    ref.read(roomChatProvider.notifier).replayOldest([
      for (final (index, chat) in chats.indexed)
        LiveMessage.normalized(
          messageId: 'local-replay-${chat.at.millisecondsSinceEpoch}-$index',
          text: chat.text,
          sender: MessageSender.of(userName: local.userName),
          isLocal: true,
        ),
    ]);
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

  /// Sends the engine configuration to a handle once: the decoder choice, the
  /// player proxy and the super-resolution shader chain (mpv property writes,
  /// so they take effect on the running engine). A replacement handle gets
  /// all of them again; a saved proxy must route the very first request, not
  /// wait for a settings change.
  Future<void> _applyEnginePreferences(PlayerHandle handle) async {
    if (identical(_preparedHandle, handle)) return;
    _preparedHandle = handle;
    try {
      final options = <EngineOption>[..._storedEngineOptions()];
      final shader = await superResolutionOption(ref.read(superResolutionModeProvider));
      if (shader != null) options.add(shader);
      await handle.applyEngineOptions(options);
    } on Object {
      // A preference the engine refused is not a playback failure.
    }
  }

  /// Applies a changed super-resolution choice to the running engine; an
  /// empty list clears the shader chain when the choice goes back to off.
  Future<void> _applySuperResolution(PlayerHandle handle, SuperResolutionMode mode) async {
    try {
      final option = await superResolutionOption(mode);
      await handle.applyEngineOptions([option ?? const EngineOption('glsl-shaders', <String>[])]);
    } on Object {
      // The picture is already playing; a shader the engine refused must not
      // turn into a playback error.
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
        LiveMessage.normalized(messageId: 'local-${DateTime.now().microsecondsSinceEpoch}', text: word, isLocal: true),
      );
      return null;
    } on Object catch (error) {
      return error.toString();
    }
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

  /// Injects a local message into the room's chat list and the local echo
  /// layer: the platform does not see it, and the echo layer has no player
  /// pause binding, so it keeps flying while the platform's danmaku are
  /// paused (the reference's "本地自发弹幕两种模式都继续"). [badges] is the
  /// local interaction's badge line (level/platform) when it shows.
  void injectLocalMessage(String text, {String badges = '', String senderName = ''}) {
    final word = text.trim();
    if (word.isEmpty) return;
    final line = badges.isEmpty ? word : '[$badges] $word';
    final message = LiveMessage.normalized(
      messageId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      text: line,
      sender: senderName.trim().isEmpty ? null : MessageSender.of(userName: senderName.trim()),
      isLocal: true,
    );
    ref.read(roomChatProvider.notifier).add(message);
    final local = ref.read(localInteractionProvider);
    final style = local.style;
    _localBarrage.send(
      BarrageItemMapper.toItem(
        DanmakuMessage(
          type: DanmakuMessageType.chat,
          userName: senderName,
          text: line,
          color: DanmakuColor.fromInt(style.color),
          isLocal: true,
          messageId: message.messageId,
          style: DanmakuStyle(
            fontSize: style.fontSize,
            baseSpeed: style.speed,
            fontWeight: style.fontWeight,
            showStroke: style.showStroke,
            strokeWidth: style.strokeWidth,
            placement: switch (style.placement) {
              LocalDanmakuPlacement.top => DanmakuPlacement.top,
              LocalDanmakuPlacement.bottom => DanmakuPlacement.bottom,
              _ => DanmakuPlacement.scroll,
            },
            fontFamily: switch (style.fontFamily) {
              'system' => null,
              'mono' => 'monospace',
              final family => family,
            },
            italic: style.italic,
            opacity: style.opacity,
            letterSpacing: style.letterSpacing,
            strokeColor: style.strokeColor,
            showShadow: style.showShadow,
            shadowColor: style.shadowColor,
            shadowBlur: style.shadowBlur,
            shadowOffset: style.shadowOffset,
            fixedDurationMs: style.fixedDurationMs,
          ),
        ),
      ),
    );
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
    Future<String?> refresh() async {
      if (capability == null) return null;
      final answer = await capability.getLines(room: room, quality: recordQuality ?? _wantedQuality);
      final url = answer.fold((_) => null, (lines) => lines.isEmpty ? null : lines.first.url);
      return url;
    }

    final danmaku = ref.read(sitesProvider).getById(room.ref.platform)?.capability<LiveDanmakuProvider>();
    return await engine.start(
      task,
      recordLine,
      refreshUrl: capability == null ? null : refresh,
      room: room,
      danmaku: danmaku,
    );
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

  Future<void> _startPlayback(LivePlaybackProvider capability, LiveRoom room) async {
    final linesAnswer = await capability.getLines(room: room, quality: _wantedQuality);
    linesAnswer.match((error) => state = _with(error: error.message), (lines) async {
      if (lines.isEmpty) {
        state = _with(lines: const [], error: 'the room has nothing to play');
        return;
      }
      state = _with(lines: lines);
      final playback = _playback ??= _openSession(capability, room);
      _states ??= playback.onStateChanged.listen((playback_) {
        state = _with(playback: playback_);
      });
      _failures ??= playback.onError.listen((failure) {
        state = _with(error: failure.message ?? failure.code.name);
      });
      _handles ??= playback.onHandleChanged.listen((handle) {
        state = _with(handle: handle, lineIndex: _playback?.sourceIndex ?? state.lineIndex);
        // The player's pause and seek carry into the flying layer; the
        // viewer's current audio follows every engine, the decoder choice
        // goes to the first one.
        _pipeline?.bind(handle);
        unawaited(_applyAudioPreferences(handle));
        unawaited(_applyEnginePreferences(handle));
      });
      await playback.play(
        LiveSourceRequest(
          sources: roomSourcesOf(lines),
          title: room.content.title,
          allowEngineFallback: true,
          engineOptions: _storedEngineOptions(),
        ),
        preferredBackend: ref.read(playerKernelBackendProvider).id,
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
      final pipeline = RoomDanmakuPipeline(
        ref.read(roomChatProvider.notifier).add,
        showChatGifts: () => ref.read(chatShowGiftsProvider),
        chatGiftsAboveTier: () => ref.read(chatGiftsAboveTierProvider),
        showFlyGifts: () => ref.read(danmakuShowGiftsProvider),
        streamer: () => room.anchor?.name ?? '',
        filter: ref.read(danmakuFilterProvider),
        repeat: ref.read(danmakuRepeatProvider),
        pausedBehavior: ref.read(danmakuPausedBehaviorProvider),
      );
      _pipeline = pipeline;
      await pipeline.start(platform: room.ref.platform, roomId: room.ref.roomId);
      _chat = session.events.listen(_onSiteMessage);
      // The page reads the pipeline's barrage engine through the notifier;
      // this rebuild is what picks it up the moment it exists.
      state = _with();
    });
  }

  /// One site message: the shield's word, then the content blocks (纯表情 /
  /// 超长, the reference's 屏蔽页), then the super chat board and the
  /// pipeline's own filters.
  void _onSiteMessage(LiveMessage message) {
    if (_shielded(message) || _shapeBlocked(message)) return;
    _collectSuperChat(message);
    _pipeline?.accept(message);
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
    final card = membershipCard(
      message,
      platform: state.room?.ref.platform ?? '',
      now: DateTime.now(),
    );
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
    answer.match(
      (error) => board.fail(error.message),
      board.addAll,
    );
  }

  /// Whether the reference's content blocks drop [message]: emoticon-only
  /// and over-long, each behind its own switch, read per message so a
  /// change on the shield page bites the very next line. The viewer's own
  /// echo is never blocked.
  bool _shapeBlocked(LiveMessage message) => danmakuShapeBlockedByRules(message, ref.read(danmakuFilterProvider));

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
    int? lineIndex,
    LivePlayQuality? quality,
    PlayerCoreState? playback,
    PlayerHandle? handle,
    bool? audioOnly,
    String? error,
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
  );

  void _teardown() {
    unawaited(_states?.cancel() ?? Future<void>.value());
    unawaited(_handles?.cancel() ?? Future<void>.value());
    unawaited(_failures?.cancel() ?? Future<void>.value());
    unawaited(_chat?.cancel() ?? Future<void>.value());
    _states = null;
    _handles = null;
    _failures = null;
    _chat = null;
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
    unawaited(_danmaku?.disconnect() ?? Future<void>.value());
    unawaited(_danmaku?.dispose() ?? Future<void>.value());
    _danmaku = null;
    unawaited(_pipeline?.dispose() ?? Future<void>.value());
    _pipeline = null;
    _localBarrage.clear();
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

/// The local interaction's echo layer; it has no player pause binding.
final localBarrageProvider = Provider<BarrageController>((ref) {
  ref.watch(roomProvider);
  return ref.read(roomProvider.notifier).localBarrage;
});
