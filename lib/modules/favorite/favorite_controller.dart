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
  final List<Worker> _audienceWorkers = [];
  int _refreshEpoch = 0;
  DateTime? _lastFullRefreshAt;
  bool _startupVerificationInProgress = false;
  Future<void>? _startupRefresh;

  // Treat returning to the app as a fresh launch after a short debounce.  A
  // two-minute window left just-ended rooms visibly "live" when users reopened
  // the app from Recents; 15 seconds still suppresses duplicate lifecycle
  // events from rotation/PiP while keeping room state current.
  static const Duration _resumeRefreshStaleAfter = Duration(seconds: 15);
  static const Duration _roomRefreshTimeout = Duration(seconds: 12);

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

    debounce(SettingsService.to.fav.favoriteRooms, (_) {
      if (!_startupVerificationInProgress) applyLocalFilter();
    }, time: const Duration(milliseconds: 1000));

    ever(selectedTagId, (_) => applyLocalFilter());
    ever(tabSiteIndex, (_) => applyLocalFilter());
    ever(tabOnlineIndex, (_) => applyLocalFilter());
    ever(tagController.tags, (_) => applyLocalFilter());
    ever(tagController.roomTagsMap, (_) => applyLocalFilter());
    _audienceWorkers.add(ever(SettingsService.to.app.preferRealOnlineCounts, (_) => applyLocalFilter()));
    _audienceWorkers.add(ever(SettingsService.to.app.realOnlinePlatforms, (_) => applyLocalFilter()));

    // Begin verification during controller startup instead of waiting for the
    // first rendered frame. Persisted metadata remains useful, but its old
    // live/offline bit is invalidated synchronously so an ended stream is not
    // painted as live while requests are still in flight (or if one fails).
    unawaited(refreshPersistedRoomsOnStartup());

    tabController.addListener(() {
      if (tabOnlineIndex.value != tabController.index) {
        tabOnlineIndex.value = tabController.index;
        if (Get.width > 680) {
          currentPage = 1;
        }
        applyLocalFilter();
      }
    });

    _setupRefreshStrategy();
    _configSubscription = refreshConfigController.configChanges.listen((config) {
      _setupRefreshStrategy();
    });

    listenFavorite();
    listenRoomChanged();
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
    if (state != AppLifecycleState.resumed) return;
    final last = _lastFullRefreshAt;
    if (last == null || DateTime.now().difference(last) >= _resumeRefreshStaleAfter) {
      unawaited(_fullRefreshRooms(showLoading: false, emitFinish: false));
    }
  }

  @override
  void onClose() {
    _refreshEpoch++;
    WidgetsBinding.instance.removeObserver(this);
    tabController.dispose();
    subscription?.cancel();
    roomChangedSubscription?.cancel();
    _configSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    _debounceTimer?.cancel();
    for (final worker in _audienceWorkers) {
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

  void _publishTransientRoomSnapshot(List<LiveRoom> rooms) {
    final filtered = getFilteredRooms(roomSnapshot: rooms);
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
    _startupVerificationInProgress = true;
    final persisted = List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);
    if (persisted.isNotEmpty) {
      SettingsService.to.fav.favoriteRooms.v = markFavoriteRoomsPendingVerification(persisted);
      updateLocalReactivePool(const <LiveRoom>[]);
      // An empty startup pool means "checking", not "there are no follows".
      pageEmpty.value = false;
    } else {
      applyLocalFilter();
    }
    try {
      await _fullRefreshRooms(showLoading: true, emitFinish: false);
    } finally {
      _startupVerificationInProgress = false;
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
  }) async {
    final refreshEpoch = ++_refreshEpoch;
    if (showLoading) loadding.value = true;
    try {
      await _refreshRoomDetails(rooms, refreshEpoch: refreshEpoch);
      if (refreshEpoch != _refreshEpoch || isClosed) return;
      if (markFullRefresh) _lastFullRefreshAt = DateTime.now();
      applyLocalFilter();
      if (emitFinish) EventBus.instance.emit('refresh_favorite_finish', true);
    } finally {
      if (showLoading && refreshEpoch == _refreshEpoch && !isClosed) {
        loadding.value = false;
      }
    }
  }

  Future<void> _refreshRoomDetails(List<LiveRoom> rooms, {required int refreshEpoch}) async {
    final valid = rooms
        .where((r) => (r.platform?.isNotEmpty ?? false) && (r.roomId?.isNotEmpty ?? false))
        .toList(growable: false);
    if (valid.isEmpty) return;

    final int batch = refreshConfigController.maxConcurrentRefresh.value > 0
        ? refreshConfigController.maxConcurrentRefresh.value
        : 5;
    final commitThreshold = batch * 4 > 20 ? batch * 4 : 20;
    final pendingUpdates = <String, LiveRoom>{};
    var processedSinceCommit = 0;
    for (int i = 0; i < valid.length; i += batch) {
      final end = i + batch > valid.length ? valid.length : i + batch;
      final batchRooms = valid.sublist(i, end);

      final results = await Future.wait(batchRooms.map(_refreshOneRoom));
      if (refreshEpoch != _refreshEpoch || isClosed) return;
      for (final updated in results.whereType<LiveRoom>()) {
        pendingUpdates[_roomKey(updated)] = updated;
      }
      processedSinceCommit += batchRooms.length;
      if (pendingUpdates.isNotEmpty) {
        // Publish each completed request batch without serializing Hive. Users
        // see rooms transition online/offline during startup, while disk writes
        // and the full favourites JSON rebuild remain coalesced below.
        final preview = mergeFavoriteRoomUpdates(SettingsService.to.fav.favoriteRooms.v, pendingUpdates);
        if (preview.changed) _publishTransientRoomSnapshot(preview.rooms);
      }
      // Persist and rebuild progressively, but in chunks large enough to avoid
      // serializing the whole favourites list after every small request batch.
      final isLastBatch = end == valid.length;
      if (pendingUpdates.isNotEmpty && (processedSinceCommit >= commitThreshold || isLastBatch)) {
        _commitRoomUpdates(Map<String, LiveRoom>.of(pendingUpdates), refreshEpoch: refreshEpoch);
        pendingUpdates.clear();
        processedSinceCommit = 0;
      }
    }
  }

  void _commitRoomUpdates(Map<String, LiveRoom> updates, {required int refreshEpoch}) {
    if (refreshEpoch != _refreshEpoch || isClosed || updates.isEmpty) return;

    // Commit bounded chunks so rooms that went offline disappear progressively
    // during startup without rebuilding/persisting after every request batch.
    // Merge into the latest persisted list at commit time:
    // a favorite removed while requests were pending stays removed, and a new
    // room is never overwritten by the startup snapshot.
    final merged = mergeFavoriteRoomUpdates(SettingsService.to.fav.favoriteRooms.v, updates);
    if (merged.changed && refreshEpoch == _refreshEpoch && !isClosed) {
      SettingsService.to.fav.favoriteRooms.v = merged.rooms;
      applyLocalFilter();
    }
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
