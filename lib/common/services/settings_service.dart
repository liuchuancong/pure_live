import 'dart:io';
import 'dart:convert';
import 'package:get/get.dart';
import 'setting_mixin/setting_webdav.dart';
import 'package:pure_live/common/index.dart';
import 'setting_mixin/setting_bit_rate.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:pure_live/modules/web_dav/webdav_config.dart';
import 'package:pure_live/plugins/extension/map_extension.dart';
import 'package:pure_live/plugins/extension/string_extension.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';
import 'package:pure_live/common/services/setting_mixin/setting_part.dart';
import 'package:pure_live/common/services/setting_mixin/auto_shut_down.dart';
import 'package:pure_live/modules/live_play/danmaku/danmaku_controller_factory.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/model/video_player_factory.dart';

class SettingsService extends GetxController with AutoShutDownMixin, SettingBitRateMixin, SettingWebdavMixin {
  static SettingsService get instance => Get.find<SettingsService>();

  SettingsService() {
    enableDynamicTheme.listen((bool value) {
      PrefUtil.setBool('enableDynamicTheme', value);
      update(['myapp']);
    });
    themeColorSwitch.listen((value) {
      themeColorSwitch.value = value;
      PrefUtil.setString('themeColorSwitch', value);
    });
    enableDenseFavorites.listen((value) {
      PrefUtil.setBool('enableDenseFavorites', value);
    });
    autoRefreshTime.listen((value) {
      PrefUtil.setInt('autoRefreshTime', value);
    });
    enableBackgroundPlay.listen((value) {
      PrefUtil.setBool('enableBackgroundPlay', value);
    });
    enableRotateScreenWithSystem.listen((value) {
      PrefUtil.setBool('enableRotateScreenWithSystem', value);
    });
    enableScreenKeepOn.listen((value) {
      PrefUtil.setBool('enableScreenKeepOn', value);
    });

    enableAutoCheckUpdate.listen((value) {
      PrefUtil.setBool('enableAutoCheckUpdate', value);
    });
    enableFullScreenDefault.listen((value) {
      PrefUtil.setBool('enableFullScreenDefault', value);
    });

    shieldList.listen((value) {
      PrefUtil.setStringList('shieldList', value);
    });

    hotAreasList.listen((value) {
      PrefUtil.setStringList('hotAreasList', value);
    });
    favoriteRooms.listen((rooms) {
      PrefUtil.setStringList('favoriteRooms', favoriteRooms.map<String>((e) => jsonEncode(e.toJson())).toList());
    });
    favoriteAreas.listen((rooms) {
      PrefUtil.setStringList('favoriteAreas', favoriteAreas.map<String>((e) => jsonEncode(e.toJson())).toList());
    });

    historyRooms.listen((rooms) {
      PrefUtil.setStringList('historyRooms', historyRooms.map<String>((e) => jsonEncode(e.toJson())).toList());
    });

    backupDirectory.listen((String value) {
      PrefUtil.setString('backupDirectory', value);
    });
    onInitShutDown();

    videoFitIndex.listen((value) {
      PrefUtil.setInt('videoFitIndex', value);
    });
    hideDanmaku.listen((value) {
      PrefUtil.setBool('hideDanmaku', value);
    });
    showColourDanmaku.listen((value) {
      PrefUtil.setBool('showColourDanmaku', value);
    });

    danmakuArea.listen((value) {
      PrefUtil.setDouble('danmakuArea', value);
    });

    danmakuSpeed.listen((value) {
      PrefUtil.setDouble('danmakuSpeed', value);
    });

    danmakuFontSize.listen((value) {
      PrefUtil.setDouble('danmakuFontSize', value);
    });

    danmakuFontBorder.listen((value) {
      PrefUtil.setDouble('danmakuFontBorder', value);
    });

    danmakuOpacity.listen((value) {
      PrefUtil.setDouble('danmakuOpacity', value);
    });

    doubleExit.listen((value) {
      PrefUtil.setBool('doubleExit', value);
    });

    enableCodec.listen((value) {
      PrefUtil.setBool('enableCodec', value);
    });

    videoPlayerIndex.listen((value) {
      PrefUtil.setInt('videoPlayerIndex', value);
    });

    danmakuControllerType.listen((value) {
      PrefUtil.setString('danmakuControllerType', value);
    });

    bilibiliCookie.listen((value) {
      PrefUtil.setString('bilibiliCookie', value);
    });

    mergeDanmuRating.listen((value) {
      PrefUtil.setDouble('mergeDanmuRating', value);
    });
    filterDanmuUserLevel.listen((value) {
      PrefUtil.setDouble('filterDanmuUserLevel', value);
    });
    filterDanmuFansLevel.listen((value) {
      PrefUtil.setDouble('filterDanmuFansLevel', value);
    });
    showDanmuFans.listen((value) {
      PrefUtil.setBool('showDanmuFans', value);
    });
    showDanmuUserLevel.listen((value) {
      PrefUtil.setBool('showDanmuUserLevel', value);
    });
    siteCookies.listen((value) {
      CoreLog.d("save siteCookies: $value");
      PrefUtil.setMap('siteCookies', value);
    });
    webDavConfigs.listen((configs) {
      PrefUtil.setStringList('webDavConfigs', configs.map<String>((e) => jsonEncode(e.toJson())).toList());
    });

    currentWebDavConfig.listen((config) {
      PrefUtil.setString('currentWebDavConfig', config);
    });
    init();
  }

