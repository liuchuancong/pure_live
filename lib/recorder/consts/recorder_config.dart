import 'recorder_keys.dart';

import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/recorder/models/record_file_item.dart';

class RecorderConfig {
  /// =========================
  /// 默认值
  /// =========================

  static const defaultSegmentTime = 300;

  static const defaultMaxTaskCount = 3;

  static const defaultAutoReconnect = true;

  static const defaultMaxCacheMB = 1024;

  static const defaultEnableCacheLimit = false;

  static const defaultMaxRetryCount = 5;

  static const defaultRetryDelay = 30;

  static const defaultPreferBestStream = true;

  /// 默认读写超时（秒）
  static const defaultRwTimeout = 15;

  /// 默认线程队列大小（用于高码率缓冲）
  static const defaultThreadQueueSize = 2048;

  /// =========================
  /// 轮询配置默认值
  /// =========================

  /// 是否启用轮询挂机
  static const defaultEnablePolling = false;

  /// 开播检测间隔（秒）
  static const defaultLiveCheckInterval = 30;

  /// 是否启用指数退避
  static const defaultEnableBackoff = false;

  /// 最大轮询间隔（秒）
  static const defaultMaxCheckInterval = 300;

  /// 是否允许后台轮询
  static const defaultAutoStartOnBoot = false;

  static const defaultUsePinyinForFolder = false;
  static const defaultRecordDanmaku = false;

  static const minSegmentTime = 60;
  static const maxSegmentTime = 3600;
  static const minMaxTaskCount = 1;
  static const maxMaxTaskCount = 10;
  static const minMaxCacheMB = 1;
  static const minMaxRetryCount = 1;
  static const maxMaxRetryCount = 20;
  static const minRetryDelay = 5;
  static const maxRetryDelay = 120;
  static const minLiveCheckInterval = 10;
  static const maxLiveCheckInterval = 300;
  static const minMaxCheckInterval = 300;
  static const maxMaxCheckInterval = 3600;
  static const supportedRwTimeouts = <int>[15, 30, 60];
  static const supportedThreadQueueSizes = <int>[512, 1024, 2048, 4096, 8192];

  static int normalizeSegmentTime(int value) => value.clamp(minSegmentTime, maxSegmentTime);

  static int normalizeMaxTaskCount(int value) => value.clamp(minMaxTaskCount, maxMaxTaskCount);

  static int normalizeMaxCacheMB(int value) => value < minMaxCacheMB ? minMaxCacheMB : value;

  static int normalizeMaxRetryCount(int value) => value.clamp(minMaxRetryCount, maxMaxRetryCount);

  static int normalizeRetryDelay(int value) => value.clamp(minRetryDelay, maxRetryDelay);

  static int normalizeLiveCheckInterval(int value) => value.clamp(minLiveCheckInterval, maxLiveCheckInterval);

  static int normalizeMaxCheckInterval(int value) => value.clamp(minMaxCheckInterval, maxMaxCheckInterval);

  static int normalizeRwTimeout(int value) => supportedRwTimeouts.contains(value) ? value : defaultRwTimeout;

  static int normalizeThreadQueueSize(int value) =>
      supportedThreadQueueSizes.contains(value) ? value : defaultThreadQueueSize;

  static String normalizeDefaultQuality(String value) =>
      PlayerConsts.resolutions.contains(value) ? value : PlayerConsts.resolutions.first;

  /// =========================
  /// 分段时长
  /// =========================

  static int get segmentTime =>
      normalizeSegmentTime(HivePrefUtil.getInt(RecorderKeys.segmentTime) ?? defaultSegmentTime);

  static Future<void> setSegmentTime(int value) =>
      HivePrefUtil.setInt(RecorderKeys.segmentTime, normalizeSegmentTime(value));

  /// =========================
  /// 最大并发
  /// =========================

