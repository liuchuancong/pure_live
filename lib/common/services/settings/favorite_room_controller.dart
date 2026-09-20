import 'dart:convert';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/consts/app_consts.dart';
import 'package:pure_live/common/services/utils/backup_migration_util.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:synchronized/synchronized.dart';

class FavoriteRoomController extends GetxController {
  static const int maxShieldKeywordLength = 40;
  static const String _favoriteRoomsStorageKey = 'favoriteRooms';
  static const String _favoriteAreasStorageKey = 'favoriteAreas';

  final Lock _favoriteMutationLock = Lock();

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
    _normalizeDanmakuBlocks();
    _normalizeSiteCatalogIds();
    _normalizeFavoriteRoomIdentities();
    _migrateSiteCatalog();
  }

  void _migrateSiteCatalog() {
    final updated = List<String>.from(hotAreasList);
    if (siteCatalogMigration.v < 2) {
      for (final site in Sites.supportSites) {
        if (!updated.contains(site.id)) updated.add(site.id);
      }
    }
    // Add only the new platform. Re-enabling all supported IDs here would
    // discard the user's deliberately hidden platforms on each new release.
    if (siteCatalogMigration.v < 3) {
      if (!updated.contains(Sites.acfunSite)) updated.add(Sites.acfunSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 3;
    }
    if (siteCatalogMigration.v < 4) {
      if (!updated.contains(Sites.picartoSite)) updated.add(Sites.picartoSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 4;
    }
    if (siteCatalogMigration.v < 5) {
      if (!updated.contains(Sites.twitcastingSite)) updated.add(Sites.twitcastingSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 5;
    }
    if (siteCatalogMigration.v < 6) {
      if (!updated.contains(Sites.missevanSite)) updated.add(Sites.missevanSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 6;
    }
    if (siteCatalogMigration.v < 7) {
      if (!updated.contains(Sites.inkeSite)) updated.add(Sites.inkeSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 7;
    }
    if (siteCatalogMigration.v < 8) {
      if (!updated.contains(Sites.kilakilaSite)) updated.add(Sites.kilakilaSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 8;
    }
    if (siteCatalogMigration.v < 9) {
      if (!updated.contains(Sites.huajiaoSite)) updated.add(Sites.huajiaoSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 9;
    }
    if (siteCatalogMigration.v < 10) {
      if (!updated.contains(Sites.openrecSite)) updated.add(Sites.openrecSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 10;
    }
    if (siteCatalogMigration.v < 11) {
      if (!updated.contains(Sites.ttingSite)) updated.add(Sites.ttingSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 11;
    }
    if (siteCatalogMigration.v < 12) {
      if (!updated.contains(Sites.xiaohongshuSite)) updated.add(Sites.xiaohongshuSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 12;
    }
    if (siteCatalogMigration.v < 13) {
      if (!updated.contains(Sites.niconicoSite)) updated.add(Sites.niconicoSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 13;
    }
    if (siteCatalogMigration.v < 14) {
      if (!updated.contains(Sites.weiboSite)) updated.add(Sites.weiboSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 14;
    }
    if (siteCatalogMigration.v < 15) {
      if (!updated.contains(Sites.showroomSite)) updated.add(Sites.showroomSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 15;
    }
    if (siteCatalogMigration.v < 16) {
      if (!updated.contains(Sites.chzzkSite)) updated.add(Sites.chzzkSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 16;
    }
    if (siteCatalogMigration.v < 17) {
      if (!updated.contains(Sites.kickSite)) updated.add(Sites.kickSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 17;
    }
    if (siteCatalogMigration.v < 18) {
      if (!updated.contains(Sites.seventeenLiveSite)) updated.add(Sites.seventeenLiveSite);
      hotAreasList.assignAll(updated);
      siteCatalogMigration.v = 18;
    }
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
      if (left[index] != right[index]) {
        return false;
      }
    }

    return true;
  }

  bool _isValidFavoriteRoom(LiveRoom room) {
    final platform = room.normalizedPlatformId.trim();
    final roomId = room.normalizedRoomId.trim().toLowerCase();

    if (platform.isEmpty || roomId.isEmpty) {
      return false;
    }

    switch (roomId) {
      case '0':
      case 'null':
      case 'undefined':
      case 'nan':
      case 'none':
        return false;
    }

    return true;
  }

  void _normalizeFavoriteRoomIdentities() {
    final current = List<LiveRoom>.from(favoriteRooms.v);

    if (current.isEmpty) return;

    final normalized = <LiveRoom>[];
    final identities = <String>{};
    var changed = false;

    for (final room in current) {
      final next = room.normalizedIdentityCopy();

      if (!identical(next, room)) {
        changed = true;
      }

      if (!_isValidFavoriteRoom(next)) {
        changed = true;
        continue;
      }

      if (!identities.add(next.identityKey)) {
        changed = true;
        continue;
      }

      normalized.add(next);
    }

    if (changed) {
      favoriteRooms.v = List<LiveRoom>.from(normalized);
    }
  }

  void removeInvalidFavoriteRooms() {
    final current = List<LiveRoom>.from(favoriteRooms.v);

    if (current.isEmpty) return;

    final validRooms = <LiveRoom>[];
    final identities = <String>{};

    for (final room in current) {
      final normalized = room.normalizedIdentityCopy();

      if (!_isValidFavoriteRoom(normalized)) {
        continue;
      }

      if (!identities.add(normalized.identityKey)) {
        continue;
      }

      validRooms.add(normalized);
    }

    if (_sameFavoriteRoomSnapshot(current, validRooms)) {
      return;
    }

    favoriteRooms.v = List<LiveRoom>.from(validRooms);
  }

  bool _sameFavoriteRoomSnapshot(List<LiveRoom> left, List<LiveRoom> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var index = 0; index < left.length; index++) {
      if (left[index].identityKey != right[index].identityKey) {
        return false;
      }
    }

    return true;
  }

  bool isFavorite(LiveRoom room) {
    return favoriteRooms.v.any((candidate) => candidate.hasSameIdentity(room));
  }

  bool isFavoriteArea(LiveArea area) {
    return favoriteAreas.v.any((candidate) => candidate.hasSameIdentity(area));
  }

  bool addRoom(LiveRoom room) {
    final normalized = room.normalizedIdentityCopy();

    if (!_isValidFavoriteRoom(normalized)) {
      return false;
    }

    if (isFavorite(normalized)) {
      return false;
    }

    final updated = List<LiveRoom>.from(favoriteRooms.v);
    updated.add(normalized);
    favoriteRooms.v = updated;

    return true;
  }

  Future<bool> addRoomDurably(LiveRoom room) {
    return _favoriteMutationLock.synchronized(() async {
      final before = List<LiveRoom>.from(favoriteRooms.v);
      if (!addRoom(room)) return false;
      await _persistRoomsOrRollback(before);
      return true;
    });
  }

  bool removeRoom(LiveRoom room) {
    final index = favoriteRooms.v.indexWhere((candidate) => candidate.hasSameIdentity(room));

    if (index < 0) return false;

    final updated = List<LiveRoom>.from(favoriteRooms.v);
    updated.removeAt(index);
    favoriteRooms.v = updated;

    return true;
  }

  Future<bool> removeRoomDurably(LiveRoom room) {
    return _favoriteMutationLock.synchronized(() async {
      final before = List<LiveRoom>.from(favoriteRooms.v);
      if (!removeRoom(room)) return false;
      await _persistRoomsOrRollback(before);
      return true;
    });
  }

  bool updateRoom(LiveRoom room) {
    final normalized = room.normalizedIdentityCopy();

    if (!_isValidFavoriteRoom(normalized)) {
      return false;
    }

    final index = favoriteRooms.v.indexWhere((candidate) => candidate.hasSameIdentity(normalized));

    if (index < 0) return false;

    final updated = List<LiveRoom>.from(favoriteRooms.v);
    updated[index] = updated[index].mergeFrom(normalized);
    favoriteRooms.v = updated;

    return true;
  }

  Future<bool> updateRoomDurably(LiveRoom room) {
    return _favoriteMutationLock.synchronized(() async {
      final before = List<LiveRoom>.from(favoriteRooms.v);
      if (!updateRoom(room)) return false;
      await _persistRoomsOrRollback(before);
      return true;
    });
  }

  Future<bool> replaceRoomsDurably(Iterable<LiveRoom> rooms) {
    final replacement = List<LiveRoom>.from(rooms);
    return mutateRoomsDurably((_) => replacement);
  }

  Future<bool> mutateRoomsDurably(List<LiveRoom> Function(List<LiveRoom> current) update) {
    return _favoriteMutationLock.synchronized(() async {
      final before = List<LiveRoom>.from(favoriteRooms.v);
      final updated = <LiveRoom>[];
      final identities = <String>{};
      for (final room in update(List<LiveRoom>.from(before))) {
        final normalized = room.normalizedIdentityCopy();
        if (_isValidFavoriteRoom(normalized) && identities.add(normalized.identityKey)) {
          updated.add(normalized);
        }
      }
      if (_encodeFavoriteRooms(before) == _encodeFavoriteRooms(updated)) return false;
      favoriteRooms.v = updated;
      await _persistRoomsOrRollback(before);
      return true;
    });
  }

  bool addArea(LiveArea area) {
    if (area.identityKey == null || isFavoriteArea(area)) return false;

    final updated = List<LiveArea>.from(favoriteAreas.v);
    updated.add(area);
    favoriteAreas.v = updated;

    return true;
  }

  Future<bool> addAreaDurably(LiveArea area) {
    return _favoriteMutationLock.synchronized(() async {
      final before = List<LiveArea>.from(favoriteAreas.v);
      if (!addArea(area)) return false;
      await _persistAreasOrRollback(before);
      return true;
    });
  }

  bool removeArea(LiveArea area) {
    final updated = List<LiveArea>.from(favoriteAreas.v);
    updated.removeWhere((candidate) => candidate.hasSameIdentity(area));

    if (updated.length == favoriteAreas.v.length) return false;

    favoriteAreas.v = updated;

    return true;
  }

  Future<bool> removeAreaDurably(LiveArea area) {
    return _favoriteMutationLock.synchronized(() async {
      final before = List<LiveArea>.from(favoriteAreas.v);
      if (!removeArea(area)) return false;
      await _persistAreasOrRollback(before);
      return true;
    });
  }

  Future<void> _persistRoomsOrRollback(List<LiveRoom> before) async {
    try {
      await _writeFavoriteRooms(favoriteRooms.v);
    } catch (error, stackTrace) {
      favoriteRooms.v = List<LiveRoom>.from(before);
      try {
        await _writeFavoriteRooms(before);
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _persistAreasOrRollback(List<LiveArea> before) async {
    try {
      await _writeFavoriteAreas(favoriteAreas.v);
    } catch (error, stackTrace) {
      favoriteAreas.v = List<LiveArea>.from(before);
      try {
        await _writeFavoriteAreas(before);
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _writeFavoriteRooms(List<LiveRoom> rooms) async {
    await HivePrefUtil.setString(_favoriteRoomsStorageKey, _encodeFavoriteRooms(rooms));
    await HivePrefUtil.flush();
  }

  Future<void> _writeFavoriteAreas(List<LiveArea> areas) async {
    await HivePrefUtil.setString(_favoriteAreasStorageKey, _encodeFavoriteAreas(areas));
    await HivePrefUtil.flush();
  }

  String _encodeFavoriteRooms(Iterable<LiveRoom> rooms) {
    return jsonEncode({'list': rooms.map((room) => room.toJson()).toList(growable: false)});
  }

  String _encodeFavoriteAreas(Iterable<LiveArea> areas) {
    return jsonEncode({'list': areas.map((area) => area.toJson()).toList(growable: false)});
  }

  bool addShieldList(String value) {
    final text = value.trim();

    if (text.isEmpty || shieldList.any((item) => item.trim().toLowerCase() == text.toLowerCase())) return false;

    final updated = List<String>.from(shieldList);
    updated.add(text);
    shieldList.assignAll(updated);
    return true;
  }

  void removeShieldList(int index) {
    if (index < 0 || index >= shieldList.length) return;

    final updated = List<String>.from(shieldList);
    updated.removeAt(index);
    shieldList.assignAll(updated);
  }

  bool addBlockedDanmakuUser(String value) {
    final user = value.trim();

    if (user.isEmpty || blockedDanmakuUsers.any((item) => item.trim().toLowerCase() == user.toLowerCase())) {
      return false;
    }

    final updated = List<String>.from(blockedDanmakuUsers);
    updated.add(user);
    blockedDanmakuUsers.assignAll(updated);
    return true;
  }

  void removeBlockedDanmakuUser(int index) {
    if (index < 0 || index >= blockedDanmakuUsers.length) {
      return;
    }

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

  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    return {
      'shieldList': _normalizeDanmakuBlockValues(List<String>.from(json['shieldList'] ?? const <String>[])),
      'blockedDanmakuUsers': _normalizeDanmakuBlockValues(
        List<String>.from(json['blockedDanmakuUsers'] ?? const <String>[]),
      ),
      'hotAreasList': List<String>.from(json['hotAreasList'] ?? AppConsts.supportSites),
      'preferPlatform': json['preferPlatform']?.toString().trim().toLowerCase() ?? Sites.bilibiliSite,
      'favoriteRooms': BackupMigrationUtil.parseObjectList(json['favoriteRooms'], LiveRoom.fromJson, strict: true),
      'favoriteAreas': BackupMigrationUtil.parseObjectList(json['favoriteAreas'], LiveArea.fromJson, strict: true),
    };
  }

  static Map<String, dynamic> parseFavoriteLists(Map<String, dynamic> json) {
    if (!json.containsKey('favoriteRooms') && !json.containsKey('favoriteAreas')) {
      throw const FormatException('No favorite lists in backup');
    }
    final parsed = <String, dynamic>{};
    if (json.containsKey('favoriteRooms')) {
      parsed['favoriteRooms'] = BackupMigrationUtil.parseObjectList(
        json['favoriteRooms'],
        LiveRoom.fromJson,
        strict: true,
      );
    }
    if (json.containsKey('favoriteAreas')) {
      parsed['favoriteAreas'] = BackupMigrationUtil.parseObjectList(
        json['favoriteAreas'],
        LiveArea.fromJson,
        strict: true,
      );
    }
    return parsed;
  }

  void restoreFavoriteLists(Map<String, dynamic> json) {
    final parsed = parseFavoriteLists(json);
    if (parsed.containsKey('favoriteRooms')) {
      favoriteRooms.v = parsed['favoriteRooms'];
      _normalizeFavoriteRoomIdentities();
    }
    if (parsed.containsKey('favoriteAreas')) {
      favoriteAreas.v = parsed['favoriteAreas'];
    }
  }

  void fromJson(Map<String, dynamic> json) {
    final parsed = parseConfig(json);
    shieldList.assignAll(parsed['shieldList']);
    blockedDanmakuUsers.assignAll(parsed['blockedDanmakuUsers']);
    hotAreasList.assignAll(parsed['hotAreasList']);
    preferPlatform.v = parsed['preferPlatform'];
    favoriteRooms.v = parsed['favoriteRooms'];
    favoriteAreas.v = parsed['favoriteAreas'];
    _normalizeSiteCatalogIds();
    _normalizeFavoriteRoomIdentities();
  }

  static Map<String, dynamic> extractConfig(Map<String, dynamic>? rootConfig) {
    final favorite = rootConfig?['favorite'] as Map<String, dynamic>? ?? {};

    return {
      'shieldList': _normalizeDanmakuBlockValues(List<String>.from(favorite['shieldList'] ?? const <String>[])),
      'blockedDanmakuUsers': _normalizeDanmakuBlockValues(
        List<String>.from(favorite['blockedDanmakuUsers'] ?? const <String>[]),
      ),
      'hotAreasList': List<String>.from(favorite['hotAreasList'] ?? AppConsts.supportSites),
      'preferPlatform': favorite['preferPlatform'] ?? Sites.bilibiliSite,
      'favoriteRooms': BackupMigrationUtil.parseObjectList(
        favorite['favoriteRooms'],
        LiveRoom.fromJson,
      ).where(_isValidFavoriteRoomStatic).map((e) => e.toJson()).toList(),
      'favoriteAreas': BackupMigrationUtil.parseObjectList(
        favorite['favoriteAreas'],
        LiveArea.fromJson,
      ).map((e) => e.toJson()).toList(),
    };
  }

  static bool _isValidFavoriteRoomStatic(LiveRoom room) {
    final platform = room.normalizedPlatformId.trim();

    final roomId = room.normalizedRoomId.trim().toLowerCase();

    if (platform.isEmpty || roomId.isEmpty) {
      return false;
    }

    switch (roomId) {
      case '0':
      case 'null':
      case 'undefined':
      case 'nan':
      case 'none':
        return false;
    }

    return true;
  }

  void _normalizeDanmakuBlocks() {
    final keywords = _normalizeDanmakuBlockValues(shieldList);
    if (!_sameStrings(shieldList, keywords)) shieldList.assignAll(keywords);
    final users = _normalizeDanmakuBlockValues(blockedDanmakuUsers);
    if (!_sameStrings(blockedDanmakuUsers, users)) blockedDanmakuUsers.assignAll(users);
  }

  static List<String> _normalizeDanmakuBlockValues(Iterable<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final rawValue in values) {
      final value = rawValue.trim();
      if (value.isNotEmpty && seen.add(value.toLowerCase())) normalized.add(value);
    }
    return normalized;
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