  void init() {
    initAutoShutDown(settingPartList);
    initBitRate(settingPartList);
    initWebdav(settingPartList);
  }

  // Theme settings
  static Map<String, ThemeMode> themeModes = {
    "System": ThemeMode.system,
    "Dark": ThemeMode.dark,
    "Light": ThemeMode.light,
  };

  static String getThemeTitle(String themeModeName) {
    switch (themeModeName) {
      case "System":
        return S.current.system;
      case "Dark":
        return S.current.dark;
      case "Light":
        return S.current.light;
      default:
        return S.current.system;
    }
  }

  final themeModeName = (PrefUtil.getString('themeMode') ?? "System").obs;

  ThemeMode get themeMode => SettingsService.themeModes[themeModeName.value]!;

  void changeThemeMode(String mode) {
    themeModeName.value = mode;
    PrefUtil.setString('themeMode', mode);
    Get.changeThemeMode(themeMode);
  }

  void changeThemeColorSwitch(String hexColor) {
    var themeColor = HexColor(hexColor);
    var lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;
    var darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
    Get.changeTheme(lightTheme);
    Get.changeTheme(darkTheme);
  }

  static Map<String, Color> themeColors = {
    "Crimson": const Color.fromARGB(255, 220, 20, 60),
    "Orange": Colors.orange,
    "Chrome": const Color.fromARGB(255, 230, 184, 0),
    "Grass": Colors.lightGreen,
    "Teal": Colors.teal,
    "SeaFoam": const Color.fromARGB(255, 112, 193, 207),
    "Ice": const Color.fromARGB(255, 115, 155, 208),
    "Blue": Colors.blue,
    "Indigo": Colors.indigo,
    "Violet": Colors.deepPurple,
    "Primary": const Color(0xFF6200EE),
    "Orchid": const Color.fromARGB(255, 218, 112, 214),
    "Variant": const Color(0xFF3700B3),
    "Secondary": const Color(0xFF03DAC6),
  };

  // Make a custom ColorSwatch to name map from the above custom colors.
  final Map<ColorSwatch<Object>, String> colorsNameMap = themeColors.map(
    (key, value) => MapEntry(ColorTools.createPrimarySwatch(value), key),
  );

  final themeColorSwitch = (PrefUtil.getString('themeColorSwitch') ?? Colors.blue.hex).obs;

  static Map<String, Locale> languages = {
    "English": const Locale.fromSubtags(languageCode: 'en'),
    "简体中文": const Locale.fromSubtags(languageCode: 'zh', countryCode: 'CN'),
  };
  final languageName = (PrefUtil.getString('language') ?? "简体中文").obs;

