import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;

import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/utils/event_bus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pure_live/shared/platforms/emoji_manager.dart';
import 'package:pure_live/shared/platforms/live_site.dart' show LiveStreamFacts;
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/core/player/core/playback_source.dart';
import 'package:pure_live/core/player/core/live_audio_service.dart';
import 'package:pure_live/domains/live/domain/live_player_facade.dart';
import 'package:pure_live/domains/live/presentation/playback/states/ui_state.dart';
import 'package:pure_live/domains/live/presentation/playback/states/player_state.dart';
import 'package:pure_live/core/stream/hls_source_query_policy.dart';
import 'package:pure_live/domains/live/presentation/playback/states/room_state.dart';
import 'package:pure_live/domains/live/presentation/playback/states/live_play_state.dart';
import 'package:pure_live/domains/recorder/presentation/pages/recorder/recorder_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/timer_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/services/room_external_opener.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/player_controller.dart';
import 'package:pure_live/core/config/app_settings_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/danmaku_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/danmaku_session_host.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/danmaku/danmaku_list_view.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/video_player/video_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/danmaku_presentation_recovery.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/local_interaction/local_interaction_controller.dart';
import 'package:pure_live/domains/live/presentation/playback/widgets/local_interaction/local_message_delivery_queue.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:pure_live/domains/live/data/favorite_room_controller.dart';
import 'package:pure_live/domains/live/data/history_controller.dart';

// live_play_controller.dart

typedef IptvPlayerStarter = Future<bool> Function(LiveRoom liveroom);

enum IptvPlaybackSwitchResult { started, superseded, failed }

@visibleForTesting
String roomStateMessage(LiveRoom room) {
  return switch (room.effectiveRestriction) {
    LiveRestriction.needsLogin => i18n('restriction_needs_login'),
    LiveRestriction.paid => i18n('restriction_paid'),
    LiveRestriction.subscribersOnly => i18n('restriction_subscribers_only'),
    LiveRestriction.private => i18n('restriction_private'),
    LiveRestriction.appOnly => i18n('restriction_app_only'),
    LiveRestriction.regionBlocked => i18n('restriction_region_blocked'),
    LiveRestriction.password => i18n('restriction_password'),
    LiveRestriction.adult => i18n('restriction_adult'),
    LiveRestriction.unplayable => i18n('restriction_unplayable'),
    LiveRestriction.none =>
      room.effectiveLiveStatus == LiveStatus.banned ? i18n('server_error_retry_later') : i18n('stream_not_live'),
  };
}

@visibleForTesting
String unknownRoomStatusMessage(LiveRoom? room) =>
    room != null && room.isRestricted ? roomStateMessage(room) : i18n('get_room_info_failed_retry');

