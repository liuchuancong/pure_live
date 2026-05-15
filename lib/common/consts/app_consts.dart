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

  // 主题模式映射
  static const Map<String, ThemeMode> themeModes = {
    "System": ThemeMode.system,
    "Dark": ThemeMode.dark,
    "Light": ThemeMode.light,
  };
  static const Map<String, String> themeModeI18n = {
    "System": "theme_mode_system",
    "Dark": "theme_mode_dark",
    "Light": "theme_mode_light",
  };

  // 语言映射
  static const Map<String, Locale> languages = {"English": Locale('en'), "简体中文": Locale('zh')};

  // 视频 Fit 模式
  List<BoxFit> videoFitList = [
    BoxFit.contain,
    BoxFit.cover,
    BoxFit.fill,
    BoxFit.fitHeight,
    BoxFit.fitWidth,
    BoxFit.scaleDown,
  ];

  /// desc 改成 key
  List<Map<String, dynamic>> videoFitType = [
    {'attr': BoxFit.contain, 'desc': 'video_fit_default'},
    {'attr': BoxFit.cover, 'desc': 'video_fit_crop_center'},
    {'attr': BoxFit.fill, 'desc': 'video_fit_fill_screen'},
    {'attr': BoxFit.fitHeight, 'desc': 'video_fit_fit_height'},
    {'attr': BoxFit.fitWidth, 'desc': 'video_fit_fit_width'},
    {'attr': BoxFit.scaleDown, 'desc': 'video_fit_scale_down'},
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