  final webPort = (PrefUtil.getString('webPort') ?? "8008").obs;

  final webPortEnable = (PrefUtil.getBool('webPortEnable') ?? false).obs;

  Locale get language => SettingsService.languages[languageName.value]!;

  Future<void> changeLanguage(String value) async {
    languageName.value = value;
    PrefUtil.setString('language', value);
    Get.updateLocale(language);
    await S.load(SettingsService.languages[SettingsService.instance.languageName.value]!);
  }

  final currentWebDavConfig = (PrefUtil.getString('currentWebDavConfig') ?? '').obs;

  final webDavConfigs =
      ((PrefUtil.getStringList('webDavConfigs') ?? []).map((e) => WebDAVConfig.fromJson(jsonDecode(e))).toList()).obs;

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

  void changePlayer(int value) {
    videoPlayerIndex.value = value;
    PrefUtil.setInt('videoPlayerIndex', value);
  }

  final enableDynamicTheme = (PrefUtil.getBool('enableDynamicTheme') ?? false).obs;

  // Custom settings
  final autoRefreshTime = (PrefUtil.getInt('autoRefreshTime') ?? 3).obs;

  final enableDenseFavorites = (PrefUtil.getBool('enableDenseFavorites') ?? false).obs;

  final enableBackgroundPlay = (PrefUtil.getBool('enableBackgroundPlay') ?? false).obs;

  final enableRotateScreenWithSystem = (PrefUtil.getBool('enableRotateScreenWithSystem') ?? false).obs;

  final enableScreenKeepOn = (PrefUtil.getBool('enableScreenKeepOn') ?? true).obs;

  final enableAutoCheckUpdate = (PrefUtil.getBool('enableAutoCheckUpdate') ?? true).obs;
  final videoFitIndex = (PrefUtil.getInt('videoFitIndex') ?? 0).obs;
  final hideDanmaku = (PrefUtil.getBool('hideDanmaku') ?? false).obs;
  final showColourDanmaku = (PrefUtil.getBool('showColourDanmaku') ?? false).obs;
  final danmakuArea = (PrefUtil.getDouble('danmakuArea') ?? 1.0).obs;
  final danmakuSpeed = (PrefUtil.getDouble('danmakuSpeed') ?? 8.0).obs;
  final danmakuFontSize = (PrefUtil.getDouble('danmakuFontSize') ?? 16.0).obs;
  final danmakuFontBorder = (PrefUtil.getDouble('danmakuFontBorder') ?? 0.5).obs;

  final danmakuOpacity = (PrefUtil.getDouble('danmakuOpacity') ?? 1.0).obs;

  final enableFullScreenDefault = (PrefUtil.getBool('enableFullScreenDefault') ?? false).obs;

  final videoPlayerIndex = (PrefUtil.getInt('videoPlayerIndex') ?? 0).obs;
  final danmakuControllerType =
      (PrefUtil.getString('danmakuControllerType') ?? DanmakuControllerfactory.getDanmakuControllerTypeList()[0]).obs;

  final enableCodec = (PrefUtil.getBool('enableCodec') ?? true).obs;

  final mergeDanmuRating = (PrefUtil.getDouble('mergeDanmuRating') ?? 0.0).obs;

  final filterDanmuUserLevel = (PrefUtil.getDouble('filterDanmuUserLevel') ?? 0.0).obs;
  final filterDanmuFansLevel = (PrefUtil.getDouble('filterDanmuFansLevel') ?? 0.0).obs;
  final showDanmuFans = (PrefUtil.getBool('showDanmuFans') ?? true).obs;
  final showDanmuUserLevel = (PrefUtil.getBool('showDanmuUserLevel') ?? true).obs;

  final doubleExit = (PrefUtil.getBool('doubleExit') ?? true).obs;
  static const List<String> resolutions = ['原画', '蓝光8M', '蓝光4M', '超清', '高清', '标清', '流畅'];

  final siteCookies = ((PrefUtil.getMap('siteCookies')).toStringMap()).obs;

