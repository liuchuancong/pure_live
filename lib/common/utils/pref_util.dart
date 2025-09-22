import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

///This is the new util class for the shared preferences.
///
///And the old `storage.dart` will be deprecated.
class PrefUtil {
  static late SharedPreferences prefs;

  static dynamic getAnyPref(String key) {
    return prefs.get(key);
  }

  static void setAnyPref(String key, dynamic value) {
    if (value is String) {
      prefs.setString(key, value);
    } else if (value is int) {
      prefs.setInt(key, value);
    } else if (value is bool) {
      prefs.setBool(key, value);
    } else if (value is double) {
      prefs.setDouble(key, value);
    } else if (value is List<String>) {
      prefs.setStringList(key, value);
    } else if (value is Map) {
      setMap(key, value);
    }
  }

  static bool? getBool(String key) {
    return prefs.getBool(key);
  }

  static Future<bool> setBool(String key, bool value) {
    return prefs.setBool(key, value);
  }

  static int? getInt(String key) {
    return prefs.getInt(key);
  }

  static Future<bool> setInt(String key, int value) {
    return prefs.setInt(key, value);
  }

  static String? getString(String key) {
    return prefs.getString(key);
  }

  static Future<bool> setString(String key, String value) {
    return prefs.setString(key, value);
  }

  static double? getDouble(String key) {
    return prefs.getDouble(key);
  }

  static Future<bool> setDouble(String key, double value) {
    return prefs.setDouble(key, value);
  }

  static List<String>? getStringList(String key) {
    return prefs.getStringList(key);
  }

  static Future<bool> setStringList(String key, List<String> value) {
    return prefs.setStringList(key, value);
  }

  /// 根据key存储Map类型
  static Future<bool> setMap(String key, Map value) {
    return prefs.setString(key, json.encode(value));
  }

  /// 根据key获取Map类型
  static Map getMap(String key) {
    String jsonStr = prefs.getString(key) ?? "";
    return jsonStr.isEmpty ? {} : json.decode(jsonStr);
  }
}
