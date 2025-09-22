import 'package:get/get.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';
import 'package:pure_live/common/services/setting_mixin/setting_part.dart';
import 'package:pure_live/common/utils/pref_util.dart';

/// 码率
mixin SettingBitRateMixin {
  /// 码率
  /// 流畅 250
  /// 标清 500
  /// 高清 1000
  /// 超清 2000
  ///
  /// 蓝光4M 4000
  /// 蓝光8M 8000
  /// 蓝光10M 10_000
  /// 蓝光20M 20_000
  /// 蓝光30M 30_000
  ///
  /// 原画 0
  /// 选择码率
  List<int> bitRateList = [0, 30000, 20000, 10000, 8000, 4000, 2000, 1000, 500, 250];

  String getBitRateName(int bitRate){
    var s = S.of(Get.context!);
    switch(bitRate) {
      case 0:
        return s.bit_rate_0;
      case 250:
        return s.bit_rate_250;
      case 500:
        return s.bit_rate_500;
      case 1000:
        return s.bit_rate_1000;
      case 2000:
        return s.bit_rate_2000;
    }
    var data = bitRate / 1000;
    var txt = "${s.bit_rate_4000}${data.toInt()}M";
    return txt;
  }

  /// 码率
  static var bitRateKey = "bitRate";
  static var bitRateDefault = 4000;
  final bitRate = (PrefUtil.getInt(bitRateKey) ?? bitRateDefault).obs;

  /// 码率
  static var bitRateMobileKey = "bitRateMobile";
  static var bitRateMobileDefault = 250;
  final bitRateMobile = (PrefUtil.getInt(bitRateMobileKey) ?? bitRateMobileDefault).obs;
  
  void initBitRate(SettingPartList settingPartList) {
    bitRate.listen((value) {
      PrefUtil.setInt(bitRateKey, value);
    });

    bitRateMobile.listen((value) {
      PrefUtil.setInt(bitRateMobileKey, value);
    });

    settingPartList.fromJsonList.add(fromJsonBitRate);
    settingPartList.toJsonList.add(toJsonBitRate);
    settingPartList.defaultConfigList.add(defaultConfigBitRate);
  }

  void onInitBitRate() {
  }

  void changeBitRate(int vBitRate) {
    bitRate.value = vBitRate;
    PrefUtil.setInt(bitRateKey, vBitRate);
  }

  void changeBitRateMobile(int vBitRateMobile) {
    bitRateMobile.value = vBitRateMobile;
    PrefUtil.setInt(bitRateMobileKey, vBitRateMobile);
  }

  void changeBitRateConfig(int vBitRate, int vBitRateMobile) {
    bitRate.value = vBitRate;
    bitRateMobile.value = vBitRateMobile;
    PrefUtil.setInt(bitRateKey, vBitRate);
    PrefUtil.setInt(bitRateMobileKey, vBitRateMobile);
    onInitBitRate();
  }

  //// -------------- 默认
  void fromJsonBitRate(Map<String, dynamic> json) {
    bitRate.value = json[bitRateKey] ?? bitRateDefault;
    bitRateMobile.value = json[bitRateMobileKey] ?? bitRateMobileDefault;
  }

  void toJsonBitRate(Map<String, dynamic> json) {
    json[bitRateKey] = bitRate.value;
    json[bitRateMobileKey] = bitRateMobile.value;
  }

  void defaultConfigBitRate(Map<String, dynamic> json) {
    json[bitRateKey] = bitRateDefault;
    json[bitRateMobileKey] = bitRateMobile;
  }
}