  final SettingPartList settingPartList = SettingPartList();

  // cookie

  final bilibiliCookie = (PrefUtil.getString('bilibiliCookie') ?? '').obs;
  static const List<BoxFit> videofitList = [
    BoxFit.contain,
    BoxFit.fill,
    BoxFit.cover,
    BoxFit.fitWidth,
    BoxFit.fitHeight,
  ];

  final preferResolution = (PrefUtil.getString('preferResolution') ?? resolutions[0]).obs;
  final preferResolutionMobile =
      (PrefUtil.getString('preferResolutionMobile') ?? resolutions[resolutions.length - 1]).obs;

  void changePreferResolution(String name) {
    if (resolutions.indexWhere((e) => e == name) != -1) {
      preferResolution.value = name;
      PrefUtil.setString('preferResolution', name);
    }
  }

  void changePreferResolutionMobile(String name) {
    if (resolutions.indexWhere((e) => e == name) != -1) {
      preferResolutionMobile.value = name;
      PrefUtil.setString('preferResolutionMobile', name);
    }
  }

  void changeDanmakuController(String name) {
    if (DanmakuControllerfactory.getDanmakuControllerTypeList().indexWhere((e) => e == name) != -1) {
      danmakuControllerType.value = name;
      PrefUtil.setString('danmakuControllerType', name);
    }
  }

  void changeWebListen(int port, bool enable) {
    try {
      if (enable) {
        // LocalHttpServer().startServer(port);
      } else {
        // LocalHttpServer().closeServer();
      }
    } catch (e) {
      CoreLog.error(e);
      SmartDialog.showToast('打开故障,请稍后重试');
    }
  }

  List<String> get resolutionsList => resolutions;

  List<BoxFit> get videofitArrary => videofitList;

  void changeAutoRefreshConfig(int minutes) {
    autoRefreshTime.value = minutes;
    PrefUtil.setInt('autoRefreshTime', minutes);
  }

  static List<String> platforms = Sites.supportSites.map((site) => site.id).toList();

  // static const List<String> players = ['Exo播放器', '系统播放器', 'IJK播放器', '阿里播放器', 'MpvPlayer'];
  static List<String> players = VideoPlayerFactory.getSupportVideoPlayerList().map((e) => e.playerName).toList();
  final preferPlatform = (PrefUtil.getString('preferPlatform') ?? platforms[0]).obs;

  List<String> get playerlist {
    if (videoPlayerIndex.value >= players.length) {
      videoPlayerIndex.value = 0;
    }
    return players;
  }

  void changePreferPlatform(String name) {
    if (platforms.indexWhere((e) => e == name) != -1) {
      preferPlatform.value = name;
      update(['myapp']);
      PrefUtil.setString('preferPlatform', name);
    }
  }

  static List<String> supportSites = Sites.supportSites.map((site) => site.id).toList();

  final shieldList = ((PrefUtil.getStringList('shieldList') ?? [])).obs;

  final hotAreasList = ((PrefUtil.getStringList('hotAreasList') ?? supportSites)).obs;

  // 用于标志 关注房间列表长度 是否变化,
  final favoriteRoomsLengthChangeFlag = false.obs;

  // Favorite rooms storage
  final favoriteRooms =
      ((PrefUtil.getStringList('favoriteRooms') ?? [])
              .map((e) => LiveRoom.fromJson(jsonDecode(e)))
              .where((room) => !room.roomId.isNullOrEmpty && !room.platform.isNullOrEmpty)
              .toList())
          .obs;

  // 存储关注，用于优化遍历
  late Map<String, LiveRoom> favoriteRoomsMap = toRoomMap(favoriteRooms.value);

  Map<String, LiveRoom> toRoomMap(List<LiveRoom> list) =>
      Map.fromEntries(list.map((e) => MapEntry(getLiveRoomKey(e), e)));

  final historyRooms =
      ((PrefUtil.getStringList('historyRooms') ?? [])
              .map((e) => LiveRoom.fromJson(jsonDecode(e)))
              .where((room) => !room.roomId.isNullOrEmpty && !room.platform.isNullOrEmpty)
              .toList())
          .obs;

