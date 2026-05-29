import 'dart:convert';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class HiveRx<T> {
  final String key;
  final Rx<T> rx;
  final T defaultValue;

  HiveRx._({required this.key, required this.defaultValue, required this.rx});

  factory HiveRx._createPrimitive({
    required String key,
    required T defaultValue,
    required T? Function(String key) getter,
    required void Function(String key, T value) setter,
  }) {
    final initialValue = getter(key) ?? defaultValue;
    final rx = Rx<T>(initialValue);
    ever<T>(rx, (v) => setter(key, v));
    return HiveRx._(key: key, defaultValue: defaultValue, rx: rx);
  }

  T get v => rx.value;

  set v(T value) => rx.value = value;

  T call([T? value]) {
    if (value != null) {
      rx.value = value;
    }
    return rx.value;
  }

  factory HiveRx.bool(String key, bool defaultValue) {
    return HiveRx<bool>._createPrimitive(
          key: key,
          defaultValue: defaultValue,
          getter: HivePrefUtil.getBool,
          setter: HivePrefUtil.setBool,
        )
        as HiveRx<T>;
  }

  factory HiveRx.int(String key, int defaultValue) {
    return HiveRx<int>._createPrimitive(
          key: key,
          defaultValue: defaultValue,
          getter: HivePrefUtil.getInt,
          setter: HivePrefUtil.setInt,
        )
        as HiveRx<T>;
  }

  factory HiveRx.double(String key, double defaultValue) {
    return HiveRx<double>._createPrimitive(
          key: key,
          defaultValue: defaultValue,
          getter: HivePrefUtil.getDouble,
          setter: HivePrefUtil.setDouble,
        )
        as HiveRx<T>;
  }

  factory HiveRx.string(String key, String defaultValue) {
    return HiveRx<String>._createPrimitive(
          key: key,
          defaultValue: defaultValue,
          getter: HivePrefUtil.getString,
          setter: HivePrefUtil.setString,
        )
        as HiveRx<T>;
  }

  factory HiveRx.stringList(String key, List<String> defaultValue) {
    return HiveRx<List<String>>._createPrimitive(
          key: key,
          defaultValue: defaultValue,
          getter: HivePrefUtil.getStringList,
          setter: HivePrefUtil.setStringList,
        )
        as HiveRx<T>;
  }

  factory HiveRx.dynamic(String key, T defaultValue) {
    final initialValue = HivePrefUtil.getAnyPref(key) ?? defaultValue;
    final rx = Rx<T>(initialValue);
    ever(rx, (v) => HivePrefUtil.setAnyPref(key, v));
    return HiveRx._(key: key, defaultValue: defaultValue, rx: rx);
  }

  factory HiveRx.object(
    String key,
    T defaultValue, {
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T value) toJson,
  }) {
    final jsonStr = HivePrefUtil.getString(key);
    T initialValue = defaultValue;

    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        initialValue = fromJson(jsonDecode(jsonStr));
      } catch (_) {
        initialValue = defaultValue;
      }
    }

    final rx = Rx<T>(initialValue);
    ever<T>(rx, (v) {
      try {
        HivePrefUtil.setString(key, jsonEncode(toJson(v)));
      } catch (_) {}
    });

    return HiveRx._(key: key, defaultValue: defaultValue, rx: rx);
  }

  void reset() {
    rx.value = defaultValue;
  }

  Future<void> remove() async {
    await HivePrefUtil.remove(key);
    rx.value = defaultValue;
  }

  void listen(void Function(T) onData) {
    rx.listen(onData);
  }
}
