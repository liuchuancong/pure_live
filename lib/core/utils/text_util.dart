import 'package:pure_live/common/index.dart';

String readableCount(String info) {
  try {
    int count = int.parse(info);
    bool isZh = Get.locale?.languageCode == 'zh';

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
