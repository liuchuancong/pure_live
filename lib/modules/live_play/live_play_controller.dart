import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/huya_site.dart';
import 'widgets/video_player/video_controller.dart';
import 'package:pure_live/plugins/emoji_manager.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:pure_live/model/live_play_quality.dart';
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

  final List<String> tabs = ['弹幕列表', '弹幕设置', '屏蔽管理'];

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

  @override
  void onInit() {
    super.onInit();
    _initCore();
  }

  void _initCore() {
    _initState();
    _initTab();
    _initBackInterceptor();
    _initDanmaku();
    _initDebounce();
    _initTimer();
    _preloadEmoji();
    _initPlayer();
  }

  void _initState() {
    detail.value = room;
    currentSite = Sites.of(site);
    liveDanmaku = currentSite.liveSite.getDanmaku();
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

  void _initDanmaku() {
    initDanmau();
  }

  void _preloadEmoji() {
    EmojiManager().preload(site);
  }

  void _initDebounce() {
    everAll([closeTimeFlag, closeTimes], (_) {
      _toggleTimer();
    });
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

    liveDanmaku.stop();
  }

  void setNormalScreen() => screenMode.value = VideoMode.normal;
  void setWidescreen() => screenMode.value = VideoMode.widescreen;
  void setFullScreen() => screenMode.value = VideoMode.fullscreen;

  Future<LiveRoom> onInitPlayerState({
    ReloadDataType reloadDataType = ReloadDataType.refreash,
    int line = 0,
    bool isReCalculate = true,
  }) async {
    final roomId = detail.value?.roomId;
    if (roomId == null) return LiveRoom();

    var liveRoom = await currentSite.liveSite.getRoomDetail(roomId: roomId, platform: detail.value!.platform!);

    if (currentSite.id == Sites.iptvSite) {
      liveRoom = liveRoom.copyWith(title: detail.value!.title!, nick: detail.value!.nick!);
    }

    handleCurrentLineAndQuality(reloadDataType: reloadDataType, line: line, isReCalculate: isReCalculate);

    detail.value = null;
    detail.value = liveRoom;
    refreshKey.value++;

    if (liveRoom.liveStatus == LiveStatus.unknown) {
      if (Get.currentRoute == '/live_play') {
        ToastUtil.show("获取直播间信息失败,请重新获取");
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
      if (!except.contains(liveRoom.platform)) {
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

      ToastUtil.show(liveRoom.liveStatus == LiveStatus.banned ? "服务器错误,请稍后获取" : "当前主播未开播或已下播");

      restoryQualityAndLines();
    }

    return liveRoom;
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
    playUrls.clear();
    currentLineIndex.value = 0;
    qualites.clear();
    currentQuality.value = 0;
  }

  void initDanmau() {
    if (!_hasRoom) return;

    if (detail.value!.isRecord == true) {
      messages.add(_systemMsg("当前主播未开播，正在轮播录像"));
    }

    messages.add(_systemMsg("开始连接弹幕服务器"));
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
      messages.add(_systemMsg("弹幕服务器连接正常"));
    };
  }

  LiveMessage _systemMsg(String text) {
    return LiveMessage(type: LiveMessageType.chat, userName: "系统消息", message: text, color: LiveMessageColor.white);
  }

  void _addMessage(LiveMessage msg) {
    if (messages.length > 200) {
      messages.removeAt(0);
    }
    messages.add(msg);
  }

  void setResolution(ReloadDataType reloadDataType, int qualityIndex, int lineIndex) {
    final manager = GlobalPlayerService.instance.playerManager;
    manager.close();

    videoController.value?.destory();

    currentQuality.value = qualityIndex;
    currentLineIndex.value = lineIndex;

    onInitPlayerState(reloadDataType: reloadDataType, line: currentLineIndex.value, isReCalculate: false);
  }

  Future<void> getPlayQualites() async {
    try {
      var playQualites = await currentSite.liveSite.getPlayQualites(detail: detail.value!);

      if (playQualites.isEmpty) {
        ToastUtil.show("无法读取视频信息");
        success.value = false;
        return;
      }

      qualites.value = playQualites;

      if (!hasUseDefaultResolution) {
        String userPrefer = settings.preferResolution.value;
        List<String> availableQualities = playQualites.map((e) => e.quality).toList();
        int matchedIndex = availableQualities.indexOf(userPrefer);
        // 尝试直接匹配用户偏好的分辨率
        if (matchedIndex != -1) {
          currentQuality.value = matchedIndex;
          hasUseDefaultResolution = true;
          getPlayUrl();
          return;
        }
        // 未匹配到，根据用户偏好的"级别"选择最接近的清晰度
        List<String> systemResolutions = settings.resolutionsList;
        int preferLevel = systemResolutions.indexOf(userPrefer);
        double preferRatio = preferLevel / (systemResolutions.length - 1);
        int targetIndex = (preferRatio * (availableQualities.length - 1)).round();
        // 确保索引在有效范围内
        targetIndex = targetIndex.clamp(0, availableQualities.length - 1);
        currentQuality.value = targetIndex;
        hasUseDefaultResolution = true;
      }

      await getPlayUrl();
    } catch (_) {
      ToastUtil.show("读取视频信息失败");
      success.value = false;
    }
  }

  Future<void> getPlayUrl() async {
    var playUrl = await currentSite.liveSite.getPlayUrls(
      detail: detail.value!,
      quality: qualites[currentQuality.value],
    );

    if (playUrl.isEmpty) {
      ToastUtil.show("无法读取播放地址");
      success.value = false;
      return;
    }

    playUrls.value = playUrl;
    log(playUrl.toString(), name: "play_url");
    setPlayer();
  }

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
    }

    GlobalPlayerState().setCurrentRoom(room.roomId!);

    videoController.value = VideoController(
      room: detail.value!,
      playUrs: playUrls.value,
      datasource: playUrls[currentLineIndex.value],
      allowScreenKeepOn: settings.enableScreenKeepOn.value,
      headers: headers,
      qualiteName: qualites[currentQuality.value].quality,
      currentLineIndex: currentLineIndex.value,
      currentQuality: currentQuality.value,
    );

    success.value = true;
  }

  void switchRoom(LiveRoom room) async {
    final manager = GlobalPlayerService.instance.playerManager;
    manager.close();
    success.value = false;
    isLiving.value = true;
    messages.clear();
    liveDanmaku.stop();
    await videoController.value?.destory();
    videoController.value = null;
    hasUseDefaultResolution = false;
    detail.value = room;
    currentSite = Sites.of(room.platform!);
    liveDanmaku = currentSite.liveSite.getDanmaku();
    EmojiManager().preload(room.platform!);
    onInitPlayerState(
      reloadDataType: room.platform == Sites.bilibiliSite ? ReloadDataType.changeLine : ReloadDataType.refreash,
    );
  }

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
      ToastUtil.show("无法打开APP，将使用浏览器打开");
      await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }
}
