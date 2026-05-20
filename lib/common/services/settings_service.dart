import 'dart:io';
import 'dart:convert';
import 'dart:developer';
import 'package:pure_live/common/index.dart';
import 'package:stop_watch_timer/stop_watch_timer.dart';
import 'package:flutter_exit_app/flutter_exit_app.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/common/global/win_auto_start.dart';
import 'package:pure_live/modules/web_dav/webdav_config.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';

class SettingsService extends GetxController {
  // ==============================
  // 🔹 Getter (computed properties)
  // ==============================
  ThemeMode get themeMode => AppConsts.themeModes[themeModeName.value]!;
  Locale get language => AppConsts.languages[languageName.value]!;
  List<String> get resolutionsList => PlayerConsts.resolutions;
  List<BoxFit> get videofitArrary => PlayerConsts.videofitList;
  List<String> get playerlist => PlayerConsts.players;

  // ==============================
  // 🎨 主题 & 语言
  // ==============================
  final themeModeName = (HivePrefUtil.getString('themeMode') ?? "System").obs;
  final enableDynamicTheme = (HivePrefUtil.getBool('enableDynamicTheme') ?? false).obs;
  final themeColorSwitch = (HivePrefUtil.getString('themeColorSwitch') ?? Colors.blue.hex).obs;
  final languageName = (HivePrefUtil.getString('language') ?? "简体中文").obs;

  // ==============================
  // ⚙️ 基础功能开关
  // ==============================
  final autoRefreshTime = (HivePrefUtil.getInt('autoRefreshTime') ?? 3).obs;
  final enableDenseFavorites = (HivePrefUtil.getBool('enableDenseFavorites') ?? true).obs;
  final enableBackgroundPlay = (HivePrefUtil.getBool('enableBackgroundPlay') ?? false).obs;
  final enableStartUp = (HivePrefUtil.getBool('enableStartUp') ?? true).obs;
  final enableRotateScreenWithSystem = (HivePrefUtil.getBool('enableRotateScreenWithSystem') ?? false).obs;
  final enableScreenKeepOn = (HivePrefUtil.getBool('enableScreenKeepOn') ?? true).obs;
  final enableAutoCheckUpdate = (HivePrefUtil.getBool('enableAutoCheckUpdate') ?? true).obs;
  final enableFullScreenDefault = (HivePrefUtil.getBool('enableFullScreenDefault') ?? false).obs;
  final dontAskExit = (HivePrefUtil.getBool('dontAskExit') ?? false).obs;
  final exitChoose = (HivePrefUtil.getString('exitChoose') ?? '').obs;
  final showSplashPage = (HivePrefUtil.getBool('showSplashPage') ?? true).obs;

  // ==============================
  // ⏰ 自动关机
  // ==============================
  final autoShutDownTime = (HivePrefUtil.getInt('autoShutDownTime') ?? 120).obs;
  final enableAutoShutDownTime = (HivePrefUtil.getBool('enableAutoShutDownTime') ?? false).obs;
  final StopWatchTimer _stopWatchTimer = StopWatchTimer(mode: StopWatchMode.countDown);
  StopWatchTimer get stopWatchTimer => _stopWatchTimer;

  // ==============================
  // 📺 播放器设置
  // ==============================
  final videoFitIndex = (HivePrefUtil.getInt('videoFitIndex') ?? 0).obs;
  final hideDanmaku = (HivePrefUtil.getBool('hideDanmaku') ?? false).obs;
  final danmakuTopArea = (HivePrefUtil.getDouble('danmakuTopArea') ?? 0.0).obs;
  final danmakuArea = (HivePrefUtil.getDouble('danmakuArea') ?? 1.0).obs;
  final danmakuBottomArea = (HivePrefUtil.getDouble('danmakuBottomArea') ?? 0.5).obs;
  final danmakuSpeed = (HivePrefUtil.getDouble('danmakuSpeed') ?? 8.0).obs;
  final danmakuFontSize = (HivePrefUtil.getDouble('danmakuFontSize') ?? 16.0).obs;
  final danmakuFontBorder = (HivePrefUtil.getDouble('danmakuFontBorder') ?? 4.0).obs;
  final danmakuOpacity = (HivePrefUtil.getDouble('danmakuOpacity') ?? 1.0).obs;

