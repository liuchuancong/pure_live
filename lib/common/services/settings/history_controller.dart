import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';

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
    historyRooms.v.removeWhere((e) => e.roomId == room.roomId);
    if (historyRooms.v.length >= 50) {
      historyRooms.v.removeRange(0, historyRooms.v.length - 49);
    }
    historyRooms.v.insert(0, room);
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
