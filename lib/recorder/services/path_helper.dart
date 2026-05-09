import 'dart:io';
import 'package:pinyindart/pinyindart.dart';

class PathHelper {
  /// 将主播名、平台名等中文字符串转换为纯拼音的安全路径
  static String toSafePinyin(String text) {
    if (text.isEmpty) return "unknown";
    // 例如: "周星星" -> "zhouxingxing"
    String pinyin = getPinyin(text, withTone: false, separator: '');

    // 2. 二次清理：只保留字母、数字和下划线，空格转下划线，且全部转为小写
    return pinyin.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
  }

  static String formatPath(String path) {
    if (Platform.isWindows) {
      return path.replaceAll('/', '\\');
    }
    return path;
  }
}
