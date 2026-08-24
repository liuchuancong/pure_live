import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';

List<LiveRoom> upsertHistoryRoom(List<LiveRoom> current, LiveRoom room, {required int watchedAt, int limit = 50}) {
  final next = List<LiveRoom>.from(current)..removeWhere((entry) => entry.hasSameIdentity(room));
  next.insert(0, room.normalizedIdentityCopy().copyWith(lastWatchedAt: watchedAt));
  if (next.length > limit) next.removeRange(limit, next.length);
  return next;
}

LiveRoom preserveHistoryMetadata(LiveRoom refreshed, LiveRoom previous) {
  return refreshed.withAudienceFallbackFrom(previous).copyWith(lastWatchedAt: previous.lastWatchedAt);
}

class HistoryController extends GetxController {
  static HistoryController get to => Get.find();

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

  void addRoomToHistory(LiveRoom room) {
    historyRooms.v = upsertHistoryRoom(historyRooms.v, room, watchedAt: DateTime.now().millisecondsSinceEpoch);
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
