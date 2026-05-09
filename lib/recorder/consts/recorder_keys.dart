class RecorderKeys {
  /// 分段时长
  static const segmentTime = "segmentTime";

  /// 最大并发
  static const maxTaskCount = "maxTaskCount";

  /// 自动重连
  static const autoReconnect = "autoReconnect";

  /// 最大缓存
  static const maxCacheMB = "maxCacheMB";

  /// 保存路径
  static const recordSavePath = "recordSavePath";

  /// 默认画质
  static const defaultQuality = "default_quality";

  /// 录制任务
  static const recorderTasks = 'recorder_tasks';

  // 录制历史
  static const recordHistory = 'record_history';

  /// 最大重试次数
  static const maxRetryCount = 'max_retry_count';

  /// 重试间隔
  static const retryDelay = 'retry_delay';

  /// 是否启用挂机轮询
  static const enablePolling = 'enable_polling';

  /// 开播检测间隔（秒）
  static const liveCheckInterval = 'live_check_interval';

  /// 是否指数退避
  static const enableBackoff = 'enable_backoff';

  /// 最大轮询间隔（秒）
  static const maxCheckInterval = 'max_check_interval';

  /// 是否允许后台挂机
  static const allowBackgroundPolling = 'allow_background_polling';
}
