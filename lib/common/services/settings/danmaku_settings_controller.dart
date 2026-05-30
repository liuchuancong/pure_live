import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class DanmakuSettingsController extends GetxController {
  final HiveRxBool hideDanmaku = HiveRxBool('hideDanmaku', false);
  final HiveRxDouble danmakuTopArea = HiveRxDouble('danmakuTopArea', 0.0);
  final HiveRxDouble danmakuArea = HiveRxDouble('danmakuArea', 1.0);
  final HiveRxDouble danmakuBottomArea = HiveRxDouble('danmakuBottomArea', 0.5);
  final HiveRxDouble danmakuSpeed = HiveRxDouble('danmakuSpeed', 8.0);
  final HiveRxDouble danmakuFontSize = HiveRxDouble('danmakuFontSize', 16.0);
  final HiveRxDouble danmakuFontBorder = HiveRxDouble('danmakuFontBorder', 4.0);
  final HiveRxDouble danmakuOpacity = HiveRxDouble('danmakuOpacity', 1.0);
  final HiveRxBool enableDanmakuDisplay = HiveRxBool('enableDanmakuDisplay', true);
  final HiveRxString danmakuFontFamilyName = HiveRxString('danmakuFontFamilyName', 'Default');

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
  }
}