class LivePlayController extends GetxController
    with GetSingleTickerProviderStateMixin, WidgetsBindingObserver
    implements DanmakuSessionHost, PlayerSessionHost {
  LivePlayController({required this.room, required this.site}) : _iptvPlayerStarter = null;

  @visibleForTesting
  LivePlayController.withIptvPlayerStarter(this._iptvPlayerStarter, {required this.room, required this.site});

  final String site;
  final LiveRoom room;
  final IptvPlayerStarter? _iptvPlayerStarter;

  late final TimerController timerController;
  late final DanmakuController danmakuController;
  late final PlayerController playerController;

  final RecorderController recorderController = Get.find<RecorderController>();
  final LocalInteractionController localInteractionController = Get.find<LocalInteractionController>();

  @override
  final Rx<LivePlayState> state = const LivePlayState().obs;
  final RxList<LiveMessage> danmakuMessages = <LiveMessage>[].obs;
  final _danmakuRemovals = StreamController<bool Function(LiveMessage)>.broadcast(sync: true);
  Stream<bool Function(LiveMessage)> get danmakuRemovals => _danmakuRemovals.stream;
  final RxInt danmakuPresentationRevision = 0.obs;
  final Rxn<LiveMessage> localGiftEffect = Rxn<LiveMessage>();
  final RxList<LiveSuperChatMessage> superChats = <LiveSuperChatMessage>[].obs;
  late Site currentSite;
  late TabController tabController;

  final List<String> tabs = [i18n('danmaku_list'), i18n('super_chat'), i18n('danmaku_settings'), i18n('block_list')];

  bool _floatingResourcesReleased = false;
  bool _ownerClosed = false;
  bool _externalOpenInFlight = false;
  bool _childControllersReleased = false;
  bool _reactiveStateClosed = false;
  bool _suppressAppFloatingOnNextPop = false;
  int _roomLoadEpoch = 0;
  int _iptvPlaybackEpoch = 0;
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

  /// Defensive conversion for the reentry snapshot's policies: the snapshot
  /// stores them as `Map<String, Object?>`, and a blind cast throws
  /// `_ConstMap is not Map<String, HlsSourceQueryPolicy>` on the hot path.

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
        sourceQueryPolicies: restored?.sourceQueryPolicies ?? const {},
        streamFacts: restored?.streamFacts ?? const {},
        ownedSource: restored?.ownedSource as OwnedPlaybackSource?,
        currentLineIndex: restored?.currentLineIndex ?? 0,
        isCurrentRoomAudioOnly: initialAudioOnly,
        hasUseDefaultResolution: restored?.hasUseDefaultResolution ?? false,
      ),
      ui: UIState(closeTimes: 60, closeTimeFlag: false),
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
    await EmojiManager().preload(site, Sites.danmakuCapability(site)?.parseDanmakuEmoji);
  }

  Future<void> _resumeCurrentRoomSession(RoomSessionSnapshot session) async {
    final controller = await playerController.attachCurrentSession(session);
    if (controller == null || isClosed) {
      // The native player disappeared between the floating-window tap and route
      // construction. Fall back to the normal bounded room initialization.
      await onInitPlayerState();
      return;
    }

    updateRoom(liveroom: session.room, isLiving: session.isLiving, success: true, isLoading: false, loadError: null);
    await _syncDanmakuConnection(session.room);
    unawaited(_refreshResumedRoomMetadata(session.room));
  }

  Future<void> _refreshResumedRoomMetadata(LiveRoom previous) async {
    final roomId = previous.roomId;
    final platform = previous.platform;
    if (roomId == null || platform == null) return;
    try {
      final fetched = await currentSite.liveSite.getRoomDetail(previous);
      if (isClosed) return;
      final current = state.value.room.detail;
      if (current?.roomId != roomId || current?.platform != platform) return;
      // A request-error fallback is pending, not a newer broadcast state.
      // Keep the attached player and its last known room while it plays.
      if (fetched.isLiveStatusPending) return;
      final refreshed = fetched.withAudienceFallbackFrom(current!);
      final isLiving = refreshed.isPlayableNow;
      updateRoom(liveroom: refreshed, isLiving: isLiving, success: true, isLoading: false);
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

  Future<void> getSuperChatMessage(LiveRoom liveroom, {required int loadEpoch}) async {
    if (!_isRoomLoadCurrent(loadEpoch, liveroom)) return;
    final liveSite = currentSite.liveSite;
    try {
      final sc = await liveSite.getSuperChatMessage(liveroom: liveroom);
      if (isClosed || _ownerClosed || !_isRoomLoadCurrent(loadEpoch, liveroom)) return;
      addBatchSuperChat(sc);
    } catch (e) {
      if (!isClosed && !_ownerClosed && _isRoomLoadCurrent(loadEpoch, liveroom)) {
        addSystemMessage(i18n('live_sc_read_failed'));
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

  /// A metadata retry on the same room is not a new paid-message session.
  /// Keep already delivered messages until they expire or the room changes.
  @visibleForTesting
  void beginRoomMetadataLoad() => updateRoom(isLoading: true, loadError: null);

  /// Restores the normal room presentation for one system-back attempt.
  ///
  /// The route-local PopScope owns whether the route can pop. Keeping teardown
  /// out of this pre-pop path prevents a failed gesture from leaving the room
  /// visible after its player listeners have already been removed.
  Future<void> exitPresentationForSystemBack() async {
    if (_handlingSystemBackPresentation || isClosed || _ownerClosed) return;
    _handlingSystemBackPresentation = true;

    final player = GlobalPlayerService.instance.player;
    final mode = state.value.ui.screenMode;
    final wasFullscreen = player.isSystemFullscreen.value || requiresSystemFullscreenExit(mode);
    try {
      setNormalScreen();
      player.isWindowFullscreen.value = false;

      if (wasFullscreen) {
        final videoController = state.value.player.videoController;
        if (videoController != null) {
          await videoController.exitFullScreen();
        } else {
          player.isSystemFullscreen.value = false;
        }
      } else {
        player.isSystemFullscreen.value = false;
      }
    } finally {
      player.isSystemFullscreen.value = false;
      player.isWindowFullscreen.value = false;
      _handlingSystemBackPresentation = false;
    }
  }

  Future<void> enterPipPresentation() async {
    final player = GlobalPlayerService.instance.player;
    if (player.isSystemFullscreen.value ||
        player.isWindowFullscreen.value ||
        state.value.ui.screenMode != VideoMode.normal) {
      await exitPresentationForSystemBack();
    }
    await player.enablePip();
  }

  @override
  void updateRoom({LiveRoom? liveroom, bool? isLiving, bool? success, bool? isLoading, String? loadError}) {
    state.value = state.value.copyWith(
      room: state.value.room.copyWith(
        detail: liveroom,
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
    Map<String, HlsSourceQueryPolicy>? sourceQueryPolicies,
    Map<String, LiveStreamFacts>? streamFacts,
    OwnedPlaybackSource? ownedSource,
    bool clearOwnedSource = false,
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
        sourceQueryPolicies: sourceQueryPolicies,
        streamFacts: streamFacts,
        ownedSource: ownedSource,
        clearOwnedSource: clearOwnedSource,
        currentLineIndex: currentLineIndex,
        isCurrentRoomAudioOnly: isCurrentRoomAudioOnly,
        hasUseDefaultResolution: hasUseDefaultResolution,
      ),
    );
  }

  void updateUI({VideoMode? screenMode, int? refreshKey, bool? isMenuOpen, int? closeTimes, bool? closeTimeFlag}) {
    state.value = state.value.copyWith(
      ui: state.value.ui.copyWith(
        screenMode: screenMode,
        refreshKey: refreshKey,
        isMenuOpen: isMenuOpen,
        closeTimes: closeTimes,
        closeTimeFlag: closeTimeFlag,
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
    if (!_danmakuRemovals.isClosed) _danmakuRemovals.add(predicate);
    _pendingDanmakuMessages.removeWhere(predicate);
    final next = danmakuMessages.where((message) => !predicate(message)).toList(growable: false);
    if (next.length != danmakuMessages.length) danmakuMessages.assignAll(next);
  }

  @override
  void removeRetractedMessages(LiveRetraction target) {
    if (isClosed) return;
    removeDanmakuWhere(
      (message) => target.matches(userId: message.userId, userName: message.userName, messageId: message.messageId),
    );
    if (target.all) {
      clearRenderedDanmaku();
    } else {
      state.value.player.videoController?.retractDanmaku(
        (message) => target.matches(userId: message.userId, userName: message.userName, messageId: message.messageId),
      );
    }
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
    updateRoom(liveroom: candidate.withAudienceFallbackFrom(detail));
  }

  void emitLocalMessage(LiveMessage msg, {required bool showAsDanmaku, Duration delay = Duration.zero}) {
    if (!localInteractionController.enabled.v) return;
    final targetRoom = state.value.room.detail;
    if (targetRoom == null) return;
    _localMessageDeliveryQueue.schedule(
      LocalMessageDelivery(
        message: msg,
        showAsDanmaku: showAsDanmaku,
        roomId: targetRoom.roomId,
        platform: targetRoom.platform,
      ),
      delay: delay,
    );
  }

  void _deliverLocalMessage(LocalMessageDelivery delivery) {
    final currentRoom = state.value.room.detail;
    if (isClosed || _ownerClosed || currentRoom == null || !delivery.matchesRoom(liveroom: currentRoom)) {
      return;
    }
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

  /// Commits the timer editor draft as one state/timer transaction.
  ///
  /// Applying duration and enabled state through the two legacy setters can
  /// restart an existing timer twice, while changing the switch inside a
  /// dialog used to mutate the live session even when the user cancelled.
  void applyRoomPlaybackTimer({required bool enabled, required int minutes}) {
    final normalizedMinutes = minutes.clamp(1, AppSettingsController.maxSleepMinutes).toInt();
    updateUI(closeTimes: normalizedMinutes, closeTimeFlag: enabled);
    timerController.toggleTimer(enabled, normalizedMinutes);
  }

  Future<LiveRoom> onInitPlayerState({
    ReloadDataType reloadDataType = ReloadDataType.refresh,
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

    beginRoomMetadataLoad();

    try {
      final fetchedRoom = await currentSite.liveSite.getRoomDetail(requestedRoom);

      var liveRoom = fetchedRoom.withAudienceFallbackFrom(requestedRoom);
      liveRoom = liveRoom.fillFromDetail(requestedRoom);
      if (!_isRoomLoadCurrent(loadEpoch, liveRoom)) return liveRoom;
      updateRoom(liveroom: liveRoom);

      if (currentSite.id == Sites.iptvSite) {
        await _initIptvPlayer(liveRoom, loadEpoch: loadEpoch);
        return liveRoom;
      }

      _handleCurrentLineAndQuality(reloadDataType, line, isReCalculate);

      if (liveRoom.isLiveStatusPending) {
        _handleUnknownStatus();
        return liveRoom;
      }

      final liveStatus = liveRoom.isPlayableNow;

      if (liveStatus) {
        unawaited(getSuperChatMessage(liveRoom, loadEpoch: loadEpoch));
        await _handleLiveRoom(liveRoom, loadEpoch: loadEpoch);
      } else {
        await _handleNotLiveRoom(liveRoom);
      }

      updateRoom(isLoading: false);
      return liveRoom;
    } catch (e) {
      if (!_isRoomLoadCurrent(loadEpoch, requestedRoom)) return LiveRoom();
      developer.log('Room load failed: $e', name: 'LivePlayController');
      updateRoom(isLoading: false, loadError: e.toString());
      ToastUtil.show(i18n('get_room_info_failed_retry'));
      return LiveRoom();
    }
  }

  bool _isRoomLoadCurrent(int epoch, LiveRoom liveroom) {
    final roomId = liveroom.roomId ?? '';
    final platform = liveroom.platform ?? '';
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
        await _addRoomToHistory(liveRoom);
        await _updateFavoriteRoomSnapshot(liveRoom);
      }

      await _syncDanmakuConnection(liveRoom);
    } catch (error, stackTrace) {
      developer.log(
        'Live room initialization failed (${error.runtimeType})',
        name: 'LivePlayController',
        stackTrace: stackTrace,
      );
      if (liveRoom.isRestricted) {
        ToastUtil.show(roomStateMessage(liveRoom));
      }
      updateRoom(success: false);
    }
  }

  Future<void> _syncDanmakuConnection(LiveRoom liveRoom) async {
    const except = [Sites.iptvSite, Sites.ccSite];
    final danmakuSettings = SettingsService.to.danmaku;
    final shouldConnectDanmaku = !danmakuSettings.hideDanmaku.v;
    if (!except.contains(liveRoom.platform) && shouldConnectDanmaku) {
      await danmakuController.connectRoom(liveRoom);
    } else {
      await danmakuController.stopDanmaku();
    }
  }

  Future<void> _handleNotLiveRoom(LiveRoom liveRoom) async {
    unawaited(danmakuController.stopDanmaku());
    clearSuperChats();
    updateRoom(success: false, isLiving: false);
    setNormalScreen();
    GlobalPlayerService.instance.player.isSystemFullscreen.value = false;
    GlobalPlayerService.instance.player.isWindowFullscreen.value = false;
    if (liveRoom.platform != Sites.iptvSite) {
      await _updateFavoriteRoomSnapshot(liveRoom);
    }
    ToastUtil.show(roomStateMessage(liveRoom));
    _restoreQualityAndLines();
  }

  Future<void> _updateFavoriteRoomSnapshot(LiveRoom liveroom) async {
    try {
      if (await FavoriteRoomController.to.updateRoomDurably(liveroom)) {
        EventBus.instance.emit('refresh_room_changed', true);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Persist favorite room refresh failed',
        name: 'LivePlayController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _addRoomToHistory(LiveRoom liveroom) async {
    try {
      await HistoryController.to.addRoomToHistoryDurably(liveroom);
    } catch (error, stackTrace) {
      developer.log('Persist room history failed', name: 'LivePlayController', error: error, stackTrace: stackTrace);
    }
  }

  void _handleUnknownStatus() {
    settleUnknownRoomMetadata();
    final message = unknownRoomStatusMessage(state.value.room.detail);
    if (state.value.player.hasPlaybackSource) {
      if (Get.currentRoute == '/live_play') ToastUtil.show(message);
      return;
    }
    unawaited(danmakuController.stopDanmaku());
    if (Get.currentRoute == '/live_play') {
      ToastUtil.show(message);
      setNormalScreen();
      GlobalPlayerService.instance.player.isSystemFullscreen.value = false;
      GlobalPlayerService.instance.player.isWindowFullscreen.value = false;
    }
  }

  @visibleForTesting
  void settleUnknownRoomMetadata() {
    final hasPlaybackSource = state.value.player.hasPlaybackSource;
    updateRoom(
      isLiving: hasPlaybackSource,
      success: hasPlaybackSource,
      isLoading: false,
      loadError: unknownRoomStatusMessage(state.value.room.detail),
    );
  }

  void _handleCurrentLineAndQuality(ReloadDataType reloadDataType, int line, bool isReCalculate) {
    if (reloadDataType == ReloadDataType.changeLine && isReCalculate && state.value.player.hasPlaybackSource) {
      final newLineIndex = (state.value.player.currentLineIndex + 1) % state.value.player.lineCount;
      updatePlayer(currentLineIndex: newLineIndex);
    }
  }

  Future<IptvPlaybackSwitchResult> _initIptvPlayer(LiveRoom liveRoom, {required int loadEpoch}) async {
    final link = liveRoom.link?.trim() ?? '';
    if (link.isEmpty || liveRoom.normalizedRoomId.isEmpty) {
      if (_isRoomLoadCurrent(loadEpoch, liveRoom)) {
        updateRoom(success: false, isLoading: false, loadError: i18n('invalid_play_url'));
        ToastUtil.show(i18n('invalid_play_url'));
      }
      return IptvPlaybackSwitchResult.failed;
    }

    updatePlayer(qualites: [LivePlayQuality(quality: '原画')], currentQuality: 0, currentLineIndex: 0);

    final started = await _switchToUrl(link, expectedRoom: liveRoom);
    if (!_isRoomLoadCurrent(loadEpoch, liveRoom)) {
      return IptvPlaybackSwitchResult.superseded;
    }

    try {
      await danmakuController.stopDanmaku();
    } catch (error, stackTrace) {
      developer.log('IPTV danmaku cleanup failed', name: 'LivePlayController', error: error, stackTrace: stackTrace);
    }
    return started;
  }

  void _restoreQualityAndLines() {
    updatePlayer(playUrls: [], currentLineIndex: 0, qualites: [], currentQuality: 0);
  }

  /// Closing the old native player also ends ownership of its selected media.
  /// A failed detail lookup for the next room must not reuse that old source.
  @visibleForTesting
  void clearClosedPlaybackSource() => _restoreQualityAndLines();

  Future<void> switchRoom(LiveRoom newRoom) async {
    // Fence any room-detail/play-quality request that was started before this
    // switch. Its late result must not restore the previous room or socket.
    invalidateRoomLoad();
    _iptvPlaybackEpoch++;
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
    clearClosedPlaybackSource();
    clearSuperChats();

    updatePlayer(hasUseDefaultResolution: false);
    updateUI(refreshKey: 0);

    final autoStartAsmr = Platform.isAndroid && SettingsService.to.app.enableAsmrSleepMode.v;
    _asmrSessionActive = autoStartAsmr;
    await LiveAudioService.configureSleepTimer(
      enabled: autoStartAsmr,
      minutes: SettingsService.to.app.asmrSleepMinutes.v,
    );
    updatePlayer(isCurrentRoomAudioOnly: autoStartAsmr);

    updateRoom(liveroom: newRoom);
    currentSite = Sites.of(newRoom.platform!);
    playerController.initSite(currentSite);

    if (!sameRoom) {
      await danmakuController.replaceDanmaku(currentSite.liveSite.getDanmaku());
    }

    await EmojiManager.instance.preload(
      newRoom.platform!,
      Sites.danmakuCapability(newRoom.platform)?.parseDanmakuEmoji,
    );

    await onInitPlayerState(
      reloadDataType: newRoom.platform == Sites.bilibiliSite ? ReloadDataType.changeLine : ReloadDataType.refresh,
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
    if (_ownerClosed || _externalOpenInFlight) return;
    final detail = state.value.room.detail;
    if (detail == null) return;
    final roomId = detail.roomId;
    bool isCurrent() => !_ownerClosed && identical(state.value.room.detail, detail) && detail.roomId == roomId;
    _externalOpenInFlight = true;
    try {
      final result = await RoomExternalOpener.open(
        site: site,
        liveroom: detail,
        android: Platform.isAndroid,
        isCurrent: isCurrent,
        onBrowserFallback: () => ToastUtil.show(i18n('open_app_failed_fallback_browser')),
      );
      if (!isCurrent()) return;
      if (result == RoomExternalOpenResult.unavailable) {
        ToastUtil.show(i18n('open_room_external_unavailable'));
      } else if (result == RoomExternalOpenResult.failed) {
        ToastUtil.show(i18n('open_room_external_failed'));
      }
    } finally {
      _externalOpenInFlight = false;
    }
  }

  Future<IptvPlaybackSwitchResult> startCatchUp({required String catchUpUrl, int? startTime, int? endTime}) async {
    final currentRoom = state.value.room.detail;
    final normalizedUrl = catchUpUrl.trim();
    if (currentRoom == null || currentRoom.normalizedRoomId.isEmpty || normalizedUrl.isEmpty) {
      return IptvPlaybackSwitchResult.failed;
    }

    final updatedRoom = currentRoom.copyWith(
      catchUpUrl: normalizedUrl,
      isCatchUp: true,
      catchUpStart: startTime,
      catchUpEnd: endTime,
    );

    updateRoom(liveroom: updatedRoom);
    return _switchToUrl(normalizedUrl, expectedRoom: updatedRoom);
  }

  Future<IptvPlaybackSwitchResult> returnToLive() async {
    final currentRoom = state.value.room.detail;
    final liveUrl = currentRoom?.link?.trim() ?? '';
    if (currentRoom == null || currentRoom.normalizedRoomId.isEmpty || liveUrl.isEmpty) {
      return IptvPlaybackSwitchResult.failed;
    }
    if (!currentRoom.isCatchUpActive) {
      return IptvPlaybackSwitchResult.started;
    }

    final liveRoom = currentRoom.withoutCatchUp();
    updateRoom(liveroom: liveRoom);
    return _switchToUrl(liveUrl, expectedRoom: liveRoom);
  }

  Future<IptvPlaybackSwitchResult> _switchToUrl(String url, {required LiveRoom expectedRoom}) async {
    final playbackEpoch = ++_iptvPlaybackEpoch;
    updateRoom(success: false, isLoading: true, loadError: null);
    updatePlayer(playUrls: [url], currentLineIndex: 0);
    try {
      final injectedStarter = _iptvPlayerStarter;
      final started = injectedStarter != null
          ? await injectedStarter(expectedRoom)
          : await playerController.setDirectPlayer(liveroom: expectedRoom, site: currentSite) != null;
      if (!_isIptvPlaybackCurrent(playbackEpoch, expectedRoom)) {
        return IptvPlaybackSwitchResult.superseded;
      }
      if (!started) {
        updateRoom(success: false, isLoading: false, loadError: i18n('play_video_failed'));
        return IptvPlaybackSwitchResult.failed;
      }
      updateRoom(success: true, isLoading: false, loadError: null);
      return IptvPlaybackSwitchResult.started;
    } catch (error, stackTrace) {
      developer.log(
        'IPTV direct player start failed',
        name: 'LivePlayController',
        error: error,
        stackTrace: stackTrace,
      );
      if (!_isIptvPlaybackCurrent(playbackEpoch, expectedRoom)) {
        return IptvPlaybackSwitchResult.superseded;
      }
      updateRoom(success: false, isLoading: false, loadError: i18n('play_video_failed'));
      rethrow;
    }
  }

  bool _isIptvPlaybackCurrent(int playbackEpoch, LiveRoom expectedRoom) {
    final currentRoom = state.value.room.detail;
    return !_ownerClosed &&
        !isClosed &&
        playbackEpoch == _iptvPlaybackEpoch &&
        currentRoom?.normalizedRoomId == expectedRoom.normalizedRoomId &&
        currentRoom?.normalizedPlatformId == expectedRoom.normalizedPlatformId &&
        currentRoom?.catchUpUrl == expectedRoom.catchUpUrl;
  }

  void setNormalScreen() => updateUI(screenMode: VideoMode.normal);
  void setWidescreen() => updateUI(screenMode: VideoMode.widescreen);
  void setFullScreen() => updateUI(screenMode: VideoMode.fullscreen);
  void setPortraitFullScreen() => updateUI(screenMode: VideoMode.portraitFullscreen);

  /// Hides media_kit's native surface before opening the recorder route.
  ///
  /// Keeping the live route mounted preserves playback and room state.  The
  /// video layer policy decides whether the native texture is retained
  /// (Android) or detached (Windows). Restoration belongs to the route
  /// observer, which waits for the recorder route's reverse
  /// transition to finish before attaching a Windows texture again.
  Future<void> openRecordCenter() async {
    await Get.toNamed(RoutePath.kRecordPage);
  }

  bool takeSuppressAppFloatingOnNextPop() {
    final suppress = _suppressAppFloatingOnNextPop;
    _suppressAppFloatingOnNextPop = false;
    return suppress;
  }

  /// Whether this room hands the video (and therefore the danmaku session) to
  /// the in-app small window. Mirrors the facade, which owns the floating
  /// window's lifetime: while it is prepared or showing, the route's pop must
  /// not tear the danmaku session down.
  @override
  bool get keepsDanmakuForFloating =>
      _floatingHandoffPrepared || GlobalPlayerService.instance.player.shouldKeepDanmakuForAppFloating;

  /// Sticky record of "this room is being handed to the small window".
  ///
  /// The facade's answer is the live truth, but it is read while the route is
  /// being torn down and GetX deletes this room's controllers in the same turn;
  /// a keep decision that flips to false for one instant stops the danmaku
  /// session for good. Prepared once, cleared when the window is closed for
  /// real, so the answer cannot be missed by ordering.
  bool _floatingHandoffPrepared = false;

  void prepareAppFloating({Future<void>? routeUnmounted}) {
    _floatingResourcesReleased = false;
    _floatingHandoffPrepared = true;
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
              sourceQueryPolicies: Map<String, HlsSourceQueryPolicy>.unmodifiable(current.player.sourceQueryPolicies),
              streamFacts: Map<String, LiveStreamFacts>.unmodifiable(current.player.streamFacts),
              ownedSource: current.player.ownedSource,
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
    _floatingHandoffPrepared = false;

    final videoController = state.value.player.videoController;
    await _disposeAppFloatingResourcesAsync(videoController);
  }

  Future<void> _disposeNormalRouteResources() async {
    try {
      // A normal route pop is not a floating-player handoff. Explicitly stop
      // the global source so decoder/network workers do not survive on the
      // home page. LivePlayerFacade keeps a short reopen grace window and then
      // releases the native player completely.
      await GlobalPlayerService.instance.player.close();
    } finally {
      try {
        await disposeAppFloatingResources();
      } finally {
        _releaseChildControllers();
        _closeReactiveState();
      }
    }
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
    _iptvPlaybackEpoch++;
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
    unawaited(_danmakuRemovals.close());

    final keepForAppFloating = GlobalPlayerService.instance.player.shouldKeepDanmakuForAppFloating;
    if (!keepForAppFloating) {
      unawaited(_disposeNormalRouteResources());
    }
    super.onClose();
  }
}
