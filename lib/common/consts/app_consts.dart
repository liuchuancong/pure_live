import 'package:flutter/material.dart';
import 'package:pure_live/core/sites.dart';

class AppConsts {
  static const List<String> supportSites = [
    Sites.bilibiliSite,
    Sites.douyuSite,
    Sites.huyaSite,
    Sites.douyinSite,
    Sites.kuaishouSite,
    Sites.ccSite,
    Sites.iptvSite,
  ];
  // 平台列表
  static const List<String> platforms = ['bilibili', 'douyu', 'huya', 'douyin', 'kuaishow', 'cc', '网络'];

  // 播放器类型
  static const List<String> players = ['Mpv播放器', 'IJK播放器'];

  // 主题模式映射
  static const Map<String, ThemeMode> themeModes = {
    "System": ThemeMode.system,
    "Dark": ThemeMode.dark,
    "Light": ThemeMode.light,
  };

  // 语言映射
  static const Map<String, Locale> languages = {"English": Locale('en'), "简体中文": Locale('zh', 'CN')};

  // 视频 Fit 模式
  List<BoxFit> videoFitList = [
    BoxFit.contain,
    BoxFit.cover,
    BoxFit.fill,
    BoxFit.fitHeight,
    BoxFit.fitWidth,
    BoxFit.scaleDown,
  ];

  List<Map<String, dynamic>> videoFitType = [
    {'attr': BoxFit.contain, 'desc': '默认比例'},
    {'attr': BoxFit.cover, 'desc': '居中裁剪'},
    {'attr': BoxFit.fill, 'desc': '填充屏幕'},
    {'attr': BoxFit.fitHeight, 'desc': '适应高度'},
    {'attr': BoxFit.fitWidth, 'desc': '适应宽度'},
    {'attr': BoxFit.scaleDown, 'desc': '等比缩小'},
  ];

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
}
