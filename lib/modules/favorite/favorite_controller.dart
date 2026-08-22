import 'dart:async';
import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/modules/favorite/favorite_startup_policy.dart';
import 'package:pure_live/common/services/settings/refresh_config_controller.dart';

class FavoriteController extends LocalReactivePageController<LiveRoom>
    with GetTickerProviderStateMixin, WidgetsBindingObserver {
  final TagManagementController tagController = Get.find<TagManagementController>();
  final RefreshConfigController refreshConfigController = Get.find<RefreshConfigController>();

  late TabController tabController;

  final tabBottomIndex = 0.obs;
  final tabSiteIndex = 0.obs;
  final tabOnlineIndex = 0.obs;
  StreamSubscription<dynamic>? subscription;
  StreamSubscription<dynamic>? roomChangedSubscription;

  StreamSubscription<dynamic>? _configSubscription;
  Timer? _autoRefreshTimer;
  Timer? _debounceTimer;
  Timer? _resumeRefreshTimer;
  Timer? _settledStatusTabTimer;
  final List<Worker> _workers = [];
  int _refreshEpoch = 0;
  DateTime? _lastFullRefreshAt;
  final isVerifyingFavorites = false.obs;
  Future<void>? _startupRefresh;

  // Treat returning to the app as a fresh launch after a short debounce.  A
  // two-minute window left just-ended rooms visibly "live" when users reopened
  // the app from Recents; 15 seconds still suppresses duplicate lifecycle
  // events from rotation/PiP while keeping room state current.
  static const Duration _resumeRefreshStaleAfter = Duration(seconds: 15);
  static const Duration _roomRefreshTimeout = Duration(seconds: 10);

  final onlineRooms = <LiveRoom>[].obs;
  final offlineRooms = <LiveRoom>[].obs;
  final replayRooms = <LiveRoom>[].obs;
  final selectedTagId = TagManagementController.allTagKey.obs;
  final visibleTags = <LiveTag>[].obs;

  FavoriteController() : super();

  @override
  void onInit() {
    super.onInit();

    tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    _workers.add(
      debounce(SettingsService.to.fav.favoriteRooms, (_) {
        if (!isVerifyingFavorites.value) applyLocalFilter();
      }, time: const Duration(milliseconds: 1000)),
    );

    _workers.add(ever(selectedTagId, (_) => applyLocalFilter()));
    _workers.add(ever(tabSiteIndex, (_) => applyLocalFilter()));
    _workers.add(ever(tabOnlineIndex, (_) => applyLocalFilter()));
    _workers.add(ever(tagController.tags, (_) => applyLocalFilter()));
    _workers.add(ever(tagController.roomTagsMap, (_) => applyLocalFilter()));
    _workers.add(ever(SettingsService.to.app.preferRealOnlineCounts, (_) => applyLocalFilter()));
    _workers.add(ever(SettingsService.to.app.realOnlinePlatforms, (_) => applyLocalFilter()));

    // Begin verification during controller startup instead of waiting for the
    // first rendered frame. Persisted metadata remains useful, but its old
    // live/offline bit is invalidated synchronously so an ended stream is not
    // painted as live while requests are still in flight (or if one fails).
    unawaited(refreshPersistedRoomsOnStartup());

    tabController.addListener(_handleStatusTabChange);

    _setupRefreshStrategy();
    _configSubscription = refreshConfigController.configChanges.listen((config) {
      _setupRefreshStrategy();
    });

    listenFavorite();
    listenRoomChanged();
  }

  void _handleStatusTabChange() {
    if (tabController.indexIsChanging) return;
    final animationValue = tabController.animation?.value ?? tabController.index.toDouble();
    if ((animationValue - tabController.index).abs() > 0.001) return;
    if (tabOnlineIndex.value == tabController.index) return;

    _settledStatusTabTimer?.cancel();
    _settledStatusTabTimer = Timer(const Duration(milliseconds: 80), () {
      if (isClosed || tabOnlineIndex.value == tabController.index) return;
      tabOnlineIndex.value = tabController.index;
      if (usesDesktopPagination) currentPage = 1;
    });
  }

  void _setupRefreshStrategy() {
    _autoRefreshTimer?.cancel();
    final bool isEnabled = refreshConfigController.autoRefreshFavorite.value;
    final int interval = refreshConfigController.autoRefreshInterval.value;
    if (isEnabled && interval > 0) {
      _autoRefreshTimer = Timer.periodic(
        Duration(minutes: interval),
        (_) => unawaited(_fullRefreshRooms(showLoading: false)),
      );
    }
  }

  void debounceRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_fullRefreshRooms(showLoading: false));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _resumeRefreshTimer?.cancel();
      return;
    }
    final last = _lastFullRefreshAt;
    if (last == null || DateTime.now().difference(last) >= _resumeRefreshStaleAfter) {
      // Paint the retained snapshot first. JSON parsing and image URL updates
      // then land as one transaction instead of competing with the foreground
      // transition and producing several visibly different grids.
      _resumeRefreshTimer?.cancel();
      _resumeRefreshTimer = Timer(
        const Duration(milliseconds: 450),
        () => unawaited(_fullRefreshRooms(showLoading: true, emitFinish: false)),
      );
    }
  }

  @override
  void onClose() {
    _refreshEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    tabController.removeListener(_handleStatusTabChange);
    tabController.dispose();
    subscription?.cancel();
    roomChangedSubscription?.cancel();
    _configSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    _resumeRefreshTimer?.cancel();
    _settledStatusTabTimer?.cancel();
    for (final worker in _workers) {
      worker.dispose();
    }
    super.onClose();
  }

  void listenFavorite() {
    subscription = EventBus.instance.listen('refresh_favorite_rooms', (data) {
      debounceRefresh();
    });
  }

  void listenRoomChanged() {
    roomChangedSubscription = EventBus.instance.listen('refresh_room_changed', (data) {
      syncRooms();
    });
  }

  void changeSelectedTag(String tagId) {
    selectedTagId.value = tagId;
    if (Get.width > 680) {
      currentPage = 1;
    }
    applyLocalFilter();
  }

  void updateRoomTags(LiveRoom room, List<String> newTagIds) {
    tagController.setRoomTags(room.roomId.toString(), newTagIds);
    applyLocalFilter();
  }

  List<LiveRoom> getAllRooms() {
    return List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);
  }

  List<LiveRoom> getFilteredRoomsIgnoringLiveStatus() {
    final List<LiveRoom> source = List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);

    final currentAvailableSites = Sites().availableSites(containsAll: true);
    if (tabSiteIndex.value < 0 || tabSiteIndex.value >= currentAvailableSites.length) {
      return [];
    }

    final activeSite = currentAvailableSites[tabSiteIndex.value];
    List<LiveRoom> siteFiltered = source;

    if (activeSite.id != Sites.allSite) {
      siteFiltered = source.where((room) {
        return room.platform?.toUpperCase() == activeSite.id.toUpperCase();
      }).toList();
    }

    if (selectedTagId.value == TagManagementController.allTagKey) {
      return siteFiltered;
    }

    return siteFiltered.where((room) {
      final List<String> ids = tagController.getTagsForRoom(room);
      return ids.contains(selectedTagId.value);
    }).toList();
  }

  List<LiveRoom> getFilteredRooms({Iterable<LiveRoom>? roomSnapshot}) {
    syncRooms(roomSnapshot: roomSnapshot);

    return _filterSyncedRooms();
  }

  List<LiveRoom> _filterSyncedRooms() {
    final currentAvailableSites = Sites().availableSites(containsAll: true);
    if (tabSiteIndex.value < 0 || tabSiteIndex.value >= currentAvailableSites.length) {
      return [];
    }
    return filteredSyncedRoomsForSite(currentAvailableSites[tabSiteIndex.value].id);
  }

  List<LiveRoom> filteredSyncedRoomsForSite(String siteId) {
    List<LiveRoom> source;

    switch (tabOnlineIndex.value) {
      case 0:
        source = onlineRooms;
        break;

      case 1:
        source = replayRooms;
        break;

      case 2:
        source = offlineRooms;
        break;

      default:
        source = onlineRooms;
    }

    List<LiveRoom> siteFiltered = source;

    if (siteId != Sites.allSite) {
      siteFiltered = source.where((room) {
        return room.platform?.toUpperCase() == siteId.toUpperCase();
      }).toList();
    }

    if (selectedTagId.value == TagManagementController.allTagKey) {
      return siteFiltered;
    }

    return siteFiltered.where((room) {
      final List<String> ids = tagController.getTagsForRoom(room);
      return ids.contains(selectedTagId.value);
    }).toList();
  }

  void syncRooms({Iterable<LiveRoom>? roomSnapshot}) {
    final List<LiveRoom> roomsBase = List<LiveRoom>.from(roomSnapshot ?? SettingsService.to.fav.favoriteRooms.v);
    final nextOnline = roomsBase.where((r) => r.liveStatus == LiveStatus.live && r.isRecord == false).toList();
    final nextOffline = roomsBase.where((r) => r.liveStatus != LiveStatus.live).toList();
    final nextReplay = roomsBase.where((r) => r.liveStatus == LiveStatus.live && r.isRecord == true).toList();

    final currentAvailableSites = Sites().availableSites(containsAll: true);
    var nextVisibleTags = <LiveTag>[];

    if (tabSiteIndex.value >= 0 && tabSiteIndex.value < currentAvailableSites.length) {
      final activeSite = currentAvailableSites[tabSiteIndex.value];
      List<LiveRoom> target;

      switch (tabOnlineIndex.value) {
        case 0:
          target = nextOnline;
          break;

        case 1:
          target = nextReplay;
          break;

        case 2:
          target = nextOffline;
          break;

        default:
          target = nextOnline;
      }
      final Set<String> tagIds = {};

      for (var room in target) {
        if (activeSite.id == Sites.allSite || room.platform?.toUpperCase() == activeSite.id.toUpperCase()) {
          final ids = tagController.getTagsForRoom(room);
          tagIds.addAll(ids);
        }
      }

      nextVisibleTags = tagController.tags.where((t) => tagIds.contains(t.id)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    }

    nextOnline.sort((a, b) {
      if (selectedTagId.value == TagManagementController.allTagKey) {
        return _audienceSortValue(b).compareTo(_audienceSortValue(a));
      }
      int sa = _getRoomTagScore(a);
      int sb = _getRoomTagScore(b);
      if (sa != sb) return sb.compareTo(sa);
      return _audienceSortValue(b).compareTo(_audienceSortValue(a));
    });
    nextReplay.sort((a, b) {
      if (selectedTagId.value == TagManagementController.allTagKey) {
        return _audienceSortValue(b).compareTo(_audienceSortValue(a));
      }
      int sa = _getRoomTagScore(a);
      int sb = _getRoomTagScore(b);
      if (sa != sb) return sb.compareTo(sa);
      return _audienceSortValue(b).compareTo(_audienceSortValue(a));
    });

    // Build and sort plain lists first, then publish each result once. The old
    // clear/addAll/sort sequence notified every Obx grid several times for one
    // background refresh, causing visible hitches with many favourites.
    _assignIfSnapshotChanged(onlineRooms, nextOnline);
    _assignIfSnapshotChanged(offlineRooms, nextOffline);
    _assignIfSnapshotChanged(replayRooms, nextReplay);
    _assignIfSnapshotChanged(visibleTags, nextVisibleTags);
  }

  void _assignIfSnapshotChanged<T>(RxList<T> target, List<T> next) {
    if (target.length == next.length) {
      var identicalSnapshot = true;
      for (var index = 0; index < next.length; index++) {
        if (!identical(target[index], next[index])) {
          identicalSnapshot = false;
          break;
        }
      }
      if (identicalSnapshot) return;
    }
    target.assignAll(next);
  }

  int _audienceSortValue(LiveRoom room) {
    final app = SettingsService.to.app;
    return room.audienceSortValue(
      preferRealOnline: app.preferRealOnlineCounts.v,
      platformEnabled: app.isRealOnlineEnabledFor(room.platform),
    );
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

  @override
  Future<void> refreshData() async {
    final startup = _startupRefresh;
    if (startup != null) {
      // BasePageView performs a one-time mobile/desktop layout notification.
      // Coalesce that request with the cold-start verification instead of
      // incrementing _refreshEpoch and cancelling the authoritative refresh.
      await startup;
      return;
    }
    currentPage = 1;
    await _fullRefreshFilterRooms(showLoading: true);
  }

  Future<void> _fullRefreshFilterRooms({required bool showLoading}) async {
    final roomsToRefresh = getFilteredRoomsIgnoringLiveStatus();
    await _runRoomRefresh(roomsToRefresh, showLoading: showLoading);
  }

  Future<void> _fullRefreshRooms({required bool showLoading, bool emitFinish = true}) async {
    final roomsToRefresh = getAllRooms();
    await _runRoomRefresh(roomsToRefresh, showLoading: showLoading, emitFinish: emitFinish, markFullRefresh: true);
  }

  @visibleForTesting
  Future<void> refreshPersistedRoomsOnStartup() {
    final current = _startupRefresh;
    if (current != null) return current;

    late final Future<void> operation;
    operation = _refreshPersistedRoomsOnStartupInternal().whenComplete(() {
      if (identical(_startupRefresh, operation)) _startupRefresh = null;
    });
    _startupRefresh = operation;
    return operation;
  }

  Future<void> _refreshPersistedRoomsOnStartupInternal() async {
    isVerifyingFavorites.value = true;
    final persisted = List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);
    if (persisted.isNotEmpty) {
      // Keep the complete previous snapshot in place while verification runs.
      // The former clear -> batch preview -> persisted chunk sequence made the
      // grid disappear, reorder and reappear once per network batch.
      applyLocalFilter();
      pageEmpty.value = false;
    } else {
      applyLocalFilter();
    }
    try {
      await _runRoomRefresh(
        persisted,
        showLoading: true,
        emitFinish: false,
        markFullRefresh: true,
        invalidateUnverified: true,
      );
    } finally {
      isVerifyingFavorites.value = false;
      // Also restores a useful offline/unknown view if a controller-level
      // exception interrupted the refresh before its normal final publish.
      applyLocalFilter();
    }
  }

  Future<void> _runRoomRefresh(
    List<LiveRoom> rooms, {
    required bool showLoading,
    bool emitFinish = true,
    bool markFullRefresh = false,
    bool invalidateUnverified = false,
  }) async {
    final refreshEpoch = ++_refreshEpoch;
    if (showLoading) loadding.value = true;
    try {
      final updates = await _refreshRoomDetails(rooms, refreshEpoch: refreshEpoch);
      if (refreshEpoch != _refreshEpoch || isClosed) return;

      final latest = List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);
      final merged = invalidateUnverified
          ? (rooms: buildVerifiedFavoriteSnapshot(latest, updates), changed: true)
          : mergeFavoriteRoomUpdates(latest, updates);
      if (merged.changed) {
        // One Hive write and one visible publication. A failed startup request
        // remains unknown instead of carrying the previous process's live bit.
        SettingsService.to.fav.favoriteRooms.v = merged.rooms;
      }
      if (markFullRefresh) _lastFullRefreshAt = DateTime.now();
      applyLocalFilter();
      if (emitFinish) EventBus.instance.emit('refresh_favorite_finish', true);
    } finally {
      if (showLoading && refreshEpoch == _refreshEpoch && !isClosed) {
        loadding.value = false;
      }
    }
  }

  Future<Map<String, LiveRoom>> _refreshRoomDetails(List<LiveRoom> rooms, {required int refreshEpoch}) async {
    final valid = rooms
        .where((r) => (r.platform?.isNotEmpty ?? false) && (r.roomId?.isNotEmpty ?? false))
        .toList(growable: false);
    if (valid.isEmpty) return const <String, LiveRoom>{};

    final concurrency = RefreshConfigController.normalizeMaxConcurrentRefresh(
      refreshConfigController.maxConcurrentRefresh.value,
    );
    final pendingUpdates = <String, LiveRoom>{};
    final results = await boundedAsyncMap<LiveRoom, LiveRoom>(
      valid,
      maxConcurrent: concurrency,
      task: _refreshOneRoom,
      shouldCancel: () => refreshEpoch != _refreshEpoch || isClosed,
    );
    if (refreshEpoch != _refreshEpoch || isClosed) return const <String, LiveRoom>{};
    for (final updated in results.whereType<LiveRoom>()) {
      pendingUpdates[_roomKey(updated)] = updated;
    }
    return pendingUpdates;
  }

  Future<LiveRoom?> _refreshOneRoom(LiveRoom room) async {
    try {
      return await Sites.of(room.platform!).liveSite
          .getRoomDetail(roomId: room.roomId!, platform: room.platform!)
          .timeout(_roomRefreshTimeout);
    } catch (error, stackTrace) {
      // One platform/room failure must not discard successful updates from the
      // rest of the batch.
      developer.log(
        'Favorite room refresh failed: ${_roomKey(room)}',
        name: 'FavoriteController',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  String _roomKey(LiveRoom room) => favoriteRoomIdentity(room);
}
