import 'dart:io';
import 'dart:async';
import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/plugins/emoji_manager.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/core/danmaku/douyin_danmaku.dart';
import 'package:pure_live/modules/live_play/states/ui_state.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/modules/live_play/states/room_state.dart';
import 'package:pure_live/modules/live_play/states/player_state.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/widgets/danmaku_list_view.dart';
import 'package:pure_live/modules/live_play/local_interaction_controller.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';
import 'package:pure_live/modules/live_play/controllers/timer_controller.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/modules/live_play/controllers/danmaku_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/player/core/live_audio_service.dart';

// live_play_controller.dart

class LivePlayController extends GetxController with GetSingleTickerProviderStateMixin {
  LivePlayController({required this.room, required this.site});

  final String site;
  final LiveRoom room;

  late final TimerController timerController;
  late final DanmakuController danmakuController;
  late final PlayerController playerController;

  final RecorderController recorderController = Get.find<RecorderController>();
  final LocalInteractionController localInteractionController = Get.find<LocalInteractionController>();

  final Rx<LivePlayState> state = const LivePlayState().obs;
  final RxList<LiveMessage> danmakuMessages = <LiveMessage>[].obs;
  final Rxn<LiveMessage> localGiftEffect = Rxn<LiveMessage>();

  late Site currentSite;
  late TabController tabController;

  final List<String> tabs = [i18n('danmaku_list'), i18n('danmaku_settings'), i18n('block_list')];

  bool _floatingResourcesReleased = false;
  bool _asmrSessionActive = false;
  Timer? _localGiftEffectTimer;
  late final String _controllerTag;

  @override
  void onInit() {
    super.onInit();
    _controllerTag = '${identityHashCode(this)}';
    currentSite = Sites.of(site);

    final autoStartAsmr = Platform.isAndroid && SettingsService.to.app.enableAsmrSleepMode.v;
    _asmrSessionActive = autoStartAsmr;
    state.value = LivePlayState(
      room: RoomState(detail: room),
      // ASMR is the only automatic audio-only entry point. Manual headphone
      // switching is scoped to the current room and is never persisted.
      player: PlayerState(isCurrentRoomAudioOnly: autoStartAsmr),
      ui: UIState(closeTimes: 60, closeTimeFlag: false),
    );
    unawaited(
      LiveAudioService.configureSleepTimer(enabled: autoStartAsmr, minutes: SettingsService.to.app.asmrSleepMinutes.v),
    );

    _initControllers();
    _initTab();
    Future.microtask(_initCore);
  }

  void _initControllers() {
    timerController = Get.put(TimerController(onEnded: _onRoomPlaybackTimerEnded), tag: 'timer-$_controllerTag');
    danmakuController = Get.put(DanmakuController(this), tag: 'danmaku-$_controllerTag');
    playerController = Get.put(PlayerController(this), tag: 'player-$_controllerTag');

    playerController.initSite(currentSite);

    danmakuController.initDanmaku(currentSite.liveSite.getDanmaku());
  }

  void _initTab() {
    tabController = TabController(length: tabs.length, vsync: this);
  }

  Future<void> _initCore() async {
    _initBackInterceptor();
    await _preloadEmoji();
    await onInitPlayerState();
  }

  void _initBackInterceptor() {
    if (Platform.isAndroid) {
      BackButtonInterceptor.add(myInterceptor, zIndex: 1, name: "live_play_page");
    }
  }

  Future<void> _preloadEmoji() async {
    emojiCache.clear();
    await EmojiManager().preload(site);
  }

  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (state.value.ui.isMenuOpen) {
      Navigator.of(Get.context!).pop();
      updateUI(isMenuOpen: false);
      return true;
    }
    if (GlobalPlayerState.to.isFullscreen.value) {
      setNormalScreen();
      state.value.player.videoController?.exitFullScreen();
      return true;
    }

