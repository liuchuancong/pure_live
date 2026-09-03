import 'dart:io';

import 'package:pinyindart/pinyindart.dart';

class PathHelper {
  static final RegExp _invalidComponentChars = RegExp(r'[\x00-\x1F<>:"/\\|?*]');
  static final RegExp _windowsReservedName = RegExp(
    r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\..*)?$',
    caseSensitive: false,
  );

  /// Converts untrusted platform/room labels into one portable path component.
  static String toSafeComponent(String text, {bool asciiOnly = false, int maxRunes = 80}) {
    if (maxRunes < 1) return 'unknown';
    var value = text.trim().replaceAll(_invalidComponentChars, '_').replaceAll(RegExp(r'\s+'), '_');
    if (asciiOnly) value = value.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    value = value.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'[. ]+$'), '');
    if (value.isEmpty || value.replaceAll('_', '').isEmpty || value == '.' || value == '..') {
      return 'unknown';
    }

    final runes = value.runes.toList(growable: false);
    if (runes.length > maxRunes) value = String.fromCharCodes(runes.take(maxRunes));
    if (_windowsReservedName.hasMatch(value)) value = '_$value';
    return value;
  }

  /// 将主播名、平台名等中文字符串转换为纯拼音的安全路径
  static String toSafePinyin(String text) {
    if (text.trim().isEmpty) return 'unknown';
    final pinyin = getPinyin(text, withTone: false, separator: '');
    return toSafeComponent(pinyin, asciiOnly: true).toLowerCase();
  }

  static String formatPath(String path) {
    if (Platform.isWindows) {
      return path.replaceAll('/', '\\');
    }
    return path;
  }
}
