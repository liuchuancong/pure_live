import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/scheduler.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pure_live/plugins/emoji_manager.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/core/danmaku/douyin_danmaku.dart';
import 'package:pure_live/player/core/live_audio_service.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/modules/live_play/controllers/timer_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_controller.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_session_host.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku/danmaku_list_view.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_presentation_recovery.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_interaction_controller.dart';
import 'package:pure_live/modules/live_play/widgets/local_interaction/local_message_delivery_queue.dart';

// live_play_controller.dart

class LivePlayController extends GetxController
    with GetSingleTickerProviderStateMixin, WidgetsBindingObserver
    implements DanmakuSessionHost, PlayerSessionHost {
  LivePlayController({required this.room, required this.site});

  final String site;
  final LiveRoom room;

  late final TimerController timerController;
  late final DanmakuController danmakuController;
  late final PlayerController playerController;

  final RecorderController recorderController = Get.find<RecorderController>();
  final LocalInteractionController localInteractionController = Get.find<LocalInteractionController>();

  @override
  final Rx<LivePlayState> state = const LivePlayState().obs;
  final RxList<LiveMessage> danmakuMessages = <LiveMessage>[].obs;
  final RxInt danmakuPresentationRevision = 0.obs;
  final Rxn<LiveMessage> localGiftEffect = Rxn<LiveMessage>();
  final RxList<LiveSuperChatMessage> superChats = <LiveSuperChatMessage>[].obs;
  late Site currentSite;
  late TabController tabController;

  final List<String> tabs = [i18n('danmaku_list'), i18n('super_chat'), i18n('danmaku_settings'), i18n('block_list')];

  bool _floatingResourcesReleased = false;
  bool _ownerClosed = false;
  bool _childControllersReleased = false;
  bool _reactiveStateClosed = false;
  bool _suppressAppFloatingOnNextPop = false;
  int _roomLoadEpoch = 0;
  bool _asmrSessionActive = false;
  Timer? _localGiftEffectTimer;
  Timer? _danmakuFlushTimer;
  Worker? _pipStateWorker;
  Worker? _screenKeepOnWorker;
  late final DanmakuPresentationRecovery _danmakuPresentationRecovery;
  bool _wasInSystemPip = false;
  bool _wasBackgrounded = false;
  bool _handlingSystemBackPresentation = false;
  final List<LiveMessage> _pendingDanmakuMessages = <LiveMessage>[];
  late final LocalMessageDeliveryQueue _localMessageDeliveryQueue;
  late final String _controllerTag;
  RoomSessionSnapshot? _reentrySession;

  static const int _maxDanmakuHistory = 500;
  static const int _maxPendingDanmakuBatch = 200;
  // The on-video barrage receives messages directly from DanmakuController.
  // This buffer only feeds the virtualized history list, whose own visual
  // cadence is 80 ms. A 64 ms batch halves full 500-item RxList copies in busy
  // rooms without slowing the moving barrage or local messages (which flush
  // immediately).
  static const Duration _danmakuBatchWindow = Duration(milliseconds: 64);
  static const Duration localChatDeliveryDelay = Duration(seconds: 2);

  Timer? _superChatExpiryTimer;
  @override
  void onInit() {
    super.onInit();
    _controllerTag = '${identityHashCode(this)}';
    currentSite = Sites.of(site);
    _localMessageDeliveryQueue = LocalMessageDeliveryQueue(onDeliver: _deliverLocalMessage);

    final manager = GlobalPlayerService.instance.player;
    _reentrySession = manager.consumeRoomSessionReentry(room);
    final resumesCurrentSession = _reentrySession != null;
    final autoStartAsmr = Platform.isAndroid && SettingsService.to.app.enableAsmrSleepMode.v;
    final initialAudioOnly = resumesCurrentSession ? manager.desiredAudioOnlyMode : autoStartAsmr;
    _asmrSessionActive = resumesCurrentSession ? LiveAudioService.isSleepSessionActive : autoStartAsmr;
    final restored = _reentrySession;
    state.value = LivePlayState(
      room: RoomState(
        detail: restored?.room ?? room,
        isLiving: restored?.isLiving ?? true,
        success: resumesCurrentSession,
      ),
      // ASMR is the only automatic audio-only entry point. Manual headphone
      // switching is scoped to the current room and is never persisted.
      player: PlayerState(
        qualites: restored?.qualities ?? const <LivePlayQuality>[],
        currentQuality: restored?.currentQuality ?? 0,
        playUrls: restored?.playUrls ?? const <String>[],
        currentLineIndex: restored?.currentLineIndex ?? 0,
        isCurrentRoomAudioOnly: initialAudioOnly,
        hasUseDefaultResolution: restored?.hasUseDefaultResolution ?? false,
      ),
      ui: UIState(closeTimes: 60, closeTimeFlag: false, displayVideoLayer: true),
    );
    // Re-entering from the app floating window continues the same room session.
    // Resetting the timer here extended an existing sleep session and also
    // forced a second audio-mode transition during route construction.
    if (!resumesCurrentSession) {
      unawaited(
        LiveAudioService.configureSleepTimer(
          enabled: autoStartAsmr,
          minutes: SettingsService.to.app.asmrSleepMinutes.v,
        ),
      );
    }

    _initControllers();
    _danmakuPresentationRecovery = DanmakuPresentationRecovery(
      isBlocked: () => GlobalPlayerService.instance.player.isCompactModeActive,
      canRecover: () {
        if (isClosed || _ownerClosed) return false;
        return state.value.room.success && state.value.room.detail != null;
      },
      recover: _recoverDanmakuAfterPresentation,
    );
    WidgetsBinding.instance.addObserver(this);
    _wasInSystemPip = manager.isInPip.value;
    _pipStateWorker = ever<bool>(manager.isInPip, (isInPip) {
      final returnedFromPip = _wasInSystemPip && !isInPip;
      _wasInSystemPip = isInPip;
      if (returnedFromPip) _restoreDanmakuPresentation();
    });
    _initTab();
    Future.microtask(_initCore);

    // This observable is owned by the application-wide SettingsService. Keep
    // and dispose its Worker explicitly; otherwise every closed room remains
    // reachable through the global Rx callback together with its 500-message
    // history, player controller and render caches.
    _screenKeepOnWorker = ever(SettingsService.to.app.enableScreenKeepOn, (_) => _updateWakelock());

    _updateWakelock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden || state == AppLifecycleState.detached) {
      _wasBackgrounded = true;
      return;
    }
    if (state != AppLifecycleState.resumed || !_wasBackgrounded) return;
    _wasBackgrounded = false;
    if (!GlobalPlayerService.instance.player.isInPip.value) {
      _restoreDanmakuPresentation();
    }
  }

  void _restoreDanmakuPresentation() {
    if (isClosed || _ownerClosed) return;
    // The portrait list is removed from the tree while LivePlayContent renders
    // the native PiP surface, so a list-local PiP worker never observes the
    // complete true -> false transition. Publish the restore from this
    // persistent controller and flush any batch that was waiting when the
    // Activity changed presentation.
    _flushDanmakuMessages();
    danmakuPresentationRevision.value++;
    _danmakuPresentationRecovery.request();
  }

  Future<void> _recoverDanmakuAfterPresentation() async {
    final detail = state.value.room.detail;
    if (detail == null || !state.value.room.success || isClosed || _ownerClosed) return;
    try {
      await danmakuController.recoverRoomConnection(detail);
    } catch (error, stackTrace) {
      developer.log(
        'Danmaku recovery after PiP/foreground failed',
        name: 'LivePlayController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _initControllers() {
    timerController = Get.put(TimerController(onEnded: _onRoomPlaybackTimerEnded), tag: 'timer-$_controllerTag');
    danmakuController = Get.put(DanmakuController(this), tag: 'danmaku-$_controllerTag');
    playerController = Get.put(PlayerController(this), tag: 'player-$_controllerTag');

    playerController.initSite(currentSite);

    danmakuController.initDanmaku(currentSite.liveSite.getDanmaku());
  }

  void _initTab() {
    tabController = TabController(length: tabs.length, vsync: this, animationDuration: pureLiveTabTransitionDuration);
  }

  Future<void> _initCore() async {
    final restored = _reentrySession;
    if (restored != null) {
      _reentrySession = null;
      await _resumeCurrentRoomSession(restored);
      _preloadEmojiInBackground();
      return;
    }

    // Emoji resources are presentation data. Keeping their disk/network work
    // off the playback critical path makes a cold room start as soon as its
    // detail and play URL are available.
    _preloadEmojiInBackground();
    await onInitPlayerState();
  }

  Future<void> _updateWakelock() async {
    final shouldKeepOn = SettingsService.to.app.enableScreenKeepOn.v;

    WakelockPlus.enabled.then((isEnabled) {
      if (isEnabled != shouldKeepOn) {
        WakelockPlus.toggle(enable: shouldKeepOn);
      }
    });
  }

  void _preloadEmojiInBackground() {
    unawaited(
      _preloadEmoji().catchError((Object error, StackTrace stackTrace) {
        developer.log('Emoji preload failed', name: 'LivePlayController', error: error, stackTrace: stackTrace);
      }),
    );
  }

  Future<void> _preloadEmoji() async {
    emojiCache.clear();
    await EmojiManager().preload(site);
  }

  Future<void> _resumeCurrentRoomSession(RoomSessionSnapshot session) async {
    final controller = await playerController.attachCurrentSession(session);
    if (controller == null || isClosed) {
      // The native player disappeared between the floating-window tap and route
      // construction. Fall back to the normal bounded room initialization.
      await onInitPlayerState();
      return;
    }

    updateRoom(detail: session.room, isLiving: session.isLiving, success: true, isLoading: false, loadError: null);
    await _syncDanmakuConnection(session.room);
    unawaited(_refreshResumedRoomMetadata(session.room));
  }

  Future<void> _refreshResumedRoomMetadata(LiveRoom previous) async {
    final roomId = previous.roomId;
    final platform = previous.platform;
    if (roomId == null || platform == null) return;
    try {
      final fetched = await currentSite.liveSite.getRoomDetail(roomId: roomId, platform: platform);
      if (isClosed) return;
      final current = state.value.room.detail;
      if (current?.roomId != roomId || current?.platform != platform) return;
      final refreshed = fetched.withAudienceFallbackFrom(current!);
      final isLiving = refreshed.status == true || refreshed.isRecord == true;
      updateRoom(detail: refreshed, isLiving: isLiving, success: true, isLoading: false);
    } catch (error, stackTrace) {
      // The already-playing session stays usable when a metadata refresh fails.
      developer.log(
        'Re-entered room metadata refresh failed',
        name: 'LivePlayController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> getSuperChatMessage(String roomId, {required String? platform, required int loadEpoch}) async {
    if (!_isRoomLoadCurrent(loadEpoch, roomId, platform)) return;
    final liveSite = currentSite.liveSite;
    try {
      final sc = await liveSite.getSuperChatMessage(roomId: roomId);
      if (isClosed || _ownerClosed || !_isRoomLoadCurrent(loadEpoch, roomId, platform)) return;
      addBatchSuperChat(sc);
    } catch (e) {
      if (!isClosed && !_ownerClosed && _isRoomLoadCurrent(loadEpoch, roomId, platform)) {
        addSystemMessage("SC读取失败");
      }
    }
  }

  @override
  void addAddSuperChat(LiveMessage msg) {
    addSingleSuperChat(msg.data as LiveSuperChatMessage);
  }

  void _removeExpiredSuperChats() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final filtered = superChats.where((x) => x.endTime.millisecondsSinceEpoch > now).toList(growable: false);
    if (filtered.length != superChats.length) {
      superChats.assignAll(filtered);
    }
    _scheduleSuperChatExpiry();
  }

  void _scheduleSuperChatExpiry() {
    _superChatExpiryTimer?.cancel();
    _superChatExpiryTimer = null;
    if (isClosed || _ownerClosed) return;
    final delay = nextSuperChatExpiryDelay(superChats, DateTime.now());
    if (delay == null) return;
    _superChatExpiryTimer = Timer(delay, _removeExpiredSuperChats);
  }

  @visibleForTesting
  static Duration? nextSuperChatExpiryDelay(Iterable<LiveSuperChatMessage> messages, DateTime now) {
    final iterator = messages.iterator;
    if (!iterator.moveNext()) return null;
    var nextExpiry = iterator.current.endTime;
    while (iterator.moveNext()) {
      final candidate = iterator.current.endTime;
      if (candidate.isBefore(nextExpiry)) nextExpiry = candidate;
    }
    final remaining = nextExpiry.difference(now);
    return remaining.isNegative || remaining == Duration.zero ? const Duration(milliseconds: 1) : remaining;
  }

  void addSingleSuperChat(LiveSuperChatMessage item) {
    final next = <LiveSuperChatMessage>{...superChats, item}.toList(growable: false);
    superChats.assignAll(next);
    _scheduleSuperChatExpiry();
  }

  void addBatchSuperChat(List<LiveSuperChatMessage> sc) {
    if (sc.isEmpty) return;
    final next = <LiveSuperChatMessage>{...superChats, ...sc}.toList(growable: false);
    superChats.assignAll(next);
    _scheduleSuperChatExpiry();
  }

  void clearSuperChats() {
    _superChatExpiryTimer?.cancel();
    _superChatExpiryTimer = null;
    if (superChats.isNotEmpty) superChats.clear();
  }

  /// Restores the normal room presentation for one system-back attempt.
  ///
  /// The route-local PopScope owns whether the route can pop. Keeping teardown
  /// out of this pre-pop path prevents a failed gesture from leaving the room
  /// visible after its player listeners have already been removed.
  Future<void> exitPresentationForSystemBack() async {
    if (_handlingSystemBackPresentation || isClosed || _ownerClosed) return;
    _handlingSystemBackPresentation = true;

    final globalState = GlobalPlayerState.to;
    final wasFullscreen = globalState.isFullscreen.value || state.value.ui.screenMode == VideoMode.fullscreen;
    try {
      setNormalScreen();
      globalState.isWindowFullscreen.value = false;

      if (wasFullscreen) {
        final videoController = state.value.player.videoController;
        if (videoController != null) {
          await videoController.exitFullScreen();
        } else {
          globalState.isFullscreen.value = false;
        }
      } else {
        globalState.isFullscreen.value = false;
      }
    } finally {
      globalState.isFullscreen.value = false;
      globalState.isWindowFullscreen.value = false;
      _handlingSystemBackPresentation = false;
    }
  }

  @override
  void updateRoom({LiveRoom? detail, bool? isLiving, bool? success, bool? isLoading, String? loadError}) {
    state.value = state.value.copyWith(
      room: state.value.room.copyWith(
        detail: detail,
        isLiving: isLiving,
        success: success,
        isLoading: isLoading,
        loadError: loadError,
      ),
    );
  }

  @override
  void updatePlayer({
    VideoController? videoController,
    bool clearVideoController = false,
    List<LivePlayQuality>? qualites,
    int? currentQuality,
    List<String>? playUrls,
    int? currentLineIndex,
    bool? isCurrentRoomAudioOnly,
    bool? hasUseDefaultResolution,
  }) {
    state.value = state.value.copyWith(
      player: state.value.player.copyWith(
        // Nullable optional parameters cannot distinguish "not supplied" from
        // "clear this field". Passing the default null on every unrelated
        // player-state update used to remove the live VideoController; toggling
        // audio mode therefore replaced the room with a permanent loading page.
        videoController: resolveVideoControllerUpdate(
          current: state.value.player.videoController,
          next: videoController,
          clear: clearVideoController,
        ),
        qualites: qualites,
        currentQuality: currentQuality,
        playUrls: playUrls,
        currentLineIndex: currentLineIndex,
        isCurrentRoomAudioOnly: isCurrentRoomAudioOnly,
        hasUseDefaultResolution: hasUseDefaultResolution,
      ),
    );
  }

  void updateUI({
    VideoMode? screenMode,
    int? refreshKey,
    bool? isMenuOpen,
    int? closeTimes,
    bool? closeTimeFlag,
    bool? displayVideoLayer,
  }) {
    state.value = state.value.copyWith(
      ui: state.value.ui.copyWith(
        screenMode: screenMode,
        refreshKey: refreshKey,
        isMenuOpen: isMenuOpen,
        closeTimes: closeTimes,
        closeTimeFlag: closeTimeFlag,
        displayVideoLayer: displayVideoLayer,
      ),
    );
  }

  void updateDanmaku({List<LiveMessage>? messages}) {
    if (messages != null) {
      danmakuMessages.assignAll(messages);
    }
  }

  @override
  void addDanmakuMessage(LiveMessage msg, {bool immediate = false}) {
    if (isClosed) return;
    if (_pendingDanmakuMessages.length >= _maxPendingDanmakuBatch) {
      _pendingDanmakuMessages.removeAt(0);
    }
    _pendingDanmakuMessages.add(msg);
    if (immediate) {
      _danmakuFlushTimer?.cancel();
      _danmakuFlushTimer = null;
      _flushDanmakuMessages();
      return;
    }
    _danmakuFlushTimer ??= Timer(_danmakuBatchWindow, _flushDanmakuMessages);
  }

  void _flushDanmakuMessages() {
    _danmakuFlushTimer?.cancel();
    _danmakuFlushTimer = null;
    if (_pendingDanmakuMessages.isEmpty || isClosed) return;
    final next = <LiveMessage>[...danmakuMessages, ..._pendingDanmakuMessages];
    _pendingDanmakuMessages.clear();
    if (next.length > _maxDanmakuHistory) {
      next.removeRange(0, next.length - _maxDanmakuHistory);
    }
    danmakuMessages.assignAll(next);
  }

  void removeDanmakuWhere(bool Function(LiveMessage message) predicate) {
    _pendingDanmakuMessages.removeWhere(predicate);
    final next = danmakuMessages.where((message) => !predicate(message)).toList(growable: false);
    if (next.length != danmakuMessages.length) danmakuMessages.assignAll(next);
  }

  Future<void> _onRoomPlaybackTimerEnded() async {
    updateUI(closeTimeFlag: false);
    await GlobalPlayerService.instance.player.pause();
    await LiveAudioService.stop();
    ToastUtil.show(i18n('room_playback_timer_finished'));
  }

  @override
  void updateRuntimeAudience(dynamic value) {
    if (isClosed) return;
    final update = value is LiveAudienceUpdate ? value : null;
    final rawValue = (update?.value ?? value)?.toString().trim() ?? '';
    if (!RegExp(r'[0-9]').hasMatch(rawValue)) return;
    final count = LiveRoom.parseAudienceNumber(rawValue);
    final detail = state.value.room.detail;
    if (detail == null) return;
    if (count < 0) return;
    final text = count.toString();
    final inferredKind = detail.platform == Sites.bilibiliSite
        ? LiveAudienceMetricKind.popularity
        : LiveAudienceMetricKind.onlineViewers;
    final kind = update?.kind ?? inferredKind;
    final candidate = switch (kind) {
      LiveAudienceMetricKind.popularity => detail.copyWith(
        watching: text,
        popularity: text,
        audienceMetricType: AudienceMetricType.popularity,
      ),
      LiveAudienceMetricKind.onlineViewers => detail.copyWith(onlineViewers: text),
      LiveAudienceMetricKind.totalViewers => detail.copyWith(totalViewers: text),
    };
    updateRoom(detail: candidate.withAudienceFallbackFrom(detail));
  }

  void emitLocalMessage(LiveMessage msg, {required bool showAsDanmaku, Duration delay = Duration.zero}) {
    if (!localInteractionController.enabled.v) return;
    _localMessageDeliveryQueue.schedule(
      LocalMessageDelivery(message: msg, showAsDanmaku: showAsDanmaku, roomEpoch: _roomLoadEpoch),
      delay: delay,
    );
  }

  void _deliverLocalMessage(LocalMessageDelivery delivery) {
    if (isClosed || _ownerClosed || delivery.roomEpoch != _roomLoadEpoch) return;
    final msg = delivery.message;
    addDanmakuMessage(msg, immediate: true);
    if (delivery.showAsDanmaku) state.value.player.videoController?.sendDanmaku(msg);
    if (msg.type == LiveMessageType.gift && localInteractionController.enableGiftEffects.v) {
      localGiftEffect.v = msg;
      _localGiftEffectTimer?.cancel();
      _localGiftEffectTimer = Timer(const Duration(seconds: 3), () => localGiftEffect.v = null);
    }
  }

  /// Applies the headphone action to this room only. Restoring video also
  /// ends an automatically started ASMR timer, while manually entering audio
  /// mode does not implicitly create a sleep session.
  @override
  Future<void> setCurrentRoomAudioOnlyFromUser(bool value) async {
    if (!value && _asmrSessionActive) {
      _asmrSessionActive = false;
      // Stopping the sleep timer updates its in-memory state synchronously, but
      // the Android keep-alive channel may answer slowly on a busy vendor ROM.
      // Keep that platform cleanup out of the native video-track transition so
      // restoring video never waits behind the foreground service.
      unawaited(
        LiveAudioService.configureSleepTimer(
          enabled: false,
          minutes: SettingsService.to.app.asmrSleepMinutes.v,
        ).catchError((Object error, StackTrace stackTrace) {
          developer.log(
            'Sleep timer cleanup failed during video restore',
            name: 'LivePlayController',
            error: error,
            stackTrace: stackTrace,
          );
        }),
      );
    }
    await playerController.changeCurrentRoomAudioOnly(value);
  }

  @override
  void addSystemMessage(String text) {
    final msg = LiveMessage(
      type: LiveMessageType.chat,
      userName: i18n('system_message'),
      message: text,
      color: LiveMessageColor.white,
    );
    addDanmakuMessage(msg);
  }

  void clearDanmakuMessages() {
    _danmakuFlushTimer?.cancel();
    _danmakuFlushTimer = null;
    _pendingDanmakuMessages.clear();
    danmakuMessages.clear();
    clearRenderedDanmaku();
  }

  @override
  void updateDanmakuRoomId(String? roomId) {
    if (state.value.danmaku.currentDanmakuRoomId == roomId) return;
    state.value = state.value.copyWith(danmaku: state.value.danmaku.copyWith(currentDanmakuRoomId: roomId));
  }

  @override
  void clearRenderedDanmaku() {
    state.value.player.videoController?.clearDanmaku();
  }

  void updateTimerFlag(bool flag) {
    updateUI(closeTimeFlag: flag);
    timerController.toggleTimer(flag, state.value.ui.closeTimes);
  }

  void updateTimerTimes(int times) {
    updateUI(closeTimes: times);
    if (state.value.ui.closeTimeFlag) {
      timerController.toggleTimer(true, times);
    }
  }

  Future<LiveRoom> onInitPlayerState({
    ReloadDataType reloadDataType = ReloadDataType.refreash,
    int line = 0,
    bool isReCalculate = true,
  }) async {
    // Keep one immutable request snapshot. Reading state again after the
    // platform request completes can merge an old response with a newly opened
    // room before the epoch fence has a chance to reject it.
    final requestedRoom = state.value.room.detail;
    final roomId = requestedRoom?.roomId;
    final requestedPlatform = requestedRoom?.platform;
    if (requestedRoom == null || roomId == null || requestedPlatform == null) return LiveRoom();
    final loadEpoch = ++_roomLoadEpoch;

    clearSuperChats();
    updateRoom(isLoading: true, loadError: null);

    try {
      final fetchedRoom = await currentSite.liveSite.getRoomDetail(roomId: roomId, platform: requestedPlatform);
      var liveRoom = fetchedRoom.withAudienceFallbackFrom(requestedRoom);
      liveRoom = liveRoom.fillFromDetail(requestedRoom);
      if (!_isRoomLoadCurrent(loadEpoch, roomId, requestedPlatform)) return liveRoom;
      updateRoom(detail: liveRoom);
      unawaited(getSuperChatMessage(roomId, platform: requestedPlatform, loadEpoch: loadEpoch));

      if (currentSite.id == Sites.iptvSite) {
        _initIptvPlayer();
        return liveRoom;
      }

      _handleCurrentLineAndQuality(reloadDataType, line, isReCalculate);

      if (liveRoom.liveStatus == LiveStatus.unknown) {
        _handleUnknownStatus();
        return liveRoom;
      }

      final liveStatus = liveRoom.status == true || liveRoom.isRecord == true;

      if (liveStatus) {
        await _handleLiveRoom(liveRoom, loadEpoch: loadEpoch);
      } else {
        _handleNotLiveRoom(liveRoom);
      }

      updateRoom(isLoading: false);
      return liveRoom;
    } catch (e) {
      if (!_isRoomLoadCurrent(loadEpoch, roomId, requestedPlatform)) return LiveRoom();
      updateRoom(isLoading: false, loadError: e.toString());
      ToastUtil.show(i18n('get_room_info_failed_retry'));
      return LiveRoom();
    }
  }

  bool _isRoomLoadCurrent(int epoch, String roomId, String? platform) {
    final current = state.value.room.detail;
    return epoch == _roomLoadEpoch && current?.roomId == roomId && current?.platform == platform;
  }

  void invalidateRoomLoad() => _roomLoadEpoch++;

  Future<void> _handleLiveRoom(LiveRoom liveRoom, {required int loadEpoch}) async {
    updateRoom(isLiving: true, success: false);

    try {
      await playerController.getPlayQualites();
      if (loadEpoch != _roomLoadEpoch) return;

      if (liveRoom.platform != Sites.iptvSite) {
        SettingsService.to.history.addRoomToHistory(liveRoom);
        SettingsService.to.fav.updateRoom(liveRoom);
        EventBus.instance.emit('refresh_room_changed', true);
      }

      await _syncDanmakuConnection(liveRoom);
    } catch (error, stackTrace) {
      developer.log(
        'Live room initialization failed (${error.runtimeType})',
        name: 'LivePlayController',
        stackTrace: stackTrace,
      );
      updateRoom(success: false);
    }
  }

  Future<void> _syncDanmakuConnection(LiveRoom liveRoom) async {
    const except = [Sites.kuaishouSite, Sites.iptvSite, Sites.ccSite];
    final danmakuSettings = SettingsService.to.danmaku;
    final shouldConnectDanmaku = danmakuSettings.enableDanmakuDisplay.v || danmakuSettings.enablePipDanmaku.v;
    if (!except.contains(liveRoom.platform) && shouldConnectDanmaku) {
      await danmakuController.connectRoom(liveRoom);
    } else {
      await danmakuController.stopDanmaku();
    }
  }

  void _handleNotLiveRoom(LiveRoom liveRoom) {
    unawaited(danmakuController.stopDanmaku());
    updateRoom(success: false, isLiving: false);
    setNormalScreen();
    GlobalPlayerState.to.isFullscreen.value = false;
    GlobalPlayerState.to.isWindowFullscreen.value = false;
    if (liveRoom.platform != Sites.iptvSite) {
      SettingsService.to.fav.updateRoom(liveRoom);
      EventBus.instance.emit('refresh_room_changed', true);
    }
    ToastUtil.show(
      liveRoom.liveStatus == LiveStatus.banned ? i18n('server_error_retry_later') : i18n('stream_not_live'),
    );
    _restoreQualityAndLines();
  }

  void _handleUnknownStatus() {
    unawaited(danmakuController.stopDanmaku());
    if (Get.currentRoute == '/live_play') {
      ToastUtil.show(i18n('get_room_info_failed_retry'));
      setNormalScreen();
      GlobalPlayerState.to.isFullscreen.value = false;
      GlobalPlayerState.to.isWindowFullscreen.value = false;
    }
  }

  void _handleCurrentLineAndQuality(ReloadDataType reloadDataType, int line, bool isReCalculate) {
    if (reloadDataType == ReloadDataType.changeLine && isReCalculate && state.value.player.playUrls.isNotEmpty) {
      final newLineIndex = (state.value.player.currentLineIndex + 1) % state.value.player.playUrls.length;
      updatePlayer(currentLineIndex: newLineIndex);
    }
  }

  void _initIptvPlayer() {
    final link = state.value.room.detail?.link;
    if (link == null || link.isEmpty) {
      ToastUtil.show(i18n('invalid_play_url'));
      return;
    }

    updatePlayer(
      qualites: [LivePlayQuality(quality: '原画')],
      currentQuality: 0,
      currentLineIndex: 0,
      playUrls: [link],
    );

    playerController.setPlayer(roomId: state.value.room.detail!.roomId!);
    updateRoom(success: true);

    unawaited(danmakuController.stopDanmaku());
  }

  void _restoreQualityAndLines() {
    updatePlayer(playUrls: [], currentLineIndex: 0, qualites: [], currentQuality: 0);
  }

  Future<void> switchRoom(LiveRoom newRoom) async {
    // Fence any room-detail/play-quality request that was started before this
    // switch. Its late result must not restore the previous room or socket.
    invalidateRoomLoad();
    playerController.invalidateLoad();
    _localMessageDeliveryQueue.cancelAll();
    final sameRoom =
        state.value.room.detail?.roomId == newRoom.roomId && state.value.room.detail?.platform == newRoom.platform;

    if (!sameRoom) {
      clearDanmakuMessages();
      await danmakuController.stopDanmaku();
    }

    final manager = GlobalPlayerService.instance.player;
    await manager.close();

    updateRoom(success: false, isLiving: true);
    await playerController.destroyPlayer();

    updatePlayer(hasUseDefaultResolution: false);
    updateUI(refreshKey: 0);

    final autoStartAsmr = Platform.isAndroid && SettingsService.to.app.enableAsmrSleepMode.v;
    _asmrSessionActive = autoStartAsmr;
    await LiveAudioService.configureSleepTimer(
      enabled: autoStartAsmr,
      minutes: SettingsService.to.app.asmrSleepMinutes.v,
    );
    updatePlayer(isCurrentRoomAudioOnly: autoStartAsmr);

    updateRoom(detail: newRoom);
    currentSite = Sites.of(newRoom.platform!);
    playerController.initSite(currentSite);

    if (!sameRoom) {
      await danmakuController.replaceDanmaku(currentSite.liveSite.getDanmaku());
    }

    await EmojiManager.instance.preload(newRoom.platform!);

    await onInitPlayerState(
      reloadDataType: newRoom.platform == Sites.bilibiliSite ? ReloadDataType.changeLine : ReloadDataType.refreash,
    );
  }

  Future<void> setResolution(ReloadDataType reloadDataType, int qualityIndex, int lineIndex) async {
    await playerController.switchStreamSelection(
      type: reloadDataType,
      qualityIndex: qualityIndex,
      lineIndex: lineIndex,
    );
  }

  Future<void> openNaviteAPP() async {
    var nativeUrl = "";
    var webUrl = "";
    final detail = state.value.room.detail;
    if (detail == null) return;

    switch (site) {
      case Sites.bilibiliSite:
        nativeUrl = "bilibili://live/${detail.roomId}";
        webUrl = "https://live.bilibili.com/${detail.roomId}";
        break;
      case Sites.douyinSite:
        final args = detail.danmakuData as DouyinDanmakuArgs;
        nativeUrl = "snssdk1128://webcast_room?room_id=${args.roomId}";
        webUrl = "https://live.douyin.com/${args.webRid}";
        break;
      case Sites.huyaSite:
        final args = detail.danmakuData as HuyaDanmakuArgs;
        nativeUrl =
            "yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide";
        webUrl = "https://www.huya.com/${detail.roomId}";
        break;
      case Sites.douyuSite:
        nativeUrl = "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${detail.roomId}";
        webUrl = "https://www.douyu.com/${detail.roomId}";
        break;
      case Sites.ccSite:
        nativeUrl = "cc://join-room/${detail.roomId}/${detail.userId}/";
        webUrl = "https://cc.163.com/${detail.roomId}";
        break;
      case Sites.twitchSite:
        nativeUrl = "https://www.twitch.tv/${detail.roomId}";
        webUrl = "https://www.twitch.tv/${detail.roomId}";
        break;
      case Sites.soopSite:
        nativeUrl = "https://play.sooplive.co.kr/${detail.roomId}";
        webUrl = nativeUrl;
        break;
      case Sites.kuaishouSite:
        nativeUrl =
            "kwai://liveaggregatesquare?liveStreamId=${detail.link}&recoStreamId=${detail.link}&recoLiveStreamId=${detail.link}&liveSquareSource=28&path=/rest/n/live/feed/sharePage/slide/more&mt_product=H5_OUTSIDE_CLIENT_SHARE";
        webUrl = "https://live.kuaishou.com/u/${detail.roomId}";
        break;
    }

    try {
      if (Platform.isAndroid) {
        await launchUrlString(nativeUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      ToastUtil.show(i18n('open_app_failed_fallback_browser'));
      await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> startCatchUp({required String catchUpUrl, int? startTime, int? endTime}) async {
    final currentRoom = state.value.room.detail;
    if (currentRoom == null) return;

    final updatedRoom = currentRoom.copyWith(
      catchUpUrl: catchUpUrl,
      isCatchUp: true,
      catchUpStart: startTime,
      catchUpEnd: endTime,
    );

    updateRoom(detail: updatedRoom);
    await _switchToUrl(catchUpUrl);
  }

  Future<void> _switchToUrl(String url) async {
    updateRoom(success: false);
    updatePlayer(playUrls: [url], currentLineIndex: 0);
    await playerController.setPlayer(roomId: state.value.room.detail!.roomId!);
    updateRoom(success: true);
  }

  void setNormalScreen() => updateUI(screenMode: VideoMode.normal);
  void setWidescreen() => updateUI(screenMode: VideoMode.widescreen);
  void setFullScreen() => updateUI(screenMode: VideoMode.fullscreen);

  /// Hides media_kit's native surface before opening the recorder route.
  ///
  /// Keeping the live route mounted preserves playback and room state.  The
  /// video layer policy decides whether the native texture is retained
  /// (Android) or detached (Windows). Restoration belongs to the route
  /// observer, which waits for the recorder route's reverse
  /// transition to finish before attaching a Windows texture again.
  Future<void> openRecordCenter() async {
    updateUI(displayVideoLayer: false);
    await SchedulerBinding.instance.endOfFrame;
    try {
      await Get.toNamed(RoutePath.kRecordPage);
    } catch (_) {
      // A failed navigation never reaches the observer's didPop callback.
      if (!isClosed) {
        updateUI(displayVideoLayer: true);
      }
      rethrow;
    }
  }

  bool takeSuppressAppFloatingOnNextPop() {
    final suppress = _suppressAppFloatingOnNextPop;
    _suppressAppFloatingOnNextPop = false;
    return suppress;
  }

  void prepareAppFloating({Future<void>? routeUnmounted}) {
    _floatingResourcesReleased = false;
    final manager = GlobalPlayerService.instance.player;
    final current = state.value;
    final detail = current.room.detail;
    manager.prepareAppFloating(
      onClose: () async {
        // A popped route may remain mounted for its reverse transition. Its
        // Obx widgets must unsubscribe before this controller closes Rx state.
        if (routeUnmounted != null) await routeUnmounted;
        await disposeAppFloatingResources();
      },
      session: detail == null
          ? null
          : RoomSessionSnapshot(
              room: detail,
              qualities: List<LivePlayQuality>.unmodifiable(current.player.qualites),
              currentQuality: current.player.currentQuality,
              playUrls: List<String>.unmodifiable(current.player.playUrls),
              currentLineIndex: current.player.currentLineIndex,
              headers: Map<String, String>.unmodifiable(current.player.videoController?.headers ?? const {}),
              isAudioOnly: manager.desiredAudioOnlyMode,
              isLiving: current.room.isLiving,
              dataSource: current.player.playUrlSafe,
              hasUseDefaultResolution: current.player.hasUseDefaultResolution,
            ),
    );
  }

  Future<void> disposeAppFloatingResources() async {
    if (_floatingResourcesReleased) return;
    _floatingResourcesReleased = true;

    final videoController = state.value.player.videoController;
    await _disposeAppFloatingResourcesAsync(videoController);
  }

  Future<void> _disposeAppFloatingResourcesAsync(VideoController? videoController) async {
    await danmakuController.stopDanmaku();
    videoController?.dispose();
    if (_ownerClosed) {
      _releaseChildControllers();
      _closeReactiveState();
    }
  }

  void _releaseChildControllers() {
    if (_childControllersReleased) return;
    _childControllersReleased = true;
    Get.delete<TimerController>(tag: 'timer-$_controllerTag', force: true);
    Get.delete<DanmakuController>(tag: 'danmaku-$_controllerTag', force: true);
    Get.delete<PlayerController>(tag: 'player-$_controllerTag', force: true);
  }

  void _closeReactiveState() {
    if (_reactiveStateClosed) return;
    _reactiveStateClosed = true;
    state.close();
  }

  @override
  void onClose() {
    _ownerClosed = true;
    _roomLoadEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    _pipStateWorker?.dispose();
    _screenKeepOnWorker?.dispose();
    _danmakuPresentationRecovery.dispose();
    clearSuperChats();
    playerController.invalidateLoad();
    _localGiftEffectTimer?.cancel();
    _localMessageDeliveryQueue.dispose();
    _danmakuFlushTimer?.cancel();
    _pendingDanmakuMessages.clear();
    tabController.dispose();

    final keepForAppFloating = GlobalPlayerService.instance.player.shouldKeepDanmakuForAppFloating;
    if (!keepForAppFloating) {
      unawaited(disposeAppFloatingResources());
      _releaseChildControllers();
      _closeReactiveState();
    }
    super.onClose();
  }
}