    state.value.player.videoController?.clearListener();
    return false;
  }

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

  void updatePlayer({
    VideoController? videoController,
    List<LivePlayQuality>? qualites,
    int? currentQuality,
    List<String>? playUrls,
    int? currentLineIndex,
    bool? isCurrentRoomAudioOnly,
    bool? hasUseDefaultResolution,
  }) {
    state.value = state.value.copyWith(
      player: state.value.player.copyWith(
        videoController: videoController,
        qualites: qualites,
        currentQuality: currentQuality,
        playUrls: playUrls,
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

  void updateDanmaku({List<LiveMessage>? messages, String? currentDanmakuRoomId}) {
    if (messages != null) {
      danmakuMessages.assignAll(messages);
    }
    state.value = state.value.copyWith(
      danmaku: state.value.danmaku.copyWith(messages: messages, currentDanmakuRoomId: currentDanmakuRoomId),
    );
  }

  void addDanmakuMessage(LiveMessage msg) {
    final currentMessages = List<LiveMessage>.from(danmakuMessages);
    if (currentMessages.length >= 500) {
      currentMessages.removeRange(0, currentMessages.length - 499);
    }
    currentMessages.add(msg);
    updateDanmaku(messages: currentMessages);
  }

  Future<void> _onRoomPlaybackTimerEnded() async {
    updateUI(closeTimeFlag: false);
    await GlobalPlayerService.instance.playerManager.pause();
    await LiveAudioService.stop();
    ToastUtil.show(i18n('room_playback_timer_finished'));
  }

  void updateRuntimeAudience(dynamic value) {
    final rawValue = value?.toString().trim() ?? '';
    if (!RegExp(r'[0-9]').hasMatch(rawValue)) return;
    final count = LiveRoom.parseAudienceNumber(rawValue);
    final detail = state.value.room.detail;
    if (detail == null) return;
    final text = count.toString();
    final isPopularityHeartbeat = detail.platform == Sites.bilibiliSite;
    updateRoom(
      detail: detail.copyWith(
        watching: text,
        popularity: isPopularityHeartbeat ? text : detail.popularity,
        onlineViewers: isPopularityHeartbeat ? detail.onlineViewers : text,
        audienceMetricType: isPopularityHeartbeat ? AudienceMetricType.popularity : AudienceMetricType.onlineViewers,
      ),
    );
  }

  void emitLocalMessage(LiveMessage msg, {required bool showAsDanmaku}) {
    if (!localInteractionController.enabled.v) return;
    addDanmakuMessage(msg);
    if (showAsDanmaku) {
      state.value.player.videoController?.sendDanmaku(msg);
    }
    if (msg.type == LiveMessageType.gift && localInteractionController.enableGiftEffects.v) {
      localGiftEffect.v = msg;
      _localGiftEffectTimer?.cancel();
      _localGiftEffectTimer = Timer(const Duration(seconds: 3), () => localGiftEffect.v = null);
    }
  }

  /// Applies the headphone action to this room only. Restoring video also
  /// ends an automatically started ASMR timer, while manually entering audio
  /// mode does not implicitly create a sleep session.
  Future<void> setCurrentRoomAudioOnlyFromUser(bool value) async {
    if (!value && _asmrSessionActive) {
      _asmrSessionActive = false;
      await LiveAudioService.configureSleepTimer(enabled: false, minutes: SettingsService.to.app.asmrSleepMinutes.v);
    }
    await playerController.changeCurrentRoomAudioOnly(value);
  }

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
    updateDanmaku(messages: []);
  }

  void updateDanmakuRoomId(String? roomId) {
    updateDanmaku(currentDanmakuRoomId: roomId);
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
    final roomId = state.value.room.detail?.roomId;
    if (roomId == null) return LiveRoom();

    updateRoom(isLoading: true, loadError: null);

    try {
      final liveRoom = await currentSite.liveSite.getRoomDetail(
        roomId: roomId,
        platform: state.value.room.detail!.platform!,
      );

      if (currentSite.id == Sites.iptvSite) {
        updateRoom(detail: liveRoom);
        _initIptvPlayer();
        return liveRoom;
      }

      _handleCurrentLineAndQuality(reloadDataType, line, isReCalculate);

      updateRoom(detail: liveRoom);
      updateUI(refreshKey: state.value.ui.refreshKey + 1);

      if (liveRoom.liveStatus == LiveStatus.unknown) {
        _handleUnknownStatus();
        return liveRoom;
      }

      final liveStatus = liveRoom.status == true || liveRoom.isRecord == true;

      if (liveStatus) {
        await _handleLiveRoom(liveRoom);
      } else {
        _handleNotLiveRoom(liveRoom);
      }

      updateRoom(isLoading: false);
      return liveRoom;
    } catch (e) {
      updateRoom(isLoading: false, loadError: e.toString());
      ToastUtil.show(i18n('get_room_info_failed_retry'));
      return LiveRoom();
    }
  }

  Future<void> _handleLiveRoom(LiveRoom liveRoom) async {
    updateRoom(isLiving: true, success: false);

    try {
      await playerController.getPlayQualites();

      if (liveRoom.platform != Sites.iptvSite) {
        SettingsService.to.history.addRoomToHistory(liveRoom);
        SettingsService.to.fav.updateRoom(liveRoom);
        EventBus.instance.emit('refresh_room_changed', true);
      }

      const except = [Sites.kuaishouSite, Sites.iptvSite, Sites.ccSite];
      final danmakuSettings = SettingsService.to.danmaku;
      final shouldConnectDanmaku = danmakuSettings.enableDanmakuDisplay.v || danmakuSettings.enablePipDanmaku.v;
      if (!except.contains(liveRoom.platform) && shouldConnectDanmaku) {
        final needReconnect = danmakuController.needReconnect(liveRoom);
        if (needReconnect) {
          danmakuController.stopDanmaku();
          danmakuController.setupDanmaku();
          danmakuController.liveDanmaku.start(liveRoom.danmakuData);
          updateDanmakuRoomId(liveRoom.roomId);
        }
      }
    } catch (error, stackTrace) {
      developer.log(
        'Live room initialization failed (${error.runtimeType})',
        name: 'LivePlayController',
        stackTrace: stackTrace,
      );
      updateRoom(success: false);
    }
  }

  void _handleNotLiveRoom(LiveRoom liveRoom) {
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

    if (SettingsService.to.danmaku.enableDanmakuDisplay.v) {
      danmakuController.stopDanmaku();
    }
  }

  void _restoreQualityAndLines() {
    updatePlayer(playUrls: [], currentLineIndex: 0, qualites: [], currentQuality: 0);
  }

  Future<void> switchRoom(LiveRoom newRoom) async {
    final sameRoom =
        state.value.room.detail?.roomId == newRoom.roomId && state.value.room.detail?.platform == newRoom.platform;

    if (!sameRoom) {
      clearDanmakuMessages();
      if (SettingsService.to.danmaku.enableDanmakuDisplay.v) {
        danmakuController.stopDanmaku();
      }
      updateDanmakuRoomId(null);
    }

    final manager = GlobalPlayerService.instance.playerManager;
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
      danmakuController.initDanmaku(currentSite.liveSite.getDanmaku());
    }

    await EmojiManager.instance.preload(newRoom.platform!);

    await onInitPlayerState(
      reloadDataType: newRoom.platform == Sites.bilibiliSite ? ReloadDataType.changeLine : ReloadDataType.refreash,
    );
  }

  Future<void> setResolution(ReloadDataType reloadDataType, int qualityIndex, int lineIndex) async {
    await GlobalPlayerService.instance.playerManager.close();
    await playerController.destroyPlayer();

    updatePlayer(currentQuality: qualityIndex, currentLineIndex: lineIndex);

    await onInitPlayerState(reloadDataType: reloadDataType, line: lineIndex, isReCalculate: false);
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

  void prepareAppFloating() {
    GlobalPlayerService.instance.playerManager.prepareAppFloating(onClose: disposeAppFloatingResources);
    _floatingResourcesReleased = false;
  }

  void disposeAppFloatingResources() {
    if (_floatingResourcesReleased) return;
    _floatingResourcesReleased = true;

    if (SettingsService.to.danmaku.enableDanmakuDisplay.v) {
      danmakuController.stopDanmaku();
    }
    state.value.player.videoController?.dispose();
  }

  @override
  void onClose() {
    _localGiftEffectTimer?.cancel();
    tabController.dispose();

    if (Platform.isAndroid) {
      BackButtonInterceptor.removeByName("live_play_page");
    }

    if (!GlobalPlayerService.instance.playerManager.shouldKeepDanmakuForAppFloating) {
      disposeAppFloatingResources();
    }

    Get.delete<TimerController>(tag: 'timer-$_controllerTag', force: true);
    Get.delete<DanmakuController>(tag: 'danmaku-$_controllerTag', force: true);
    Get.delete<PlayerController>(tag: 'player-$_controllerTag', force: true);

    state.close();
    super.onClose();
  }
}
