import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class TagManagementController extends GetxController {
  static const String _storageKey = 'user_custom_tags_v5';
  static const String _roomTagsMappingKey = 'room_to_tags_mapping_v1';
  final RxMap<String, List<String>> roomTagsMap = <String, List<String>>{}.obs;
  final RxList<LiveTag> tags = <LiveTag>[].obs;
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
      tags.assignAll(list);
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

  void setRoomTags(LiveRoom room, List<String> newTagIds) {
    final roomKey = room.identityKey;
    if (newTagIds.isEmpty) {
      roomTagsMap.remove(roomKey);
    } else {
      roomTagsMap[roomKey] = List<String>.from(newTagIds);
    }

    roomTagsMap.refresh();
    saveRoomTagsMapping();
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
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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
    final cleanName = newName.trim();
    if (cleanName.isEmpty) return false;

    if (tags[index].name != cleanName) {
      final exists = tags.any((tag) => tag.name.toLowerCase() == cleanName.toLowerCase());
      if (exists) return false;
    }

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
    tags.removeAt(index);
    _refreshSequentialOrders();
  }

  void _refreshSequentialOrders() {
    for (int i = 0; i < tags.length; i++) {
      tags[i].order = i;
    }
    tags.refresh();
    saveTags();
  }

  Map<String, dynamic> exportToJson() {
    return {'tags': tags.map((e) => e.toJson()).toList(), 'roomTagsMap': roomTagsMap};
  }

  void importFromJson(Map<String, dynamic>? json) {
    if (json == null) return;

    if (json.containsKey('tags') && json['tags'] != null) {
      final storedTags = json['tags'] as List;
      final list = storedTags.map((e) => LiveTag.fromJson(Map<String, dynamic>.from(e))).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      tags.assignAll(list);
      saveTags();
    }

    if (json.containsKey('roomTagsMap') && json['roomTagsMap'] != null) {
      final storedMap = json['roomTagsMap'] as Map;
      final convertedMap = storedMap.map((key, value) {
        return MapEntry(key.toString(), List<String>.from(value as List));
      });
      roomTagsMap.assignAll(convertedMap);
      saveRoomTagsMapping();
    }
  }
}
