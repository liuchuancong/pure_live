import 'dart:async';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';

class FavoriteController extends BasePageController<LiveRoom> with GetTickerProviderStateMixin {
  final TagManagementController tagController = Get.find<TagManagementController>();
  final RefreshConfigController refreshConfigController = Get.find<RefreshConfigController>();

  late TabController tabController;

  final tabBottomIndex = 0.obs;
  final tabSiteIndex = 0.obs;
  final tabOnlineIndex = 0.obs;
  StreamSubscription<dynamic>? subscription;
  StreamSubscription<dynamic>? _configSubscription;
  Timer? _autoRefreshTimer;
  Stopwatch? _refreshStopwatch;

  final onlineRooms = [].obs;
  final offlineRooms = [].obs;

  final selectedTagId = 'ALL'.obs;
  final visibleTags = <LiveTag>[].obs;
  final isLoading = true.obs;

  FavoriteController() : super();

  @override
  void onInit() {
    super.onInit();

    tabController = TabController(length: 2, vsync: this);

    syncRooms();

    debounce(SettingsService.to.fav.favoriteRooms, (rooms) => syncRooms(), time: const Duration(milliseconds: 1000));

    ever(selectedTagId, (_) => syncRooms());
    ever(tagController.tags, (_) => syncRooms());
    ever(tabSiteIndex, (_) => syncRooms());
    ever(tagController.roomTagsMap, (_) {
      syncRooms();
    });
    ever(tagController.tags, (_) {
      syncRooms();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshData();
    });

    tabController.addListener(() {
      if (tabOnlineIndex.value != tabController.index) {
        tabOnlineIndex.value = tabController.index;
        currentPage = 1;
        syncRooms();
      }
    });

    _setupRefreshStrategy();
    _configSubscription = refreshConfigController.configChanges.listen((config) {
      _setupRefreshStrategy();
    });

    listenFavorite();
  }

  void _setupRefreshStrategy() {
    _autoRefreshTimer?.cancel();
    final bool isEnabled = refreshConfigController.autoRefreshFavorite.value;
    final int interval = refreshConfigController.autoRefreshInterval.value;
    if (isEnabled && interval > 0) {
      _autoRefreshTimer = Timer.periodic(Duration(minutes: interval), (timer) => refreshData());
    }
  }

  @override
  void onClose() {
    tabController.dispose();
    subscription?.cancel();
    _configSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    super.onClose();
  }

  void listenFavorite() {
    subscription = EventBus.instance.listen('refresh_favorite_rooms', (data) {
      refreshData();
    });
  }

  List<LiveRoom> getFilteredRooms({required bool isOnline}) {
    final List<dynamic> sourceList = isOnline ? onlineRooms : offlineRooms;
    final typedList = sourceList.cast<LiveRoom>();

    if (selectedTagId.value == 'ALL') {
      return typedList;
    }

    return typedList.where((room) {
      final List<String> roomTagIds = tagController.getTagsForRoom(room);
      return roomTagIds.contains(selectedTagId.value);
    }).toList();
  }

  void changeSelectedTag(String tagId) {
    selectedTagId.value = tagId;
    currentPage = 1;
    syncRooms();
  }

  void reloadPage() async {
    await refreshData();
  }

  void updateRoomTags(LiveRoom room, List<String> newTagIds) {
    final tagController = Get.find<TagManagementController>();
    tagController.setRoomTags(room.roomId.toString(), newTagIds);
    syncRooms();
  }

  void syncRooms() {
    onlineRooms.clear();
    offlineRooms.clear();
    List<dynamic> roomsBase = List.from(SettingsService.to.fav.favoriteRooms.v);
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

    final allFiltered = getFilteredRooms(isOnline: tabOnlineIndex.value == 0);
    totalCount.value = allFiltered.length;

    final int maxPage = (totalCount.value! / pageSize.value).ceil();
    canLoadMore.value = currentPage < maxPage;

    int startOffset = (currentPage - 1) * pageSize.value;
    int endOffset = startOffset + pageSize.value;
    if (startOffset > allFiltered.length) {
      currentPage = 1;
      startOffset = 0;
      endOffset = pageSize.value;
    }
    if (endOffset > allFiltered.length) {
      endOffset = allFiltered.length;
    }

    if (allFiltered.isEmpty) {
      list.clear();
    } else {
      list.assignAll(allFiltered.sublist(startOffset, endOffset));
    }

    pageEmpty.value = allFiltered.isEmpty;
    pageLoadding.value = false;
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

  @override
  Future<List<LiveRoom>> getData(int page, int pageSize) async {
    if (SettingsService.to.fav.favoriteRooms.v.isEmpty) {
      isLoading.value = false;
      return [];
    }

    _refreshStopwatch = Stopwatch()..start();

    var futures = SettingsService.to.fav.favoriteRooms.v
        .where((room) => room.platform!.isNotEmpty)
        .map((room) => Sites.of(room.platform!).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!))
        .toList();
    final int batchSize = refreshConfigController.maxConcurrentRefresh.value > 0
        ? refreshConfigController.maxConcurrentRefresh.value
        : 5;

    for (int i = 0; i < futures.length; i += batchSize) {
      try {
        List<LiveRoom> rooms = await Future.wait(
          futures.sublist(i, i + batchSize > futures.length ? futures.length : i + batchSize),
        );
        for (var room in rooms) {
          final currentList = List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);
          final index = currentList.indexWhere((e) => e.roomId == room.roomId && e.platform == room.platform);
          if (index != -1) {
            currentList[index] = room;
            SettingsService.to.fav.favoriteRooms.v = currentList;
          }
        }
      } catch (e) {
        debugPrint('Error during refresh for a batch of requests: $e');
      }
    }

    _refreshStopwatch?.stop();
    debugPrint('Refresh process finished in ${_refreshStopwatch?.elapsedMilliseconds} ms');
    _refreshStopwatch = null;

    isLoading.value = false;
    EventBus.instance.emit('refresh_favorite_finish', true);

    syncRooms();

    int startOffset = (page - 1) * pageSize;
    int endOffset = startOffset + pageSize;
    final allFiltered = getFilteredRooms(isOnline: tabOnlineIndex.value == 0);

    if (startOffset >= allFiltered.length) return [];
    if (endOffset > allFiltered.length) endOffset = allFiltered.length;

    return tyrannicalCast(allFiltered.sublist(startOffset, endOffset));
  }

  List<LiveRoom> tyrannicalCast(List<dynamic> list) => list.cast<LiveRoom>();
}