  final videoPlayerIndex = (HivePrefUtil.getInt('videoPlayerIndex') ?? 0).obs;
  final useHardStopOnExit = (HivePrefUtil.getBool('useHardStopOnExit') ?? true).obs;
  final enableCodec = (HivePrefUtil.getBool('enableCodec') ?? true).obs;
  final playerCompatMode = (HivePrefUtil.getBool('playerCompatMode') ?? false).obs;
  final customPlayerOutput = (HivePrefUtil.getBool('customPlayerOutput') ?? false).obs;
  final videoOutputDriver = (HivePrefUtil.getString('videoOutputDriver') ?? "gpu").obs;
  final audioOutputDriver = (HivePrefUtil.getString('audioOutputDriver') ?? "auto").obs;
  final videoHardwareDecoder = (HivePrefUtil.getString('videoHardwareDecoder') ?? "auto").obs;
  final floatPlay = (HivePrefUtil.getBool('floatPlay') ?? false).obs;
  final enableProxy = (HivePrefUtil.getBool('enableProxy') ?? false).obs;
  final proxyHost = (HivePrefUtil.getString('proxyHost') ?? '').obs;
  final proxyPort = (HivePrefUtil.getInt('proxyPort') ?? 1080).obs;
  // ==============================
  // 🍪 平台 Cookie
  // ==============================
  final bilibiliCookie = (HivePrefUtil.getString('bilibiliCookie') ?? '').obs;
  final huyaCookie = (HivePrefUtil.getString('huyaCookie') ?? '').obs;
  final douyinCookie = (HivePrefUtil.getString('douyinCookie') ?? '').obs;
  final kuaishouCookie = (HivePrefUtil.getString('kuaishouCookie') ?? '').obs;

  // ==============================
  // 📋 列表数据：屏蔽、热区、偏好
  // ==============================
  final shieldList = ((HivePrefUtil.getStringList('shieldList') ?? [])).obs;
  final hotAreasList = ((HivePrefUtil.getStringList('hotAreasList') ?? AppConsts.supportSites)).obs;
  final preferResolution = (HivePrefUtil.getString('preferResolution') ?? PlayerConsts.resolutions[0]).obs;
  final preferResolutionCellular =
      (HivePrefUtil.getString('preferResolutionCellular') ?? PlayerConsts.resolutions[0]).obs;
  final preferPlatform = (HivePrefUtil.getString('preferPlatform') ?? Sites.bilibiliSite).obs;
  final enableDanmakuDisplay = (HivePrefUtil.getBool('enableDanmakuDisplay') ?? true).obs;

  // ==============================
  // ❤️ 收藏 & 历史
  // ==============================
  final favoriteRooms =
      ((HivePrefUtil.getStringList('favoriteRooms') ?? []).map((e) => LiveRoom.fromJson(jsonDecode(e))).toList()).obs;
  final historyRooms =
      ((HivePrefUtil.getStringList('historyRooms') ?? []).map((e) => LiveRoom.fromJson(jsonDecode(e))).toList()).obs;
  final favoriteAreas =
      ((HivePrefUtil.getStringList('favoriteAreas') ?? []).map((e) => LiveArea.fromJson(jsonDecode(e))).toList()).obs;

  // ==============================
  // ☁️ WebDAV & 备份
  // ==============================
  final backupDirectory = (HivePrefUtil.getString('backupDirectory') ?? '').obs;
  final currentWebDavConfig = (HivePrefUtil.getString('currentWebDavConfig') ?? '').obs;
  final webDavConfigs =
      ((HivePrefUtil.getStringList('webDavConfigs') ?? []).map((e) => WebDAVConfig.fromJson(jsonDecode(e))).toList())
          .obs;
  final m3uDirectory = (HivePrefUtil.getString('m3uDirectory') ?? 'm3uDirectory').obs;

