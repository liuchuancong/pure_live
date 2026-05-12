import 'package:hive_ce/hive.dart';

class HivePrefUtil {
  static late Box _box;

  static Future<void> init() async {
    if (!Hive.isBoxOpen('app_settings')) {
      _box = await Hive.openBox('app_settings');
    } else {
      _box = Hive.box('app_settings');
    }
  }

  static dynamic getAnyPref(String key) {
    return _box.get(key);
  }

  static Future<bool> setAnyPref(String key, dynamic value) async {
    await _box.put(key, value);
    return true;
  }

  static bool? getBool(String key) {
    final value = _box.get(key);
    return value is bool ? value : null;
  }

  static Future<bool> setBool(String key, bool value) {
    _box.put(key, value);
    return Future.value(true);
  }

  static int? getInt(String key) {
    final value = _box.get(key);
    return value is int ? value : null;
  }

  static Future<bool> setInt(String key, int value) {
    _box.put(key, value);
    return Future.value(true);
  }

  static String? getString(String key) {
    final value = _box.get(key);
    return value is String ? value : null;
  }

  static Future<bool> setString(String key, String value) {
    _box.put(key, value);
    return Future.value(true);
  }

  static double? getDouble(String key) {
    final value = _box.get(key);
    return value is double ? value : null;
  }

  static Future<bool> setDouble(String key, double value) {
    _box.put(key, value);
    return Future.value(true);
  }

  static List<String>? getStringList(String key) {
    final value = _box.get(key);
    return value is List<String> ? value : null;
  }

  static Future<bool> setStringList(String key, List<String> value) {
    _box.put(key, value);
    return Future.value(true);
  }

  /// 删除指定 key
  static Future<bool> remove(String key) async {
    await _box.delete(key);
    return true;
  }

  /// 是否存在 key
  static bool containsKey(String key) {
    return _box.containsKey(key);
  }

  /// 清空全部
  static Future<bool> clear() async {
    await _box.clear();
    return true;
  }
}
