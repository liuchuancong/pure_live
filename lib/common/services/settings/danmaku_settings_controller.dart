import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class DanmakuSettingsController extends GetxController {
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
  final RxBool enablePipDanmaku = hiveBool('enablePipDanmaku', true);
  final RxBool pipDanmakuAutoScale = hiveBool('pipDanmakuAutoScale', true);
  final RxBool pipDanmakuUseOriginalColor = hiveBool('pipDanmakuUseOriginalColor', true);
  final RxInt pipDanmakuColor = hiveInt('pipDanmakuColor', 0xFFFFFFFF);
  final RxDouble pipDanmakuFontSize = hiveDouble('pipDanmakuFontSize', 12.0);
  final RxDouble pipDanmakuSpeed = hiveDouble('pipDanmakuSpeed', 90.0);
  final RxDouble pipDanmakuOpacity = hiveDouble('pipDanmakuOpacity', 0.9);
  final RxDouble pipDanmakuArea = hiveDouble('pipDanmakuArea', 0.5);
  final RxInt pipDanmakuMaxVisibleCount = hiveInt('pipDanmakuMaxVisibleCount', 6);
  final RxDouble pipDanmakuEmitInterval = hiveDouble('pipDanmakuEmitInterval', 0.35);
  final RxInt pipDanmakuFps = hiveInt('pipDanmakuFps', 30);

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
    enablePipDanmaku.v = json['enablePipDanmaku'] ?? true;
    pipDanmakuAutoScale.v = json['pipDanmakuAutoScale'] ?? true;
    pipDanmakuUseOriginalColor.v = json['pipDanmakuUseOriginalColor'] ?? true;
    pipDanmakuColor.v = json['pipDanmakuColor']?.toInt() ?? 0xFFFFFFFF;
    pipDanmakuFontSize.v = (json['pipDanmakuFontSize'] ?? 12.0).toDouble().clamp(8.0, 24.0).toDouble();
    pipDanmakuSpeed.v = (json['pipDanmakuSpeed'] ?? 90.0).toDouble().clamp(20.0, 400.0).toDouble();
    pipDanmakuOpacity.v = (json['pipDanmakuOpacity'] ?? 0.9).toDouble().clamp(0.1, 1.0).toDouble();
    pipDanmakuArea.v = (json['pipDanmakuArea'] ?? 0.5).toDouble().clamp(0.1, 1.0).toDouble();
    pipDanmakuMaxVisibleCount.v = (json['pipDanmakuMaxVisibleCount'] ?? 6).toInt().clamp(1, 20).toInt();
    pipDanmakuEmitInterval.v = (json['pipDanmakuEmitInterval'] ?? 0.35).toDouble().clamp(0.05, 2.0).toDouble();
    pipDanmakuFps.v = (json['pipDanmakuFps'] ?? 30).toInt().clamp(15, 60).toInt();
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
      'enablePipDanmaku': danmaku['enablePipDanmaku'] ?? true,
      'pipDanmakuAutoScale': danmaku['pipDanmakuAutoScale'] ?? true,
      'pipDanmakuUseOriginalColor': danmaku['pipDanmakuUseOriginalColor'] ?? true,
      'pipDanmakuColor': (danmaku['pipDanmakuColor'] ?? 0xFFFFFFFF).toInt(),
      'pipDanmakuFontSize': (danmaku['pipDanmakuFontSize'] ?? 12.0).toDouble().clamp(8.0, 24.0).toDouble(),
      'pipDanmakuSpeed': (danmaku['pipDanmakuSpeed'] ?? 90.0).toDouble().clamp(20.0, 400.0).toDouble(),
      'pipDanmakuOpacity': (danmaku['pipDanmakuOpacity'] ?? 0.9).toDouble().clamp(0.1, 1.0).toDouble(),
      'pipDanmakuArea': (danmaku['pipDanmakuArea'] ?? 0.5).toDouble().clamp(0.1, 1.0).toDouble(),
      'pipDanmakuMaxVisibleCount': (danmaku['pipDanmakuMaxVisibleCount'] ?? 6).toInt().clamp(1, 20).toInt(),
      'pipDanmakuEmitInterval': (danmaku['pipDanmakuEmitInterval'] ?? 0.35).toDouble().clamp(0.05, 2.0).toDouble(),
      'pipDanmakuFps': (danmaku['pipDanmakuFps'] ?? 30).toInt().clamp(15, 60).toInt(),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final danmaku = Map<String, dynamic>.from(rootConfig['danmaku'] ?? {});
    updateFields.forEach((k, v) => danmaku[k] = v);
    rootConfig['danmaku'] = danmaku;
    return rootConfig;
  }
}
