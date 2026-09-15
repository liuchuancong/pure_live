import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class TagManagementController extends GetxController {
  static const String _storageKey = 'user_custom_tags_v5';
  static const String _roomTagsMappingKey = 'room_to_tags_mapping_v1';
  final RxMap<String, List<String>> roomTagsMap = <String, List<String>>{}.obs;
  final RxList<LiveTag> tags = <LiveTag>[].obs;
  int _lastGeneratedTagId = 0;
  static const Map<String, String> allTag = {'all': '全部'};
  static String get allTagKey => allTag.keys.first;
  static String get allTagLabel => allTag.values.first;
  @override
  void onInit() {
    super.onInit();
    _loadTags();
    _loadRoomTagsMapping();
  }

  void _loadTags() {
    final List<dynamic>? storedTags = HivePrefUtil.getAnyPref(_storageKey);
    if (storedTags != null) {
      final list = storedTags.map((e) => LiveTag.fromJson(Map<String, dynamic>.from(e))).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      final usedIds = <String>{};
      var repaired = false;
      final normalized = <LiveTag>[];
      for (var index = 0; index < list.length; index++) {
        final tag = list[index];
        var id = tag.id.trim();
        if (id.isEmpty || usedIds.contains(id)) {
          id = _allocateTagId(usedIds);
          repaired = true;
        }
        usedIds.add(id);
        if (id != tag.id || tag.order != index) {
          repaired = true;
          normalized.add(LiveTag(id: id, name: tag.name, description: tag.description, order: index));
        } else {
          normalized.add(tag);
        }
      }
      tags.assignAll(normalized);
      if (repaired) saveTags();
    } else {
      tags.clear();
    }
  }

  Future<void> saveTags() async {
    await HivePrefUtil.setAnyPref(_storageKey, tags.map((e) => e.toJson()).toList());
  }

  Future<void> saveRoomTagsMapping() async {
    await HivePrefUtil.setAnyPref(_roomTagsMappingKey, roomTagsMap);
  }

  Future<void> setRoomTags(LiveRoom room, List<String> newTagIds) async {
    final roomKey = room.identityKey;
    final validTagIds = tags.map((tag) => tag.id).toSet();
    final normalizedTagIds = newTagIds.where(validTagIds.contains).toSet().toList(growable: false);
    final legacyKey = room.normalizedRoomId;
    if (legacyKey.isNotEmpty && legacyKey != roomKey) {
      roomTagsMap.remove(legacyKey);
    }
    if (normalizedTagIds.isEmpty) {
      roomTagsMap.remove(roomKey);
    } else {
      roomTagsMap[roomKey] = normalizedTagIds;
    }

    roomTagsMap.refresh();
    await saveRoomTagsMapping();
  }

  /// Moves the legacy room-number-only mapping to platform-scoped identities.
  /// A legacy tag is copied to every matching platform room before the old key
  /// is removed, preserving data while allowing future edits to diverge.
  void migrateLegacyRoomTagKeys(Iterable<LiveRoom> rooms) {
    var changed = false;
    final migratedLegacyKeys = <String>{};
    for (final room in rooms) {
      final legacyKey = room.normalizedRoomId;
      if (legacyKey.isEmpty || room.normalizedPlatformId.isEmpty) continue;
      final legacyTags = roomTagsMap[legacyKey];
      if (legacyTags == null) continue;
      roomTagsMap.putIfAbsent(room.identityKey, () => List<String>.from(legacyTags));
      migratedLegacyKeys.add(legacyKey);
      changed = true;
    }
    for (final key in migratedLegacyKeys) {
      roomTagsMap.remove(key);
    }
    if (!changed) return;
    roomTagsMap.refresh();
    saveRoomTagsMapping();
  }

  void _loadRoomTagsMapping() {
    final Map<dynamic, dynamic>? storedMap = HivePrefUtil.getAnyPref(_roomTagsMappingKey);

    if (storedMap != null) {
      final convertedMap = storedMap.map((key, value) {
        return MapEntry(key.toString(), List<String>.from(value as List));
      });
      roomTagsMap.assignAll(convertedMap);
    }
  }

  List<String> getTagsForRoom(LiveRoom room) {
    return roomTagsMap[room.identityKey] ?? roomTagsMap[room.normalizedRoomId] ?? [];
  }

  bool addTag(String name, String description) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return false;

    final exists = tags.any((tag) => tag.name.toLowerCase() == cleanName.toLowerCase());
    if (exists) return false;

    final newTag = LiveTag(
      id: _allocateTagId(tags.map((tag) => tag.id).toSet()),
      name: cleanName,
      description: description.trim(),
      order: tags.length,
    );

    tags.add(newTag);
    saveTags();
    return true;
  }

  void updateAllTags(List<LiveTag> newList) {
    tags.assignAll(newList);
    for (int i = 0; i < tags.length; i++) {
      tags[i].order = i;
    }
    tags.refresh();
    saveTags();
  }

  bool updateTag(int index, String newName, String newDescription) {
    if (index < 0 || index >= tags.length) return false;
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return false;

    final normalizedName = cleanName.toLowerCase();
    final exists = tags.asMap().entries.any(
      (entry) => entry.key != index && entry.value.name.toLowerCase() == normalizedName,
    );
    if (exists) return false;

    tags[index].name = cleanName;
    tags[index].description = newDescription.trim();
    tags.refresh();
    saveTags();
    return true;
  }

  void pinToTop(int index) {
    if (index <= 0 || index >= tags.length) return;

    final targetTag = tags.removeAt(index);
    tags.insert(0, targetTag);

    _refreshSequentialOrders();
  }

  void togglePinStatus(int index) {
    _refreshSequentialOrders();
  }

  void deleteTag(int index) {
    if (index < 0 || index >= tags.length) return;
    final deletedTagId = tags[index].id;
    tags.removeAt(index);

    var mappingChanged = false;
    for (final entry in roomTagsMap.entries.toList(growable: false)) {
      final remainingIds = entry.value.where((id) => id != deletedTagId).toList(growable: false);
      if (remainingIds.length == entry.value.length) continue;
      mappingChanged = true;
      if (remainingIds.isEmpty) {
        roomTagsMap.remove(entry.key);
      } else {
        roomTagsMap[entry.key] = remainingIds;
      }
    }
    if (mappingChanged) {
      roomTagsMap.refresh();
      saveRoomTagsMapping();
    }
    _refreshSequentialOrders();
  }

  void _refreshSequentialOrders() {
    for (int i = 0; i < tags.length; i++) {
      tags[i].order = i;
    }
    tags.refresh();
    saveTags();
  }

  String _allocateTagId(Set<String> usedIds) {
    var candidate = DateTime.now().microsecondsSinceEpoch;
    if (candidate <= _lastGeneratedTagId) candidate = _lastGeneratedTagId + 1;
    while (usedIds.contains(candidate.toString())) {
      candidate++;
    }
    _lastGeneratedTagId = candidate;
    return candidate.toString();
  }

  Map<String, dynamic> exportToJson() {
    return {'tags': tags.map((e) => e.toJson()).toList(), 'roomTagsMap': roomTagsMap};
  }

  static Map<String, dynamic> parseConfig(Map<String, dynamic> json) {
    final result = <String, dynamic>{};
    if (json['tags'] != null) {
      final storedTags = json['tags'] as List;
      final list = storedTags.map((e) => LiveTag.fromJson(Map<String, dynamic>.from(e))).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      result['tags'] = list;
    }
    if (json['roomTagsMap'] != null) {
      final storedMap = json['roomTagsMap'] as Map;
      result['roomTagsMap'] = storedMap.map((key, value) {
        return MapEntry(key.toString(), List<String>.from(value as List));
      });
    }
    return result;
  }

  void importFromJson(Map<String, dynamic>? json) {
    if (json == null) return;
    final parsed = parseConfig(json);
    if (parsed.containsKey('tags')) {
      tags.assignAll(parsed['tags']);
      saveTags();
    }
    if (parsed.containsKey('roomTagsMap')) {
      roomTagsMap.assignAll(parsed['roomTagsMap']);
      saveRoomTagsMapping();
    }
  }
}
