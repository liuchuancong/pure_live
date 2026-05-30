import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';

class FavoriteRoomController extends GetxController {
  final RxList<String> shieldList = hiveStringList('shieldList', []);
  final RxList<String> hotAreasList = hiveStringList('hotAreasList', AppConsts.supportSites);
  final RxString preferPlatform = hiveString('preferPlatform', Sites.bilibiliSite);
  final Rx<List<LiveRoom>> favoriteRooms = hiveObject(
    'favoriteRooms',
    <LiveRoom>[],
    fromJson: (json) {
      return List<LiveRoom>.from((json['list'] ?? []).map((e) => LiveRoom.fromJson(e)));
    },
    toJson: (list) {
      return {'list': list.map((e) => e.toJson()).toList()};
    },
  );

  final Rx<List<LiveArea>> favoriteAreas = hiveObject(
    'favoriteAreas',
    <LiveArea>[],
    fromJson: (json) {
      return List<LiveArea>.from((json['list'] ?? []).map((e) => LiveArea.fromJson(e)));
    },
    toJson: (list) {
      return {'list': list.map((e) => e.toJson()).toList()};
    },
  );

  bool isFavorite(LiveRoom room) => favoriteRooms.v.any((e) => e.roomId == room.roomId);
  bool isFavoriteArea(LiveArea area) => favoriteAreas.v.any((e) => e.areaId == area.areaId);

  bool addRoom(LiveRoom room) {
    if (isFavorite(room)) return false;
    favoriteRooms.v.add(room);
    favoriteRooms.refresh();
    return true;
  }

  bool removeRoom(LiveRoom room) {
    final res = favoriteRooms.v.remove(room);
    favoriteRooms.refresh();
    return res;
  }

  bool updateRoom(LiveRoom room) {
    final idx = favoriteRooms.v.indexWhere((e) => e.roomId == room.roomId);
    if (idx == -1) return false;
    favoriteRooms.v[idx] = room;
    favoriteRooms.refresh();
    return true;
  }

  bool addArea(LiveArea area) {
    if (isFavoriteArea(area)) return false;
    favoriteAreas.v.add(area);
    favoriteAreas.refresh();
    return true;
  }

  bool removeArea(LiveArea area) {
    final res = favoriteAreas.v.remove(area);
    favoriteAreas.refresh();
    return res;
  }

  void addShieldList(String value) => shieldList.v.add(value);
  void removeShieldList(int idx) => shieldList.v.removeAt(idx);

  LiveRoom? getRoomById(String roomId, String platform) {
    for (final room in favoriteRooms.v) {
      if (room.roomId == roomId && room.platform == platform) {
        return room;
      }
    }
    return null;
  }

  void changePreferPlatform(String name) {
    final list = Sites.supportSites.map((e) => e.id).toList();
    if (list.contains(name)) {
      preferPlatform.v = name;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'shieldList': shieldList.v,
      'hotAreasList': hotAreasList.v,
      'preferPlatform': preferPlatform.v,
      'favoriteRooms': favoriteRooms.v.map((e) => e.toJson()).toList(),
      'favoriteAreas': favoriteAreas.v.map((e) => e.toJson()).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    shieldList.v = List<String>.from(json['shieldList'] ?? []);

    hotAreasList.v = List<String>.from(json['hotAreasList'] ?? AppConsts.supportSites);

    preferPlatform.v = json['preferPlatform'] ?? Sites.bilibiliSite;

    favoriteRooms.v = BackupMigrationUtil.parseObjectList(json['favoriteRooms'], (m) => LiveRoom.fromJson(m));

    favoriteAreas.v = BackupMigrationUtil.parseObjectList(json['favoriteAreas'], (m) => LiveArea.fromJson(m));
  }
}
