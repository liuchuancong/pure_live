import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/core/sites.dart';

enum HomeMenu {
  favorites('favorites'),
  popular('popular'),
  areas('areas'),
  record('record');

  final String id;
  const HomeMenu(this.id);

  static HomeMenu? fromId(String id) {
    return HomeMenu.values.firstWhereOrNull((e) => e.id == id);
  }
}

class AppConsts {
  static const String defaultLoadingStyleKey = 'default';
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

  static const List<Map<String, String>> allStyles = [
    {'key': 'default', 'nameEn': 'Default Ring', 'nameZh': '默认圆环'},
    {'key': 'rotatingPlain', 'nameEn': 'Rotating Plain', 'nameZh': '旋转方块'},
    {'key': 'doubleBounce', 'nameEn': 'Double Bounce', 'nameZh': '双重大圆'},
    {'key': 'wave', 'nameEn': 'Wave', 'nameZh': '波浪跳跃'},
    {'key': 'wanderingCubes', 'nameEn': 'Wandering Cubes', 'nameZh': '双块漫游'},
    {'key': 'fadingFour', 'nameEn': 'Fading Four', 'nameZh': '交替隐藏'},
    {'key': 'fadingCube', 'nameEn': 'Fading Cube', 'nameZh': '渐隐方块'},
    {'key': 'pulse', 'nameEn': 'Pulse', 'nameZh': '脉冲水波'},
    {'key': 'chasingDots', 'nameEn': 'Chasing Dots', 'nameZh': '追逐双圆'},
    {'key': 'threeBounce', 'nameEn': 'Three Bounce', 'nameZh': '三点弹跳'},
    {'key': 'circle', 'nameEn': 'Circle', 'nameZh': '时钟小点'},
    {'key': 'cubeGrid', 'nameEn': 'Cube Grid', 'nameZh': '九宫方格'},
    {'key': 'fadingCircle', 'nameEn': 'Fading Circle', 'nameZh': '渐隐圆圈'},
    {'key': 'rotatingCircle', 'nameEn': 'Rotating Circle', 'nameZh': '旋转大圆'},
    {'key': 'foldingCube', 'nameEn': 'Folding Cube', 'nameZh': '折叠魔方'},
    {'key': 'pumpingHeart', 'nameEn': 'Pumping Heart', 'nameZh': '心跳波动'},
    {'key': 'hourGlass', 'nameEn': 'Hour Glass', 'nameZh': '翻转沙漏'},
    {'key': 'pouringHourGlass', 'nameEn': 'Pouring Hour Glass', 'nameZh': '流动沙漏'},
    {'key': 'pouringHourGlassRefined', 'nameEn': 'Hour Glass Refined', 'nameZh': '质感沙漏'},
    {'key': 'fadingGrid', 'nameEn': 'Fading Grid', 'nameZh': '矩阵渐隐'},
    {'key': 'ring', 'nameEn': 'Ring', 'nameZh': '纯净圆环'},
    {'key': 'ripple', 'nameEn': 'Ripple', 'nameZh': '震荡涟漪'},
    {'key': 'spinningCircle', 'nameEn': 'Spinning Circle', 'nameZh': '半圆飞旋'},
    {'key': 'spinningLines', 'nameEn': 'Spinning Lines', 'nameZh': '流动线条'},
    {'key': 'squareCircle', 'nameEn': 'Square Circle', 'nameZh': '方变圆弧'},
    {'key': 'dualRing', 'nameEn': 'Dual Ring', 'nameZh': '双轨游环'},
    {'key': 'pianoWave', 'nameEn': 'Piano Wave', 'nameZh': '琴键节奏'},
    {'key': 'dancingSquare', 'nameEn': 'Dancing Square', 'nameZh': '律动方块'},
    {'key': 'threeInOut', 'nameEn': 'Three In Out', 'nameZh': '三点缩放'},
    {'key': 'waveSpinner', 'nameEn': 'Wave Spinner', 'nameZh': '声波雷达'},
    {'key': 'pulsingGrid', 'nameEn': 'Pulsing Grid', 'nameZh': '脉冲网格'},
    {'key': 'waveDots', 'nameEn': 'Wave Dots', 'nameZh': '律动圆点'},
    {'key': 'inkDrop', 'nameEn': 'Ink Drop', 'nameZh': '动态水滴'},
    {'key': 'twistingDots', 'nameEn': 'Twisting Dots', 'nameZh': '基因螺旋'},
    {'key': 'threeRotatingDots', 'nameEn': 'Three Rotating', 'nameZh': '三星环绕'},
    {'key': 'staggeredDotsWave', 'nameEn': 'Staggered Wave', 'nameZh': '错落波浪'},
    {'key': 'fourRotatingDots', 'nameEn': 'Four Rotating', 'nameZh': '四星环绕'},
    {'key': 'fallingDot', 'nameEn': 'Falling Dot', 'nameZh': '重力落点'},
    {'key': 'progressiveDots', 'nameEn': 'Progressive Dots', 'nameZh': '线性生长'},
    {'key': 'discreteCircular', 'nameEn': 'Discrete Circle', 'nameZh': '分离圆环'},
    {'key': 'threeArchedCircle', 'nameEn': 'Three Arched', 'nameZh': '三重连环'},
    {'key': 'bouncingBall', 'nameEn': 'Bouncing Ball', 'nameZh': '地面弹球'},
    {'key': 'flickr', 'nameEn': 'Flickr', 'nameZh': '环绕互换'},
    {'key': 'hexagonDots', 'nameEn': 'Hexagon Dots', 'nameZh': '六角矩阵'},
    {'key': 'beat', 'nameEn': 'Beat', 'nameZh': '心率电波'},
    {'key': 'twoRotatingArc', 'nameEn': 'Two Rotating Arc', 'nameZh': '双轴弧旋'},
    {'key': 'horizontalRotatingDots', 'nameEn': 'Horizontal Dots', 'nameZh': '水平环绕'},
    {'key': 'newtonCradle', 'nameEn': 'Newton Cradle', 'nameZh': '牛顿摆球'},
    {'key': 'stretchedDots', 'nameEn': 'Stretched Dots', 'nameZh': '拉伸光点'},
    {'key': 'halfTriangleDot', 'nameEn': 'Half Triangle', 'nameZh': '三角错落'},
    {'key': 'dotsTriangle', 'nameEn': 'Dots Triangle', 'nameZh': '动态三角'},
  ];
}
