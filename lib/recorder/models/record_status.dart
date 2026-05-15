import 'package:pure_live/plugins/locale_helper.dart';

enum RecordStatus {
  queued, // 排队中（达到并发上限）
  preparing, // 准备中（解析流/线路/清晰度）
  running, // 录制中
  reconnecting, // 断线重连中
  processing, //正在合并 TS 为 MP4
  completed, // 正常完成（手动或流结束）
  failed, // 失败（不可恢复或重试结束）
  waitingLive,
  stopped, // 用户手动停止
}

extension RecordStatusExt on RecordStatus {
  int get order {
    switch (this) {
      case RecordStatus.running:
        return 0;
      case RecordStatus.reconnecting:
        return 1;
      case RecordStatus.processing:
        return 2;
      case RecordStatus.preparing:
        return 3;
      case RecordStatus.queued:
        return 4;
      case RecordStatus.waitingLive:
        return 5;
      case RecordStatus.failed:
        return 6;
      case RecordStatus.completed:
        return 7;
      case RecordStatus.stopped:
        return 8;
    }
  }
  String get label {
    switch (this) {
      case RecordStatus.queued:
        return i18n("record_queued");
      case RecordStatus.preparing:
        return i18n("record_preparing");
      case RecordStatus.running:
        return i18n("record_running");
      case RecordStatus.reconnecting:
        return i18n("record_reconnecting");
      case RecordStatus.processing:
        return i18n("record_processing");
      case RecordStatus.completed:
        return i18n("record_completed");
      case RecordStatus.failed:
        return i18n("record_failed");
      case RecordStatus.waitingLive:
        return i18n("record_waiting_live");
      case RecordStatus.stopped:
        return i18n("record_stopped");
    }
  }

  bool get isActive {
    switch (this) {
      case RecordStatus.running:
      case RecordStatus.reconnecting:
      case RecordStatus.processing:
      case RecordStatus.preparing:
        return true;
      default:
        return false;
    }
  }

  bool get isFinished {
    switch (this) {
      case RecordStatus.completed:
      case RecordStatus.failed:
      case RecordStatus.stopped:
        return true;
      default:
        return false;
    }
  }
}