  static int get maxTaskCount =>
      normalizeMaxTaskCount(HivePrefUtil.getInt(RecorderKeys.maxTaskCount) ?? defaultMaxTaskCount);

  static Future<void> setMaxTaskCount(int value) =>
      HivePrefUtil.setInt(RecorderKeys.maxTaskCount, normalizeMaxTaskCount(value));

  /// =========================
  /// 自动重连
  /// =========================

  static bool get autoReconnect => HivePrefUtil.getBool(RecorderKeys.autoReconnect) ?? defaultAutoReconnect;

  static Future<void> setAutoReconnect(bool value) => HivePrefUtil.setBool(RecorderKeys.autoReconnect, value);

  /// =========================
  /// 最大缓存
  /// =========================

  static int get maxCacheMB => normalizeMaxCacheMB(HivePrefUtil.getInt(RecorderKeys.maxCacheMB) ?? defaultMaxCacheMB);

  static Future<void> setMaxCacheMB(int value) =>
      HivePrefUtil.setInt(RecorderKeys.maxCacheMB, normalizeMaxCacheMB(value));

  /// =========================
  /// 缓存限制
  /// =========================

  static bool get enableCacheLimit => HivePrefUtil.getBool(RecorderKeys.enableCacheLimit) ?? defaultEnableCacheLimit;

  static Future<void> setEnableCacheLimit(bool value) => HivePrefUtil.setBool(RecorderKeys.enableCacheLimit, value);

  /// =========================
  /// 保存目录
  /// =========================

  static String get recordSavePath => HivePrefUtil.getString(RecorderKeys.recordSavePath) ?? '';

  static Future<void> setRecordSavePath(String value) => HivePrefUtil.setString(RecorderKeys.recordSavePath, value);

  /// =========================
  /// 默认画质
  /// =========================

  static String get defaultQuality =>
      normalizeDefaultQuality(HivePrefUtil.getString(RecorderKeys.defaultQuality) ?? PlayerConsts.resolutions.first);

  static Future<void> setDefaultQuality(String value) =>
      HivePrefUtil.setString(RecorderKeys.defaultQuality, normalizeDefaultQuality(value));

  /// =========================
  /// 最大重试次数
  /// =========================

  static int get maxRetryCount =>
      normalizeMaxRetryCount(HivePrefUtil.getInt(RecorderKeys.maxRetryCount) ?? defaultMaxRetryCount);

  static Future<void> setMaxRetryCount(int value) =>
      HivePrefUtil.setInt(RecorderKeys.maxRetryCount, normalizeMaxRetryCount(value));

  /// =========================
  /// 重试延迟
  /// =========================

  static int get retryDelay => normalizeRetryDelay(HivePrefUtil.getInt(RecorderKeys.retryDelay) ?? defaultRetryDelay);

  static Future<void> setRetryDelay(int value) =>
      HivePrefUtil.setInt(RecorderKeys.retryDelay, normalizeRetryDelay(value));

  /// =========================
  /// 是否启用轮询
  /// =========================

  static bool get enablePolling => HivePrefUtil.getBool(RecorderKeys.enablePolling) ?? defaultEnablePolling;

  static Future<void> setEnablePolling(bool value) => HivePrefUtil.setBool(RecorderKeys.enablePolling, value);

  /// =========================
  /// 开播检测间隔
  /// =========================

  static int get liveCheckInterval =>
      normalizeLiveCheckInterval(HivePrefUtil.getInt(RecorderKeys.liveCheckInterval) ?? defaultLiveCheckInterval);

  static Future<void> setLiveCheckInterval(int value) =>
      HivePrefUtil.setInt(RecorderKeys.liveCheckInterval, normalizeLiveCheckInterval(value));

  /// =========================
  /// 指数退避
  /// =========================

  static bool get enableBackoff => HivePrefUtil.getBool(RecorderKeys.enableBackoff) ?? defaultEnableBackoff;

