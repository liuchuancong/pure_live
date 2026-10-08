import 'package:flutter/material.dart';
import 'package:pure_live/get/get.dart';
import 'package:flex_color_picker/flex_color_picker.dart';

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
  static const Set<String> supportAndroidAbis = {'arm64-v8a', 'armeabi-v7a', 'x86_64'};
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

  static const Map<String, Locale> languages = {"English": Locale('en'), "简体中文": Locale('zh')};

  // Video fit values and labels share one ordered source because the stored
  // setting is an index into this list.
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
  static Map<ColorSwatch<Object>, String> colorsNameMap = AppConsts.themeColors.map(
    (key, value) => MapEntry(ColorTools.createPrimarySwatch(value), key),
  );
  static const Map<int, String> fontWeightLabels = {
    100: 'font_weight_thin',
    200: 'font_weight_extra_light',
    300: 'font_weight_light',
    400: 'font_weight_normal',
    500: 'font_weight_medium',
    600: 'font_weight_semi_bold',
    700: 'font_weight_bold',
    800: 'font_weight_extra_bold',
    900: 'font_weight_black',
  };

  /// Every spinner the loading-style picker offers, by key.
  ///
  /// The names are not carried here: `loading_style_<key>` resolves them
  /// through the locale files, so an English interface cannot fall back to
  /// a Chinese label the way the old nameZh / nameEn columns did.
  static const List<String> loadingStyleKeys = <String>[
    "default",
    "rotatingPlain",
    "doubleBounce",
    "wave",
    "wanderingCubes",
    "fadingFour",
    "fadingCube",
    "pulse",
    "chasingDots",
    "threeBounce",
    "circle",
    "cubeGrid",
    "fadingCircle",
    "rotatingCircle",
    "foldingCube",
    "pumpingHeart",
    "hourGlass",
    "pouringHourGlass",
    "pouringHourGlassRefined",
    "fadingGrid",
    "ring",
    "ripple",
    "spinningCircle",
    "spinningLines",
    "squareCircle",
    "dualRing",
    "pianoWave",
    "dancingSquare",
    "threeInOut",
    "waveSpinner",
    "pulsingGrid",
    "waveDots",
    "inkDrop",
    "twistingDots",
    "threeRotatingDots",
    "staggeredDotsWave",
    "fourRotatingDots",
    "fallingDot",
    "progressiveDots",
    "discreteCircular",
    "threeArchedCircle",
    "bouncingBall",
    "flickr",
    "hexagonDots",
    "beat",
    "twoRotatingArc",
    "horizontalRotatingDots",
    "newtonCradle",
    "stretchedDots",
    "halfTriangleDot",
    "dotsTriangle",
    "ballPulse",
    "ballGridPulse",
    "ballClipRotate",
    "ballClipRotatePulse",
    "squareSpin",
    "ballClipRotateMultiple",
    "ballPulseRise",
    "ballRotate",
    "cubeTransition",
    "ballZigZag",
    "ballZigZagDeflect",
    "ballTrianglePath",
    "ballTrianglePathColored",
    "ballTrianglePathColoredFilled",
    "ballScale",
    "lineScale",
    "lineScaleParty",
    "ballScaleMultiple",
    "ballPulseSync",
    "ballBeat",
    "lineScalePulseOut",
    "lineScalePulseOutRapid",
    "ballScaleRipple",
    "ballScaleRippleMultiple",
    "ballSpinFadeLoader",
    "lineSpinFadeLoader",
    "triangleSkewSpin",
    "pacman",
    "ballGridBeat",
    "semiCircleSpin",
    "ballRotateChase",
    "orbit",
    "audioEqualizer",
    "circleStrokeSpin",
  ];

  /// The locale key holding one spinner's display name.
  static String loadingStyleLabel(String key) => 'loading_style_$key';
}