  // ==============================
  // 🎨 颜色映射（静态）
  // ==============================
  final Map<ColorSwatch<Object>, String> colorsNameMap = AppConsts.themeColors.map(
    (key, value) => MapEntry(ColorTools.createPrimarySwatch(value), key),
  );
  final cacheSizeMB = 0.0.obs;
  // ==============================
  // 🧩 Lifecycle: onInit
  // ==============================
  @override
  void onInit() {
    super.onInit();

    // === 监听并持久化 ===
    enableDynamicTheme.listen((bool value) {
      HivePrefUtil.setBool('enableDynamicTheme', value);
      update(['myapp']);
    });

    themeColorSwitch.listen((value) {
      themeColorSwitch.value = value;
      HivePrefUtil.setString('themeColorSwitch', value);
    });

    enableDenseFavorites.listen((value) {
      HivePrefUtil.setBool('enableDenseFavorites', value);
    });

    autoRefreshTime.listen((value) {
      HivePrefUtil.setInt('autoRefreshTime', value);
    });

    debounce(autoShutDownTime, (callback) {
      HivePrefUtil.setInt('autoShutDownTime', autoShutDownTime.value);
      if (enableAutoShutDownTime.isTrue) {
        _stopWatchTimer.onStopTimer();
        _stopWatchTimer.setPresetMinuteTime(autoShutDownTime.value, add: false);
        _stopWatchTimer.onStartTimer();
      } else {
        _stopWatchTimer.onStopTimer();
      }
    }, time: 1.seconds);

    enableBackgroundPlay.listen((value) {
      HivePrefUtil.setBool('enableBackgroundPlay', value);
    });

    enableStartUp.listen((value) async {
      HivePrefUtil.setBool('enableStartUp', value);
      setupLaunchAtStartup();
    });

    enableRotateScreenWithSystem.listen((value) {
      HivePrefUtil.setBool('enableRotateScreenWithSystem', value);
    });

    enableScreenKeepOn.listen((value) {
      HivePrefUtil.setBool('enableScreenKeepOn', value);
    });

    debounce(enableAutoShutDownTime, (callback) {
      HivePrefUtil.setBool('enableAutoShutDownTime', enableAutoShutDownTime.value);
      if (enableAutoShutDownTime.value == true) {
        _stopWatchTimer.onStopTimer();
        _stopWatchTimer.setPresetMinuteTime(autoShutDownTime.value, add: false);
        _stopWatchTimer.onStartTimer();
      } else {
        _stopWatchTimer.onStopTimer();
      }
    }, time: 1.seconds);

    enableAutoCheckUpdate.listen((value) {
      HivePrefUtil.setBool('enableAutoCheckUpdate', value);
    });

    enableFullScreenDefault.listen((value) {
      HivePrefUtil.setBool('enableFullScreenDefault', value);
    });

    shieldList.listen((value) {
      HivePrefUtil.setStringList('shieldList', value);
    });

    hotAreasList.listen((value) {
      HivePrefUtil.setStringList('hotAreasList', value);
    });

    favoriteRooms.listen((rooms) {
      HivePrefUtil.setStringList('favoriteRooms', favoriteRooms.map<String>((e) => jsonEncode(e.toJson())).toList());
    });

    webDavConfigs.listen((configs) {
      HivePrefUtil.setStringList('webDavConfigs', configs.map<String>((e) => jsonEncode(e.toJson())).toList());
    });

    currentWebDavConfig.listen((config) {
      HivePrefUtil.setString('currentWebDavConfig', config);
    });

    favoriteAreas.listen((rooms) {
      HivePrefUtil.setStringList('favoriteAreas', favoriteAreas.map<String>((e) => jsonEncode(e.toJson())).toList());
    });

    historyRooms.listen((rooms) {
      HivePrefUtil.setStringList('historyRooms', historyRooms.map<String>((e) => jsonEncode(e.toJson())).toList());
    });

    backupDirectory.listen((String value) {
      HivePrefUtil.setString('backupDirectory', value);
    });

    onInitShutDown();

    _stopWatchTimer.fetchEnded.listen((value) {
      _stopWatchTimer.onStopTimer();
      FlutterExitApp.exitApp();
    });

    floatPlay.listen((value) {
      HivePrefUtil.setBool('floatPlay', value);
    });

    enableProxy.listen((value) {
      HivePrefUtil.setBool('enableProxy', value);
    });

    proxyHost.listen((value) {
      HivePrefUtil.setString('proxyHost', value);
    });

    proxyPort.listen((value) {
      HivePrefUtil.setInt('proxyPort', value);
    });

    videoFitIndex.listen((value) {
      HivePrefUtil.setInt('videoFitIndex', value);
    });

    hideDanmaku.listen((value) {
      HivePrefUtil.setBool('hideDanmaku', value);
    });

    danmakuArea.listen((value) {
      HivePrefUtil.setDouble('danmakuArea', value);
    });

    danmakuTopArea.listen((value) {
      HivePrefUtil.setDouble('danmakuTopArea', value);
    });

    danmakuBottomArea.listen((value) {
      HivePrefUtil.setDouble('danmakuBottomArea', value);
    });

    danmakuSpeed.listen((value) {
      HivePrefUtil.setDouble('danmakuSpeed', value);
    });

    danmakuFontSize.listen((value) {
      HivePrefUtil.setDouble('danmakuFontSize', value);
    });

    danmakuFontBorder.listen((value) {
      HivePrefUtil.setDouble('danmakuFontBorder', value);
    });

    danmakuOpacity.listen((value) {
      HivePrefUtil.setDouble('danmakuOpacity', value);
    });

    enableCodec.listen((value) {
      HivePrefUtil.setBool('enableCodec', value);
    });

    playerCompatMode.listen((value) {
      HivePrefUtil.setBool('playerCompatMode', value);
    });

    videoPlayerIndex.listen((value) {
      HivePrefUtil.setInt('videoPlayerIndex', value);
    });

    useHardStopOnExit.listen((value) {
      HivePrefUtil.setBool('useHardStopOnExit', value);
    });

    bilibiliCookie.listen((value) {
      HivePrefUtil.setString('bilibiliCookie', value);
    });

    huyaCookie.listen((value) {
      HivePrefUtil.setString('huyaCookie', value);
    });

    dontAskExit.listen((value) {
      HivePrefUtil.setBool('dontAskExit', value);
    });

    showSplashPage.listen((value) {
      HivePrefUtil.setBool('showSplashPage', value);
    });

    exitChoose.listen((value) {
      HivePrefUtil.setString('exitChoose', value);
    });

    douyinCookie.listen((value) {
      HivePrefUtil.setString('douyinCookie', value);
    });

    kuaishouCookie.listen((value) {
      HivePrefUtil.setString('kuaishouCookie', value);
    });

    customPlayerOutput.listen((value) {
      HivePrefUtil.setBool('customPlayerOutput', value);
    });

    videoOutputDriver.listen((value) {
      HivePrefUtil.setString('videoOutputDriver', value);
    });

    audioOutputDriver.listen((value) {
      HivePrefUtil.setString('audioOutputDriver', value);
    });

    videoHardwareDecoder.listen((value) {
      HivePrefUtil.setString('videoHardwareDecoder', value);
    });

    enableDanmakuDisplay.listen((value) {
      HivePrefUtil.setBool('enableDanmakuDisplay', value);
    });
    getCacheSize();
  }

