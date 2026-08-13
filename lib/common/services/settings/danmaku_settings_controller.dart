import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class DanmakuSettingsController extends GetxController {
  static const bool defaultEnablePipDanmaku = true;
  static const bool defaultPipDanmakuAutoScale = true;
  static const bool defaultPipDanmakuUseOriginalColor = true;
  static const int defaultPipDanmakuColor = 0xFFFFFFFF;
  static const double defaultPipDanmakuFontSize = 12.0;
  static const double defaultPipDanmakuSpeed = 90.0;
  static const double defaultPipDanmakuOpacity = 0.9;
  static const double defaultPipDanmakuArea = 0.5;
  static const int defaultPipDanmakuMaxVisibleCount = 6;
  static const double defaultPipDanmakuEmitInterval = 0.35;
  static const int defaultPipDanmakuFps = 30;

  final RxBool hideDanmaku = hiveBool('hideDanmaku', false);
  final RxDouble danmakuTopArea = hiveDouble('danmakuTopArea', 0.0);
  final RxDouble danmakuArea = hiveDouble('danmakuArea', 1.0);
  final RxDouble danmakuBottomArea = hiveDouble('danmakuBottomArea', 0.5);
  final RxDouble danmakuSpeed = hiveDouble('danmakuSpeed', 8.0);
  final RxDouble danmakuFontSize = hiveDouble('danmakuFontSize', 16.0);
  final RxDouble danmakuFontBorder = hiveDouble('danmakuFontBorder', 4.0);
  final RxDouble danmakuOpacity = hiveDouble('danmakuOpacity', 1.0);
  final RxBool enableDanmakuDisplay = hiveBool('enableDanmakuDisplay', true);
  final RxBool enableDanmakuStroke = hiveBool('enableDanmakuStroke', true);
  final RxInt danmakuFps = hiveInt('danmakuFps', 60);
  final RxString danmakuFontFamilyName = hiveString('danmakuFontFamilyName', 'Default');
  final RxBool enablePipDanmaku = hiveBool('enablePipDanmaku', defaultEnablePipDanmaku);
  final RxBool pipDanmakuAutoScale = hiveBool('pipDanmakuAutoScale', defaultPipDanmakuAutoScale);
  final RxBool pipDanmakuUseOriginalColor = hiveBool('pipDanmakuUseOriginalColor', defaultPipDanmakuUseOriginalColor);
  final RxInt pipDanmakuColor = hiveInt('pipDanmakuColor', defaultPipDanmakuColor);
  final RxDouble pipDanmakuFontSize = hiveDouble('pipDanmakuFontSize', defaultPipDanmakuFontSize);
  final RxDouble pipDanmakuSpeed = hiveDouble('pipDanmakuSpeed', defaultPipDanmakuSpeed);
  final RxDouble pipDanmakuOpacity = hiveDouble('pipDanmakuOpacity', defaultPipDanmakuOpacity);
  final RxDouble pipDanmakuArea = hiveDouble('pipDanmakuArea', defaultPipDanmakuArea);
  final RxInt pipDanmakuMaxVisibleCount = hiveInt('pipDanmakuMaxVisibleCount', defaultPipDanmakuMaxVisibleCount);
  final RxDouble pipDanmakuEmitInterval = hiveDouble('pipDanmakuEmitInterval', defaultPipDanmakuEmitInterval);
  final RxInt pipDanmakuFps = hiveInt('pipDanmakuFps', defaultPipDanmakuFps);

  void resetPipDanmaku() {
    enablePipDanmaku.v = defaultEnablePipDanmaku;
    pipDanmakuAutoScale.v = defaultPipDanmakuAutoScale;
    pipDanmakuUseOriginalColor.v = defaultPipDanmakuUseOriginalColor;
    pipDanmakuColor.v = defaultPipDanmakuColor;
    pipDanmakuFontSize.v = defaultPipDanmakuFontSize;
    pipDanmakuSpeed.v = defaultPipDanmakuSpeed;
    pipDanmakuOpacity.v = defaultPipDanmakuOpacity;
    pipDanmakuArea.v = defaultPipDanmakuArea;
    pipDanmakuMaxVisibleCount.v = defaultPipDanmakuMaxVisibleCount;
    pipDanmakuEmitInterval.v = defaultPipDanmakuEmitInterval;
    pipDanmakuFps.v = defaultPipDanmakuFps;
  }

  Map<String, dynamic> toJson() {
    return {
      'hideDanmaku': hideDanmaku.v,
      'danmakuTopArea': danmakuTopArea.v,
      'danmakuArea': danmakuArea.v,
      'danmakuBottomArea': danmakuBottomArea.v,
      'danmakuSpeed': danmakuSpeed.v,
      'danmakuFontSize': danmakuFontSize.v,
      'danmakuFontBorder': danmakuFontBorder.v,
      'danmakuOpacity': danmakuOpacity.v,
      'enableDanmakuDisplay': enableDanmakuDisplay.v,
      'danmakuFontFamilyName': danmakuFontFamilyName.v,
      'enableDanmakuStroke': enableDanmakuStroke.v,
      'danmakuFps': danmakuFps.v,
      'enablePipDanmaku': enablePipDanmaku.v,
      'pipDanmakuAutoScale': pipDanmakuAutoScale.v,
      'pipDanmakuUseOriginalColor': pipDanmakuUseOriginalColor.v,
      'pipDanmakuColor': pipDanmakuColor.v,
      'pipDanmakuFontSize': pipDanmakuFontSize.v,
      'pipDanmakuSpeed': pipDanmakuSpeed.v,
      'pipDanmakuOpacity': pipDanmakuOpacity.v,
      'pipDanmakuArea': pipDanmakuArea.v,
      'pipDanmakuMaxVisibleCount': pipDanmakuMaxVisibleCount.v,
      'pipDanmakuEmitInterval': pipDanmakuEmitInterval.v,
      'pipDanmakuFps': pipDanmakuFps.v,
    };
  }

  void fromJson(Map<String, dynamic> json) {
    hideDanmaku.v = json['hideDanmaku'] ?? false;
    danmakuTopArea.v = json['danmakuTopArea']?.toDouble() ?? 0.0;
    danmakuArea.v = json['danmakuArea']?.toDouble() ?? 1.0;
    danmakuBottomArea.v = json['danmakuBottomArea']?.toDouble() ?? 0.5;
    danmakuSpeed.v = json['danmakuSpeed']?.toDouble() ?? 8.0;
    danmakuFontSize.v = json['danmakuFontSize']?.toDouble() ?? 16.0;
    danmakuFontBorder.v = json['danmakuFontBorder']?.toDouble() ?? 4.0;
    danmakuOpacity.v = json['danmakuOpacity']?.toDouble() ?? 1.0;
    enableDanmakuDisplay.v = json['enableDanmakuDisplay'] ?? true;
    danmakuFontFamilyName.v = json['danmakuFontFamilyName'] ?? 'Default';
    enableDanmakuStroke.v = json['enableDanmakuStroke'] ?? true;
    danmakuFps.v = json['danmakuFps']?.toInt() ?? 60;
    enablePipDanmaku.v = json['enablePipDanmaku'] ?? defaultEnablePipDanmaku;
    pipDanmakuAutoScale.v = json['pipDanmakuAutoScale'] ?? defaultPipDanmakuAutoScale;
    pipDanmakuUseOriginalColor.v = json['pipDanmakuUseOriginalColor'] ?? defaultPipDanmakuUseOriginalColor;
    pipDanmakuColor.v = json['pipDanmakuColor']?.toInt() ?? defaultPipDanmakuColor;
    pipDanmakuFontSize.v = (json['pipDanmakuFontSize'] ?? defaultPipDanmakuFontSize)
        .toDouble()
        .clamp(8.0, 24.0)
        .toDouble();
    pipDanmakuSpeed.v = (json['pipDanmakuSpeed'] ?? defaultPipDanmakuSpeed).toDouble().clamp(20.0, 400.0).toDouble();
    pipDanmakuOpacity.v = (json['pipDanmakuOpacity'] ?? defaultPipDanmakuOpacity).toDouble().clamp(0.1, 1.0).toDouble();
    pipDanmakuArea.v = (json['pipDanmakuArea'] ?? defaultPipDanmakuArea).toDouble().clamp(0.1, 1.0).toDouble();
    pipDanmakuMaxVisibleCount.v = (json['pipDanmakuMaxVisibleCount'] ?? defaultPipDanmakuMaxVisibleCount)
        .toInt()
        .clamp(1, 20)
        .toInt();
    pipDanmakuEmitInterval.v = (json['pipDanmakuEmitInterval'] ?? defaultPipDanmakuEmitInterval)
        .toDouble()
        .clamp(0.05, 2.0)
        .toDouble();
    pipDanmakuFps.v = (json['pipDanmakuFps'] ?? defaultPipDanmakuFps).toInt().clamp(15, 60).toInt();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final danmaku = rootConfig?['danmaku'] as Map<String, dynamic>? ?? {};
    return {
      'hideDanmaku': danmaku['hideDanmaku'] ?? false,
      'danmakuTopArea': (danmaku['danmakuTopArea'] ?? 0.0).toDouble(),
      'danmakuArea': (danmaku['danmakuArea'] ?? 1.0).toDouble(),
      'danmakuBottomArea': (danmaku['danmakuBottomArea'] ?? 0.5).toDouble(),
      'danmakuSpeed': (danmaku['danmakuSpeed'] ?? 8.0).toDouble(),
      'danmakuFontSize': (danmaku['danmakuFontSize'] ?? 16.0).toDouble(),
      'danmakuFontBorder': (danmaku['danmakuFontBorder'] ?? 4.0).toDouble(),
      'danmakuOpacity': (danmaku['danmakuOpacity'] ?? 1.0).toDouble(),
      'enableDanmakuDisplay': danmaku['enableDanmakuDisplay'] ?? true,
      'danmakuFontFamilyName': danmaku['danmakuFontFamilyName'] ?? 'Default',
      'enableDanmakuStroke': danmaku['enableDanmakuStroke'] ?? true,
      'danmakuFps': (danmaku['danmakuFps'] ?? 60).toInt(),
      'enablePipDanmaku': danmaku['enablePipDanmaku'] ?? defaultEnablePipDanmaku,
      'pipDanmakuAutoScale': danmaku['pipDanmakuAutoScale'] ?? defaultPipDanmakuAutoScale,
      'pipDanmakuUseOriginalColor': danmaku['pipDanmakuUseOriginalColor'] ?? defaultPipDanmakuUseOriginalColor,
      'pipDanmakuColor': (danmaku['pipDanmakuColor'] ?? defaultPipDanmakuColor).toInt(),
      'pipDanmakuFontSize': (danmaku['pipDanmakuFontSize'] ?? defaultPipDanmakuFontSize)
          .toDouble()
          .clamp(8.0, 24.0)
          .toDouble(),
      'pipDanmakuSpeed': (danmaku['pipDanmakuSpeed'] ?? defaultPipDanmakuSpeed)
          .toDouble()
          .clamp(20.0, 400.0)
          .toDouble(),
      'pipDanmakuOpacity': (danmaku['pipDanmakuOpacity'] ?? defaultPipDanmakuOpacity)
          .toDouble()
          .clamp(0.1, 1.0)
          .toDouble(),
      'pipDanmakuArea': (danmaku['pipDanmakuArea'] ?? defaultPipDanmakuArea).toDouble().clamp(0.1, 1.0).toDouble(),
      'pipDanmakuMaxVisibleCount': (danmaku['pipDanmakuMaxVisibleCount'] ?? defaultPipDanmakuMaxVisibleCount)
          .toInt()
          .clamp(1, 20)
          .toInt(),
      'pipDanmakuEmitInterval': (danmaku['pipDanmakuEmitInterval'] ?? defaultPipDanmakuEmitInterval)
          .toDouble()
          .clamp(0.05, 2.0)
          .toDouble(),
      'pipDanmakuFps': (danmaku['pipDanmakuFps'] ?? defaultPipDanmakuFps).toInt().clamp(15, 60).toInt(),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final danmaku = Map<String, dynamic>.from(rootConfig['danmaku'] ?? {});
    updateFields.forEach((k, v) => danmaku[k] = v);
    rootConfig['danmaku'] = danmaku;
    return rootConfig;
  }
}
