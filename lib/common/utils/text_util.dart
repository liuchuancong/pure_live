import 'package:get/get.dart';
import 'package:pure_live/plugins/locale_helper.dart';
import 'package:easy_localization/easy_localization.dart';

String readableCount(String info) {
  try {
    int count = int.parse(info);
    bool isZh = EasyLocalization.of(Get.context!)?.locale.languageCode == 'zh';

    if (isZh) {
      if (count >= 10000) {
        return '${(count / 10000).toStringAsFixed(1)}${i18n("count_wan")}';
      }
    } else {
      if (count >= 1000) {
        return '${(count / 1000).toStringAsFixed(1)}${i18n("count_k")}';
      }
    }
  } catch (_) {}
  return info;
}