  // ==============================
  // 🛠️ 方法区（按功能分组）
  // ==============================

  // --- 主题 & 语言 ---
  void changeThemeMode(String mode) {
    themeModeName.value = mode;
    HivePrefUtil.setString('themeMode', mode);
    Get.changeThemeMode(themeMode);
  }

  void changeThemeColorSwitch(String hexColor) {
    var themeColor = HexColor(hexColor);
    var lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;
    var darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
    Get.changeTheme(lightTheme);
    Get.changeTheme(darkTheme);
  }

  void changeLanguage(String value) {
    languageName.value = value;
    HivePrefUtil.setString('language', value);
    EasyLocalization.of(Get.context!)!.setLocale(AppConsts.languages[value]!);
    Get.updateLocale(language);
  }

  // --- 播放器 & 分辨率 ---
  void changePlayer(int value) {
    videoPlayerIndex.value = value;
    HivePrefUtil.setInt('videoPlayerIndex', value);
  }

  void changePreferResolution(String name) {
    if (PlayerConsts.resolutions.indexWhere((e) => e == name) != -1) {
      preferResolution.value = name;
      HivePrefUtil.setString('preferResolution', name);
    }
  }

  void changePreferResolutionCellular(String name) {
    if (PlayerConsts.resolutions.indexWhere((e) => e == name) != -1) {
      preferResolutionCellular.value = name;
      HivePrefUtil.setString('preferResolutionCellular', name);
    }
  }

  void changePreferPlatform(String name) {
    List<String> platforms = Sites.supportSites.map((site) => site.id).toList();
    if (platforms.indexWhere((e) => e == name) != -1) {
      preferPlatform.value = name;
      update(['myapp']);
      HivePrefUtil.setString('preferPlatform', name);
    }
  }

  // --- 自动关机 ---
  void onInitShutDown() {
    if (enableAutoShutDownTime.isTrue) {
      _stopWatchTimer.setPresetMinuteTime(autoShutDownTime.value, add: false);
      _stopWatchTimer.onStartTimer();
    }
  }