  // 存储历史，用于优化遍历
  late Map<String, LiveRoom> historyRoomsMap = toRoomMap(historyRooms.value);

  String getLiveRoomKey(LiveRoom room) {
    return toLiveRoomKey(room.platform, room.roomId);
  }

  String toLiveRoomKey(String? platform, String? roomId) {
    return "${platform ?? ''}__${roomId ?? ''}";
  }

  bool isFavorite(LiveRoom room) {
    if (room.roomId.isNullOrEmpty || room.platform.isNullOrEmpty) {
      return false;
    }
    return favoriteRoomsMap.containsKey(getLiveRoomKey(room));
  }

  LiveRoom getLiveRoomByRoomId(String roomId, String platform) {
    var liveRoomKey = toLiveRoomKey(platform, roomId);
    return favoriteRoomsMap[liveRoomKey] ??
        historyRoomsMap[liveRoomKey] ??
        LiveRoom(roomId: roomId, platform: platform, liveStatus: LiveStatus.unknown);
  }

  bool addRoom(LiveRoom room) {
    if (room.roomId.isNullOrEmpty || room.platform.isNullOrEmpty) {
      return false;
    }
    var liveRoomKey = getLiveRoomKey(room);
    if (favoriteRoomsMap.containsKey(liveRoomKey)) {
      return false;
    }
    favoriteRoomsMap[liveRoomKey] = room;
    favoriteRooms.add(room);
    favoriteRoomsLengthChangeFlag.toggle();
    return true;
  }

  void addShieldList(String value) {
    shieldList.add(value);
  }

  void removeShieldList(int value) {
    shieldList.removeAt(value);
  }

  bool removeRoom(LiveRoom room) {
    var liveRoomKey = getLiveRoomKey(room);
    if (!favoriteRoomsMap.containsKey(liveRoomKey)) {
      return false;
    }
    favoriteRoomsMap.remove(liveRoomKey);
    favoriteRooms.remove(room);
    favoriteRoomsLengthChangeFlag.toggle();
    return true;
  }

  bool updateRoom(LiveRoom room) {
    if (room.roomId.isNullOrEmpty || room.platform.isNullOrEmpty) {
      return false;
    }
    updateRoomInHistory(room);

    var liveRoomKey = getLiveRoomKey(room);
    var containsKey = favoriteRoomsMap.containsKey(liveRoomKey);
    if (!containsKey) return false;
    favoriteRoomsMap[liveRoomKey] = room;
    favoriteRooms.value = favoriteRoomsMap.values.toList();
    return true;
  }

  LiveRoom updateRecordTag(LiveRoom newLiveRoom, LiveRoom oldLiveRoom) {
    if (newLiveRoom.recordWatching.isNullOrEmpty) {
      newLiveRoom.recordWatching = oldLiveRoom.recordWatching;
    }
    if (newLiveRoom.liveStatus == LiveStatus.live && newLiveRoom.recordWatching.isNotNullOrEmpty) {
      var watching = readableCountStrToNum(newLiveRoom.watching);
      var recordWatching = readableCountStrToNum(newLiveRoom.recordWatching);
      if (watching <= recordWatching * 1.2) {
        newLiveRoom.liveStatus = LiveStatus.replay;
        newLiveRoom.isRecord = true;
      }
    }
    // CoreLog.d(jsonEncode(newLiveRoom));
    // CoreLog.d(jsonEncode(oldLiveRoom));
    return newLiveRoom;
  }

  void innerUpdateRooms(List<LiveRoom> rooms, Map<String, LiveRoom> roomsMap, RxList<LiveRoom> rxList) {
    bool flag = false;
    for (var room in rooms) {
      var liveRoomKey = getLiveRoomKey(room);
      if (roomsMap.containsKey(liveRoomKey)) {
        flag = true;
        roomsMap[liveRoomKey] = updateRecordTag(room, roomsMap[liveRoomKey]!);
      }
    }
    if (flag) {
      rxList.value = roomsMap.values.toList();
    }
  }

