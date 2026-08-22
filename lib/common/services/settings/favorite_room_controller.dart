import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';

class FavoriteRoomController extends GetxController {
  final RxList<String> shieldList = hiveStringList('shieldList', []);
  final RxList<String> blockedDanmakuUsers = hiveStringList('blockedDanmakuUsers', []);
  final RxList<String> hotAreasList = hiveStringList('hotAreasList', AppConsts.supportSites);
  final RxInt siteCatalogMigration = hiveInt('siteCatalogMigration', 0);
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

  @override
  void onInit() {
    super.onInit();
    _normalizeSiteCatalogIds();
    _normalizeFavoriteRoomIdentities();
    if (siteCatalogMigration.v < 2) {
      for (final site in Sites.supportSites) {
        if (!hotAreasList.contains(site.id)) hotAreasList.add(site.id);
      }
      siteCatalogMigration.v = 2;
    }
  }

  void _normalizeSiteCatalogIds() {
    final supported = Sites.supportedSiteIds;
    final seen = <String>{};
    final normalized = <String>[];
    for (final rawId in hotAreasList.v) {
      final id = rawId.trim().toLowerCase();
      if (supported.contains(id) && seen.add(id)) normalized.add(id);
    }
    if (!_sameStrings(hotAreasList.v, normalized)) hotAreasList.v = normalized;

    final preferred = preferPlatform.v.trim().toLowerCase();
    preferPlatform.v = supported.contains(preferred) ? preferred : Sites.bilibiliSite;
  }

  bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  void _normalizeFavoriteRoomIdentities() {
    final normalized = <LiveRoom>[];
    final identities = <String>{};
    var changed = false;
    for (final room in favoriteRooms.v) {
      final next = room.normalizedIdentityCopy();
      if (!identical(next, room)) changed = true;
      if (next.normalizedPlatformId.isEmpty || next.normalizedRoomId.isEmpty) {
        normalized.add(next);
        continue;
      }
      if (identities.add(next.identityKey)) {
        normalized.add(next);
      } else {
        changed = true;
      }
    }
    if (changed) favoriteRooms.v = normalized;
  }

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

  bool isFavorite(LiveRoom room) => favoriteRooms.v.any((candidate) => candidate.hasSameIdentity(room));
  bool isFavoriteArea(LiveArea area) => favoriteAreas.v.any((e) => e.areaId == area.areaId);

  bool addRoom(LiveRoom room) {
    final normalized = room.normalizedIdentityCopy();
    if (isFavorite(normalized)) return false;
    favoriteRooms.v.add(normalized);
    favoriteRooms.refresh();
    return true;
  }

  bool removeRoom(LiveRoom room) {
    final index = favoriteRooms.v.indexWhere((candidate) => candidate.hasSameIdentity(room));
    if (index < 0) return false;
    favoriteRooms.v.removeAt(index);
    favoriteRooms.refresh();
    return true;
  }

  bool updateRoom(LiveRoom room) {
    final normalized = room.normalizedIdentityCopy();
    final idx = favoriteRooms.v.indexWhere((candidate) => candidate.hasSameIdentity(normalized));
    if (idx == -1) return false;
    favoriteRooms.v[idx] = normalized;
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
  void addBlockedDanmakuUser(String value) {
    final user = value.trim();
    if (user.isNotEmpty && !blockedDanmakuUsers.contains(user)) blockedDanmakuUsers.add(user);
  }

  void removeBlockedDanmakuUser(int idx) => blockedDanmakuUsers.removeAt(idx);

  LiveRoom? getRoomById(String roomId, String platform) {
    final identity = '${platform.trim().toLowerCase()}:${roomId.trim()}';
    for (final room in favoriteRooms.v) {
      if (room.identityKey == identity) {
        return room;
      }
    }
    return null;
  }

  void changePreferPlatform(String name) {
    final normalized = name.trim().toLowerCase();
    final list = Sites.supportSites.map((e) => e.id).toList();
    if (list.contains(normalized)) {
      preferPlatform.v = normalized;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'shieldList': shieldList.v,
      'blockedDanmakuUsers': blockedDanmakuUsers.v,
      'hotAreasList': hotAreasList.v,
      'preferPlatform': preferPlatform.v,
      'favoriteRooms': favoriteRooms.v.map((e) => e.toJson()).toList(),
      'favoriteAreas': favoriteAreas.v.map((e) => e.toJson()).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    shieldList.v = List<String>.from(json['shieldList'] ?? []);
    blockedDanmakuUsers.v = List<String>.from(json['blockedDanmakuUsers'] ?? []);

    hotAreasList.v = List<String>.from(json['hotAreasList'] ?? AppConsts.supportSites);

    preferPlatform.v = json['preferPlatform'] ?? Sites.bilibiliSite;

    favoriteRooms.v = BackupMigrationUtil.parseObjectList(json['favoriteRooms'], (m) => LiveRoom.fromJson(m));

    favoriteAreas.v = BackupMigrationUtil.parseObjectList(json['favoriteAreas'], (m) => LiveArea.fromJson(m));

    _normalizeSiteCatalogIds();
    _normalizeFavoriteRoomIdentities();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final favorite = rootConfig?['favorite'] as Map<String, dynamic>? ?? {};
    return {
      'shieldList': List<String>.from(favorite['shieldList'] ?? []),
      'blockedDanmakuUsers': List<String>.from(favorite['blockedDanmakuUsers'] ?? []),
      'hotAreasList': List<String>.from(favorite['hotAreasList'] ?? AppConsts.supportSites),
      'preferPlatform': favorite['preferPlatform'] ?? Sites.bilibiliSite,
      'favoriteRooms': BackupMigrationUtil.parseObjectList(
        favorite['favoriteRooms'],
        LiveRoom.fromJson,
      ).map((e) => e.toJson()).toList(),
      'favoriteAreas': BackupMigrationUtil.parseObjectList(
        favorite['favoriteAreas'],
        LiveArea.fromJson,
      ).map((e) => e.toJson()).toList(),
    };
  }

  static Map<String, dynamic> mergeConfig(Map<String, dynamic> rootConfig, Map<String, dynamic> updateFields) {
    final favorite = Map<String, dynamic>.from(rootConfig['favorite'] ?? {});
    updateFields.forEach((k, v) => favorite[k] = v);
    rootConfig['favorite'] = favorite;
    return rootConfig;
  }
}