  void changeShutDownConfig(int minutes, bool isAutoShutDown) {
    autoShutDownTime.value = minutes;
    enableAutoShutDownTime.value = isAutoShutDown;
    HivePrefUtil.setInt('autoShutDownTime', minutes);
    HivePrefUtil.setBool('enableAutoShutDownTime', isAutoShutDown);
    onInitShutDown();
  }

  void changeAutoRefreshConfig(int minutes) {
    autoRefreshTime.value = minutes;
    HivePrefUtil.setInt('autoRefreshTime', minutes);
  }

  // --- 收藏 & 历史操作 ---
  bool isFavorite(LiveRoom room) {
    return favoriteRooms.any((element) => element.roomId == room.roomId);
  }

  LiveRoom getLiveRoomByRoomId(String roomId, String platform) {
    if (!favoriteRooms.any((element) => element.roomId == roomId) &&
        !historyRooms.any((element) => element.roomId == roomId)) {
      return LiveRoom(roomId: roomId, platform: platform, liveStatus: LiveStatus.unknown);
    }
    return favoriteRooms.firstWhere(
      (element) => element.roomId == roomId && element.platform == platform,
      orElse: () => historyRooms.firstWhere((element) => element.roomId == roomId && element.platform == platform),
    );
  }

  bool addRoom(LiveRoom room) {
    if (favoriteRooms.any((element) => element.roomId == room.roomId)) {
      return false;
    }
    favoriteRooms.add(room);
    return true;
  }

  void addShieldList(String value) {
    shieldList.add(value);
  }

  void removeShieldList(int value) {
    shieldList.removeAt(value);
  }

  bool removeRoom(LiveRoom room) {
    if (!favoriteRooms.any((element) => element.roomId == room.roomId)) {
      return false;
    }
    favoriteRooms.remove(room);
    return true;
  }

  bool updateRoom(LiveRoom room) {
    int idx = favoriteRooms.indexWhere((element) => element.roomId == room.roomId);
    updateRoomInHistory(room);
    if (idx == -1) return false;
    favoriteRooms[idx] = room;
    return true;
  }

  void updateRooms(List<LiveRoom> rooms) {
    favoriteRooms.value = rooms;
  }

  bool updateRoomInHistory(LiveRoom room) {
    int idx = historyRooms.indexWhere((element) => element.roomId == room.roomId);
    if (idx == -1) return false;
    historyRooms[idx] = room;
    return true;
  }

  void addRoomToHistory(LiveRoom room) {
    if (historyRooms.any((element) => element.roomId == room.roomId)) {
      historyRooms.remove(room);
    }
    updateRoom(room);
    if (historyRooms.length > 50) {
      historyRooms.removeRange(0, historyRooms.length - 50);
    }
    historyRooms.insert(0, room);
  }

  // --- 区域收藏 ---
  bool isFavoriteArea(LiveArea area) {
    return favoriteAreas.any(
      (element) =>
          element.areaId == area.areaId && element.platform == area.platform && element.areaType == area.areaType,
    );
  }

  bool addArea(LiveArea area) {
    if (favoriteAreas.any(
      (element) =>
          element.areaId == area.areaId && element.platform == area.platform && element.areaType == area.areaType,
    )) {
      return false;
    }
    favoriteAreas.add(area);
    return true;
  }

  Future<void> setupLaunchAtStartup() async {
    try {
      bool alreadyEnabled = WindowsAutoStart.isEnabled();
      if (enableStartUp.value) {
        if (alreadyEnabled == false) {
          bool result = WindowsAutoStart.enable();
          log("Enable result: $result");
        } else {
          WindowsAutoStart.disable();
        }
      }
    } catch (e) {
      log("Auto-start error: $e");
    }
  }

  bool removeArea(LiveArea area) {
    if (!favoriteAreas.any(
      (element) =>
          element.areaId == area.areaId && element.platform == area.platform && element.areaType == area.areaType,
    )) {
      return false;
    }
    favoriteAreas.remove(area);
    return true;
  }

  // --- WebDAV ---
  bool addWebDavConfig(WebDAVConfig config) {
    if (webDavConfigs.any((element) => element.name == config.name)) {
      return false;
    }
    webDavConfigs.add(config);
    return true;
  }

  bool removeWebDavConfig(WebDAVConfig config) {
    if (!webDavConfigs.any((element) => element.name == config.name)) {
      return false;
    }
    webDavConfigs.remove(config);
    return true;
  }

