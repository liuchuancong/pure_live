import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';

class HistoryController extends GetxController {
  static HistoryController get to => Get.find();

  static const String historyLimitKey = 'historyLimit';
  static const int defaultHistoryLimit = 50;

  final Rx<List<LiveRoom>> historyRooms = hiveObject(
    'historyRooms',
    <LiveRoom>[],
    fromJson: (json) {
      return (json['list'] as List).map((e) => LiveRoom.fromJson(e)).toList();
    },
    toJson: (list) {
      return {'list': list.map((e) => e.toJson()).toList()};
    },
  );

  final historyLimit = hiveInt(historyLimitKey, defaultHistoryLimit);

  List<LiveRoom> upsertHistoryRoom(List<LiveRoom> current, LiveRoom room, {required int watchedAt, int? limit}) {
    final maxLength = limit ?? historyLimit.v;

    final next = List<LiveRoom>.from(current)..removeWhere((entry) => entry.hasSameIdentity(room));

    next.insert(0, room.normalizedIdentityCopy().copyWith(lastWatchedAt: watchedAt));

    if (next.length > maxLength) {
      next.removeRange(maxLength, next.length);
    }

    return next;
  }

  Future<void> setHistoryLimit(int value) async {
    historyLimit.v = value;

    if (historyRooms.v.length > value) {
      historyRooms.v = historyRooms.v.take(value).toList();
      historyRooms.refresh();
    }
  }

  LiveRoom preserveHistoryMetadata(LiveRoom refreshed, LiveRoom previous) {
    return refreshed.withAudienceFallbackFrom(previous).copyWith(lastWatchedAt: previous.lastWatchedAt);
  }

  void addRoomToHistory(LiveRoom room) {
    historyRooms.v = upsertHistoryRoom(historyRooms.v, room, watchedAt: DateTime.now().millisecondsSinceEpoch);
    historyRooms.refresh();
  }

  void removeRoomFromHistory(LiveRoom room) {
    historyRooms.v.removeWhere((entry) => entry.hasSameIdentity(room));
    historyRooms.refresh();
  }

  void removeRoomFromHistoryAt(int index) {
    if (index < 0 || index >= historyRooms.v.length) return;
    historyRooms.v.removeAt(index);
    historyRooms.refresh();
  }

  void clearHistory() {
    historyRooms.v.clear();
    historyRooms.refresh();
  }

  Map<String, dynamic> toJson() {
    return {'historyRooms': historyRooms.v.map((e) => e.toJson()).toList()};
  }

  void fromJson(Map<String, dynamic> json) {
    historyRooms.v = BackupMigrationUtil.parseObjectList(json['historyRooms'], (m) => LiveRoom.fromJson(m));
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final history = rootConfig?['history'] as Map<String, dynamic>? ?? {};

    final list = BackupMigrationUtil.parseObjectList(history['historyRooms'], LiveRoom.fromJson);

    return {'historyRooms': list.map((e) => e.toJson()).toList()};
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final history = Map<String, dynamic>.from(rootConfig['history'] ?? {});

    updateFields.forEach((k, v) => history[k] = v);
    rootConfig['history'] = history;

    return rootConfig;
  }
}
