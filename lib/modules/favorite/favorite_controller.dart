import 'dart:async';
import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:synchronized/synchronized.dart';
import 'package:pure_live/plugins/event_bus.dart';
import 'package:pure_live/modules/tags/live_tag.dart';
import 'package:pure_live/core/interface/live_site.dart';
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
  final List<Worker> _workers = [];
  bool _selectionTransaction = false;
  int? _lastSyncedFavoriteSnapshot;
  int _refreshEpoch = 0;
  final Lock _refreshLock = Lock();
  DateTime? _lastFullRefreshAt;
  final isVerifyingFavorites = false.obs;
  Future<void>? _startupRefresh;
  FavoriteVerificationPreview? _verificationPreview;
  final Map<String, DateTime> _refreshFailureCooldown = {};
  static const Duration _refreshFailureRetryAfter = Duration(minutes: 5);
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
    tagController.migrateLegacyRoomTagKeys(SettingsService.to.fav.favoriteRooms.v);

    _workers.add(
      debounce(SettingsService.to.fav.favoriteRooms, (_) {
        if (!isVerifyingFavorites.value && !_isCurrentFavoriteSnapshotSynced()) {
          applyLocalFilter();
        }
      }, time: const Duration(milliseconds: 1000)),
    );

    _workers.add(
      ever(selectedTagId, (_) {
        if (!_selectionTransaction) applyLocalFilter();
      }),
    );
    _workers.add(
      ever(tabSiteIndex, (_) {
        if (!_selectionTransaction) applyLocalFilter(resyncSource: false);
      }),
    );
    _workers.add(
      ever(tabOnlineIndex, (_) {
        if (!_selectionTransaction) applyLocalFilter(resyncSource: false);
      }),
    );
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
    selectStatusIndex(tabController.index);
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
    if (!refreshConfigController.refreshFavoriteOnResume.value) {
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
        () => unawaited(_fullRefreshRooms(showLoading: true, emitFinish: false, bypassFailureCooldown: true)),
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
      applyLocalFilter();
    });
  }

  /// Commits a settled platform page as one local filter transaction.
  ///
  /// The previous listener reset the tag and then changed the site in two Rx
  /// writes. Each write rebuilt and sorted the full favourites snapshot, so a
  /// single horizontal swipe could publish two different grids.
  void selectSiteIndex(int index) {
    final availableSites = Sites().availableSites(containsAll: true);
    if (index < 0 || index >= availableSites.length) return;
    final resetTag = selectedTagId.value != TagManagementController.allTagKey;
    if (tabSiteIndex.value == index && !resetTag) return;

    _selectionTransaction = true;
    tabSiteIndex.value = index;
    if (resetTag) selectedTagId.value = TagManagementController.allTagKey;
    _selectionTransaction = false;
    currentPage = 1;
    applyLocalFilter(resyncSource: false);
  }

  void selectStatusIndex(int index) {
    if (index < 0 || index >= tabController.length) return;
    final resetTag = selectedTagId.value != TagManagementController.allTagKey;
    if (tabOnlineIndex.value == index && !resetTag) return;

    _selectionTransaction = true;
    tabOnlineIndex.value = index;
    if (resetTag) selectedTagId.value = TagManagementController.allTagKey;
    _selectionTransaction = false;
    currentPage = 1;
    applyLocalFilter(resyncSource: false);
  }

  void animateToStatusIndex(int index) {
    if (index < 0 || index >= tabController.length) return;
    if (tabController.index == index) {
      selectStatusIndex(index);
      return;
    }
    tabController.animateTo(index, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic);
  }

  void changeSelectedTag(String tagId) {
    if (selectedTagId.value == tagId) return;
    currentPage = 1;
    selectedTagId.value = tagId;
  }

  void updateRoomTags(LiveRoom room, List<String> newTagIds) {
    tagController.setRoomTags(room, newTagIds);
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
      final siteId = activeSite.id.trim().toLowerCase();
      siteFiltered = source.where((room) {
        return room.normalizedPlatformId == siteId;
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

  List<LiveRoom> getFilteredRooms({Iterable<LiveRoom>? roomSnapshot, bool resyncSource = true}) {
    if (resyncSource) syncRooms(roomSnapshot: roomSnapshot);

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
      final normalizedSiteId = siteId.trim().toLowerCase();
      siteFiltered = source.where((room) {
        return room.normalizedPlatformId == normalizedSiteId;
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

  int favoriteCountForSite(String siteId, {int? statusIndex}) {
    final Iterable<LiveRoom> source = statusIndex == null
        ? SettingsService.to.fav.favoriteRooms.v
        : switch (statusIndex) {
            0 => onlineRooms,
            1 => replayRooms,
            2 => offlineRooms,
            _ => const <LiveRoom>[],
          };
    if (siteId == Sites.allSite) return source.length;
    final normalizedSite = siteId.trim().toLowerCase();
    return source.where((room) => room.platform?.trim().toLowerCase() == normalizedSite).length;
  }

  void syncRooms({Iterable<LiveRoom>? roomSnapshot}) {
    final preview = roomSnapshot == null ? _verificationPreview : null;
    final List<LiveRoom> roomsBase = List<LiveRoom>.from(
      roomSnapshot ?? preview?.rooms ?? SettingsService.to.fav.favoriteRooms.v,
    );
    _lastSyncedFavoriteSnapshot = _favoriteSnapshotSignature(roomsBase);
    final nextOnline = preview != null
        ? List<LiveRoom>.from(preview.onlineRooms)
        : roomsBase.where((r) => r.liveStatus == LiveStatus.live && r.isRecord == false).toList();
    final nextOffline = preview != null
        ? List<LiveRoom>.from(preview.offlineRooms)
        : roomsBase.where((r) => r.liveStatus != LiveStatus.live).toList();
    final nextReplay = preview != null
        ? List<LiveRoom>.from(preview.replayRooms)
        : roomsBase.where((r) => r.liveStatus == LiveStatus.live && r.isRecord == true).toList();

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
      final normalizedSiteId = activeSite.id.trim().toLowerCase();

      for (var room in target) {
        if (activeSite.id == Sites.allSite || room.normalizedPlatformId == normalizedSiteId) {
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

  bool _isCurrentFavoriteSnapshotSynced() {
    return _lastSyncedFavoriteSnapshot == _favoriteSnapshotSignature(SettingsService.to.fav.favoriteRooms.v);
  }

  int _favoriteSnapshotSignature(Iterable<LiveRoom> rooms) {
    return Object.hashAll(
      rooms.map(
        (room) => Object.hash(
          room.identityKey,
          room.liveStatus,
          room.isRecord,
          room.title,
          room.nick,
          room.avatar,
          room.cover,
          room.area,
          room.watching,
          room.popularity,
          room.onlineViewers,
          room.totalViewers,
          room.followers,
          Object.hashAll(room.tagIds),
        ),
      ),
    );
  }

  void _refreshVisibleTagsFromSyncedRooms() {
    final sites = Sites().availableSites(containsAll: true);
    if (tabSiteIndex.value < 0 || tabSiteIndex.value >= sites.length) {
      _assignIfSnapshotChanged(visibleTags, const <LiveTag>[]);
      return;
    }
    final source = switch (tabOnlineIndex.value) {
      0 => onlineRooms,
      1 => replayRooms,
      2 => offlineRooms,
      _ => onlineRooms,
    };
    final siteId = sites[tabSiteIndex.value].id;
    final tagIds = <String>{};
    for (final room in source) {
      if (siteId == Sites.allSite || room.normalizedPlatformId == siteId) {
        tagIds.addAll(tagController.getTagsForRoom(room));
      }
    }
    final next = tagController.tags.where((tag) => tagIds.contains(tag.id)).toList(growable: false)
      ..sort((left, right) => left.order.compareTo(right.order));
    _assignIfSnapshotChanged(visibleTags, next);
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

  void applyLocalFilter({bool resyncSource = true}) {
    if (!resyncSource) _refreshVisibleTagsFromSyncedRooms();
    final filtered = getFilteredRooms(resyncSource: resyncSource);
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
    await _fullRefreshFilterRooms(showLoading: true, bypassFailureCooldown: true);
  }

  Future<void> _fullRefreshFilterRooms({required bool showLoading, bool bypassFailureCooldown = false}) async {
    final roomsToRefresh = getFilteredRoomsIgnoringLiveStatus();
    await _runRoomRefresh(
      roomsToRefresh,
      showLoading: showLoading,
      invalidateUnverified: true,
      bypassFailureCooldown: bypassFailureCooldown,
    );
  }

  Future<void> _fullRefreshRooms({
    required bool showLoading,
    bool emitFinish = true,
    bool bypassFailureCooldown = false,
  }) async {
    final startup = _startupRefresh;
    if (startup != null) {
      // Cold-start verification already covers every favourite. Coalescing
      // lifecycle/timer events here prevents a second refresh from invalidating
      // the authoritative startup result halfway through its network pass.
      await startup;
      return;
    }
    final roomsToRefresh = getAllRooms();
    await _runRoomRefresh(
      roomsToRefresh,
      showLoading: showLoading,
      emitFinish: emitFinish,
      markFullRefresh: true,
      invalidateUnverified: true,
      bypassFailureCooldown: bypassFailureCooldown,
    );
  }

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
    final persisted = List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);
    _verificationPreview = buildFavoriteVerificationPreview(persisted);
    isVerifyingFavorites.value = true;
    if (persisted.isNotEmpty) {
      // Keep cached metadata and bucket positions, but publish every status as
      // unknown. This avoids both stale "live" claims and the clear/reorder/
      // reappear sequence that made launch feel visually unstable.
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
        bypassFailureCooldown: true,
      );
    } finally {
      _verificationPreview = null;
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
    bool bypassFailureCooldown = false,
  }) {
    // One refresh owns the snapshot transaction at a time. The former epoch
    // scheme cancelled whichever pass happened to finish second; a lifecycle
    // resume 450 ms after launch could therefore discard startup verification
    // and leave failed rooms with yesterday's live bit.
    return _refreshLock.synchronized(() async {
      if (isClosed) return;
      final refreshEpoch = _refreshEpoch;
      if (showLoading) loadding.value = true;
      try {
        final updates = await _refreshRoomDetails(
          rooms,
          refreshEpoch: refreshEpoch,
          bypassFailureCooldown: bypassFailureCooldown,
        );
        if (refreshEpoch != _refreshEpoch || isClosed) return;

        final latest = List<LiveRoom>.from(SettingsService.to.fav.favoriteRooms.v);
        final merged = invalidateUnverified
            ? mergeAuthoritativeFavoriteRefresh(latest, rooms.map(favoriteRoomIdentity), updates)
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
    });
  }

  Future<Map<String, LiveRoom>> _refreshRoomDetails(
    List<LiveRoom> rooms, {
    required int refreshEpoch,
    required bool bypassFailureCooldown,
  }) async {
    final valid = rooms
        .where((r) => (r.platform?.isNotEmpty ?? false) && (r.roomId?.isNotEmpty ?? false))
        .toList(growable: false);
    if (valid.isEmpty) return const <String, LiveRoom>{};

    final concurrency = RefreshConfigController.normalizeMaxConcurrentRefresh(
      refreshConfigController.maxConcurrentRefresh.value,
    );
    // Reuse one adapter per platform inside a refresh pass. Besides reducing
    // allocation, this lets cookie/device/bootstrap requests use single-flight
    // state while the bounded I/O workers refresh several cards concurrently.
    final siteCache = <String, LiveSite>{};
    final pendingUpdates = <String, LiveRoom>{};
    final results = await boundedAsyncMap<LiveRoom, ({String key, LiveRoom room})>(
      valid,
      maxConcurrent: concurrency,
      task: (room) async {
        final updated = await _refreshOneRoom(room, siteCache, bypassFailureCooldown: bypassFailureCooldown);
        if (updated == null) return null;
        // Match by the requested favourite identity, not a canonical id that a
        // platform may return (Douyin room ids, for example, can change to the
        // stable web rid). Keep the stored identity stable for tags and keys.
        return (key: _roomKey(room), room: bindFavoriteRefreshResultToRequest(room, updated));
      },
      shouldCancel: () => refreshEpoch != _refreshEpoch || isClosed,
    );
    if (refreshEpoch != _refreshEpoch || isClosed) return const <String, LiveRoom>{};
    for (final update in results.whereType<({String key, LiveRoom room})>()) {
      pendingUpdates[update.key] = update.room;
    }
    return pendingUpdates;
  }

  Future<LiveRoom?> _refreshOneRoom(
    LiveRoom room,
    Map<String, LiveSite> siteCache, {
    required bool bypassFailureCooldown,
  }) async {
    final key = _roomKey(room);
    final failedAt = _refreshFailureCooldown[key];
    if (!bypassFailureCooldown && failedAt != null && DateTime.now().difference(failedAt) < _refreshFailureRetryAfter) {
      return null;
    }

    try {
      final platform = room.normalizedPlatformId;
      final roomId = room.normalizedRoomId;
      final liveSite = siteCache.putIfAbsent(platform, () => Sites.of(platform).liveSite);
      final operation = liveSite is LiveSiteRoomRefresher
          ? (liveSite as LiveSiteRoomRefresher).getRoomDetailForRefresh(roomId: roomId, platform: platform)
          : liveSite.getRoomDetail(roomId: roomId, platform: platform);
      final result = await operation.timeout(_roomRefreshTimeout);
      _refreshFailureCooldown.remove(key);
      return result;
    } catch (error, stackTrace) {
      final key = _roomKey(room);
      _refreshFailureCooldown[key] = DateTime.now();

      if (error is FormatException && error.message == 'Huya room metadata is unavailable') {
        developer.log('Favorite room unavailable: $key', name: 'FavoriteController');
      } else {
        developer.log(
          'Favorite room refresh failed: $key',
          name: 'FavoriteController',
          error: error,
          stackTrace: stackTrace,
        );
      }

      return null;
    }
  }

  String _roomKey(LiveRoom room) => favoriteRoomIdentity(room);
}