  bool updateWebDavConfig(WebDAVConfig config) {
    int idx = webDavConfigs.indexWhere((element) => element.name == config.name);
    if (idx == -1) return false;
    webDavConfigs[idx] = config;
    return true;
  }

  void updateWebDavConfigs(List<WebDAVConfig> configs) {
    webDavConfigs.value = configs;
  }

  bool isWebDavConfigExist(String name) {
    return webDavConfigs.any((element) => element.name == name);
  }

  WebDAVConfig? getWebDavConfigByName(String name) {
    if (isWebDavConfigExist(name)) {
      return webDavConfigs.firstWhere((element) => element.name == name);
    } else {
      return null;
    }
  }

  // --- 备份 & 恢复 ---
  bool backup(File file) {
    try {
      final json = toJson();
      file.writeAsStringSync(jsonEncode(json));
    } catch (e) {
      return false;
    }
    return true;
  }

  bool recover(File file) {
    try {
      final json = file.readAsStringSync();
      fromJson(jsonDecode(json));
    } catch (e) {
      return false;
    }
    return true;
  }

  void setBilibiliCookit(String cookie) {
    final BiliBiliAccountService biliAccountService = Get.find<BiliBiliAccountService>();
    if (biliAccountService.cookie.isEmpty || biliAccountService.uid == 0) {
      biliAccountService.resetCookie(cookie);
      biliAccountService.loadUserInfo();
    }
  }

