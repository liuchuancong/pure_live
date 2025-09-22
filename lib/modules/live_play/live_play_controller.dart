import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:get/get.dart';
import 'package:fl_pip/fl_pip.dart';
import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/utils.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/modules/util/rx_util.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../model/live_play_quality_play_url_info.dart';
import 'package:pure_live/common/models/live_room_rx.dart';
import '../../core/danmaku/util/danmaku_message_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/modules/live_play/load_type.dart';
import 'package:pure_live/modules/live_play/danmu_merge.dart';
import 'package:pure_live/modules/util/listen_list_util.dart';
import 'package:pure_live/plugins/route_history_observer.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';
import 'package:pure_live/core/iptv/src/general_utils_object_extension.dart';
import 'package:pure_live/modules/live_play/danmaku/danmaku_controller_base.dart';
import 'package:pure_live/modules/live_play/danmaku/danmaku_controller_factory.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

// import 'package:floating/floating.dart';

class LivePlayController extends StateController {
  LivePlayController({required this.room, required this.site});

  final String site;

  late Site currentSite = Sites.of(site);

  late LiveDanmaku liveDanmaku = Sites.of(site).liveSite.getDanmaku();

  final settings = Get.find<SettingsService>();

  final messages = <LiveMessage>[].obs;

  // 控制唯一子组件
  VideoController? videoController;

  final playerKey = GlobalKey();

  final danmakuViewKey = GlobalKey();

  final LiveRoom room;

  // Rx<LiveRoom?> detail = Rx<LiveRoom?>(LiveRoom());

  final LiveRoomRx liveRoomRx = LiveRoomRx();

  final success = false.obs;

  var liveStatus = false.obs;

  Map<String, List<String>> liveStream = {};

  /// 清晰度数据
  RxList<LivePlayQuality> qualites = RxList<LivePlayQuality>();

  /// 当前清晰度
  final currentQuality = 0.obs;

  /// 线路数据
  var playUrls = RxList<LivePlayQualityPlayUrlInfo>();

  /// 当前线路
  final currentLineIndex = 0.obs;

  int loopCount = 0;

  int lastExitTime = 0;

  /// 双击退出Flag
  bool doubleClickExit = false;

  /// 双击退出Timer
  Timer? doubleClickTimer;

  var isFirstLoad = true.obs;

  /// 是否在加载视频
  var isLoadingVideo = false.obs;

  // 0 代表向上 1 代表向下
  int isNextOrPrev = 0;

  // 当前直播间信息 下一个频道或者上一个
  // var currentPlayRoom = LiveRoom().obs;

  var getVideoSuccess = true.obs;

  var lastChannelIndex = 0.obs;

  Timer? channelTimer;

  Timer? loadRefreshRoomTimer;

  Timer? networkTimer;

  // 切换线路会添加到这个数组里面
  var isLastLine = false.obs;

  var hasError = false.obs;

  var loadTimeOut = true.obs;

  // 是否是手动切换线路
  var isActive = false.obs;

  /// 是否 关注
  var isFavorite = false.obs;

  // /// 在线人数
  // var online = "".obs;

  /// 是否全屏
  final isFullscreen = false.obs;

  /// 画质状态
  final isPiP = false.obs;

  /// PIP画中画
  // Floating? pip;
  StreamSubscription? _pipSubscription;

  /// StreamSubscription
  final List<StreamSubscription?> subscriptionList = [];

  final StreamController<bool> streamController = StreamController<bool>();
  Stream<bool> get streamState => streamController.stream; // 获取流。

