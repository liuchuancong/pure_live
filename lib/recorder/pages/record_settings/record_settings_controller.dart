import 'dart:io';
import 'package:get/get.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pure_live/common/index.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pure_live/common/global/app_path_manager.dart';
import 'package:pure_live/recorder/consts/recorder_config.dart';
import 'package:pure_live/recorder/services/cache_service.dart';

class RecordSettingsController extends GetxController {
  /// =====================================
  /// 基础配置
  /// =====================================
  final defaultQuality = RecorderConfig.defaultQuality.obs;
  final recordSavePath = RecorderConfig.recordSavePath.obs;
  final maxCacheMB = RecorderConfig.maxCacheMB.obs;
  final enableCacheLimit = RecorderConfig.enableCacheLimit.obs;
  final cacheSizeMB = 0.0.obs;

  /// =====================================
  /// 录制性能与画质
  /// =====================================
  final segmentTime = RecorderConfig.segmentTime.obs;
  final maxTaskCount = RecorderConfig.maxTaskCount.obs;
  final preferBestStream = RecorderConfig.preferBestStream.obs;
  final rwTimeout = RecorderConfig.rwTimeout.obs;
  final threadQueueSize = RecorderConfig.threadQueueSize.obs;

  /// =====================================
  /// 自动重连逻辑
  /// =====================================
  final autoReconnect = RecorderConfig.autoReconnect.obs;
  final maxRetryCount = RecorderConfig.maxRetryCount.obs;
  final retryDelay = RecorderConfig.retryDelay.obs;

  /// =====================================
  /// 挂机检测轮询
  /// =====================================
  final enablePolling = RecorderConfig.enablePolling.obs;
  final liveCheckInterval = RecorderConfig.liveCheckInterval.obs;
  final enableBackoff = RecorderConfig.enableBackoff.obs;
  final maxCheckInterval = RecorderConfig.maxCheckInterval.obs;

  final autoStartOnBoot = RecorderConfig.autoStartOnBoot.obs;
  final usePinyinForFolder = RecorderConfig.usePinyinForFolder.obs;

  @override
  void onInit() {
    super.onInit();
    refreshCacheSize();
    initRecordPath();
  }

  /// =====================================
  /// 刷新缓存大小
  /// =====================================
  Future<void> refreshCacheSize() async {
    cacheSizeMB.value = await CacheService.to.getCacheSize();
  }

  /// =====================================
  /// 更新缓存限制开关
  /// =====================================
  Future<void> updateEnableCacheLimit(bool v) async {
    enableCacheLimit.value = v;
    await RecorderConfig.setEnableCacheLimit(v);
  }

  /// =====================================
  /// 清除缓存
  /// =====================================
  Future<void> clearCache() async {
    await CacheService.to.clearAll();
    await refreshCacheSize();
  }

  /// =====================================
  /// 更新切片时长
  /// =====================================
  Future<void> updateSegmentTime(int v) async {
    segmentTime.value = v;
    await RecorderConfig.setSegmentTime(v);
  }

  /// =====================================
  /// 更新最大任务数
  /// =====================================
  Future<void> updateMaxTask(int v) async {
    maxTaskCount.value = v;
    await RecorderConfig.setMaxTaskCount(v);
  }

  /// =====================================
  /// 更新自动重连
  /// =====================================
  Future<void> updateAutoReconnect(bool v) async {
    autoReconnect.value = v;
    await RecorderConfig.setAutoReconnect(v);
  }

  /// =====================================
  /// 更新最大重试次数
  /// =====================================
  Future<void> updateMaxRetryCount(int v) async {
    maxRetryCount.value = v;
    await RecorderConfig.setMaxRetryCount(v);
  }

  /// =====================================
  /// 更新重试等待时间
  /// =====================================
  Future<void> updateRetryDelay(int v) async {
    retryDelay.value = v;
    await RecorderConfig.setRetryDelay(v);
  }

  /// =====================================
  /// 更新开播检测间隔
  /// =====================================
  Future<void> updateLiveCheckInterval(int v) async {
    liveCheckInterval.value = v;
    await RecorderConfig.setLiveCheckInterval(v);
  }

  /// =====================================
  /// 更新最大检测间隔
  /// =====================================
  Future<void> updateMaxCheckInterval(int v) async {
    maxCheckInterval.value = v;
    await RecorderConfig.setMaxCheckInterval(v);
  }

  /// =====================================
  /// 更新挂机检测
  /// =====================================
  Future<void> updateEnablePolling(bool v) async {
    enablePolling.value = v;
    await RecorderConfig.setEnablePolling(v);
  }

  /// =====================================
  /// 更新指数退避
  /// =====================================
  Future<void> updateEnableBackoff(bool v) async {
    enableBackoff.value = v;
    await RecorderConfig.setEnableBackoff(v);
  }

  /// =====================================
  /// 选择录制目录
  /// =====================================
  Future<void> pickRecordDir() async {
    final path = recordSavePath.value;
    if (path.isNotEmpty) {
      // 调用系统默认应用打开该文件夹
      final result = await OpenFilex.open(path);

      if (result.type != ResultType.done) {
        ToastUtil.show(result.message);
      }
    } else {
      final result = await FilePicker.getDirectoryPath();

      if (result != null) {
        recordSavePath.value = result;
        await RecorderConfig.setRecordSavePath(result);
        await refreshCacheSize();
      }
    }
  }

  Future<void> updateDefaultQuality(String v) async {
    defaultQuality.value = v;
    await RecorderConfig.setDefaultQuality(v);
  }

  Future<void> updateMaxCache(int v) async {
    maxCacheMB.value = v;
    await RecorderConfig.setMaxCacheMB(v);
  }

  Future<void> updatePreferBestStream(bool v) async {
    preferBestStream.value = v;
    await RecorderConfig.setPreferBestStream(v);
  }

  /// =====================================
  /// 更新读写超时
  /// =====================================
  Future<void> updateRwTimeout(int v) async {
    rwTimeout.value = v;
    await RecorderConfig.setRwTimeout(v);
  }

  /// =====================================
  /// 更新缓冲队列大小
  /// =====================================
  Future<void> updateThreadQueueSize(int v) async {
    threadQueueSize.value = v;
    await RecorderConfig.setThreadQueueSize(v);
  }

  Future<void> updateAutoStartOnBoot(bool v) async {
    autoStartOnBoot.value = v;
    await RecorderConfig.setAutoStartOnBoot(v);
  }

  Future<void> updateUsePinyinForFolder(bool v) async {
    usePinyinForFolder.value = v;
    await RecorderConfig.setUsePinyinForFolder(v);
  }

  Future<void> initRecordPath() async {
    if (recordSavePath.isEmpty) {
      final Directory recordDir = await AppPathManager().getDir(AppPathManager.dirRecords);
      recordSavePath.value = recordDir.path;
      await RecorderConfig.setRecordSavePath(recordDir.path);
    }
  }
}
