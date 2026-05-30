import 'dart:convert';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class HiveRx<T> extends Rx<T> {
  final String key;
  final T defaultValue;

  HiveRx._({required this.key, required this.defaultValue, required T initialValue}) : super(initialValue);

  T get v => value;
  set v(T newValue) => value = newValue;

  factory HiveRx.bool(String key, bool defaultValue) {
    return HiveRxBool(key, defaultValue) as HiveRx<T>;
  }

  factory HiveRx.int(String key, int defaultValue) {
    return HiveRxInt(key, defaultValue) as HiveRx<T>;
  }

  factory HiveRx.double(String key, double defaultValue) {
    return HiveRxDouble(key, defaultValue) as HiveRx<T>;
  }

  factory HiveRx.string(String key, String defaultValue) {
    return HiveRxString(key, defaultValue) as HiveRx<T>;
  }

  factory HiveRx.stringList(String key, List<String> defaultValue) {
    return HiveRxStringList(key, defaultValue) as HiveRx<T>;
  }

  factory HiveRx.dynamic(String key, T defaultValue) {
    final initialValue = HivePrefUtil.getAnyPref(key) ?? defaultValue;
    final instance = HiveRx<T>._(key: key, defaultValue: defaultValue, initialValue: initialValue);
    ever<T>(instance, (v) => HivePrefUtil.setAnyPref(key, v));
    return instance;
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

    final instance = HiveRx<T>._(key: key, defaultValue: defaultValue, initialValue: initialValue);
    ever<T>(instance, (v) {
      try {
        HivePrefUtil.setString(key, jsonEncode(toJson(v)));
      } catch (_) {}
    });
    return instance;
  }

  void reset() {
    value = defaultValue;
  }

  Future<void> remove() async {
    await HivePrefUtil.remove(key);
    value = defaultValue;
  }
}

// =============================================================================
// Concrete Implementation Subclasses (Keep them below)
// =============================================================================

class HiveRxBool extends RxBool {
  final String key;
  final bool defaultValue;

  HiveRxBool(this.key, this.defaultValue) : super(HivePrefUtil.getBool(key) ?? defaultValue) {
    ever<bool>(this, (v) => HivePrefUtil.setBool(key, v));
  }

  bool get v => value;
  set v(bool newValue) => value = newValue;

  void reset() => value = defaultValue;
  Future<void> removePref() async {
    await HivePrefUtil.remove(key);
    value = defaultValue;
  }
}

class HiveRxString extends RxString {
  final String key;
  final String defaultValue;

  HiveRxString(this.key, this.defaultValue) : super(HivePrefUtil.getString(key) ?? defaultValue) {
    ever<String>(this, (v) => HivePrefUtil.setString(key, v));
  }

  String get v => value;
  set v(String newValue) => value = newValue;

  void reset() => value = defaultValue;
  Future<void> removePref() async {
    await HivePrefUtil.remove(key);
    value = defaultValue;
  }
}

class HiveRxInt extends RxInt {
  final String key;
  final int defaultValue;

  HiveRxInt(this.key, this.defaultValue) : super(HivePrefUtil.getInt(key) ?? defaultValue) {
    ever<int>(this, (v) => HivePrefUtil.setInt(key, v));
  }

  int get v => value;
  set v(int newValue) => value = newValue;

  void reset() => value = defaultValue;
  Future<void> removePref() async {
    await HivePrefUtil.remove(key);
    value = defaultValue;
  }
}

class HiveRxDouble extends RxDouble {
  final String key;
  final double defaultValue;

  HiveRxDouble(this.key, this.defaultValue) : super(HivePrefUtil.getDouble(key) ?? defaultValue) {
    ever<double>(this, (v) => HivePrefUtil.setDouble(key, v));
  }

  double get v => value;
  set v(double newValue) => value = newValue;

  void reset() => value = defaultValue;
  Future<void> removePref() async {
    await HivePrefUtil.remove(key);
    value = defaultValue;
  }
}

class HiveRxStringList extends RxList<String> {
  final String key;
  final List<String> defaultValue;

  HiveRxStringList(this.key, this.defaultValue) : super(HivePrefUtil.getStringList(key) ?? defaultValue) {
    ever<List<String>>(this, (v) => HivePrefUtil.setStringList(key, v));
  }

  List<String> get v => this;
  set v(List<String> newValue) => assignAll(newValue);

  void reset() => assignAll(defaultValue);
  Future<void> removePref() async {
    await HivePrefUtil.remove(key);
    assignAll(defaultValue);
  }
}
