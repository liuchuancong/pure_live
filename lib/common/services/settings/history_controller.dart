import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

class HistoryController extends GetxController {
  static HistoryController get to => Get.find();

  // 历史记录独立存储
  final historyRooms = HiveRx.object(
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
    // 限制最多50条
    if (historyRooms.v.length >= 50) {
      historyRooms.v.removeRange(0, historyRooms.v.length - 49);
    }
    historyRooms.v.insert(0, room);
    historyRooms.rx.refresh();
  }

  void clearHistory() {
    historyRooms.v.clear();
    historyRooms.rx.refresh();
  }

  Map<String, dynamic> toJson() {
    return {'historyRooms': historyRooms.v.map((e) => e.toJson()).toList()};
  }

  void fromJson(Map<String, dynamic> json) {
    if (json['historyRooms'] != null) {
      historyRooms.v = (json['historyRooms'] as List).map((e) => LiveRoom.fromJson(Map.from(e))).toList();
    }
  }
}
