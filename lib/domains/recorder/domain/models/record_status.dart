import 'package:pure_live/core/utils/i18n.dart';

enum RecordStatus {
  queued,
  preparing,
  running,
  reconnecting,
  processing,
  completed,
  failed,
  waitingLive,
  stopped,
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
