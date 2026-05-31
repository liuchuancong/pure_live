import 'dart:convert';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

RxBool hiveBool(String key, bool defaultValue) {
  final initialValue = HivePrefUtil.getBool(key) ?? defaultValue;
  return RxBool(initialValue)..hive(key);
}

RxString hiveString(String key, String defaultValue) {
  final initialValue = HivePrefUtil.getString(key) ?? defaultValue;
  return RxString(initialValue)..hive(key);
}

RxInt hiveInt(String key, int defaultValue) {
  final initialValue = HivePrefUtil.getInt(key) ?? defaultValue;
  return RxInt(initialValue)..hive(key);
}

RxDouble hiveDouble(String key, double defaultValue) {
  final initialValue = HivePrefUtil.getDouble(key) ?? defaultValue;
  return RxDouble(initialValue)..hive(key);
}

RxList<String> hiveStringList(String key, List<String> defaultValue) {
  final initialValue = HivePrefUtil.getStringList(key);
  if (initialValue != null) {
    return RxList<String>(List<String>.from(initialValue))..hiveList(key);
  } else {
    return RxList<String>(List<String>.from(defaultValue))..hiveList(key);
  }
}

Rx<T> hiveObject<T>(
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
    } catch (_) {}
  }
  return Rx<T>(initialValue)..hiveObject(key, toJson: toJson);
}

extension HiveRxExtension<T> on Rx<T> {
  T get v => value;
  set v(T newValue) => value = newValue;

  void hive(String key) {
    ever<T>(this, (v) {
      if (v is bool) {
        HivePrefUtil.setBool(key, v);
      } else if (v is String) {
        HivePrefUtil.setString(key, v);
      } else if (v is int) {
        HivePrefUtil.setInt(key, v);
      } else if (v is double) {
        HivePrefUtil.setDouble(key, v);
      } else {
        HivePrefUtil.setAnyPref(key, v);
      }
    });
  }

  void hiveObject(String key, {required Map<String, dynamic> Function(T value) toJson}) {
    ever<T>(this, (v) {
      try {
        HivePrefUtil.setString(key, jsonEncode(toJson(v)));
      } catch (_) {}
    }, condition: () => true);
  }
}

extension HiveRxListExtension on RxList<String> {
  List<String> get v => this;

  set v(List<String> newValue) {
    try {
      assignAll(List<String>.from(newValue));
    } catch (_) {
      value = List<String>.from(newValue);
    }
  }

  void hiveList(String key) {
    ever<List<String>>(this, (v) {
      HivePrefUtil.setStringList(key, v);
    });
  }
}
