import 'package:pure_live/core/index.dart';

export 'invisible_placeholders.dart';

String readableCount(String info) {
  try {
    int count = int.parse(info);
    // 判据是**语言包里有哪个单位键**，不是 `Get.locale`：locale 还没解析（或落到
    // 备用包）时判错方向，就会去要另一个包里不存在的键，界面上渲染出
    // "1.2count_k" 这种原始键名。中文包按「万」缩写（≥10000 才缩），其它包按 K
    // （≥1000 就缩）——两种阈值都保持原样。
    if (i18nExists('count_wan')) {
      if (count >= 10000) {
        return '${(count / 10000).toStringAsFixed(1)}${i18n("count_wan")}';
      }
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}${i18n("count_k")}';
    }
  } catch (_) {}
  return info;
}
