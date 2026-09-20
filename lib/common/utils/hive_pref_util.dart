import 'package:hive_ce/hive.dart';

class HivePrefUtil {
  static late Box _box;
  static Map<String, dynamic>? _writeBatch;
  static bool get isCollectingWrites => _writeBatch != null;

  /// Collect settings notifications and await their actual storage
  /// result. This is not a transaction for Rx state or external side effects.
  static Future<void> persistBatch(void Function() update) async {
    if (_writeBatch != null) throw StateError('Nested settings write batch');
    final values = <String, dynamic>{};
    _writeBatch = values;
    try {
      update();
      // GetX uses asynchronous stream delivery. Keep the collection open until
      // notifications queued by this synchronous import have drained.
      await Future<void>.delayed(Duration.zero);
    } finally {
      _writeBatch = null;
    }
    await _box.putAll(values);
    await _box.flush();
  }

  static dynamic _get(String key) {
    final batch = _writeBatch;
    return batch != null && batch.containsKey(key) ? batch[key] : _box.get(key);
  }

  static Future<void> _put(String key, dynamic value) {
    final batch = _writeBatch;
    if (batch != null) {
      batch[key] = value;
      return Future<void>.value();
    }
    return _box.put(key, value);
  }

  static Future<void> init() async {
    if (!Hive.isBoxOpen('app_settings')) {
      _box = await Hive.openBox('app_settings');
    } else {
      _box = Hive.box('app_settings');
    }
  }

  static dynamic getAnyPref(String key) {
    return _get(key);
  }

  static Future<bool> setAnyPref(String key, dynamic value) async {
    await _put(key, value);
    return true;
  }

  /// Commits related preferences in one Hive batch so readers never observe
  /// only part of a multi-key state transition.
  static Future<void> setPrefs(Map<String, dynamic> values) async {
    final batch = _writeBatch;
    if (batch != null) {
      batch.addAll(values);
      return;
    }
    await _box.putAll(values);
  }

  static bool? getBool(String key) {
    final value = _get(key);
    return value is bool ? value : null;
  }

  static Future<bool> setBool(String key, bool value) async {
    await _put(key, value);
    return true;
  }

  static int? getInt(String key) {
    final value = _get(key);
    return value is int ? value : null;
  }

  static Future<bool> setInt(String key, int value) async {
    await _put(key, value);
    return true;
  }

  static String? getString(String key) {
    final value = _get(key);
    return value is String ? value : null;
  }

  static Future<bool> setString(String key, String value) async {
    await _put(key, value);
    return true;
  }

  static double? getDouble(String key) {
    final value = _get(key);
    return value is double ? value : null;
  }

  static Future<bool> setDouble(String key, double value) async {
    await _put(key, value);
    return true;
  }

  static List<String>? getStringList(String key) {
    final value = _get(key);
    return value is List<String> ? value : null;
  }

  static Future<bool> setStringList(String key, List<String> value) async {
    await _put(key, value);
    return true;
  }

  /// 删除指定 key
  static Future<bool> remove(String key) async {
    await _box.delete(key);
    return true;
  }

  /// 是否存在 key
  static bool containsKey(String key) {
    return (_writeBatch?.containsKey(key) ?? false) || _box.containsKey(key);
  }

  /// 清空全部
  static Future<bool> clear() async {
    await _box.clear();
    return true;
  }

  /// Waits until all queued settings writes reach disk. Desktop shutdown uses
  /// this before destroying the native window so rapid final changes survive
  /// an application update or immediate exit.
  static Future<void> flush() => _box.flush();
}
