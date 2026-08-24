import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';

class FavoriteRoomController extends GetxController {
  final RxList<String> shieldList = hiveStringList('shieldList', <String>[]);
  final RxList<String> blockedDanmakuUsers = hiveStringList('blockedDanmakuUsers', <String>[]);
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

  @override
  void onInit() {
    super.onInit();
    _normalizeSiteCatalogIds();
    _normalizeFavoriteRoomIdentities();
    _migrateSiteCatalog();
  }

  void _migrateSiteCatalog() {
    if (siteCatalogMigration.v >= 2) return;
    final updated = List<String>.from(hotAreasList);
    for (final site in Sites.supportSites) {
      if (!updated.contains(site.id)) {
        updated.add(site.id);
      }
    }
    hotAreasList.assignAll(updated);
    siteCatalogMigration.v = 2;
  }

  void _normalizeSiteCatalogIds() {
    final supported = Sites.supportedSiteIds;
    final seen = <String>{};
    final normalized = <String>[];
    for (final rawId in hotAreasList) {
      final id = rawId.trim().toLowerCase();
      if (supported.contains(id) && seen.add(id)) {
        normalized.add(id);
      }
    }
    if (!_sameStrings(hotAreasList, normalized)) {
      hotAreasList.assignAll(normalized);
    }
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
      if (!identical(next, room)) {
        changed = true;
      }
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
    if (changed) {
      favoriteRooms.v = List<LiveRoom>.from(normalized);
    }
  }

  bool isFavorite(LiveRoom room) {
    return favoriteRooms.v.any((candidate) => candidate.hasSameIdentity(room));
  }

  bool isFavoriteArea(LiveArea area) {
    return favoriteAreas.v.any((e) => e.areaId == area.areaId);
  }

  bool addRoom(LiveRoom room) {
    final normalized = room.normalizedIdentityCopy();
    if (isFavorite(normalized)) return false;
    final updated = List<LiveRoom>.from(favoriteRooms.v);
    updated.add(normalized);
    favoriteRooms.v = updated;
    return true;
  }

  bool removeRoom(LiveRoom room) {
    final index = favoriteRooms.v.indexWhere((candidate) => candidate.hasSameIdentity(room));
    if (index < 0) return false;
    final updated = List<LiveRoom>.from(favoriteRooms.v);
    updated.removeAt(index);
    favoriteRooms.v = updated;
    return true;
  }

  bool updateRoom(LiveRoom room) {
    final normalized = room.normalizedIdentityCopy();
    final index = favoriteRooms.v.indexWhere((candidate) => candidate.hasSameIdentity(normalized));

    if (index < 0) return false;

    final updated = List<LiveRoom>.from(favoriteRooms.v);
    updated[index] = updated[index].mergeFrom(normalized);
    favoriteRooms.v = updated;

    return true;
  }

  bool addArea(LiveArea area) {
    if (isFavoriteArea(area)) return false;
    final updated = List<LiveArea>.from(favoriteAreas.v);
    updated.add(area);
    favoriteAreas.v = updated;
    return true;
  }

  bool removeArea(LiveArea area) {
    final updated = List<LiveArea>.from(favoriteAreas.v);
    final removed = updated.remove(area);
    if (!removed) return false;
    favoriteAreas.v = updated;
    return true;
  }

  void addShieldList(String value) {
    final text = value.trim();
    if (text.isEmpty || shieldList.contains(text)) return;
    final updated = List<String>.from(shieldList);
    updated.add(text);
    shieldList.assignAll(updated);
  }

  void removeShieldList(int index) {
    if (index < 0 || index >= shieldList.length) return;
    final updated = List<String>.from(shieldList);
    updated.removeAt(index);
    shieldList.assignAll(updated);
  }

  void addBlockedDanmakuUser(String value) {
    final user = value.trim();
    if (user.isEmpty || blockedDanmakuUsers.contains(user)) return;
    final updated = List<String>.from(blockedDanmakuUsers);
    updated.add(user);
    blockedDanmakuUsers.assignAll(updated);
  }

  void removeBlockedDanmakuUser(int index) {
    if (index < 0 || index >= blockedDanmakuUsers.length) return;
    final updated = List<String>.from(blockedDanmakuUsers);
    updated.removeAt(index);
    blockedDanmakuUsers.assignAll(updated);
  }

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
    if (Sites.supportedSiteIds.contains(normalized)) {
      preferPlatform.v = normalized;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'shieldList': List<String>.from(shieldList),
      'blockedDanmakuUsers': List<String>.from(blockedDanmakuUsers),
      'hotAreasList': List<String>.from(hotAreasList),
      'preferPlatform': preferPlatform.v,
      'favoriteRooms': favoriteRooms.v.map((e) => e.toJson()).toList(),
      'favoriteAreas': favoriteAreas.v.map((e) => e.toJson()).toList(),
    };
  }

  void fromJson(Map<String, dynamic> json) {
    shieldList.assignAll(List<String>.from(json['shieldList'] ?? const <String>[]));
    blockedDanmakuUsers.assignAll(List<String>.from(json['blockedDanmakuUsers'] ?? const <String>[]));
    hotAreasList.assignAll(List<String>.from(json['hotAreasList'] ?? AppConsts.supportSites));
    final preferred = json['preferPlatform']?.toString();
    preferPlatform.v = preferred?.trim().toLowerCase() ?? Sites.bilibiliSite;
    favoriteRooms.v = List<LiveRoom>.from(
      BackupMigrationUtil.parseObjectList(json['favoriteRooms'], (m) => LiveRoom.fromJson(m)),
    );
    favoriteAreas.v = List<LiveArea>.from(
      BackupMigrationUtil.parseObjectList(json['favoriteAreas'], (m) => LiveArea.fromJson(m)),
    );
    _normalizeSiteCatalogIds();
    _normalizeFavoriteRoomIdentities();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final favorite = rootConfig?['favorite'] as Map<String, dynamic>? ?? {};
    return {
      'shieldList': List<String>.from(favorite['shieldList'] ?? const <String>[]),
      'blockedDanmakuUsers': List<String>.from(favorite['blockedDanmakuUsers'] ?? const <String>[]),
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
    updateFields.forEach((key, value) {
      favorite[key] = value;
    });
    rootConfig['favorite'] = favorite;
    return rootConfig;
  }
}
