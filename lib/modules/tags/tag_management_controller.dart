import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class TagManagementController extends GetxController {
  static const String _storageKey = 'user_custom_tags_v5';
  static const String _roomTagsMappingKey = 'room_to_tags_mapping_v1';
  final RxMap<String, List<String>> roomTagsMap = <String, List<String>>{}.obs;
  final RxList<LiveTag> tags = <LiveTag>[].obs;
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

  void setRoomTags(String roomId, List<String> newTagIds) {
    if (newTagIds.isEmpty) {
      roomTagsMap.remove(roomId);
    } else {
      roomTagsMap[roomId] = newTagIds;
    }

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
    final String roomId = room.roomId.toString();
    return roomTagsMap[roomId] ?? [];
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
}