  /// 释放一些系统状态
  Future resetSystem() async {
    _pipSubscription?.cancel();
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        FlPiP().status.removeListener(flPiPListener);
      }
    } catch (e) {
      CoreLog.error(e);
    }
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge, overlays: SystemUiOverlay.values);

    await videoController?.setPortraitOrientation();
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      // 亮度重置,桌面平台可能会报错,暂时不处理桌面平台的亮度
      try {
        await videoController?.brightnessController.resetApplicationScreenBrightness();
      } catch (e) {
        CoreLog.error(e);
      }
    }

    await WakelockPlus.disable();
  }

  Future enablePIP() async {
    if (!((Platform.isAndroid || Platform.isIOS))) {
      SmartDialog.showToast("设备不支持小窗播放");
      return;
    }

    //关闭并清除弹幕
    if (videoController?.videoPlayer.isPipMode.value == true) {
      videoController?.settings.hideDanmaku.updateValueNotEquate(true);
      videoController?.showController.updateValueNotEquate(false);
    }
    danmakuController.clear();
    danmakuController.pause();
    videoController?.showController.updateValueNotEquate(false);
    // //关闭控制器
    // showControlsState.updateValueNotEquate(false);

    //监听事件
    var isVertical = videoController?.videoPlayer.isVertical.value ?? false;
    Rational ratio = const Rational.landscape();
    if (isVertical) {
      ratio = const Rational.vertical();
    } else {
      ratio = const Rational.landscape();
    }
    CoreLog.d("$ratio");
    // await pip?.enable(ImmediatePiP());

    // subscriptionList.add(pip?.pipStatusStream.listen((event) {
    //   if (event == PiPStatus.disabled) {
    //     // danmakuController?.clear();
    //     // showDanmakuState.updateValueNotEquate(danmakuStateBeforePIP;
    //   }
    //   CoreLog.w(event.toString());
    // }));
    FlPiP().enable(
      ios: FlPiPiOSConfig(videoPath: "", audioPath: "", packageName: null),
      android: FlPiPAndroidConfig(aspectRatio: ratio),
    );
  }

  /// flPiP android 画中画状态
  Future<void> flPiPListener() async {
    var statusInfo = await FlPiP().isActive;
    switch (statusInfo?.status) {
      case PiPStatus.enabled:
        isPiP.updateValueNotEquate(true);
        break;
      default:
        isPiP.updateValueNotEquate(false);
        break;
    }
  }

  /// 监听返回键
  Future<bool> onBackPressed() async {
    if (videoController == null) {
      return true;
    }
    // 通过静态变量访问历史,判断是否真正退出
    List<Route<dynamic>> routes = RouteHistoryObserver.routeHistory;
    var lastRoute = routes.last;
    var lastRouteName = lastRoute.settings.name;
    CoreLog.d("lastRoute: $lastRouteName");
    if (lastRouteName != RoutePath.kLivePlay) {
      return true;
    }
    if (videoController!.showSettting.value) {
      videoController?.showSettting.toggle();
      return false;
    }
    if (videoController!.videoPlayer.isFullscreen.value) {
      videoController?.exitFull();
      return false;
    }
    bool doubleExit = Get.find<SettingsService>().doubleExit.value;
    if (!doubleExit) {
      disPoserPlayer();
      return true;
    }
    int nowExitTime = DateTime.now().millisecondsSinceEpoch;
    if (nowExitTime - lastExitTime > 1000) {
      lastExitTime = nowExitTime;
      SmartDialog.showToast(S.current.double_click_to_exit);
      return false;
    }
    disPoserPlayer();
    return true;
  }

  DanmakuSettingOption danmakuSettingOption = DanmakuSettingOption();

  /// 弹幕控制器 初始化
  void initDanmakuController() {
    var danmakuControllerType = settings.danmakuControllerType.value;
    danmakuController = DanmakuControllerfactory.getDanmakuController(danmakuControllerType);
    var danmakuArea = settings.danmakuArea.value;
    danmakuSettingOption = DanmakuSettingOption(
      opacity: settings.danmakuOpacity.value,
      fontSize: settings.danmakuFontSize.value,
      fontWeight: 4,
      duration: settings.danmakuSpeed.value.toInt(),
      showStroke: settings.danmakuFontBorder.value > 0,
      massiveMode: false,
      hideScroll: false,
      hideTop: false,
      hideBottom: danmakuArea < 0.70,
      safeArea: true,
    );
    danmakuController.updateOption(danmakuSettingOption);
    subscriptionList.add(
      settings.danmakuArea.listen((data) {
        danmakuSettingOption.hideBottom = data < 0.70;
      }),
    );
    subscriptionList.add(
      settings.danmakuOpacity.listen((data) {
        danmakuSettingOption.opacity = data;
      }),
    );
    subscriptionList.add(
      settings.danmakuFontSize.listen((data) {
        danmakuSettingOption.fontSize = data;
      }),
    );
    subscriptionList.add(
      settings.danmakuSpeed.listen((data) {
        danmakuSettingOption.duration = data.toInt();
      }),
    );
    subscriptionList.add(
      settings.danmakuFontBorder.listen((data) {
        danmakuSettingOption.showStroke = data > 0;
      }),
    );
    if (settings.hideDanmaku.value) {
      danmakuController.clear();
      danmakuController.pause();
    }
    subscriptionList.add(
      settings.hideDanmaku.listen((data) {
        if (data) {
          danmakuController.clear();
          danmakuController.pause();
        } else {
          danmakuController.resume();
        }
      }),
    );
  }

  @override
  void onInit() {
    super.onInit();
    // 发现房间ID 会变化 使用静态列表ID 对比
    CoreLog.d('onInit');
    initPip();
    initDanmakuController();

    // liveRoomRx = room;

    liveRoomRx.updateByLiveRoom(room);

    liveRoomRx.watching.updateValueNotEquate(liveRoomRx.watching.value ?? "0");
    // detail.updateValueNotEquate(liveRoomRx;
    isFavorite.updateValueNotEquate(settings.isFavorite(room));
    onInitPlayerState(firstLoad: true);
    subscriptionList.add(
      isFirstLoad.listen((p0) {
        if (isFirstLoad.value) {
          loadTimeOut.updateValueNotEquate(true);
          Timer(const Duration(seconds: 8), () {
            isFirstLoad.updateValueNotEquate(false);
            loadTimeOut.updateValueNotEquate(false);
            Timer(const Duration(seconds: 5), () {
              loadTimeOut.updateValueNotEquate(true);
            });
          });
        } else {
          // 防止闪屏
          Timer(const Duration(seconds: 2), () {
            loadTimeOut.updateValueNotEquate(false);
            Timer(const Duration(seconds: 5), () {
              loadTimeOut.updateValueNotEquate(true);
            });
          });
        }
      }),
    );

    subscriptionList.add(
      isLastLine.listen((p0) {
        if (isLastLine.value && hasError.value && isActive.value == false) {
          // 刷新到了最后一路线 并且有错误
          SmartDialog.showToast("当前房间无法播放,正在为您刷新直播间信息...", displayTime: const Duration(seconds: 1));
          isLastLine.updateValueNotEquate(false);
          isFirstLoad.updateValueNotEquate(true);
          restoryQualityAndLines();
          resetRoom(liveRoomRx.toLiveRoom());
        } else {
          if (success.value) {
            isActive.updateValueNotEquate(false);
            loadRefreshRoomTimer?.cancel();
          }
        }
      }),
    );

    subscriptionList.add(
      getVideoSuccess.listen((p0) {
        isLoadingVideo.updateValueNotEquate(true);
        if (p0) {
          isLoadingVideo.updateValueNotEquate(false);
        }
      }),
    );
    initAutoShutDown();
  }

  void resetRoom(LiveRoom item) async {
    // if (liveRoomRx.platform == site.id && liveRoomRx.roomId == roomId) {
    //   return;
    // }
    var of = Sites.of(item.platform ?? "");
    currentSite = of;

    // var liveRoom = liveRoomRx;
    // liveRoom.roomId = roomId;
    // liveRoom.platform = site.id;
    liveRoomRx.updateByLiveRoom(item);

    success.updateValueNotEquate(false);
    hasError.updateValueNotEquate(false);
    if (videoController != null && !videoController!.hasDestory) {
      await videoController?.destory();
      videoController = null;
    }

    isFirstLoad.updateValueNotEquate(true);
    getVideoSuccess.updateValueNotEquate(false);
    loadTimeOut.updateValueNotEquate(false);
    isLoadingVideo.updateValueNotEquate(true);

    currentLineIndex.updateValueNotEquate(0);
    currentQuality.updateValueNotEquate(0);
    playUrls.updateValueNotEquate([]);

    Timer(const Duration(milliseconds: 100), () {
      // log('resetRoom', name: 'LivePlayController');
      CoreLog.d('resetRoom');
      onInitPlayerState(firstLoad: true);
    });
  }

  /// 获取信息出错
  void getInfoError(String mgs) {
    SmartDialog.showToast(mgs, displayTime: const Duration(seconds: 2));
    liveStatus.updateValueNotEquate(false);
    hasError.updateValueNotEquate(true);
    isLoadingVideo.updateValueNotEquate(false);
    getVideoSuccess.updateValueNotEquate(false);
  }

  Future<LiveRoom> onInitPlayerState({
    ReloadDataType reloadDataType = ReloadDataType.refreash,
    int line = 0,
    bool active = false,
    bool firstLoad = false,
  }) async {
    isActive.updateValueNotEquate(active);
    isFirstLoad.updateValueNotEquate(firstLoad);
    isLoadingVideo.updateValueNotEquate(true);
    var liveRoom = liveRoomRx.toLiveRoom();
    // 只有第一次需要重新配置信息
    if (isFirstLoad.value) {
      try {
        liveRoom = await currentSite.liveSite.getRoomDetail(detail: liveRoom);
      } catch (e) {
        CoreLog.error(e);
        getInfoError("$e");
        return liveRoom;
      }
      isFavorite.updateValueNotEquate(settings.isFavorite(liveRoom));
      liveRoomRx.updateByLiveRoom(liveRoom);
      // liveRoomRx = liveRoom;
      // liveRoomRx.data = liveRoom.data;
    }
    isLastLine.updateValueNotEquate(calcIsLastLine(line) && reloadDataType == ReloadDataType.changeLine);
    if (isLastLine.value) {
      hasError.updateValueNotEquate(true);
    } else {
      hasError.updateValueNotEquate(false);
    }
    // active 代表用户是否手动切换路线 只有不是手动自动切换才会显示路线错误信息
    if (isLastLine.value && hasError.value && active == false) {
      restoryQualityAndLines();
      getVideoSuccess.updateValueNotEquate(false);
      isFirstLoad.updateValueNotEquate(false);
      success.updateValueNotEquate(false);
      return liveRoom;
    } else {
      handleCurrentLineAndQuality(reloadDataType: reloadDataType, line: line, active: active);
      // detail.updateValueNotEquate(liveRoom;
      liveRoomRx.watching.updateValueNotEquate(liveRoom.watching ?? "0");
      if (liveRoom.liveStatus == LiveStatus.unknown) {
        SmartDialog.showToast("获取直播间信息失败,请按重新获取", displayTime: const Duration(seconds: 2));
        getVideoSuccess.updateValueNotEquate(false);
        isFirstLoad.updateValueNotEquate(false);
        return liveRoom;
      }

      // 开始播放
      liveStatus.updateValueNotEquate(
        liveRoomRx.liveStatus.value != LiveStatus.unknown && liveRoomRx.liveStatus.value != LiveStatus.offline,
      );
      if (liveStatus.value) {
        try {
          await getPlayQualites();
        } catch (e) {
          CoreLog.error(e);
          getInfoError("获取清晰度失败");
          return liveRoom;
        }
        getVideoSuccess.updateValueNotEquate(true);
        if (liveRoomRx.platform.value == Sites.iptvSite) {
          settings.addRoomToHistory(liveRoomRx.toLiveRoom());
        } else {
          settings.addRoomToHistory(liveRoom);

          // 更新录播观看人数信息
          if ((liveRoom.liveStatus == LiveStatus.live && liveRoom.isRecord == true) ||
              liveRoom.liveStatus == LiveStatus.replay) {
            liveRoom.liveStatus = LiveStatus.replay;
            liveRoom.recordWatching = liveRoom.watching;
          }
          settings.updateRoom(liveRoom);
          CoreLog.d(jsonEncode(liveRoom));
          var favoriteController = Get.find<FavoriteController>();
          favoriteController.syncRooms();
        }

        // start danmaku server
        List<String> except = ['iptv'];
        // 重新刷新才重新加载弹幕
        if (firstLoad &&
            except.indexWhere((element) => element == liveRoom.platform!) == -1 &&
            liveRoom.danmakuData != null) {
          try {
            liveDanmaku.stop();
          } catch (e) {
            CoreLog.error(e);
          }
          liveDanmaku = Sites.of(liveRoomRx.platform.value!).liveSite.getDanmaku();
          initDanmau();
          liveDanmaku.start(liveRoom.danmakuData);
        }
      } else {
        isFirstLoad.updateValueNotEquate(false);
        success.updateValueNotEquate(false);
        getVideoSuccess.updateValueNotEquate(true);
        isLoadingVideo.updateValueNotEquate(false);
        SmartDialog.showToast("当前主播未开播或主播已下播", displayTime: const Duration(seconds: 2));
        messages.add(
          LiveMessage(type: LiveMessageType.chat, userName: "系统消息", message: "当前主播未开播或主播已下播", color: Colors.redAccent),
        );
        restoryQualityAndLines();
      }

      return liveRoom;
    }
  }

  bool calcIsLastLine(int line) {
    var lastLine = line + 1;
    if (playUrls.isEmpty) {
      return true;
    }
    if (playUrls.length == 1) {
      return true;
    }
    if (lastLine == playUrls.length) {
      return true;
    }
    return false;
  }

  void disPoserPlayer() {
    try {
      ListenListUtil.clearStreamSubscriptionList(subscriptionList.where((e) => e != null).map((e) => e!).toList());
      videoController?.dispose();
      videoController = null;
      liveDanmaku.stop();
      success.updateValueNotEquate(false);
      resetSystem();
      danmakuController.dispose();

      channelTimer?.cancel();
      loadRefreshRoomTimer?.cancel();
      networkTimer?.cancel();
      doubleClickTimer?.cancel();
      autoExitTimer?.cancel();

      streamController.close();
    } catch (e) {
      CoreLog.error(e);
    }
  }

  void handleCurrentLineAndQuality({
    ReloadDataType reloadDataType = ReloadDataType.refreash,
    int line = 0,
    bool active = false,
  }) {
    if (reloadDataType == ReloadDataType.changeLine && active == false) {
      if (line == playUrls.length - 1) {
        currentLineIndex.updateValueNotEquate(0);
      } else {
        currentLineIndex.updateValueNotEquate(currentLineIndex.value + 1);
      }
      loopCount++;
      isFirstLoad.updateValueNotEquate(false);
    }
  }

  void restoryQualityAndLines() {
    // playUrls.updateValueNotEquate([];
    currentLineIndex.updateValueNotEquate(0);
    // qualites.updateValueNotEquate([];
    loopCount = 0;
    currentQuality.updateValueNotEquate(0);
  }

  /// 是否显示弹幕
  bool isShowDanmau(LiveMessage msg) {
    /// 彩色弹幕
    if (settings.showColourDanmaku.value) {
      bool isShowColour = msg.color != Colors.white;
      if (!isShowColour) {
        return false;
      }
    }
    // CoreLog.d("isShowColour  msg:${msg.fansLevel} ${msg.fansName}");

    /// 用户等级
    var filterDanmuUserLevel = settings.filterDanmuUserLevel.value.toInt();
    if (filterDanmuUserLevel > 0 && msg.userLevel.isNotNullOrEmpty) {
      if (filterDanmuUserLevel > (int.parse(msg.userLevel))) {
        return false;
      }
    }
    // CoreLog.d("filterDanmuUserLevel  msg:${msg.fansLevel} ${msg.fansName}");

    /// 粉丝等级
    var filterDanmuFansLevel = settings.filterDanmuFansLevel.value.toInt();
    if (filterDanmuFansLevel > 0 && msg.fansLevel.isNotNullOrEmpty) {
      if (filterDanmuFansLevel > (int.parse(msg.fansLevel))) {
        return false;
      }
    }

    // CoreLog.d("filterDanmuFansLevel  msg:${msg.fansLevel} ${msg.fansName}");

    /// 不在黑名单
    bool isNotInShieldList = settings.shieldList.every((element) => !msg.message.contains(element));
    if (!isNotInShieldList) {
      return false;
    }

    // CoreLog.d("isNotInShieldList  msg:${msg.fansLevel} ${msg.fansName}");

    var repeat = DanmuMerge.getInstance().isRepeat(msg.message);

    // CoreLog.d("repeat $repeat  msg:${msg.fansLevel} ${msg.fansName}");

    return !repeat;
  }

  void initPip() {
    if (Platform.isAndroid || Platform.isIOS) {
      // pip = Floating();
      // subscriptionList.add(pip?.pipStatusStream.listen((status) {
      //   // if (status == PiPStatus.enabled) {
      //   //   isPipMode.value = true;
      //   //   key.currentState?.enterFullscreen();
      //   // } else {
      //   //   isPipMode.value = false;
      //   //   key.currentState?.exitFullscreen();
      //   // }
      // }));
      FlPiP().status.addListener(flPiPListener);
    }
    subscriptionList.add(
      isPiP.listen((e) {
        streamController.add(e);
      }),
    );
  }

  /// 初始化弹幕接收事件
  void initDanmau() {
    messages.clear();
    if (liveRoomRx.isRecord.value!) {
      messages.add(
        LiveMessage(type: LiveMessageType.chat, userName: "系统消息", message: "当前主播未开播，正在轮播录像", color: Colors.grey),
      );
    }
    messages.add(
      LiveMessage(type: LiveMessageType.chat, userName: "系统消息", message: "开始连接弹幕服务器", color: Colors.blueGrey),
    );
    liveDanmaku.onMessage = (msg) {
      if (msg.type == LiveMessageType.chat) {
        var message = msg.message;
        message = DanmakuMessageUtil.handleMessage(message);
        msg.message = message;
        var isShow = isShowDanmau(msg);
        // CoreLog.d("isShow:$isShow  msg:${msg.fansLevel} ${msg.fansName}");
        if (isShow) {
          DanmuMerge().add(msg.message);
          messages.add(msg);
          if (videoController != null && videoController!.hasDestory == false) {
            sendDanmaku(msg);
          }
        }
      } else if (msg.type == LiveMessageType.online) {
        /// 在线人数
        var onlineNum = msg.data as int;
        var numStr = onlineNum.toString();
        // CoreLog.d(online.toString());
        if (liveRoomRx.watching.value != numStr) {
          liveRoomRx.watching.updateValueNotEquate(onlineNum.toString());
          // liveRoomRx.watching = online.toString();
          // liveRoomRx.watching = online.toString();
        }
      }
    };
    liveDanmaku.onClose = (msg) {
      messages.add(LiveMessage(type: LiveMessageType.chat, userName: "系统消息", message: msg, color: Colors.blueGrey));
    };
    liveDanmaku.onReady = () {
      messages.add(
        LiveMessage(type: LiveMessageType.chat, userName: "系统消息", message: "弹幕服务器连接正常", color: Colors.blueGrey),
      );
    };
  }

  /// 选择直播路线
  void setResolution(String quality, String index) {
    CoreLog.d("setResolution");
    CoreLog.d("quality: $quality \t index: $index");
    isLoadingVideo.updateValueNotEquate(true);
    if (videoController != null && videoController!.hasDestory == false) {
      // videoController!.destory();
      videoController!.pause();
    }

    currentQuality.updateValueNotEquate(qualites.map((e) => e.quality).toList().indexWhere((e) => e == quality));
    currentLineIndex.updateValueNotEquate(int.tryParse(index) ?? 0);
    onInitPlayerState(
      reloadDataType: ReloadDataType.changeLine,
      line: currentLineIndex.value,
      active: true,
      firstLoad: false,
    );
  }

  /// 初始化播放器
  Future<void> getPlayQualites() async {
    try {
      var playQualites = qualites.value;
      if (isFirstLoad.value) {
        playQualites = await currentSite.liveSite.getPlayQualites(detail: liveRoomRx.toLiveRoom());
        for (var playQuality in playQualites) {
          var quality = playQuality.quality;
          quality = quality.replaceAll(" ", "");
          quality = quality.replaceAll("质臻", "8M");
          if (quality == "蓝光") {
            quality = "蓝光4M";
          }
          playQuality.quality = quality;
        }
      }
      if (playQualites.isEmpty) {
        SmartDialog.showToast("无法读取视频信息,请重新获取", displayTime: const Duration(seconds: 2));
        getVideoSuccess.updateValueNotEquate(false);
        isFirstLoad.updateValueNotEquate(false);
        success.updateValueNotEquate(false);
        return;
      }
      qualites.value = playQualites;
      // 第一次加载 使用系统默认线路
      if (isFirstLoad.value) {
        // var qualityLevel = await getQualityLevelByResolution();
        var qualityLevel = await getQualityLevelByBitRate();
        currentQuality.updateValueNotEquate(qualityLevel);
      }
      isFirstLoad.updateValueNotEquate(false);
      getPlayUrl();
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast("无法读取视频信息,请重新获取");
      getVideoSuccess.updateValueNotEquate(false);
      isFirstLoad.updateValueNotEquate(false);
      success.updateValueNotEquate(false);
    }
  }

  Future<void> getPlayUrl() async {
    var quality = qualites[currentQuality.value];
    var playUrlList = quality.playUrlList;
    if (playUrlList.isNullOrEmpty) {
      try {
        playUrlList = await currentSite.liveSite.getPlayUrls(
          detail: liveRoomRx.toLiveRoom(),
          quality: qualites[currentQuality.value],
        );
      } catch (e) {
        CoreLog.error(e);
        getInfoError("无法读取播放地址");
        return;
      }
      quality.playUrlList = playUrlList;
    }
    if (playUrlList.isNullOrEmpty) {
      SmartDialog.showToast("无法读取播放地址,请重新获取", displayTime: const Duration(seconds: 2));
      getVideoSuccess.updateValueNotEquate(false);
      isFirstLoad.updateValueNotEquate(false);
      success.updateValueNotEquate(false);
      return;
    }
    if (currentLineIndex.value >= quality.playUrlList.length) {
      currentLineIndex.updateValueNotEquate(quality.playUrlList.length - 1);
    }
    playUrls.updateValueNotEquate(playUrlList);
    // log("playUrlList : ${playUrlList}", name: runtimeType.toString());
    setPlayer();
  }

  /// 第一次获取清晰度 通过清晰度名
  Future<int> getQualityLevelByResolution() async {
    var playQualites = qualites.value;
    var resolution = settings.preferResolution.value;
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      /// 移动网络
      resolution = settings.preferResolutionMobile.value;
    }
    int qualityLevel = settings.resolutionsList.indexOf(resolution);
    qualityLevel = math.max(0, qualityLevel);
    qualityLevel = math.min(playQualites.length - 1, qualityLevel);

    // fix 清晰度判断逻辑, 根据名字匹配
    for (var i = 0; i < playQualites.length; i++) {
      var playQuality = playQualites[i];
      if (playQuality.quality.contains(resolution)) {
        qualityLevel = i;
        break;
      }
    }
    return qualityLevel;
  }

  /// 第一次获取清晰度 通过比特率
  Future<int> getQualityLevelByBitRate() async {
    var playQualites = qualites.value;
    var bitRate = settings.bitRate.value;
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      /// 移动网络
      bitRate = settings.bitRateMobile.value;
    }
    int qualityLevel = 0;

    // fix 清晰度判断逻辑, 根据名字匹配
    for (var i = 0; i < playQualites.length; i++) {
      var playQuality = playQualites[i];
      var vBitRate = playQuality.bitRate;
      if (vBitRate * 1.3 >= bitRate) {
        qualityLevel = i;
      } else {
        continue;
      }
      if (vBitRate * 0.8 <= bitRate) {
        return qualityLevel;
      }
    }

    /// 原画清晰度
    if (bitRate <= 0) {
      return 0;
    }
    return qualityLevel;
  }

  void setPlayer() async {
    var headers = currentSite.liveSite.getVideoHeaders();
    try {
      // await videoController?.pause();
    } catch (e) {
      // [Player] has been disposed
      videoController?.dispose();
      // log(e.toString());
      CoreLog.error(e);
    }
    // log("playUrls ${playUrls.value}", name: runtimeType.toString());
    // log("currentLineIndex : $currentLineIndex", name: runtimeType.toString());
    // log("current play url : ${playUrls.value[currentLineIndex.value]}", name: runtimeType.toString());
    // try{
    //   videoController?.dispose();
    //   videoController == null;
    // }catch(e) {
    //   CoreLog.error(e);
    // }
    if (videoController == null || videoController!.hasDestory) {
      videoController = VideoController(
        livePlayController: this,
        playerKey: playerKey,
        room: liveRoomRx.toLiveRoom(),
        datasourceType: 'network',
        datasource: playUrls.value[currentLineIndex.value].playUrl,
        allowScreenKeepOn: settings.enableScreenKeepOn.value,
        allowBackgroundPlay: settings.enableBackgroundPlay.value,
        fullScreenByDefault: settings.enableFullScreenDefault.value,
        autoPlay: true,
        headers: headers,
        qualiteName: qualites[currentQuality.value].quality,
        currentLineIndex: currentLineIndex.value,
        currentQuality: currentQuality.value,
      );
      subscriptionList.add(
        videoController?.videoPlayer.isFullscreen.listen((e) {
          isFullscreen.updateValueNotEquate(e);
          streamController.add(e);
        }),
      );
    } else {
      // videoController?.datasource = playUrls.value[currentLineIndex.value].playUrl;
      // videoController?.qualiteName = qualites[currentQuality.value].quality;
      // videoController?.currentLineIndex = currentLineIndex.value;
      // videoController?.currentQuality = currentQuality.value;
      // videoController?.setDataSource(playUrls.value[currentLineIndex.value].playUrl, headers);
      // videoController?.initVideoController();
      // videoController?.play();
    }

    videoController?.datasource = playUrls.value[currentLineIndex.value].playUrl;
    videoController?.qualiteName = qualites[currentQuality.value].quality;
    videoController?.currentLineIndex = currentLineIndex.value;
    videoController?.currentQuality = currentQuality.value;
    videoController?.setDataSource(playUrls.value[currentLineIndex.value].playUrl, headers);

    success.updateValueNotEquate(true);

    networkTimer?.cancel();
    networkTimer = Timer(const Duration(seconds: 10), () async {
      if (videoController != null && videoController!.hasDestory == false) {
        final connectivityResults = await Connectivity().checkConnectivity();
        if (!connectivityResults.contains(ConnectivityResult.none)) {
          if (videoController?.isActivePause.value != true && videoController?.videoPlayer.isPlaying.value != true) {
            CoreLog.d("videoController refresh");
            videoController!.refresh();
          }
        }
      }
    });
  }

  Future<void> openNaviteAPP() async {
    var liveRoom = liveRoomRx.toLiveRoom();
    var jumpToNativeUrl = currentSite.liveSite.getJumpToNativeUrl(liveRoom);
    var jumpToWebUrl = currentSite.liveSite.getJumpToWebUrl(liveRoom);
    if (jumpToNativeUrl == "" && jumpToWebUrl == "") {
      return;
    }
    try {
      if (Platform.isAndroid) {
        await launchUrlString(jumpToNativeUrl, mode: LaunchMode.externalApplication);
      } else {
        await launchUrlString(jumpToWebUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      SmartDialog.showToast("无法打开APP，将使用浏览器打开");
      await launchUrlString(jumpToWebUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void onClose() {
    disPoserPlayer();
    super.onClose();
  }

  @override
  void dispose() {
    disPoserPlayer();
    super.dispose();
  }

  /// 弹幕
  late DanmakuControllerBase danmakuController;

  void sendDanmaku(LiveMessage msg) {
    if (settings.hideDanmaku.value) return;
    danmakuController.addDanmaku(IDanmakuContentItem(msg.message, color: msg.color));
  }

  /// ------------------------- 定时关闭
  void initAutoShutDown() {
    setAutoExit();
    subscriptionList.add(
      settings.autoShutDownTime.listen((value) {
        setAutoExit();
      }),
    );
    subscriptionList.add(
      settings.enableAutoShutDownTime.listen((value) {
        setAutoExit();
      }),
    );
  }

  int getCurrentMinute() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000 ~/ 60;
  }

  void switchRoom(LiveRoom room) async {
    success.value = false;
    hasError.value = false;
    messages.clear();
    if (videoController != null && !videoController!.hasDestory) {
      await videoController?.destory();
      videoController = null;
    }
    isFirstLoad.value = true;
    getVideoSuccess.value = true;
    loadTimeOut.value = false;
    liveRoomRx.updateByLiveRoom(room);
    onInitPlayerState(firstLoad: true);
  }

  Timer? autoExitTimer;
  var countdown = 0.obs;
  var delayAutoExit = false.obs;
  void setAutoExit() {
    if (!settings.enableAutoShutDownTime.value) {
      autoExitTimer?.cancel();
      return;
    }
    autoExitTimer?.cancel();
    countdown.value = settings.autoShutDownTime.value * 60;
    CoreLog.d("countdown: $countdown");
    var refreshTimeSecond = 1;
    autoExitTimer = Timer.periodic(Duration(seconds: refreshTimeSecond), (timer) async {
      countdown.value -= refreshTimeSecond;
      CoreLog.d("countdown: $countdown");
      if (countdown.value <= 0) {
        countdown.value = 0;
        timer = Timer(const Duration(seconds: 10), () async {
          await WakelockPlus.disable();
          doubleClickExit;
          exit(0);
        });
        autoExitTimer?.cancel();
        var delay = await Utils.showAlertDialog(
          S.current.settings_delay_close_info,
          title: S.current.settings_delay_close,
          confirm: S.current.settings_delay,
          cancel: S.current.settings_close,
          selectable: true,
        );
        if (delay) {
          timer.cancel();
          delayAutoExit.value = true;
          setAutoExit();
        } else {
          delayAutoExit.value = false;
          await WakelockPlus.disable();
          exit(0);
        }
      }
    });
  }
}