  Future<double> getCacheSize() async {
    final recordsDir = await AppPathManager().recordsDir;
    final imageCacheDir = await AppPathManager().imageCacheDir;
    final downloadDir = await AppPathManager().downloadDir;
    final iptvCacheDir = await AppPathManager().iptvCacheDir;
    final List<Directory> targetDirs = [recordsDir, imageCacheDir, downloadDir, iptvCacheDir];
    double totalSizeBytes = 0;
    for (final dir in targetDirs) {
      if (!dir.existsSync()) continue;

      try {
        final files = dir.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            totalSizeBytes += file.lengthSync();
          }
        }
      } catch (e) {
        debugPrint("计算目录 ${dir.path} 尺寸时出错: $e");
      }
    }
    cacheSizeMB.value = totalSizeBytes / 1024 / 1024;
    return totalSizeBytes / 1024 / 1024;
  }

  Future<void> clearCache() async {
    final recordsDir = await AppPathManager().recordsDir;
    final imageCacheDir = await AppPathManager().imageCacheDir;
    final downloadDir = await AppPathManager().downloadDir;
    final iptvCacheDir = await AppPathManager().iptvCacheDir;

    final List<Directory> targetDirs = [recordsDir, imageCacheDir, downloadDir, iptvCacheDir];
    for (final dir in targetDirs) {
      if (!dir.existsSync()) continue;

      try {
        dir.deleteSync(recursive: true);
        dir.createSync(recursive: true);
      } catch (e) {
        debugPrint("清空目录 ${dir.path} 失败: $e");
      }
    }
    cacheSizeMB.value = 0;
  }

  final refreshTurns = 0.0.obs;
  Future<void> handleManualRefresh() async {
    refreshTurns.value += 1.0;

    await getCacheSize();
  }

  void fromJson(Map<String, dynamic> json) {
    List<T> safeParseList<T>(dynamic data, T Function(Map<String, dynamic>) fromJsonFactory) {
      if (data == null || data is! List) return [];
      return data.map<T>((e) {
        if (e is Map<String, dynamic>) {
          return fromJsonFactory(e);
        } else if (e is String) {
          try {
            return fromJsonFactory(jsonDecode(e));
          } catch (err) {
            debugPrint("解析單項數據失敗: $err");
          }
        }
        return fromJsonFactory({}); // 備選方案
      }).toList();
    }

    favoriteRooms.value = safeParseList<LiveRoom>(json['favoriteRooms'], (m) => LiveRoom.fromJson(m));
    favoriteAreas.value = safeParseList<LiveArea>(json['favoriteAreas'], (m) => LiveArea.fromJson(m));
    shieldList.value = json['shieldList'] != null ? (json['shieldList'] as List).map((e) => e.toString()).toList() : [];
    hotAreasList.value = json['hotAreasList'] != null
        ? (json['hotAreasList'] as List).map((e) => e.toString()).toList()
        : [];
    autoShutDownTime.value = json['autoShutDownTime'] ?? 120;
    currentWebDavConfig.value = json['currentWebDavConfig'] ?? '';
    autoRefreshTime.value = json['autoRefreshTime'] ?? 3;
    themeModeName.value = AppConsts.themeModes.keys.firstWhere((e) => e == json['themeMode'], orElse: () => "System");
    enableAutoShutDownTime.value = json['enableAutoShutDownTime'] ?? false;
    enableDynamicTheme.value = json['enableDynamicTheme'] ?? false;
    enableDenseFavorites.value = json['enableDenseFavorites'] ?? false;
    enableBackgroundPlay.value = json['enableBackgroundPlay'] ?? false;
    enableStartUp.value = json['enableStartUp'] ?? true;
    enableRotateScreenWithSystem.value = json['enableRotateScreenWithSystem'] ?? false;
    enableScreenKeepOn.value = json['enableScreenKeepOn'] ?? true;
    enableAutoCheckUpdate.value = json['enableAutoCheckUpdate'] ?? true;
    enableFullScreenDefault.value = json['enableFullScreenDefault'] ?? false;
    languageName.value = AppConsts.languages.keys.firstWhere((e) => e == json['languageName'], orElse: () => "简体中文");
    preferResolution.value = PlayerConsts.resolutions.firstWhere(
      (e) => e == json['preferResolution'],
      orElse: () => PlayerConsts.resolutions[0],
    );
    preferResolutionCellular.value = PlayerConsts.resolutions.firstWhere(
      (e) => e == json['preferResolutionCellular'],
      orElse: () => PlayerConsts.resolutions[0],
    );
    List<String> platforms = Sites.supportSites.map((site) => site.id).toList();
    preferPlatform.value = platforms.firstWhere((e) => e == json['preferPlatform'], orElse: () => Sites.bilibiliSite);
    videoFitIndex.value = json['videoFitIndex'] ?? 0;
    hideDanmaku.value = json['hideDanmaku'] ?? false;
    danmakuTopArea.value = json['danmakuTopArea'] != null
        ? double.parse(json['danmakuTopArea'].toString()) > 0.4
              ? 0.4
              : double.parse(json['danmakuTopArea'].toString())
        : 0.0;
    danmakuArea.value = json['danmakuArea'] != null
        ? double.parse(json['danmakuArea'].toString()) > 1.0
              ? 1.0
              : double.parse(json['danmakuArea'].toString())
        : 1.0;
    danmakuBottomArea.value = double.parse(json['danmakuBottomArea'].toString());
    danmakuSpeed.value = json['danmakuSpeed'] != null ? double.parse(json['danmakuSpeed'].toString()) : 8.0;
    danmakuFontSize.value = json['danmakuFontSize'] != null ? double.parse(json['danmakuFontSize'].toString()) : 16.0;
    danmakuFontBorder.value = json['danmakuFontBorder'] != null
        ? double.parse(json['danmakuFontBorder'].toString())
        : 4.0;
    danmakuOpacity.value = json['danmakuOpacity'] != null ? double.parse(json['danmakuOpacity'].toString()) : 1.0;
    floatPlay.value = json['floatPlay'] ?? true;
    enableProxy.value = json['enableProxy'] ?? false;
    proxyHost.value = json['proxyHost'] ?? '';
    proxyPort.value = json['proxyPort'] ?? 1080;
    enableCodec.value = json['enableCodec'] ?? true;
    playerCompatMode.value = json['playerCompatMode'] ?? false;
    bilibiliCookie.value = json['bilibiliCookie'] ?? '';
    huyaCookie.value = json['huyaCookie'] ?? '';
    dontAskExit.value = json['dontAskExit'] ?? false;
    useHardStopOnExit.value = json['useHardStopOnExit'] ?? true;
    showSplashPage.value = json['showSplashPage'] ?? true;
    exitChoose.value = json['exitChoose'] ?? '';
    douyinCookie.value = json['douyinCookie'] ?? '';
    kuaishouCookie.value = json['kuaishouCookie'] ?? '';
    enableDanmakuDisplay.value = json['enableDanmakuDisplay'] ?? true;
    themeColorSwitch.value = json['themeColorSwitch'] ?? Colors.blue.hex;
    customPlayerOutput.value = json['customPlayerOutput'] ?? false;
    videoOutputDriver.value = PlayerConsts.videoOutputDrivers.keys.contains(json['videoOutputDriver'])
        ? json['videoOutputDriver']
        : 'gpu';
    audioOutputDriver.value = PlayerConsts.audioOutputDrivers.keys.contains(json['audioOutputDriver'])
        ? json['audioOutputDriver']
        : 'auto';
    videoHardwareDecoder.value = PlayerConsts.hardwareDecoder.keys.contains(json['videoHardwareDecoder'])
        ? json['audioOutputDriver']
        : 'auto';
    changeThemeMode(themeModeName.value);
    changeThemeColorSwitch(themeColorSwitch.value);
    setBilibiliCookit(bilibiliCookie.value);
    changeLanguage(languageName.value);
    changePreferResolution(preferResolution.value);
    changePreferResolutionCellular(preferResolutionCellular.value);
    changePreferPlatform(preferPlatform.value);
    changeShutDownConfig(autoShutDownTime.value, enableAutoShutDownTime.value);
    changeAutoRefreshConfig(autoRefreshTime.value);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['favoriteRooms'] = favoriteRooms.map<String>((e) => jsonEncode(e.toJson())).toList();
    json['webDavConfigs'] = webDavConfigs.map<String>((e) => jsonEncode(e.toJson())).toList();
    json['favoriteAreas'] = favoriteAreas.map<String>((e) => jsonEncode(e.toJson())).toList();
    json['themeMode'] = themeModeName.value;
    json['currentWebDavConfig'] = currentWebDavConfig.value;
    json['autoRefreshTime'] = autoRefreshTime.value;
    json['autoShutDownTime'] = autoShutDownTime.value;
    json['enableAutoShutDownTime'] = enableAutoShutDownTime.value;
    json['enableDynamicTheme'] = enableDynamicTheme.value;
    json['enableDenseFavorites'] = enableDenseFavorites.value;
    json['enableBackgroundPlay'] = enableBackgroundPlay.value;
    json['enableStartUp'] = enableStartUp.value;
    json['enableRotateScreenWithSystem'] = enableRotateScreenWithSystem.value;
    json['enableScreenKeepOn'] = enableScreenKeepOn.value;
    json['enableAutoCheckUpdate'] = enableAutoCheckUpdate.value;
    json['enableFullScreenDefault'] = enableFullScreenDefault.value;
    json['preferResolution'] = preferResolution.value;
    json['preferResolutionCellular'] = preferResolutionCellular.value;
    json['preferPlatform'] = preferPlatform.value;
    json['languageName'] = languageName.value;
    json['videoFitIndex'] = videoFitIndex.value;
    json['hideDanmaku'] = hideDanmaku.value;
    json['danmakuTopArea'] = danmakuTopArea.value;
    json['danmakuArea'] = 1.0;
    json['danmakuBottomArea'] = danmakuBottomArea.value;
    json['danmakuSpeed'] = danmakuSpeed.value;
    json['danmakuFontSize'] = danmakuFontSize.value;
    json['danmakuFontBorder'] = danmakuFontBorder.value;
    json['danmakuOpacity'] = danmakuOpacity.value;
    json['floatPlay'] = floatPlay.value;
    json['enableProxy'] = enableProxy.value;
    json['proxyHost'] = proxyHost.value;
    json['proxyPort'] = proxyPort.value;
    json['videoPlayerIndex'] = videoPlayerIndex.value;
    json['useHardStopOnExit'] = useHardStopOnExit.value;
    json['enableCodec'] = enableCodec.value;
    json['playerCompatMode'] = playerCompatMode.value;
    json['bilibiliCookie'] = bilibiliCookie.value;
    json['huyaCookie'] = huyaCookie.value;
    json['dontAskExit'] = dontAskExit.value;
    json['showSplashPage'] = showSplashPage.value;
    json['exitChoose'] = exitChoose.value;
    json['douyinCookie'] = douyinCookie.value;
    json['kuaishouCookie'] = kuaishouCookie.value;
    json['enableDanmakuDisplay'] = enableDanmakuDisplay.value;
    json['shieldList'] = shieldList.map<String>((e) => e.toString()).toList();
    json['hotAreasList'] = hotAreasList.map<String>((e) => e.toString()).toList();
    json['themeColorSwitch'] = themeColorSwitch.value;
    json['customPlayerOutput'] = customPlayerOutput.value;
    json['videoOutputDriver'] = videoOutputDriver.value;
    json['audioOutputDriver'] = audioOutputDriver.value;
    json['videoHardwareDecoder'] = videoHardwareDecoder.value;
    return json;
  }
}
