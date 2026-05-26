import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/huya_site.dart';
import 'widgets/video_player/video_controller.dart';
import 'package:pure_live/plugins/emoji_manager.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pure_live/core/danmaku/huya_danmaku.dart';
import 'package:pure_live/modules/live_play/load_type.dart';
import 'package:pure_live/core/danmaku/douyin_danmaku.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/modules/live_play/player_state.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:pure_live/recorder/pages/recorder/recorder_controller.dart';

enum VideoMode { normal, widescreen, fullscreen }

class LivePlayController extends StateController with GetSingleTickerProviderStateMixin {
  LivePlayController({required this.room, required this.site});

  final String site;
  final LiveRoom room;

  final RecorderController recorderController = Get.find<RecorderController>();
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown);

  late Site currentSite;
  late LiveDanmaku liveDanmaku;
  late TabController tabController;

  final settings = Get.find<SettingsService>();

  final List<String> tabs = [i18n('danmaku_list'), i18n('danmaku_settings'), i18n('block_list')];

  final messages = <LiveMessage>[].obs;
  final isLiving = true.obs;
  final videoController = Rx<VideoController?>(null);

  final detail = Rx<LiveRoom?>(null);
  final success = false.obs;

  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();
  final currentQuality = 0.obs;

  RxList<String> playUrls = RxList<String>();
  final currentLineIndex = 0.obs;

  var closeTimes = 240.obs;
  var closeTimeFlag = false.obs;

  final screenMode = VideoMode.normal.obs;
  final refreshKey = 0.obs;

  bool hasUseDefaultResolution = false;

  bool get _hasRoom => detail.value != null;

  LivePlayQuality get _qualitySafe {
    if (qualites.isEmpty) {
      return LivePlayQuality(quality: '原画');
    }
    final i = currentQuality.value;
    if (i < 0 || i >= qualites.length) return qualites.first;
    return qualites[i];
  }

  String get _playUrlSafe {
    if (playUrls.isEmpty) return '';
    final i = currentLineIndex.value;
    if (i < 0 || i >= playUrls.length) return playUrls.first;
    return playUrls[i];
  }

  @override
  void onInit() {
    super.onInit();
    _initCore();
  }

  void _initCore() {
    _initState();
    _initTab();
    _initBackInterceptor();
    _initDebounce();
    _initTimer();
    _preloadEmoji();
    _initPlayer();
  }

  void _initState() {
    detail.value = room;
    currentSite = Sites.of(site);
    if (settings.enableDanmakuDisplay.value) {
      liveDanmaku = currentSite.liveSite.getDanmaku();
    }
  }

  void _initTab() {
    tabController = TabController(length: tabs.length, vsync: this);
  }

  void _initBackInterceptor() {
    if (Platform.isAndroid) {
      BackButtonInterceptor.add(myInterceptor, zIndex: 1, name: "live_play_page");
    }
  }

  void _initPlayer() {
    if (!_hasRoom) return;
    onInitPlayerState(
      reloadDataType: detail.value!.platform == Sites.bilibiliSite
          ? ReloadDataType.changeLine
          : ReloadDataType.refreash,
    );
  }

  void _preloadEmoji() => EmojiManager().preload(site);

  void _initDebounce() {
    everAll([closeTimeFlag, closeTimes], (_) => _toggleTimer());
  }

  void _initTimer() {
    _stopWatchTimer.fetchEnded.listen((_) {
      _stopWatchTimer.onStopTimer();
      exit(0);
    });
  }

  void _toggleTimer() {
    if (closeTimeFlag.isTrue) {
      _stopWatchTimer.onStopTimer();
      _stopWatchTimer.setPresetMinuteTime(closeTimes.value, add: false);
      _stopWatchTimer.onStartTimer();
    } else {
      _stopWatchTimer.onStopTimer();
    }
  }

  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (GlobalPlayerState.to.isFullscreen.value) {
      setNormalScreen();
      videoController.value?.exitFullScreen();
      return true;
    }

    if (videoController.value?.showSettting.value == true) {
      videoController.value?.showSettting.toggle();
      return true;
    }
    videoController.value?.clearListener();
    success.value = false;
    return false;
  }

  @override
  void onClose() {
    _disposeAll();
    super.onClose();
  }

  void _disposeAll() {
    tabController.dispose();
    _stopWatchTimer.onStopTimer();
    if (Platform.isAndroid) {
      BackButtonInterceptor.removeByName("live_play_page");
    }
    if (settings.enableDanmakuDisplay.value) {
      liveDanmaku.stop();
    }
  }

  void setNormalScreen() => screenMode.value = VideoMode.normal;
  void setWidescreen() => screenMode.value = VideoMode.widescreen;
  void setFullScreen() => screenMode.value = VideoMode.fullscreen;

  // =========================================================
  // 初始化播放
  // =========================================================
  Future<LiveRoom> onInitPlayerState({
    ReloadDataType reloadDataType = ReloadDataType.refreash,
    int line = 0,
    bool isReCalculate = true,
  }) async {
    final roomId = detail.value?.roomId;
    if (roomId == null) return LiveRoom();
    var liveRoom = await currentSite.liveSite.getRoomDetail(roomId: roomId, platform: detail.value!.platform!);
    // ================= IPTV =================
    bool isIptv = currentSite.id == Sites.iptvSite;
    if (isIptv) {
      detail.value = null;
      detail.value = liveRoom;
      _initIptvPlayer();
      return detail.value!;
    }

    handleCurrentLineAndQuality(reloadDataType: reloadDataType, line: line, isReCalculate: isReCalculate);

    detail.value = null;
    detail.value = liveRoom;
    refreshKey.value++;

    if (liveRoom.liveStatus == LiveStatus.unknown) {
      if (Get.currentRoute == '/live_play') {
        ToastUtil.show(i18n('get_room_info_failed_retry'));
        setNormalScreen();
        GlobalPlayerState.to.isFullscreen.value = false;
        GlobalPlayerState.to.isWindowFullscreen.value = false;
      }
      return liveRoom;
    }

    final liveStatus = liveRoom.status! || liveRoom.isRecord!;

    if (liveStatus) {
      isLiving.value = true;
      await getPlayQualites();

      settings.addRoomToHistory(liveRoom);

      const except = ['kuaishou', 'iptv', 'cc'];
      if (!except.contains(liveRoom.platform) && settings.enableDanmakuDisplay.value) {
        liveDanmaku.stop();
        initDanmau();
        liveDanmaku.start(liveRoom.danmakuData);
      }
    } else {
      success.value = false;
      isLiving.value = false;

      setNormalScreen();
      GlobalPlayerState.to.isFullscreen.value = false;
      GlobalPlayerState.to.isWindowFullscreen.value = false;

      ToastUtil.show(
        liveRoom.liveStatus == LiveStatus.banned ? i18n('server_error_retry_later') : i18n('stream_not_live'),
      );

      restoryQualityAndLines();
    }

    return liveRoom;
  }

  void switchRoom(LiveRoom newRoom) async {
    final manager = GlobalPlayerService.instance.playerManager;
    manager.close();
    success.value = false;
    isLiving.value = true;
    messages.clear();
    if (settings.enableDanmakuDisplay.value) {
      liveDanmaku.stop();
    }
    await videoController.value?.destory();
    videoController.value = null;
    hasUseDefaultResolution = false;
    detail.value = newRoom;
    currentSite = Sites.of(newRoom.platform!);
    if (settings.enableDanmakuDisplay.value) {
      liveDanmaku = currentSite.liveSite.getDanmaku();
    }
    EmojiManager().preload(newRoom.platform!);
    onInitPlayerState(
      reloadDataType: newRoom.platform == Sites.bilibiliSite ? ReloadDataType.changeLine : ReloadDataType.refreash,
    );
  }

  // ================= IPTV =================
  void _initIptvPlayer() {
    final link = detail.value?.link;
    log(' IPTV link: ${detail.value?.link}');
    if (link == null || link.isEmpty) {
      ToastUtil.show(i18n('invalid_play_url'));
      return;
    }

    qualites = RxList([LivePlayQuality(quality: '原画')]);
    currentQuality.value = 0;
    currentLineIndex.value = 0;
    playUrls.value = [link];

    setPlayer();
    if (settings.enableDanmakuDisplay.value) {
      liveDanmaku.stop();
    }
  }

  void handleCurrentLineAndQuality({
    ReloadDataType reloadDataType = ReloadDataType.refreash,
    int line = 0,
    bool isReCalculate = true,
  }) {
    if (reloadDataType == ReloadDataType.changeLine && isReCalculate && playUrls.isNotEmpty) {
      currentLineIndex.value = (currentLineIndex.value + 1) % playUrls.length;
    }
  }

  void restoryQualityAndLines() {
    playUrls.value = [];
    currentLineIndex.value = 0;
    qualites.value = [];
    currentQuality.value = 0;
  }

  // =========================================================
  // 弹幕
  // =========================================================
  void initDanmau() {
    if (!_hasRoom) return;
    if (!settings.enableDanmakuDisplay.value) {
      return;
    }
    if (detail.value!.isRecord == true) {
      messages.add(_systemMsg(i18n('recording_mode_notice')));
    }

    messages.add(_systemMsg(i18n('connect_danmaku_server')));

    final rxVideoCtrl = videoController;

    liveDanmaku.onMessage = (msg) {
      if (msg.type == LiveMessageType.chat) {
        if (settings.shieldList.every((e) => !msg.message.contains(e))) {
          _addMessage(msg);
          if (rxVideoCtrl.value != null) {
            rxVideoCtrl.value!.sendDanmaku(msg);
          }
        }
      }
    };

    liveDanmaku.onClose = (msg) {
      messages.add(_systemMsg(msg));
    };

    liveDanmaku.onReady = () {
      messages.add(_systemMsg(i18n('danmaku_connected')));
    };
  }

  LiveMessage _systemMsg(String text) => LiveMessage(
    type: LiveMessageType.chat,
    userName: i18n('system_message'),
    message: text,
    color: LiveMessageColor.white,
  );

  void _addMessage(LiveMessage msg) {
    if (messages.length > 100) messages.removeAt(0);
    messages.add(msg);
  }

  // =========================================================
  // 设置播放器
  // =========================================================
  void setPlayer() async {
    Map<String, String> headers = {};

    if (currentSite.id == Sites.bilibiliSite) {
      headers = {
        "cookie": settings.bilibiliCookie.value,
        "authority": "api.bilibili.com",
        "accept":
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
        "accept-language": "zh-CN,zh;q=0.9",
        "cache-control": "no-cache",
        "dnt": "1",
        "pragma": "no-cache",
        "sec-ch-ua": '"Not A(Brand";v="99", "Google Chrome";v="121", "Chromium";v="121"',
        "sec-ch-ua-mobile": "?0",
        "sec-ch-ua-platform": '"macOS"',
        "sec-fetch-dest": "document",
        "sec-fetch-mode": "navigate",
        "sec-fetch-site": "none",
        "sec-fetch-user": "?1",
        "upgrade-insecure-requests": "1",
        "user-agent":
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36",
        "referer": "https://live.bilibili.com",
      };
    } else if (currentSite.id == Sites.huyaSite) {
      final ua = await HuyaSite().getHuYaUA();
      headers = {"user-agent": ua, "origin": "https://www.huya.com"};
    } else if (currentSite.id == Sites.iptvSite) {
      if (settings.customIptvUserAgent.value.isNotEmpty) {
        headers = {"user-agent": settings.customIptvUserAgent.value};
      }
    }

    GlobalPlayerState().setCurrentRoom(room.roomId!);

    videoController.value = VideoController(
      room: detail.value!,
      playUrs: playUrls.value,
      datasource: _playUrlSafe,
      allowScreenKeepOn: settings.enableScreenKeepOn.value,
      headers: headers,
      qualiteName: _qualitySafe.quality,
      currentLineIndex: currentLineIndex.value,
      currentQuality: currentQuality.value,
    );

    success.value = true;
  }

  // =========================================================
  // 切换清晰度
  // =========================================================
  void setResolution(ReloadDataType reloadDataType, int qualityIndex, int lineIndex) {
    GlobalPlayerService.instance.playerManager.close();
    videoController.value?.destory();

    currentQuality.value = qualityIndex;
    currentLineIndex.value = lineIndex;

    onInitPlayerState(reloadDataType: reloadDataType, line: currentLineIndex.value, isReCalculate: false);
  }

  // =========================================================
  // 清晰度
  // =========================================================
  Future<void> getPlayQualites() async {
    try {
      var playQualites = await currentSite.liveSite.getPlayQualites(detail: detail.value!);

      if (playQualites.isEmpty) {
        ToastUtil.show(i18n('cannot_read_video_info'));
        success.value = false;
        return;
      }

      qualites.value = playQualites;

      if (!hasUseDefaultResolution) {
        String userPrefer;
        final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

        if (connectivityResult.contains(ConnectivityResult.mobile)) {
          // 包含移动网络逻辑
          userPrefer = settings.preferResolutionCellular.value;
        } else {
          // 其他（WiFi、以太网等）
          userPrefer = settings.preferResolution.value;
        }

        List<String> availableQualities = playQualites.map((e) => e.quality).toList();
        int matchedIndex = availableQualities.indexOf(userPrefer);

        // 尝试直接匹配用户偏好的分辨率
        if (matchedIndex != -1) {
          currentQuality.value = matchedIndex;
          hasUseDefaultResolution = true;
          getPlayUrl();
          return;
        }

        List<String> systemResolutions = settings.resolutionsList;
        int preferLevel = systemResolutions.indexOf(userPrefer);

        if (preferLevel == -1) preferLevel = 0;

        double preferRatio = preferLevel / (systemResolutions.length - 1);
        int targetIndex = (preferRatio * (availableQualities.length - 1)).round();

        targetIndex = targetIndex.clamp(0, availableQualities.length - 1);
        currentQuality.value = targetIndex;
        hasUseDefaultResolution = true;
      }

      await getPlayUrl();
    } catch (_) {
      ToastUtil.show(i18n('read_video_failed'));
      success.value = false;
    }
  }

  Future<void> getPlayUrl() async {
    var playUrl = await currentSite.liveSite.getPlayUrls(
      detail: detail.value!,
      quality: qualites[currentQuality.value],
    );

    if (playUrl.isEmpty) {
      ToastUtil.show(i18n('cannot_read_play_url'));
      success.value = false;
      return;
    }

    playUrls.value = playUrl;
    setPlayer();
  }

  // =========================================================
  // 打开外部APP
  // =========================================================
  Future<void> openNaviteAPP() async {
    var naviteUrl = "";
    var webUrl = "";
    if (site == Sites.bilibiliSite) {
      naviteUrl = "bilibili://live/${detail.value?.roomId}";
      webUrl = "https://live.bilibili.com/${detail.value?.roomId}";
    } else if (site == Sites.douyinSite) {
      var args = detail.value?.danmakuData as DouyinDanmakuArgs;
      naviteUrl = "snssdk1128://webcast_room?room_id=${args.roomId}";
      webUrl = "https://live.douyin.com/${args.webRid}";
    } else if (site == Sites.huyaSite) {
      var args = detail.value?.danmakuData as HuyaDanmakuArgs;
      naviteUrl =
          "yykiwi://homepage/index.html?banneraction=https%3A%2F%2Fdiy-front.cdn.huya.com%2Fzt%2Ffrontpage%2Fcc%2Fupdate.html%3Fhyaction%3Dlive%26channelid%3D${args.subSid}%26subid%3D${args.subSid}%26liveuid%3D${args.subSid}%26screentype%3D1%26sourcetype%3D0%26fromapp%3Dhuya_wap%252Fclick%252Fopen_app_guide%26&fromapp=huya_wap/click/open_app_guide";
      webUrl = "https://www.huya.com/${detail.value?.roomId}";
    } else if (site == Sites.douyuSite) {
      naviteUrl =
          "douyulink://?type=90001&schemeUrl=douyuapp%3A%2F%2Froom%3FliveType%3D0%26rid%3D${detail.value?.roomId}";
      webUrl = "https://www.douyu.com/${detail.value?.roomId}";
    } else if (site == Sites.ccSite) {
      log(detail.value!.userId.toString(), name: "cc_user_id");
      naviteUrl = "cc://join-room/${detail.value?.roomId}/${detail.value?.userId}/";
      webUrl = "https://cc.163.com/${detail.value?.roomId}";
    } else if (site == Sites.kuaishouSite) {
      naviteUrl =
          "kwai://liveaggregatesquare?liveStreamId=${detail.value?.link}&recoStreamId=${detail.value?.link}&recoLiveStreamId=${detail.value?.link}&liveSquareSource=28&path=/rest/n/live/feed/sharePage/slide/more&mt_product=H5_OUTSIDE_CLIENT_SHARE";
      webUrl = "https://live.kuaishou.com/u/${detail.value?.roomId}";
    }
    try {
      if (Platform.isAndroid) {
        await launchUrlString(naviteUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ToastUtil.show(i18n('open_app_failed_fallback_browser'));
      await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> startCatchUp({required String catchUpUrl, int? startTime, int? endTime}) async {
    var room = detail.value!;
    detail.value = null;
    detail.value = room.copyWith(catchUpUrl: catchUpUrl, isCatchUp: true, catchUpStart: startTime, catchUpEnd: endTime);
    await _switchToUrl(catchUpUrl);
  }

  Future<void> _switchToUrl(String url) async {
    success.value = false;
    playUrls.value = [url];
    currentLineIndex.value = 0;
    setPlayer();
  }
}
