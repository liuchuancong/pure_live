import 'dart:async';
import 'dart:developer' as developer;
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';

class FavoriteController extends LocalReactivePageController<LiveRoom> with GetTickerProviderStateMixin {
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
  Timer? _debounceTimer;

  final onlineRooms = <LiveRoom>[].obs;
  final offlineRooms = <LiveRoom>[].obs;

  final selectedTagId = 'ALL'.obs;
  final visibleTags = <LiveTag>[].obs;
  final isLoading = true.obs;

  FavoriteController() : super() {
    onExternalRefresh = () {
      _fullRefreshRooms();
    };
  }

  @override
  void onInit() {
    super.onInit();

    tabController = TabController(length: 2, vsync: this);

    debounce(SettingsService.to.fav.favoriteRooms, (_) => applyLocalFilter(), time: const Duration(milliseconds: 1000));

    ever(selectedTagId, (_) => applyLocalFilter());
    ever(tabSiteIndex, (_) => applyLocalFilter());
    ever(tabOnlineIndex, (_) => applyLocalFilter());
    ever(tagController.tags, (_) => applyLocalFilter());
    ever(tagController.roomTagsMap, (_) => applyLocalFilter());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      applyLocalFilter();
    });

    tabController.addListener(() {
      if (tabOnlineIndex.value != tabController.index) {
        tabOnlineIndex.value = tabController.index;
        currentPage = 1;
        applyLocalFilter();
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

  void debounceRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      refreshData();
    });
  }

  @override
  void onClose() {
    tabController.dispose();
    subscription?.cancel();
    _configSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    super.onClose();
  }

  void listenFavorite() {
    subscription = EventBus.instance.listen('refresh_favorite_rooms', (data) {
      debounceRefresh();
    });
  }

  void changeSelectedTag(String tagId) {
    selectedTagId.value = tagId;
    currentPage = 1;
    applyLocalFilter();
  }

  void updateRoomTags(LiveRoom room, List<String> newTagIds) {
    tagController.setRoomTags(room.roomId.toString(), newTagIds);
    applyLocalFilter();
  }

  List<LiveRoom> getFilteredRooms() {
    syncRooms();

    final bool isOnline = tabOnlineIndex.value == 0;
    final List<LiveRoom> source = isOnline ? onlineRooms : offlineRooms;

    final currentAvailableSites = Sites().availableSites(containsAll: true);
    if (tabSiteIndex.value < 0 || tabSiteIndex.value >= currentAvailableSites.length) {
      return [];
    }

    final activeSite = currentAvailableSites[tabSiteIndex.value];
    List<LiveRoom> siteFiltered = source;

    if (activeSite.id != 'all') {
      siteFiltered = source.where((room) {
        return room.platform?.toUpperCase() == activeSite.id.toUpperCase();
      }).toList();
    }

    if (selectedTagId.value == 'ALL') {
      return siteFiltered;
    }

    return siteFiltered.where((room) {
      final List<String> ids = tagController.getTagsForRoom(room);
      return ids.contains(selectedTagId.value);
    }).toList();
  }

  void syncRooms() {
    onlineRooms.clear();
    offlineRooms.clear();

    final List<LiveRoom> roomsBase = List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);
    onlineRooms.addAll(roomsBase.where((r) => r.liveStatus == LiveStatus.live));
    offlineRooms.addAll(roomsBase.where((r) => r.liveStatus != LiveStatus.live));

    final currentAvailableSites = Sites().availableSites(containsAll: true);
    visibleTags.clear();

    if (tabSiteIndex.value >= 0 && tabSiteIndex.value < currentAvailableSites.length) {
      final activeSite = currentAvailableSites[tabSiteIndex.value];
      final target = tabOnlineIndex.value == 0 ? onlineRooms : offlineRooms;
      final Set<String> tagIds = {};

      for (var room in target) {
        if (activeSite.id == 'all' || room.platform?.toUpperCase() == activeSite.id.toUpperCase()) {
          final ids = tagController.getTagsForRoom(room);
          tagIds.addAll(ids);
        }
      }

      final tags = tagController.tags.where((t) => tagIds.contains(t.id)).toList();
      tags.sort((a, b) => a.order.compareTo(b.order));
      visibleTags.assignAll(tags);
    }

    for (var room in onlineRooms) {
      room.watching = int.tryParse(room.watching ?? '')?.toString() ?? '0';
    }

    onlineRooms.sort((a, b) {
      if (selectedTagId.value == 'ALL') {
        return int.parse(b.watching!).compareTo(int.parse(a.watching!));
      }
      int sa = _getRoomTagScore(a);
      int sb = _getRoomTagScore(b);
      if (sa != sb) return sb.compareTo(sa);
      return int.parse(b.watching!).compareTo(int.parse(a.watching!));
    });
  }

  int _getRoomTagScore(LiveRoom room) {
    final ids = tagController.getTagsForRoom(room);
    if (ids.isEmpty) return 0;

    int highest = 0;
    const maxScore = 1000000;

    for (var id in ids) {
      final idx = tagController.tags.indexWhere((t) => id == t.id);
      if (idx != -1) {
        final tag = tagController.tags[idx];
        final score = maxScore - tag.order * 100;
        if (score > highest) highest = score;
      }
    }
    return highest;
  }

  void applyLocalFilter() {
    final filtered = getFilteredRooms();
    updateLocalReactivePool(filtered);
  }

  Future<void> _fullRefreshRooms() async {
    isLoading.value = true;

    List<LiveRoom> roomsToRefresh = getFilteredRooms();

    await _refreshRoomDetails(roomsToRefresh);

    applyLocalFilter();

    isLoading.value = false;
    EventBus.instance.emit('refresh_favorite_finish', true);
  }

  Future<void> _refreshRoomDetails(List<LiveRoom> rooms) async {
    final valid = rooms.where((r) => r.platform?.isNotEmpty ?? false).toList();
    if (valid.isEmpty) return;

    _refreshStopwatch = Stopwatch()..start();

    final int batch = refreshConfigController.maxConcurrentRefresh.value > 0
        ? refreshConfigController.maxConcurrentRefresh.value
        : 5;

    for (int i = 0; i < valid.length; i += batch) {
      final end = i + batch > valid.length ? valid.length : i + batch;
      final batchRooms = valid.sublist(i, end);

      try {
        final futures = batchRooms
            .map(
              (room) => Sites.of(room.platform!).liveSite.getRoomDetail(roomId: room.roomId!, platform: room.platform!),
            )
            .toList();

        final results = await Future.wait(futures);
        for (var updated in results) {
          final list = List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);
          final idx = list.indexWhere((e) => e.roomId == updated.roomId && e.platform == updated.platform);
          if (idx != -1) {
            list[idx] = updated;
            SettingsService.to.fav.favoriteRooms.v = list;
          }
        }
      } catch (e) {
        developer.log('Error refreshing room details: $e');
      }
    }

    _refreshStopwatch?.stop();
    _refreshStopwatch = null;
  }
}
