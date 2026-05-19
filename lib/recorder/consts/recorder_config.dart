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

  static const _defaultEnableCacheLimit = false;

  static const _defaultMaxRetryCount = 5;

  static const _defaultRetryDelay = 30;

  static const _defaultPreferBestStream = true;

  /// 默认读写超时（秒）
  static const _defaultRwTimeout = 15;

  /// 默认线程队列大小（用于高码率缓冲）
  static const _defaultThreadQueueSize = 2048;

  /// =========================
  /// 轮询配置默认值
  /// =========================

  /// 是否启用轮询挂机
  static const _defaultEnablePolling = false;

  /// 开播检测间隔（秒）
  static const _defaultLiveCheckInterval = 30;

  /// 是否启用指数退避
  static const _defaultEnableBackoff = false;

  /// 最大轮询间隔（秒）
  static const _defaultMaxCheckInterval = 300;

  /// 是否允许后台轮询
  static const _defaultAutoStartOnBoot = false;

  static const _defaultUsePinyinForFolder = false;

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

  static String get recordSavePath => HivePrefUtil.getString(RecorderKeys.recordSavePath) ?? '';

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

  static bool get autoStartOnBoot => HivePrefUtil.getBool(RecorderKeys.autoStartOnBoot) ?? _defaultAutoStartOnBoot;

  static Future<void> setAutoStartOnBoot(bool value) => HivePrefUtil.setBool(RecorderKeys.autoStartOnBoot, value);

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

  /// 优先选择最高画质轨道 (对应 FFmpeg 的 -map 0:v:0)
  static bool get preferBestStream => HivePrefUtil.getBool(RecorderKeys.preferBestStream) ?? _defaultPreferBestStream;

  static Future<void> setPreferBestStream(bool value) => HivePrefUtil.setBool(RecorderKeys.preferBestStream, value);

  /// 网络读写超时 (对应 FFmpeg 的 -rw_timeout，单位为秒)
  static int get rwTimeout => HivePrefUtil.getInt(RecorderKeys.rwTimeout) ?? _defaultRwTimeout;

  static Future<void> setRwTimeout(int value) => HivePrefUtil.setInt(RecorderKeys.rwTimeout, value);

  /// 线程队列大小 (对应 FFmpeg 的 -thread_queue_size)
  /// 录制原画建议 2048 或更高，防止由于写入慢导致的丢帧
  static int get threadQueueSize => HivePrefUtil.getInt(RecorderKeys.threadQueueSize) ?? _defaultThreadQueueSize;

  static Future<void> setThreadQueueSize(int value) => HivePrefUtil.setInt(RecorderKeys.threadQueueSize, value);

  /// =========================
  /// Folder Naming Strategy
  /// =========================

  /// Whether to use Pinyin (true) or Anchor Name (false) as folder name
  static bool get usePinyinForFolder =>
      HivePrefUtil.getBool(RecorderKeys.folderNamingStrategy) ?? _defaultUsePinyinForFolder;

  static Future<void> setUsePinyinForFolder(bool value) =>
      HivePrefUtil.setBool(RecorderKeys.folderNamingStrategy, value);

  static final enableCacheLimit = HivePrefUtil.getBool(RecorderKeys.enableCacheLimit) ?? _defaultEnableCacheLimit;

  static Future<void> setEnableCacheLimit(bool v) async {
    await HivePrefUtil.setBool(RecorderKeys.enableCacheLimit, v);
  }
}
