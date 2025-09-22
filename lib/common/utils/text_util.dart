import 'package:pure_live/core/common/core_log.dart';

String readableCount(String info) {
  info = info.trim();
  if(info == "") {
    return "0";
  }
  try {
    int count = int.parse(info);
    if (count > 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
  } catch (e) {
    CoreLog.error(e);
    return info;
  }
  return info;
}


/// 统计人数 字符串转 int
int readableCountStrToNum(String? str) {
  if (str == null || str == "") {
    return 0;
  }
  var ratio = 1;
  var tmp = str;
  // 倍率
  if (tmp.contains("百")) {
    ratio *= 100;
    tmp = tmp.replaceFirst("百", "");
  }
  if (tmp.contains("千")) {
    ratio *= 1000;
    tmp = tmp.replaceFirst("千", "");
  }
  if (tmp.contains("万")) {
    ratio *= 10000;
    tmp = tmp.replaceFirst("万", "");
  }
  if (tmp.contains("亿")) {
    ratio *= 100000000;
    tmp = tmp.replaceFirst("亿", "");
  }
  tmp = tmp.replaceAll("+", "").replaceAll("-", "");
  var firstMatch = RegExp(r"(\d+(\.\d+)?)").firstMatch(tmp)?.group(1);

  if (firstMatch == null) {
    return 0;
  }
  var parse = double.parse(firstMatch);
  var num = (parse * ratio).floor();
  return num;
}