  void updateRooms(List<LiveRoom> rooms) {
    innerUpdateRooms(rooms, favoriteRoomsMap, favoriteRooms);
    innerUpdateRooms(rooms, historyRoomsMap, historyRooms);
  }

  bool updateRoomInHistory(LiveRoom room) {
    if (room.roomId.isNullOrEmpty || room.platform.isNullOrEmpty) {
      return false;
    }
    var liveRoomKey = getLiveRoomKey(room);
    var containsKey = historyRoomsMap.containsKey(liveRoomKey);
    if (!containsKey) return false;
    historyRoomsMap[liveRoomKey] = room;
    historyRooms.value = historyRoomsMap.values.toList();
    return true;
  }

  /// 清除历史记录
  void clearHistory() {
    historyRoomsMap.clear();
    historyRooms.clear();
  }

  void addRoomToHistory(LiveRoom room) {
    if (room.roomId.isNullOrEmpty || room.platform.isNullOrEmpty) {
      return;
    }
    var liveRoomKey = getLiveRoomKey(room);
    if (historyRoomsMap.containsKey(liveRoomKey)) {
      historyRoomsMap.remove(liveRoomKey);
    }
    updateRoom(room);
    //默认只记录50条，够用了
    // 防止数据量大页面卡顿
    // if (historyRooms.length > 50) {
    //   historyRooms.removeRange(0, historyRooms.length - 50);
    // }
    historyRoomsMap[liveRoomKey] = room;
    var keys = historyRoomsMap.keys.toList();
    var length2 = keys.length;
    for (var i = 0; i < length2 - 50; i++) {
      historyRoomsMap.remove(keys[i]);
    }
    historyRooms.value = historyRoomsMap.values.toList();
  }

  // Favorite areas storage
  final favoriteAreas =
      ((PrefUtil.getStringList('favoriteAreas') ?? []).map((e) => LiveArea.fromJson(jsonDecode(e))).toList()).obs;

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

  // Backup & recover storage
  final backupDirectory = (PrefUtil.getString('backupDirectory') ?? '').obs;

  final m3uDirectory = (PrefUtil.getString('m3uDirectory') ?? 'm3uDirectory').obs;

  bool backup(File file) {
    try {
      final json = toJson();
      file.writeAsStringSync(jsonEncode(json));
    } catch (e) {
      CoreLog.error(e);
      return false;
    }
    return true;
  }

