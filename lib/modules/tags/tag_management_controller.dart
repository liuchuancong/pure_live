import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';

class TagManagementController extends GetxController {
  static const String _storageKey = 'user_custom_tags_v5';
  final RxList<LiveTag> tags = <LiveTag>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadTags();
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

  Future<void> _saveTags() async {
    await HivePrefUtil.setAnyPref(_storageKey, tags.map((e) => e.toJson()).toList());
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
      isPinned: false,
    );

    tags.add(newTag);
    _saveTags();
    return true;
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
    _saveTags();
    return true;
  }

  void togglePin(int index) {
    final targetTag = tags.removeAt(index);
    targetTag.isPinned = !targetTag.isPinned;

    if (targetTag.isPinned) {
      tags.insert(0, targetTag);
    } else {
      int lastPinnedIndex = tags.indexWhere((t) => t.isPinned);
      if (lastPinnedIndex == -1) {
        tags.insert(0, targetTag);
      } else {
        tags.insert(lastPinnedIndex + 1, targetTag);
      }
    }

    _refreshSequentialOrders();
  }

  void deleteTag(int index) {
    tags.removeAt(index);
    _refreshSequentialOrders();
  }

  void onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final LiveTag item = tags.removeAt(oldIndex);
    tags.insert(newIndex, item);

    _refreshSequentialOrders();
  }

  void _refreshSequentialOrders() {
    for (int i = 0; i < tags.length; i++) {
      tags[i].order = i;
    }
    tags.refresh();
    _saveTags();
  }
}