  static Future<void> setEnableBackoff(bool value) => HivePrefUtil.setBool(RecorderKeys.enableBackoff, value);

  /// =========================
  /// 最大轮询间隔
  /// =========================

  static int get maxCheckInterval =>
      normalizeMaxCheckInterval(HivePrefUtil.getInt(RecorderKeys.maxCheckInterval) ?? defaultMaxCheckInterval);

  static Future<void> setMaxCheckInterval(int value) =>
      HivePrefUtil.setInt(RecorderKeys.maxCheckInterval, normalizeMaxCheckInterval(value));

  /// =========================
  /// 后台轮询
  /// =========================

  static bool get autoStartOnBoot => HivePrefUtil.getBool(RecorderKeys.autoStartOnBoot) ?? defaultAutoStartOnBoot;

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
  static bool get preferBestStream => HivePrefUtil.getBool(RecorderKeys.preferBestStream) ?? defaultPreferBestStream;

  static Future<void> setPreferBestStream(bool value) => HivePrefUtil.setBool(RecorderKeys.preferBestStream, value);

  /// 网络读写超时 (对应 FFmpeg 的 -rw_timeout，单位为秒)
  static int get rwTimeout => normalizeRwTimeout(HivePrefUtil.getInt(RecorderKeys.rwTimeout) ?? defaultRwTimeout);

  static Future<void> setRwTimeout(int value) => HivePrefUtil.setInt(RecorderKeys.rwTimeout, normalizeRwTimeout(value));

  /// 线程队列大小 (对应 FFmpeg 的 -thread_queue_size)
  /// 录制原画建议 2048 或更高，防止由于写入慢导致的丢帧
  static int get threadQueueSize =>
      normalizeThreadQueueSize(HivePrefUtil.getInt(RecorderKeys.threadQueueSize) ?? defaultThreadQueueSize);

  static Future<void> setThreadQueueSize(int value) =>
      HivePrefUtil.setInt(RecorderKeys.threadQueueSize, normalizeThreadQueueSize(value));

  /// Repairs legacy, edited, or restored values so later reads and exports use
  /// the same finite choices and slider bounds as the settings page.
  static Future<void> normalizeStoredValues() async {
    final writes = <Future<void>>[];

    void normalizeInt(String key, int value) {
      final stored = HivePrefUtil.getInt(key);
      if (stored != null && stored != value) writes.add(HivePrefUtil.setInt(key, value));
    }

    normalizeInt(RecorderKeys.segmentTime, segmentTime);
    normalizeInt(RecorderKeys.maxTaskCount, maxTaskCount);
    normalizeInt(RecorderKeys.maxCacheMB, maxCacheMB);
    normalizeInt(RecorderKeys.maxRetryCount, maxRetryCount);
    normalizeInt(RecorderKeys.retryDelay, retryDelay);
    normalizeInt(RecorderKeys.liveCheckInterval, liveCheckInterval);
    normalizeInt(RecorderKeys.maxCheckInterval, maxCheckInterval);
    normalizeInt(RecorderKeys.rwTimeout, rwTimeout);
    normalizeInt(RecorderKeys.threadQueueSize, threadQueueSize);
    final quality = defaultQuality;
    final storedQuality = HivePrefUtil.getString(RecorderKeys.defaultQuality);
    if (storedQuality != null && storedQuality != quality) {
      writes.add(HivePrefUtil.setString(RecorderKeys.defaultQuality, quality));
    }
    await Future.wait(writes);
  }

  /// =========================
  /// Folder Naming Strategy
  /// =========================

  /// Whether to use Pinyin (true) or Anchor Name (false) as folder name
  static bool get usePinyinForFolder =>
      HivePrefUtil.getBool(RecorderKeys.folderNamingStrategy) ?? defaultUsePinyinForFolder;

  static Future<void> setUsePinyinForFolder(bool value) =>
      HivePrefUtil.setBool(RecorderKeys.folderNamingStrategy, value);
}