  bool recover(File file) {
    try {
      final json = file.readAsStringSync();
      fromJson(jsonDecode(json));
    } catch (e) {
      CoreLog.error(e);
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

  void fromJson(Map<String, dynamic> json) {
    favoriteRooms.value = json['favoriteRooms'] != null
        ? (json['favoriteRooms'] as List).map<LiveRoom>((e) => LiveRoom.fromJson(jsonDecode(e))).toList()
        : [];
    favoriteAreas.value = json['favoriteAreas'] != null
        ? (json['favoriteAreas'] as List).map<LiveArea>((e) => LiveArea.fromJson(jsonDecode(e))).toList()
        : [];
    shieldList.value = json['shieldList'] != null ? (json['shieldList'] as List).map((e) => e.toString()).toList() : [];
    hotAreasList.value = json['hotAreasList'] != null
        ? (json['hotAreasList'] as List).map((e) => e.toString()).toList()
        : [];

    favoriteRoomsMap = toRoomMap(favoriteRooms.value);
    historyRoomsMap = toRoomMap(historyRooms.value);
    favoriteRoomsLengthChangeFlag.toggle();

    autoRefreshTime.value = json['autoRefreshTime'] ?? 3;
    themeModeName.value = json['themeMode'] ?? "System";
    enableDynamicTheme.value = json['enableDynamicTheme'] ?? false;
    enableDenseFavorites.value = json['enableDenseFavorites'] ?? false;
    enableBackgroundPlay.value = json['enableBackgroundPlay'] ?? false;
    enableRotateScreenWithSystem.value = json['enableRotateScreenWithSystem'] ?? false;
    enableScreenKeepOn.value = json['enableScreenKeepOn'] ?? true;
    enableAutoCheckUpdate.value = json['enableAutoCheckUpdate'] ?? true;
    enableFullScreenDefault.value = json['enableFullScreenDefault'] ?? false;
    languageName.value = json['languageName'] ?? "简体中文";
    preferResolution.value = json['preferResolution'] ?? resolutions[0];
    preferResolutionMobile.value = json['preferResolutionMobile'] ?? resolutions[resolutions.length - 1];
    preferPlatform.value = json['preferPlatform'] ?? platforms[0];
    videoFitIndex.value = json['videoFitIndex'] ?? 0;
    hideDanmaku.value = json['hideDanmaku'] ?? false;
    showColourDanmaku.value = json['showColourDanmaku'] ?? false;
    danmakuControllerType.value =
        json['danmakuControllerType'] ?? DanmakuControllerfactory.getDanmakuControllerTypeList()[0];
    danmakuArea.value = json['danmakuArea'] != null ? double.parse(json['danmakuArea'].toString()) : 1.0;
    danmakuSpeed.value = json['danmakuSpeed'] != null ? double.parse(json['danmakuSpeed'].toString()) : 8.0;
    danmakuFontSize.value = json['danmakuFontSize'] != null ? double.parse(json['danmakuFontSize'].toString()) : 16.0;
    danmakuFontBorder.value = json['danmakuFontBorder'] != null
        ? double.parse(json['danmakuFontBorder'].toString())
        : 0.5;
    danmakuOpacity.value = json['danmakuOpacity'] != null ? double.parse(json['danmakuOpacity'].toString()) : 1.0;
    doubleExit.value = json['doubleExit'] ?? true;
    videoPlayerIndex.value = json['videoPlayerIndex'] ?? 0;
    enableCodec.value = json['enableCodec'] ?? true;
    mergeDanmuRating.value = json['mergeDanmuRating'] != null ? double.parse(json['mergeDanmuRating'].toString()) : 0.0;
    filterDanmuUserLevel.value = json['filterDanmuUserLevel'] != null
        ? double.parse(json['filterDanmuUserLevel'].toString())
        : 0.0;
    filterDanmuFansLevel.value = json['filterDanmuFansLevel'] != null
        ? double.parse(json['filterDanmuFansLevel'].toString())
        : 0.0;
    showDanmuFans.value = json['showDanmuFans'] ?? true;
    showDanmuUserLevel.value = json['showDanmuUserLevel'] ?? true;
    bilibiliCookie.value = json['bilibiliCookie'] ?? '';
    themeColorSwitch.value = json['themeColorSwitch'] ?? Colors.blue.hex;
    webPort.value = json['webPort'] ?? '8008';
    webPortEnable.value = json['webPortEnable'] ?? false;
    Map siteCookiesMap = (json['siteCookies'] ?? {});
    siteCookies.value = siteCookiesMap.toStringMap();
    changeThemeMode(themeModeName.value);
    changeThemeColorSwitch(themeColorSwitch.value);
    setBilibiliCookit(bilibiliCookie.value);
    changeLanguage(languageName.value);
    changePreferResolution(preferResolution.value);
    changePreferResolutionMobile(preferResolutionMobile.value);
    changePreferPlatform(preferPlatform.value);
    // changeShutDownConfig(autoShutDownTime.value, enableAutoShutDownTime.value);
    changeAutoRefreshConfig(autoRefreshTime.value);

    for (var f in settingPartList.fromJsonList) {
      f.call(json);
    }
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['favoriteRooms'] = favoriteRooms.map<String>((e) => jsonEncode(e.toJson())).toList();
    json['favoriteAreas'] = favoriteAreas.map<String>((e) => jsonEncode(e.toJson())).toList();
    json['themeMode'] = themeModeName.value;

    json['autoRefreshTime'] = autoRefreshTime.value;

    json['enableDynamicTheme'] = enableDynamicTheme.value;
    json['enableDenseFavorites'] = enableDenseFavorites.value;
    json['enableBackgroundPlay'] = enableBackgroundPlay.value;
    json['enableRotateScreenWithSystem'] = enableRotateScreenWithSystem.value;
    json['enableScreenKeepOn'] = enableScreenKeepOn.value;
    json['enableAutoCheckUpdate'] = enableAutoCheckUpdate.value;
    json['enableFullScreenDefault'] = enableFullScreenDefault.value;
    json['preferResolution'] = preferResolution.value;
    json['preferResolutionMobile'] = preferResolutionMobile.value;
    json['preferPlatform'] = preferPlatform.value;
    json['languageName'] = languageName.value;

    json['videoFitIndex'] = videoFitIndex.value;
    json['hideDanmaku'] = hideDanmaku.value;
    json['showColourDanmaku'] = showColourDanmaku.value;
    json['danmakuArea'] = danmakuArea.value;
    json['danmakuSpeed'] = danmakuSpeed.value;
    json['danmakuFontSize'] = danmakuFontSize.value;
    json['danmakuFontBorder'] = danmakuFontBorder.value;
    json['danmakuOpacity'] = danmakuOpacity.value;
    json['doubleExit'] = doubleExit.value;
    json['videoPlayerIndex'] = videoPlayerIndex.value;
    json['enableCodec'] = enableCodec.value;
    json['bilibiliCookie'] = bilibiliCookie.value;
    json['shieldList'] = shieldList.map<String>((e) => e.toString()).toList();
    json['hotAreasList'] = hotAreasList.map<String>((e) => e.toString()).toList();

    json['mergeDanmuRating'] = mergeDanmuRating.value;
    json['filterDanmuUserLevel'] = filterDanmuUserLevel.value;
    json['filterDanmuFansLevel'] = filterDanmuFansLevel.value;
    json['showDanmuFans'] = showDanmuFans.value;
    json['showDanmuUserLevel'] = showDanmuUserLevel.value;
    json['themeColorSwitch'] = themeColorSwitch.value;
    json['webPort '] = webPort.value;
    json['webPortEnable'] = webPortEnable.value;
    json['siteCookies'] = siteCookies.value;
    CoreLog.d("siteCookies: ${siteCookies.value}");

    json['danmakuControllerType'] = danmakuControllerType.value;

    for (var f in settingPartList.toJsonList) {
      f.call(json);
    }

    return json;
  }

  Map<String, dynamic> defaultConfig() {
    Map<String, dynamic> json = {
      "favoriteRooms": [],
      "favoriteAreas": [],
      "themeMode": "Light",
      "themeColor": "Chrome",
      "enableDynamicTheme": false,
      "autoShutDownTime": 120,
      "autoRefreshTime": 3,
      "languageName": languageName.value,
      "enableAutoShutDownTime": false,
      "enableDenseFavorites": false,
      "enableBackgroundPlay": false,
      "enableRotateScreenWithSystem": false,
      "enableScreenKeepOn": true,
      "enableAutoCheckUpdate": false,
      "enableFullScreenDefault": false,
      "preferResolution": "原画",
      "preferPlatform": "bilibili",
      "hideDanmaku": false,
      "showColourDanmaku": false,
      "danmakuArea": 1.0,
      "danmakuSpeed": 8.0,
      "danmakuFontSize": 16.0,
      "danmakuFontBorder": 0.5,
      "danmakuOpacity": 1.0,
      'doubleExit': true,
      "videoPlayerIndex": 0,
      'enableCodec': true,
      'bilibiliCookie': '',
      'shieldList': [],
      'mergeDanmuRating': 0.0,
      "hotAreasList": [],
      "webPortEnable": false,
      "webPort": "8008",
      "siteCookies": {},
      "filterDanmuUserLevel": 0.0,
      "filterDanmuFansLevel": 0.0,
      "showDanmuFans": true,
      "showDanmuUserLevel": true,
      "danmakuControllerType": 0,
    };
    for (var f in settingPartList.defaultConfigList) {
      f.call(json);
    }
    return json;
  }
}
