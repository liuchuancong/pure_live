import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pure_live/recorder/consts/recorder_config.dart';

class RecordSettingsController extends GetxController {
  /// =====================================
  /// 切片时长
  /// =====================================
  final segmentTime = RecorderConfig.segmentTime.obs;

  /// =====================================
  /// 最大任务数
  /// =====================================
  final maxTaskCount = RecorderConfig.maxTaskCount.obs;

  /// =====================================
  /// 自动重连
  /// =====================================
  final autoReconnect = RecorderConfig.autoReconnect.obs;

  /// =====================================
  /// 最大重试次数
  /// =====================================
  final maxRetryCount = RecorderConfig.maxRetryCount.obs;

  /// =====================================
  /// 重试等待时间
  /// =====================================
  final retryDelay = RecorderConfig.retryDelay.obs;

  /// =====================================
  /// 开播检测间隔
  /// =====================================
  final liveCheckInterval = RecorderConfig.liveCheckInterval.obs;

  /// =====================================
  /// 最大检测间隔
  /// =====================================
  final maxCheckInterval = RecorderConfig.maxCheckInterval.obs;

  /// =====================================
  /// 启用挂机检测
  /// =====================================
  final enablePolling = RecorderConfig.enablePolling.obs;

  /// =====================================
  /// 启用指数退避
  /// =====================================
  final enableBackoff = RecorderConfig.enableBackoff.obs;

  final defaultQuality = RecorderConfig.defaultQuality.obs;

  final recordSavePath = RecorderConfig.recordSavePath.obs;

  final maxCacheMB = RecorderConfig.maxCacheMB.obs;

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
    final result = await FilePicker.getDirectoryPath();

    if (result != null) {
      recordSavePath.value = result;
      await RecorderConfig.setRecordSavePath(result);
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
}
