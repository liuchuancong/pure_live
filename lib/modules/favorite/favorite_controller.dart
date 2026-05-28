import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';

class FavoriteController extends GetxController with GetTickerProviderStateMixin {
  final SettingsService settings = Get.find<SettingsService>();
  final TagManagementController tagController = Get.find<TagManagementController>();

  late TabController tabController;

  final tabBottomIndex = 0.obs;
  final tabSiteIndex = 0.obs;
  final tabOnlineIndex = 0.obs;
  bool isFirstLoad = true;
  StreamSubscription<dynamic>? subscription;
  Timer? _autoRefreshTimer;

  final refreshController = EasyRefreshController(controlFinishRefresh: true, controlFinishLoad: true);
  final onlineRooms = [].obs;
  final offlineRooms = [].obs;

  final selectedTagId = 'ALL'.obs;
  final visibleTags = <LiveTag>[].obs;

  @override
  void onInit() {
    super.onInit();

    tabController = TabController(length: 2, vsync: this);

    syncRooms();

    debounce(settings.favoriteRooms, (rooms) => syncRooms(), time: const Duration(milliseconds: 1000));

    ever(selectedTagId, (_) => syncRooms());
    ever(tagController.tags, (_) => syncRooms());
    ever(tabSiteIndex, (_) => syncRooms());
    ever(tagController.roomTagsMap, (_) {
      syncRooms();
    });
    ever(tagController.tags, (_) {
      syncRooms();
    });
    onRefresh();

    tabController.addListener(() {
      tabOnlineIndex.value = tabController.index;
    });

    if (settings.autoRefreshTime.value != 0) {
      _autoRefreshTimer = Timer.periodic(Duration(minutes: settings.autoRefreshTime.value), (timer) => onRefresh());
    }
    listenFavorite();
  }

  @override
  void onClose() {
    tabController.dispose();
    subscription?.cancel();
    _autoRefreshTimer?.cancel();
    super.onClose();
  }

  void listenFavorite() {
    subscription = EventBus.instance.listen('refresh_favorite_rooms', (data) {
      onRefresh();
    });
  }

  List<dynamic> getFilteredRooms({required bool isOnline}) {
    final sourceList = isOnline ? onlineRooms : offlineRooms;

    if (selectedTagId.value == 'ALL') {
      return sourceList;
    }

    return sourceList.where((room) {
      final List<String> roomTagIds = tagController.getTagsForRoom(room);
      return roomTagIds.contains(selectedTagId.value);
    }).toList();
  }

  void changeSelectedTag(String tagId) {
    selectedTagId.value = tagId;
    syncRooms();
  }

  void reloadPage() async {
    refreshController.callRefresh();
    await onRefresh();
    refreshController.finishRefresh(IndicatorResult.success);
  }

  void updateRoomTags(LiveRoom room, List<String> newTagIds) {
    final tagController = Get.find<TagManagementController>();
    tagController.setRoomTags(room.roomId.toString(), newTagIds);
    syncRooms();
  }

  void syncRooms() {
    onlineRooms.clear();
    offlineRooms.clear();
    List<dynamic> roomsBase = List.from(settings.favoriteRooms);
    onlineRooms.addAll(roomsBase.where((room) => room.liveStatus == LiveStatus.live));
    offlineRooms.addAll(roomsBase.where((room) => room.liveStatus != LiveStatus.live));
    final currentAvailableSites = Sites().availableSites(containsAll: true);
    if (tabSiteIndex.value >= 0 && tabSiteIndex.value < currentAvailableSites.length) {
      final activeSite = currentAvailableSites[tabSiteIndex.value];
      final targetList = tabOnlineIndex.value == 0 ? onlineRooms : offlineRooms;
      final Set<String> activeTagIdSet = {};
      for (var room in targetList) {
        if (activeSite.id == 'all' || room.platform?.toUpperCase() == activeSite.id.toUpperCase()) {
          final List<String> currentRoomTagIds = tagController.getTagsForRoom(room);
          for (var id in currentRoomTagIds) {
            activeTagIdSet.add(id);
          }
        }
      }

      final matchedTags = tagController.tags.where((t) => activeTagIdSet.contains(t.id)).toList();
      matchedTags.sort((a, b) => a.order.compareTo(b.order));
      visibleTags.assignAll(matchedTags);
    }

    for (var room in onlineRooms) {
      if (int.tryParse(room.watching!) == null) {
        room.watching = "0";
      }
    }

    onlineRooms.sort((a, b) {
      if (selectedTagId.value == 'ALL') {
        return int.parse(b.watching!).compareTo(int.parse(a.watching!));
      }

      int scoreA = _getRoomTagScore(a);
      int scoreB = _getRoomTagScore(b);

      if (scoreA != scoreB) {
        return scoreB.compareTo(scoreA);
      }

      return int.parse(b.watching!).compareTo(int.parse(a.watching!));
    });
  }

  int _getRoomTagScore(dynamic room) {
    final List<String> currentRoomTagIds = tagController.getTagsForRoom(room);

    if (currentRoomTagIds.isEmpty) return 0;

    int highestScore = 0;
    int maxScore = 1000000;

    for (var id in currentRoomTagIds) {
      final tagIndex = tagController.tags.indexWhere((t) => t.id == id);
      if (tagIndex != -1) {
        final tag = tagController.tags[tagIndex];
        int currentScore = maxScore - (tag.order * 100);
        if (currentScore > highestScore) {
          highestScore = currentScore;
        }
      }
    }
    return highestScore;
  }

  Future<bool> onRefresh() async {
    if (isFirstLoad) await Future.delayed(const Duration(seconds: 1));

    if (settings.favoriteRooms.value.isEmpty) return false;

    var futures = settings.favoriteRooms.value
        .where((room) => room.platform!.isNotEmpty)
        .map((room) => Sites.of(room.platform!).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!))
        .toList();
    try {
      for (int i = 0; i < futures.length; i += 5) {
        try {
          List<LiveRoom> rooms = await Future.wait(futures.sublist(i, i + 5 > futures.length ? futures.length : i + 5));
          for (var room in rooms) {
            try {
              settings.updateRoom(room);
            } catch (e) {
              debugPrint('Error during refresh for a single request: $e');
            }
          }
        } catch (e) {
          debugPrint('Error during refresh for a batch of requests: $e');
        }
      }
      syncRooms();
    } catch (e) {
      debugPrint('Error during refresh: $e');
    }
    isFirstLoad = false;
    EventBus.instance.emit('refresh_favorite_finish', true);
    return false;
  }
}
