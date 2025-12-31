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
import 'package:pure_live/player/switchable_global_player.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';

enum VideoMode { normal, widescreen, fullscreen }

class LivePlayController extends StateController with GetSingleTickerProviderStateMixin {
  LivePlayController({required this.room, required this.site});
  final String site;
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown);

  late Site currentSite;

  late LiveDanmaku liveDanmaku;

  PlayerInstanceState playerState = PlayerInstanceState();

  final settings = Get.find<SettingsService>();

  late TabController tabController;

  final List<String> tabs = ['弹幕列表', '弹幕设置', '屏蔽管理'];

  final messages = <LiveMessage>[].obs;

  final isLiving = true.obs;
  // 控制唯一子组件
  final videoController = Rx<VideoController?>(null);

  final LiveRoom room;

  Rx<LiveRoom?> detail = Rx<LiveRoom?>(LiveRoom());

  final success = false.obs;

  /// 清晰度数据
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度
  final RxInt currentQuality = 0.obs;

  /// 线路数据
  RxList<String> playUrls = RxList<String>();

  /// 当前线路
  final RxInt currentLineIndex = 0.obs;

  var closeTimes = 240.obs;

  var closeTimeFlag = false.obs;

  final screenMode = VideoMode.normal.obs;

  bool hasUseDefaultResolution = false;

  final refreshKey = DateTime.now().millisecondsSinceEpoch.obs;

  @override
  void onClose() {
    tabController.dispose();
    if (Platform.isAndroid) {
      BackButtonInterceptor.removeByName("live_play_page");
    }
    super.onClose();
  }

  @override
  void dispose() {
    tabController.dispose();
    if (Platform.isAndroid) {
      BackButtonInterceptor.removeByName("live_play_page");
    }
    super.dispose();
  }

  @override
  void onInit() {
    super.onInit();
    if (Platform.isAndroid) {
      BackButtonInterceptor.add(myInterceptor, zIndex: 1, name: "live_play_page");
    }
    detail.value = room;
    currentSite = Sites.of(site);
    liveDanmaku = Sites.of(site).liveSite.getDanmaku();
    onInitPlayerState();
    EmojiManager().preload(site);
    debounce(closeTimeFlag, (callback) {
      if (closeTimeFlag.isTrue) {
        _stopWatchTimer.onStopTimer();
        _stopWatchTimer.setPresetMinuteTime(closeTimes.value, add: false);
        _stopWatchTimer.onStartTimer();
      } else {
        _stopWatchTimer.onStopTimer();
      }
    }, time: 1.seconds);

    debounce(closeTimes, (callback) {
      if (closeTimeFlag.isTrue) {
        _stopWatchTimer.onStopTimer();
        _stopWatchTimer.setPresetMinuteTime(closeTimes.value, add: false);
        _stopWatchTimer.onStartTimer();
      } else {
        _stopWatchTimer.onStopTimer();
      }
    }, time: 1.seconds);
    _stopWatchTimer.fetchEnded.listen((value) {
      _stopWatchTimer.onStopTimer();
      exit(0);
    });
    tabController = TabController(length: tabs.length, vsync: this);
  }

  void resetRoom(Site site, String roomId) async {
    success.value = false;
    await videoController.value!.destory();
    videoController.value = null;
    Timer(const Duration(milliseconds: 4000), () {
      if (Get.currentRoute == '/live_play') {
        onInitPlayerState();
      }
    });
  }

  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (videoController.value!.isFullscreen.value) {
      setNormalScreen();
      videoController.value!.exitFullScreen();
      return true;
    }

    if (videoController.value!.showSettting.value) {
      videoController.value!.showSettting.toggle();
      return true;
    }
    success.value = false;
    return false;
  }

  Future<LiveRoom> onInitPlayerState({
    ReloadDataType reloadDataType = ReloadDataType.refreash,
    int line = 0,
    bool isReCalculate = true,
  }) async {
    var liveRoom = await currentSite.liveSite.getRoomDetail(
      roomId: detail.value!.roomId!,
      platform: detail.value!.platform!,
    );
    if (currentSite.id == Sites.iptvSite) {
      liveRoom = liveRoom.copyWith(title: detail.value!.title!, nick: detail.value!.nick!);
    }

    handleCurrentLineAndQuality(reloadDataType: reloadDataType, line: line, isReCalculate: isReCalculate);
    detail.value = null;
    detail.value = liveRoom;
    refreshKey.value = DateTime.now().millisecondsSinceEpoch;
    if (liveRoom.liveStatus == LiveStatus.unknown) {
      if (Get.currentRoute == '/live_play') {
        SmartDialog.showToast("获取直播间信息失败,请重新获取", displayTime: const Duration(seconds: 2));
      }
      return liveRoom;
    }

    bool liveStatus = liveRoom.status! || liveRoom.isRecord!;
    if (liveStatus) {
      isLiving.value = true;
      await getPlayQualites();
      if (detail.value!.platform == Sites.iptvSite) {
        settings.addRoomToHistory(detail.value!);
      } else {
        settings.addRoomToHistory(liveRoom);
      }
      // start danmaku server
      List<String> except = ['kuaishou', 'iptv', 'cc'];
      if (except.indexWhere((element) => element == liveRoom.platform!) == -1) {
        liveDanmaku.stop();
        initDanmau();
        liveDanmaku.start(liveRoom.danmakuData);
      }
    } else {
      success.value = false;
      isLiving.value = false;
      if (liveRoom.liveStatus == LiveStatus.banned) {
        SmartDialog.showToast("服务器错误,请稍后获取", displayTime: const Duration(seconds: 2));
      } else {
        SmartDialog.showToast("当前主播未开播或主播已下播", displayTime: const Duration(seconds: 2));
      }
      restoryQualityAndLines();
    }

    return liveRoom;
  }

  void setNormalScreen() {
    screenMode.value = VideoMode.normal;
  }

  void setWidescreen() {
    screenMode.value = VideoMode.widescreen;
  }

  void setFullScreen() {
    screenMode.value = VideoMode.fullscreen;
  }

  void handleCurrentLineAndQuality({
    ReloadDataType reloadDataType = ReloadDataType.refreash,
    int line = 0,
    bool isReCalculate = true,
  }) {
    if (reloadDataType == ReloadDataType.changeLine && isReCalculate) {
      if (line == playUrls.length - 1) {
        currentLineIndex.value = 0;
      } else {
        currentLineIndex.value = currentLineIndex.value + 1;
      }
    }
  }

  void restoryQualityAndLines() {
    playUrls.value = [];
    currentLineIndex.value = 0;
    qualites.value = [];
    currentQuality.value = 0;
  }

  /// 初始化弹幕接收事件
  void initDanmau() {
    if (detail.value!.isRecord!) {
      messages.add(
        LiveMessage(
          type: LiveMessageType.chat,
          userName: "系统消息",
          message: "当前主播未开播，正在轮播录像",
          color: LiveMessageColor.white,
        ),
      );
    }
    messages.add(
      LiveMessage(type: LiveMessageType.chat, userName: "系统消息", message: "开始连接弹幕服务器", color: LiveMessageColor.white),
    );
    final rxVideoCtrl = videoController;
    liveDanmaku.onMessage = (msg) {
      if (msg.type == LiveMessageType.chat) {
        if (settings.shieldList.every((element) => !msg.message.contains(element))) {
          messages.add(msg);
          if (rxVideoCtrl.value != null) {
            rxVideoCtrl.value!.sendDanmaku(msg);
          }
        }
      }
    };
    liveDanmaku.onClose = (msg) {
      messages.add(
        LiveMessage(type: LiveMessageType.chat, userName: "系统消息", message: msg, color: LiveMessageColor.white),
      );
    };
    liveDanmaku.onReady = () {
      messages.add(
        LiveMessage(type: LiveMessageType.chat, userName: "系统消息", message: "弹幕服务器连接正常", color: LiveMessageColor.white),
      );
    };
  }

  void setResolution(ReloadDataType reloadDataType, int qualityIndex, int lineIndex) {
    SwitchableGlobalPlayer().dispose();
    videoController.value!.destory();
    currentQuality.value = qualityIndex;
    currentLineIndex.value = lineIndex;
    onInitPlayerState(reloadDataType: reloadDataType, line: currentLineIndex.value, isReCalculate: false);
  }

  /// 初始化播放器
  Future<void> getPlayQualites() async {
    try {
      var playQualites = await currentSite.liveSite.getPlayQualites(detail: detail.value!);
      if (playQualites.isEmpty) {
        SmartDialog.showToast("无法读取视频信息,请重新获取", displayTime: const Duration(seconds: 2));
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

      getPlayUrl();
    } catch (e) {
      SmartDialog.showToast("读取视频信息失败,请重新获取");
      success.value = false;
    }
  }

  Future<void> getPlayUrl() async {
    var playUrl = await currentSite.liveSite.getPlayUrls(
      detail: detail.value!,
      quality: qualites[currentQuality.value],
    );
    if (playUrl.isEmpty) {
      SmartDialog.showToast("无法读取播放地址,请重新获取", displayTime: const Duration(seconds: 2));
      success.value = false;
      return;
    }
    playUrls.value = playUrl;
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
      var ua = await HuyaSite().getHuYaUA();
      headers = {"user-agent": ua, "origin": "https://www.huya.com"};
    }

    playerState = GlobalPlayerState().setCurrentRoom(room.roomId!);
    videoController.value = VideoController(
      room: detail.value!,
      datasource: playUrls.value[currentLineIndex.value],
      allowScreenKeepOn: settings.enableScreenKeepOn.value,
      headers: headers,
      qualiteName: qualites[currentQuality.value].quality,
      currentLineIndex: currentLineIndex.value,
      currentQuality: currentQuality.value,
      initialState: playerState,
    );
    success.value = true;
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
      SmartDialog.showToast("无法打开APP，将使用浏览器打开");
      await launchUrlString(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  void switchRoom(LiveRoom room) async {
    SwitchableGlobalPlayer().dispose();
    success.value = false;
    isLiving.value = true;
    messages.clear();
    liveDanmaku.stop();
    await videoController.value!.destory();
    videoController.value = null;
    hasUseDefaultResolution = false;
    detail.value = room;
    currentSite = Sites.of(room.platform!);
    liveDanmaku = Sites.of(room.platform!).liveSite.getDanmaku();
    EmojiManager().preload(room.platform!);
    onInitPlayerState();
  }
}
