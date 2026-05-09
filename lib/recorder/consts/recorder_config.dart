import 'recorder_keys.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/recorder/models/record_file_item.dart';

class RecorderConfig {
  /// =========================
  /// 默认值
  /// =========================

  static const _defaultSegmentTime = 300;

  static const _defaultMaxTaskCount = 3;

  static const _defaultAutoReconnect = true;

  static const _defaultMaxCacheMB = 1024;

  static const _defaultMaxRetryCount = 5;

  static const _defaultRetryDelay = 30;

  /// =========================
  /// 轮询配置默认值
  /// =========================

  /// 是否启用轮询挂机
  static const _defaultEnablePolling = true;

  /// 开播检测间隔（秒）
  static const _defaultLiveCheckInterval = 30;

  /// 是否启用指数退避
  static const _defaultEnableBackoff = true;

  /// 最大轮询间隔（秒）
  static const _defaultMaxCheckInterval = 300;

  /// 是否允许后台轮询
  static const _defaultAllowBackgroundPolling = true;

  /// =========================
  /// 初始化默认配置
  /// =========================

  static Future<void> init() async {
    await _ensureDefault(RecorderKeys.segmentTime, _defaultSegmentTime);

    await _ensureDefault(RecorderKeys.maxTaskCount, _defaultMaxTaskCount);

    await _ensureDefault(RecorderKeys.autoReconnect, _defaultAutoReconnect);

    await _ensureDefault(RecorderKeys.maxCacheMB, _defaultMaxCacheMB);

    await _ensureDefault(RecorderKeys.maxRetryCount, _defaultMaxRetryCount);

    await _ensureDefault(RecorderKeys.retryDelay, _defaultRetryDelay);

    /// =========================
    /// 轮询配置
    /// =========================

    await _ensureDefault(RecorderKeys.enablePolling, _defaultEnablePolling);

    await _ensureDefault(RecorderKeys.liveCheckInterval, _defaultLiveCheckInterval);

    await _ensureDefault(RecorderKeys.enableBackoff, _defaultEnableBackoff);

    await _ensureDefault(RecorderKeys.maxCheckInterval, _defaultMaxCheckInterval);

    await _ensureDefault(RecorderKeys.allowBackgroundPolling, _defaultAllowBackgroundPolling);
  }

  /// =========================
  /// 默认值写入
  /// =========================

  static Future<void> _ensureDefault(String key, dynamic defaultValue) async {
    final v = HivePrefUtil.getAnyPref(key);

    if (v == null) {
      await HivePrefUtil.setAnyPref(key, defaultValue);
    }
  }

  /// =========================
  /// 分段时长
  /// =========================

  static int get segmentTime => HivePrefUtil.getInt(RecorderKeys.segmentTime) ?? _defaultSegmentTime;

  static Future<void> setSegmentTime(int value) => HivePrefUtil.setInt(RecorderKeys.segmentTime, value);

  /// =========================
  /// 最大并发
  /// =========================

  static int get maxTaskCount => HivePrefUtil.getInt(RecorderKeys.maxTaskCount) ?? _defaultMaxTaskCount;

  static Future<void> setMaxTaskCount(int value) => HivePrefUtil.setInt(RecorderKeys.maxTaskCount, value);

  /// =========================
  /// 自动重连
  /// =========================

  static bool get autoReconnect => HivePrefUtil.getBool(RecorderKeys.autoReconnect) ?? _defaultAutoReconnect;

  static Future<void> setAutoReconnect(bool value) => HivePrefUtil.setBool(RecorderKeys.autoReconnect, value);

  /// =========================
  /// 最大缓存
  /// =========================

  static int get maxCacheMB => HivePrefUtil.getInt(RecorderKeys.maxCacheMB) ?? _defaultMaxCacheMB;

  static Future<void> setMaxCacheMB(int value) => HivePrefUtil.setInt(RecorderKeys.maxCacheMB, value);

  /// =========================
  /// 保存目录
  /// =========================

  static String get recordSavePath => HivePrefUtil.getString(RecorderKeys.recordSavePath) ?? "";

  static Future<void> setRecordSavePath(String value) => HivePrefUtil.setString(RecorderKeys.recordSavePath, value);

  /// =========================
  /// 默认画质
  /// =========================

  static String get defaultQuality => HivePrefUtil.getString(RecorderKeys.defaultQuality) ?? "原画";

  static Future<void> setDefaultQuality(String value) => HivePrefUtil.setString(RecorderKeys.defaultQuality, value);

  /// =========================
  /// 最大重试次数
  /// =========================

  static int get maxRetryCount => HivePrefUtil.getInt(RecorderKeys.maxRetryCount) ?? _defaultMaxRetryCount;

  static Future<void> setMaxRetryCount(int value) => HivePrefUtil.setInt(RecorderKeys.maxRetryCount, value);

  /// =========================
  /// 重试延迟
  /// =========================

  static int get retryDelay => HivePrefUtil.getInt(RecorderKeys.retryDelay) ?? _defaultRetryDelay;

  static Future<void> setRetryDelay(int value) => HivePrefUtil.setInt(RecorderKeys.retryDelay, value);

  /// =========================
  /// 是否启用轮询
  /// =========================

  static bool get enablePolling => HivePrefUtil.getBool(RecorderKeys.enablePolling) ?? _defaultEnablePolling;

  static Future<void> setEnablePolling(bool value) => HivePrefUtil.setBool(RecorderKeys.enablePolling, value);

  /// =========================
  /// 开播检测间隔
  /// =========================

  static int get liveCheckInterval => HivePrefUtil.getInt(RecorderKeys.liveCheckInterval) ?? _defaultLiveCheckInterval;

  static Future<void> setLiveCheckInterval(int value) => HivePrefUtil.setInt(RecorderKeys.liveCheckInterval, value);

  /// =========================
  /// 指数退避
  /// =========================

  static bool get enableBackoff => HivePrefUtil.getBool(RecorderKeys.enableBackoff) ?? _defaultEnableBackoff;

  static Future<void> setEnableBackoff(bool value) => HivePrefUtil.setBool(RecorderKeys.enableBackoff, value);

  /// =========================
  /// 最大轮询间隔
  /// =========================

  static int get maxCheckInterval => HivePrefUtil.getInt(RecorderKeys.maxCheckInterval) ?? _defaultMaxCheckInterval;

  static Future<void> setMaxCheckInterval(int value) => HivePrefUtil.setInt(RecorderKeys.maxCheckInterval, value);

  /// =========================
  /// 后台轮询
  /// =========================

  static bool get allowBackgroundPolling =>
      HivePrefUtil.getBool(RecorderKeys.allowBackgroundPolling) ?? _defaultAllowBackgroundPolling;

  static Future<void> setAllowBackgroundPolling(bool value) =>
      HivePrefUtil.setBool(RecorderKeys.allowBackgroundPolling, value);

  /// =========================
  /// 录制历史
  /// =========================

  static Future<void> saveRecordHistory(List<RecordFileItem> history) async {
    await HivePrefUtil.setAnyPref(RecorderKeys.recordHistory, history.map((e) => e.toJson()).toList());
  }

  static List<dynamic> getRecordHistory() {
    final raw = HivePrefUtil.getAnyPref(RecorderKeys.recordHistory);

    if (raw == null || raw is! List) {
      return [];
    }

    return raw;
  }

  static Future<void> clearRecordHistory() async {
    await HivePrefUtil.remove(RecorderKeys.recordHistory);
  }
}
