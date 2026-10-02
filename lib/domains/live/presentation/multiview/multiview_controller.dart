import 'dart:async';
import 'dart:developer' as developer;

import 'package:pure_live/core/index.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/shared/platforms/live_site.dart';
import 'package:pure_live/shared/platforms/live_danmaku.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/domains/live/data/stream/flv_splice_relay.dart';
import 'package:media_core/media_core.dart' as mc;
import 'package:media_core_media_kit/media_core_media_kit.dart';
import 'package:media_core_multiview/media_core_multiview.dart' as wall;
import 'package:pure_live/shared/platforms/live_quality_discovery.dart';
import 'package:pure_live/domains/live/domain/live_input_playback_binder.dart';
import 'package:pure_live/core/player/kernel/player_kernel_service.dart';
import 'package:pure_live/domains/live/presentation/multiview/models/multiview_models.dart';
import 'package:pure_live/domains/live/presentation/playback/controllers/player_controller.dart';
import 'package:pure_live/domains/live/presentation/multiview/danmaku/multiview_danmaku_session.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';

/// 房间对象 → 可播放源解析器。
///
/// 复用站点适配器既有入口（getRoomDetail/getPlayQualites/getPlayUrls），
/// 禁止在 multiview 内复制解析逻辑；测试注入假实现。
/// [preferLowest] 为小格自动降质联动服务：true 时默认取最低档（列表末项）。
typedef MultiviewStreamResolver = Future<MultiviewStreamSource> Function(
  LiveRoom liveroom, {
  required bool preferLowest,
});

/// 进入 multiview 时暂停全局播放器的钩子。
typedef MultiviewGlobalPauseHook = Future<void> Function();

/// Loads and saves the per-room volume used by multiview.
typedef MultiviewRoomVolumeLoader = double Function(LiveRoom liveroom);
typedef MultiviewRoomVolumeSaver = Future<void> Function(LiveRoom liveroom, double volume);

/// 多画面同看控制器。
///
/// 播放编排归 media_core 的 MultiviewController（墙）：每格播放器、
/// 卡顿看门狗、重启预算、解码预算、音频互斥都在墙上。pure_live 保留
/// 业务编排：站点解析、逐格画质/线路切换、签名 URL 租约续期闭包、
/// 房间音量记忆、页级弹幕会话。
///
/// owned 私有协议源以 custom-input recipe 进墙，由 kernel 的
/// customInputOpener 获取回环租约后打开。
class MultiviewController extends GetxController {
  MultiviewController({
    this._streamResolver,
    Site Function(String)? siteFor,
    MultiviewGlobalPauseHook? pauseGlobalPlayback,
    MultiviewDanmakuEngineFactory? danmakuEngineFactory,
    MultiviewRoomVolumeLoader? roomVolumeLoader,
    MultiviewRoomVolumeSaver? roomVolumeSaver,
    int? maxCellCount,
    this.frameStallTimeout = const Duration(seconds: 10),
    bool Function()? isFramePresentationVisible,
    this.frameWatchdogElapsed,
  }) : _siteFor = siteFor ?? Sites.of,
       _pauseGlobalPlayback = pauseGlobalPlayback ?? _defaultPauseGlobalPlayback,
       _danmakuEngineFactory = danmakuEngineFactory ?? _defaultDanmakuEngineFactory,
       _roomVolumeLoader = roomVolumeLoader ?? _defaultRoomVolumeLoader,
       _roomVolumeSaver = roomVolumeSaver ?? _defaultRoomVolumeSaver,
       maxCellCount = maxCellCount ?? (PlatformUtils.isDesktop ? maxCells : MultiviewLayout.focus.capacity) {
    if (this.maxCellCount < MultiviewLayout.focus.capacity || this.maxCellCount > maxCells) {
      throw ArgumentError.value(this.maxCellCount, 'maxCellCount', 'must be between 4 and $maxCells');
    }
  }

  /// focus 布局的桌面端格子数上限。
  static const int maxCells = 9;

  final int maxCellCount;
  final Duration frameStallTimeout;
  final Duration Function()? frameWatchdogElapsed;

  Future<MultiviewStreamSource> _defaultStreamResolver(
    LiveRoom liveroom, {
    required bool preferLowest,
    required LiveQualityDiscoveryScope discoveryScope,
  }) => resolveStreamForSite(
    liveroom,
    site: _siteFor(liveroom.platform!),
    preferLowest: preferLowest,
    discoveryScope: discoveryScope,
  );

  @visibleForTesting
  static Future<MultiviewStreamSource> resolveStreamForSite(
    LiveRoom liveroom, {
    required Site site,
    required bool preferLowest,
    LiveInputPlaybackBinder bindOwnedInput = bindLiveInputForPlayback,
    LiveQualityDiscoveryScope? discoveryScope,
  }) async {
    discoveryScope?.checkActive();
    final platform = liveroom.platform!;
    final liveSite = site.liveSite;
    final detail = liveSite is LiveSiteRecordRoomResolver
        ? await (liveSite as LiveSiteRecordRoomResolver).getRoomDetailForRecording(liveroom)
        : await liveSite.getRoomDetail(liveroom);
    discoveryScope?.checkActive();
    if (detail.isExplicitlyOfflineNow) {
      throw MultiviewRoomOffline(detail);
    }
    if (!detail.isPlayableNow) {
      throw StateError('multiview: room status is ${detail.effectiveLiveStatus.name} for $platform/${liveroom.roomId}');
    }
    final qualities = discoveryScope == null
        ? await liveSite.discoverPlayQualities(liveroom: detail)
        : await discoveryScope.discover(liveSite, detail);
    if (qualities.isEmpty) {
      throw StateError('multiview: no play qualities for $platform/${liveroom.roomId}');
    }

    final qualityIndex = preferLowest ? qualities.length - 1 : 0;
    Future<MultiviewStreamSource> loadQuality(LivePlayQuality quality) async {
      final resolution = await site.liveSite.resolvePlayUrls(liveroom: detail, quality: quality);
      final nextUrls = resolution.urls;
      if (!resolution.hasSources) {
        throw StateError('multiview: no play urls for $platform/${liveroom.roomId} @ ${quality.quality}');
      }
      final applied = resolveAppliedPlayQuality(qualities: qualities, requested: quality, resolution: resolution);
      final choices = List<LivePlayQuality>.unmodifiable([
        for (final choice in qualities)
          choice.selectionId == applied.selectionId ? applied : choice.withPlaybackUnconfirmed(false),
      ]);
      final appliedIndex = choices.indexWhere((choice) => choice.selectionId == applied.selectionId);
      final recipe = resolution.inputRecipe;
      if (recipe != null) {
        return MultiviewStreamSource.owned(
          source: bindOwnedInput(recipe),
          qualities: choices,
          qualityIndex: appliedIndex < 0 ? qualityIndex : appliedIndex,
        );
      }
      final headers = await PlayerController.resolvePlaybackHeaders(site: site, liveroom: detail);
      return MultiviewStreamSource(
        url: nextUrls.first,
        headers: Map.unmodifiable(headers),
        lines: List.unmodifiable(nextUrls),
        qualities: choices,
        qualityIndex: appliedIndex < 0 ? qualityIndex : appliedIndex,
        leaseFor: _leaseLookup(site, detail, applied, nextUrls),
        sourceQueryPolicies: resolution.sourceQueryPolicies,
      );
    }

    discoveryScope?.checkActive();
    final initial = await loadQuality(qualities[qualityIndex]);
    discoveryScope?.checkActive();
    final owned = initial.ownedSource;
    if (owned != null) {
      return MultiviewStreamSource.owned(
        source: owned,
        qualities: initial.qualities,
        qualityIndex: initial.qualityIndex,
        qualityLoader: loadQuality,
      );
    }
    return MultiviewStreamSource(
      url: initial.url,
      headers: initial.headers,
      qualities: initial.qualities,
      qualityIndex: initial.qualityIndex,
      qualityLoader: loadQuality,
      lines: initial.lines,
      sourceQueryPolicies: initial.sourceQueryPolicies,
    );
  }

  static MultiviewLeaseLookup? _leaseLookup(Site site, LiveRoom liveroom, LivePlayQuality quality, List<String> lines) {
    final liveSite = site.liveSite;
    if (liveSite is! LivePlayLeaseMetadata) return null;
    final metadata = liveSite as LivePlayLeaseMetadata;
    return (url) {
      final refreshAt = metadata.getPlayUrlRefreshAt(url);
      if (!FlvSpliceRelay.appliesTo(url, refreshAt: refreshAt)) return null;
      final lineIndex = lines.indexOf(url);
      return MultiviewSourceLease(
        refreshAt: refreshAt!,
        renew: (current) async {
          final resolution = await liveSite.resolvePlayUrls(liveroom: liveroom, quality: quality);
          final urls = resolution.urls;
          if (urls.isEmpty) throw StateError('multiview: no renewed url for ${liveroom.platform}/${liveroom.roomId}');
          final next = urls[(lineIndex < 0 ? 0 : lineIndex).clamp(0, urls.length - 1)];
          return FlvLeasedSource(Uri.parse(next), refreshAt: metadata.getPlayUrlRefreshAt(next));
        },
      );
    };
  }

  static LiveDanmaku _defaultDanmakuEngineFactory(LiveRoom liveroom) {
    return Sites.of(liveroom.platform!).liveSite.getDanmaku();
  }

  static double _defaultRoomVolumeLoader(LiveRoom liveroom) => liveroom.getSavedVolume();

  static Future<void> _defaultRoomVolumeSaver(LiveRoom liveroom, double volume) {
    return liveroom.saveCurrentVolume(volume);
  }

  static Future<void> _defaultPauseGlobalPlayback() async {
    final service = GlobalPlayerService.instance;
    if (!service.initialized) return;
    final manager = service.player;
    if (manager.isAppFloatingActive) {
      await manager.closeAppFloating();
      return;
    }
    if (manager.isPlayingNow) {
      await manager.pause();
    }
  }

  /// 当前布局；初始为四画面。
  final Rx<MultiviewLayout> layout = MultiviewLayout.quad.obs;

  /// focus 布局下当前大画面格下标。
  final RxInt focusedCellIndex = 0.obs;

  /// 单格状态列表，长度恒等于 [layout] 容量。
  final RxList<MultiviewCellState> cells = RxList<MultiviewCellState>(
    List.generate(MultiviewLayout.quad.capacity, MultiviewCellState.empty),
  );

  /// 每格播放状态（供 UI 播放/暂停按钮态）。
  final RxList<bool> playingFlags = RxList<bool>(
    List.generate(MultiviewLayout.quad.capacity, (_) => false, growable: true),
  );

  void setVisibleFocusSmallCells(Iterable<int> indices) {}

  final RxInt _audioFocusIndex = 0.obs;
  final RxBool allMuted = false.obs;
  final RxBool smallCellsLowQuality = false.obs;

  /// 页级弹幕开关。
  ///
  /// 不再自持「默认关闭」：普通直播间默认就显示弹幕（全局 `hideDanmaku` 默认关），
  /// 多画面此前默认关，于是同一个应用里两种播放形态的默认行为分裂——多画面
  /// 进来永远没有弹幕。这里与全局设置双向同步（见 [onInit]），开关语义、
  /// 持久化与普通直播间一致。
  final RxBool danmakuEnabled = false.obs;
  final BarrageController barrageController = BarrageController();

  final MultiviewStreamResolver? _streamResolver;
  final Site Function(String) _siteFor;
  final Map<int, LiveQualityDiscoveryScope> _discoveryScopes = {};
  final Set<Future<void>> _retiringDiscoveries = {};
  bool _closed = false;

  void _retireDiscovery(LiveQualityDiscoveryScope scope) {
    late final Future<void> pending;
    pending = scope.close().whenComplete(() => _retiringDiscoveries.remove(pending));
    _retiringDiscoveries.add(pending);
  }

  void _cancelDiscovery(int cellIndex) {
    final scope = _discoveryScopes.remove(cellIndex);
    if (scope != null) _retireDiscovery(scope);
  }

  final MultiviewGlobalPauseHook _pauseGlobalPlayback;
  final MultiviewDanmakuEngineFactory _danmakuEngineFactory;
  final MultiviewRoomVolumeLoader _roomVolumeLoader;
  final MultiviewRoomVolumeSaver _roomVolumeSaver;

  late final MultiviewDanmakuSession _danmakuSession = MultiviewDanmakuSession(
    engineFactory: _danmakuEngineFactory,
    onChatMessage: _forwardChatMessage,
  );

  final List<Worker> _rxWorkers = <Worker>[];

  /// 每格墙路径的解析上下文（画质表/换档闭包/线路/租约）。
  final Map<int, MultiviewStreamSource> _sourceContexts = {};

  /// 弹幕就绪房间缓存：房间身份键 → 带弹幕连接票据的房间。
  ///
  /// 选台面板只提供本地关注/历史里的房间快照，而 `LiveRoom.toJson` 有意不持久化
  /// `danmakuData`（弹幕票据是短时效凭据，见 [LiveRoom.toJson]）。于是重启后多画面
  /// 拿到的房间必然没有弹幕参数，[MultiviewDanmakuSession.supportsRoom] 直接为假——
  /// 弹幕永远连不上。这里在真正要连弹幕时按普通直播间的同一入口
  /// （`LiveSite.getRoomDetail`，它会带回弹幕票据）补一次，并按房间缓存。
  final Map<String, LiveRoom> _danmakuRooms = {};

  /// 进行中的弹幕房间补取，同一房间并发只发一次请求。
  final Map<String, Future<LiveRoom>> _danmakuRoomLoads = {};

  /// 弹幕房间缓存上限；超出后整片丢弃重建，避免长时间多画面巡台无界增长。
  static const int _danmakuRoomCacheLimit = 16;

  /// 弹幕会话同步代次：焦点/布局/开关连续变化时丢弃迟到的旧房间连接。
  int _danmakuSyncEpoch = 0;

  /// 当前聊天房间键；用于在换房间时清掉上一路的弹幕。
  String? _danmakuRoomKey;

  /// 每格会话音量镜像（房间音量记忆）。
  final Map<int, double> _volumes = {};

  wall.MultiviewController? _wall;
  StreamSubscription<wall.MultiviewSnapshot>? _wallSub;

  wall.MultiviewController get _wallController {
    final existing = _wall;
    if (existing != null) return existing;
    final host = mc.KernelPoolPlayerHost(PlayerKernelService.instance.kernel);
    final controller = wall.MultiviewController(
      players: host,
      config: wall.MultiviewConfig.defaults.copyWith(layout: _wallLayout(layout.value), maxCells: maxCellCount),
    );
    _wall = controller;
    _wallSub = controller.onChanged.listen((_) => _syncFromWall());
    return controller;
  }

  static wall.MultiviewLayout _wallLayout(MultiviewLayout value) => switch (value) {
    MultiviewLayout.single => wall.MultiviewLayout.single,
    MultiviewLayout.dual => wall.MultiviewLayout.dual,
    MultiviewLayout.quad => wall.MultiviewLayout.quad,
    // pure focus 容量为动态 4..maxCells；墙 nine 容量 9 与上限一致，
    // 一大多小的呈现由页面自持，墙只负责格播放与音频互斥。
    MultiviewLayout.focus => wall.MultiviewLayout.nine,
  };

  int get _selectedCellIndex {
    if (cells.isEmpty) return 0;
    final selected = layout.value == MultiviewLayout.focus ? focusedCellIndex.value : _audioFocusIndex.value;
    return selected.clamp(0, cells.length - 1);
  }

  int get audioFocusIndex => _audioFocusIndex.value;

  RxInt get audioFocusIndexState => _audioFocusIndex;

  /// 暴露墙内指定格的 playerId（Windows 视口重设需要定位 kernel 播放器）。
  wall.MultiviewCell? wallCellAt(int index) {
    final controller = _wall;
    if (controller == null || index >= controller.cells.length) return null;
    return controller.cells[index];
  }

  bool get canAddCell => layout.value == MultiviewLayout.focus && cells.length < maxCellCount;

  @override
  void onInit() {
    super.onInit();
    unawaited(
      _pauseGlobalPlayback().catchError((Object error, StackTrace stackTrace) {
        developer.log(
          'MultiviewController: pause global playback failed',
          name: 'MultiviewController',
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
    _rxWorkers.add(
      everAll([danmakuEnabled, layout, focusedCellIndex, _audioFocusIndex], (_) => unawaited(_syncDanmakuSession())),
    );
    _rxWorkers.add(ever(smallCellsLowQuality, (_) => unawaited(_reconcileSmallCellQualities())));
    // 弹幕开关与普通直播间共用全局设置：默认跟随 `hideDanmaku`（默认关 = 显示），
    // 两处开关互相写回，多画面不再有自己的一套默认值。
    danmakuEnabled.value = !SettingsService.to.danmaku.hideDanmaku.v;
    _rxWorkers.add(ever(danmakuEnabled, (enabled) => SettingsService.to.danmaku.hideDanmaku.value = !enabled));
    _rxWorkers.add(
      ever(SettingsService.to.danmaku.hideDanmaku, (hidden) {
        if (danmakuEnabled.value == hidden) danmakuEnabled.value = !hidden;
      }),
    );
  }

  Future<void> _reconcileSmallCellQualities() async {
    if (layout.value != MultiviewLayout.focus) return;
    for (var i = 0; i < cells.length; i++) {
      if (i == focusedCellIndex.value) continue;
      final cell = cells[i];
      if (cell.status != MultiviewCellStatus.playing || cell.qualities.isEmpty) continue;
      final targetIndex = smallCellsLowQuality.value ? cell.qualities.length - 1 : 0;
      if (cell.qualityIndex == targetIndex) continue;
      await setCellQuality(i, targetIndex);
    }
  }

  void _forwardChatMessage(LiveMessage message) {
    barrageController.send(
      BarrageItem(
        content: message.message,
        userId: message.userId,
        userName: message.userName,
        textColor: Color.fromARGB(255, message.color.r, message.color.g, message.color.b),
      ),
    );
  }

  Future<void> _syncDanmakuSession() async {
    final token = ++_danmakuSyncEpoch;
    try {
      final room = danmakuEnabled.value && cells.isNotEmpty ? cells[_selectedCellIndex].room : null;
      final platform = room?.platform;
      if (room == null || platform == null || !MultiviewDanmakuSession.isSupportedPlatform(platform)) {
        _retargetDanmakuLayer(null);
        await _danmakuSession.disconnect();
        return;
      }
      final ready = await _danmakuReadyRoom(room);
      // 焦点/布局/开关可能在等待期间又变过；迟到的旧房间不得把弹幕拉回去。
      if (token != _danmakuSyncEpoch) return;
      if (!MultiviewDanmakuSession.supportsRoom(ready)) {
        _retargetDanmakuLayer(null);
        await _danmakuSession.disconnect();
        return;
      }
      _retargetDanmakuLayer(ready.identityKey);
      await _danmakuSession.connect(ready);
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: danmaku session sync failed',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 换聊天房间时清掉上一路弹幕：否则上一个直播间的消息会继续在新房间画面上滚动。
  void _retargetDanmakuLayer(String? key) {
    if (_danmakuRoomKey == key) return;
    _danmakuRoomKey = key;
    barrageController.clear();
  }

  /// 取回带着弹幕连接票据的房间；已有票据时原样返回。
  ///
  /// 与普通直播间走同一个入口（`getRoomDetail`），不另建解析逻辑；失败时退回
  /// 原房间，弹幕不可用不得影响播放主链路。
  Future<LiveRoom> _danmakuReadyRoom(LiveRoom room) {
    if (MultiviewDanmakuSession.supportsRoom(room)) return Future<LiveRoom>.value(room);
    final platform = room.platform;
    if (platform == null || !MultiviewDanmakuSession.isSupportedPlatform(platform)) {
      return Future<LiveRoom>.value(room);
    }
    final key = room.identityKey;
    final cached = _danmakuRooms[key];
    if (cached != null) return Future<LiveRoom>.value(cached);
    final pending = _danmakuRoomLoads[key];
    if (pending != null) return pending;
    final future = _loadDanmakuRoom(room, platform, key);
    _danmakuRoomLoads[key] = future;
    return future;
  }

  Future<LiveRoom> _loadDanmakuRoom(LiveRoom room, String platform, String key) async {
    try {
      final detail = await _siteFor(platform).liveSite.getRoomDetail(room);
      if (MultiviewDanmakuSession.supportsRoom(detail)) {
        if (_danmakuRooms.length >= _danmakuRoomCacheLimit) _danmakuRooms.clear();
        _danmakuRooms[key] = detail;
        return detail;
      }
      return room;
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: danmaku room detail failed for $key',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
      return room;
    } finally {
      _danmakuRoomLoads.remove(key);
    }
  }

  // ---------------------------------------------------------------------------
  // 墙状态镜像
  // ---------------------------------------------------------------------------

  void _syncFromWall() {
    final controller = _wall;
    if (controller == null || _closed) return;
    final snapshot = controller.snapshot;
    for (final wallCell in snapshot.cells) {
      final index = wallCell.index;
      if (index >= cells.length) continue;
      final status = _pureStatus(wallCell);
      var playing = wallCell.isPlaying;
      switch (status) {
        case MultiviewCellStatus.playing:
          _updateCell(
            index,
            cells[index].copyWith(status: status, clearError: true, videoController: _wallVideo(index)),
          );
        case MultiviewCellStatus.resolving:
          if (cells[index].status == MultiviewCellStatus.empty) continue;
          _updateCell(index, cells[index].copyWith(status: status));
        case MultiviewCellStatus.error:
          final failure = wallCell.failure;
          _updateCell(
            index,
            cells[index].copyWith(
              status: status,
              errorKind: failure == null || failure.kind == wall.MultiviewCellFailureKind.resolveFailure
                  ? MultiviewCellErrorKind.resolveFailure
                  : MultiviewCellErrorKind.startFailure,
              errorDetail: failure?.message,
            ),
          );
        case MultiviewCellStatus.offline:
          _updateCell(index, cells[index].copyWith(status: status));
        case MultiviewCellStatus.empty:
          if (cells[index].status == MultiviewCellStatus.empty) continue;
          _updateCell(index, MultiviewCellState.empty(index)..copyWith(room: cells[index].room));
      }
      if (index < playingFlags.length && playingFlags[index] != playing) {
        playingFlags[index] = playing;
      }
    }
  }

  static MultiviewCellStatus _pureStatus(wall.MultiviewCell wallCell) => switch (wallCell.status) {
    wall.MultiviewCellStatus.empty => MultiviewCellStatus.empty,
    wall.MultiviewCellStatus.starting => MultiviewCellStatus.resolving,
    wall.MultiviewCellStatus.playing => MultiviewCellStatus.playing,
    wall.MultiviewCellStatus.paused => MultiviewCellStatus.playing,
    wall.MultiviewCellStatus.offline => MultiviewCellStatus.offline,
    wall.MultiviewCellStatus.recovering => MultiviewCellStatus.resolving,
    wall.MultiviewCellStatus.failed => MultiviewCellStatus.error,
  };

  VideoController? _wallVideo(int index) {
    final controller = _wall;
    if (controller == null) return null;
    if (index >= controller.cells.length) return null;
    final playerId = controller.cells[index].playerId;
    if (playerId == null) return null;
    final handle = PlayerKernelService.instance.kernel.get(mc.PlayerId(playerId));
    if (handle == null || handle.disposed) return null;
    final adapter = handle.adapter;
    return adapter is MediaKitPlayerAdapter ? adapter.videoController : null;
  }

  // ---------------------------------------------------------------------------
  // 布局与格子管理
  // ---------------------------------------------------------------------------

  Future<void> setLayout(MultiviewLayout newLayout) async {
    if (newLayout == layout.value) return;
    final capacity = newLayout.capacity;
    final controller = _wall;

    for (var i = capacity; i < cells.length; i++) {
      _cancelDiscovery(i);
      _sourceContexts.remove(i);
      _volumes.remove(i);
      await controller?.clear(i);
    }

    while (cells.length > capacity) {
      playingFlags.removeLast();
      cells.removeLast();
    }
    while (cells.length < capacity) {
      cells.add(MultiviewCellState.empty(cells.length));
      playingFlags.add(false);
    }

    _visibleRelayout(controller, newLayout);
    layout.value = newLayout;

    if (newLayout == MultiviewLayout.focus) {
      focusedCellIndex.value = _audioFocusIndex.value;
    }
    if (focusedCellIndex.value >= capacity) {
      focusedCellIndex.value = capacity - 1;
    }
    if (_audioFocusIndex.value >= capacity) {
      _refocusToFirstPlaying(fallback: 0);
    }
    unawaited(_syncDanmakuSession());
  }

  Future<void> _visibleRelayout(wall.MultiviewController? controller, MultiviewLayout newLayout) async {
    if (controller == null) return;
    final mapped = _wallLayout(newLayout);
    if (controller.config.layout == mapped) return;
    await controller.updateConfig(
      controller.config.copyWith(
        layout: mapped,
        maxCells: newLayout == MultiviewLayout.focus ? maxCellCount : mapped.capacity,
      ),
    );
  }

  Future<void> addCell() async {
    if (layout.value != MultiviewLayout.focus) {
      throw StateError('multiview: addCell is only available in focus layout');
    }
    if (!canAddCell) {
      throw StateError('multiview: cell limit reached ($maxCellCount)');
    }
    cells.add(MultiviewCellState.empty(cells.length));
    playingFlags.add(false);
  }

  Future<void> promoteCell(int cellIndex) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final previousFocused = focusedCellIndex.value;
    focusedCellIndex.value = cellIndex;
    await setAudioFocus(cellIndex);
    await _wall?.setVideoFocus(cellIndex);

    if (!smallCellsLowQuality.value || layout.value != MultiviewLayout.focus) return;
    final promoted = cells[cellIndex];
    if (promoted.qualities.isNotEmpty && promoted.qualityIndex != 0) {
      await setCellQuality(cellIndex, 0);
    }
    if (previousFocused == cellIndex || previousFocused < 0 || previousFocused >= cells.length) return;
    final demoted = cells[previousFocused];
    if (demoted.qualities.isNotEmpty && demoted.qualityIndex != demoted.qualities.length - 1) {
      await setCellQuality(previousFocused, demoted.qualities.length - 1);
    }
  }

  void removeCell(int cellIndex) {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    _cancelDiscovery(cellIndex);
    _sourceContexts.remove(cellIndex);
    _volumes.remove(cellIndex);
    if (_audioFocusIndex.value == cellIndex) {
      _refocusToFirstPlaying(fallback: cellIndex);
    }
    if (focusedCellIndex.value == cellIndex) {
      focusedCellIndex.value = _findPlayingCell() ?? 0;
    }
    _updateCell(cellIndex, MultiviewCellState.empty(cellIndex));
    unawaited(_wall?.clear(cellIndex));
    unawaited(_syncDanmakuSession());
  }

  int? _findPlayingCell() {
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].status == MultiviewCellStatus.playing) return i;
    }
    return null;
  }

  /// 释放全部格子并回到空墙；对已清空的格幂等。
  Future<void> disposeAll() async {
    if (_closed || isClosed) return;
    for (var i = 0; i < cells.length; i++) {
      _cancelDiscovery(i);
      _sourceContexts.remove(i);
      _volumes.remove(i);
      if (i < playingFlags.length) playingFlags[i] = false;
      _updateCell(i, MultiviewCellState.empty(i));
    }
    await _wall?.clearAll();
    _audioFocusIndex.value = 0;
    focusedCellIndex.value = 0;
    unawaited(_syncDanmakuSession());
  }

  void _refocusToFirstPlaying({required int fallback}) {
    final playing = _findPlayingCell();
    if (playing != null) {
      _audioFocusIndex.value = playing;
      unawaited(_wallController.setAudioFocus(playing));
    } else if (_audioFocusIndex.value >= cells.length) {
      _audioFocusIndex.value = fallback.clamp(0, cells.isEmpty ? 0 : cells.length - 1);
    }
  }

  // ---------------------------------------------------------------------------
  // 分配
  // ---------------------------------------------------------------------------

  Future<void> assignRoom(int cellIndex, LiveRoom liveroom, {bool fromFrameRecovery = false}) async {
    if (_closed || isClosed) return;
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final targetRoom = liveroom.normalizedIdentityCopy();
    if (targetRoom.normalizedPlatformId.isEmpty || !Sites.isSupported(targetRoom.normalizedPlatformId)) {
      throw ArgumentError.value(liveroom.platform, 'room.platform', 'Unsupported live platform');
    }
    if (targetRoom.normalizedRoomId.isEmpty) {
      throw ArgumentError.value(liveroom.roomId, 'room.roomId', 'Room id is required');
    }

    _cancelDiscovery(cellIndex);
    await _teardownSlot(cellIndex);

    _updateCell(
      cellIndex,
      cells[cellIndex].copyWith(
        room: targetRoom,
        status: MultiviewCellStatus.resolving,
        clearError: true,
        clearVideoController: true,
        clearQuality: true,
      ),
    );

    if (targetRoom.isExplicitlyOfflineNow) {
      _updateCell(cellIndex, cells[cellIndex].copyWith(status: MultiviewCellStatus.offline));
      return;
    }

    final preferLowest =
        smallCellsLowQuality.value && layout.value == MultiviewLayout.focus && cellIndex != focusedCellIndex.value;

    final MultiviewStreamSource source;
    final scope = LiveQualityDiscoveryScope();
    _discoveryScopes[cellIndex] = scope;
    try {
      source = _streamResolver != null
          ? await _streamResolver(targetRoom, preferLowest: preferLowest)
          : await _defaultStreamResolver(targetRoom, preferLowest: preferLowest, discoveryScope: scope);
    } on MultiviewRoomOffline catch (offline) {
      _updateCell(
        cellIndex,
        cells[cellIndex].copyWith(
          room: offline.room.fillFromDetail(targetRoom),
          status: MultiviewCellStatus.offline,
          clearVideoController: true,
          clearQuality: true,
        ),
      );
      return;
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: resolve stream failed for ${targetRoom.platform}/${targetRoom.roomId}',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
      _failCell(cellIndex, MultiviewCellErrorKind.resolveFailure, error.toString());
      return;
    } finally {
      if (identical(_discoveryScopes[cellIndex], scope)) _discoveryScopes.remove(cellIndex);
      await scope.close();
    }
    if (_closed || isClosed) return;

    await _assignWallCell(cellIndex, targetRoom, source);
  }

  Future<void> _assignWallCell(int cellIndex, LiveRoom targetRoom, MultiviewStreamSource source) async {
    _sourceContexts[cellIndex] = source;
    final roomVolume = _roomVolumeLoader(targetRoom).clamp(0.0, 1.0);
    _volumes[cellIndex] = roomVolume;
    try {
      await _wallController.assign(cellIndex, _wallSource(cellIndex, source));
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: start playback failed for ${targetRoom.platform}/${targetRoom.roomId}',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
      _sourceContexts.remove(cellIndex);
      _failCell(cellIndex, MultiviewCellErrorKind.startFailure, error.toString());
      return;
    }
    if (_closed || isClosed) return;

    try {
      await _wallController.setCellVolume(cellIndex, roomVolume);
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: restore room volume failed',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
    }

    final shouldTakeAudioFocus = layout.value != MultiviewLayout.focus || cellIndex == focusedCellIndex.value;
    if (shouldTakeAudioFocus) {
      await setAudioFocus(cellIndex);
    }
    unawaited(_syncDanmakuSession());
  }

  /// 墙路径源：URL/请求头/租约到期与续期闭包全部由 pure_live 业务供给。
  /// owned 私有协议源走 custom-input recipe（createInput 闭包即 recipe），
  /// 由 kernel 的 customInputOpener 获取回环租约并绕过代理打开。
  wall.MultiviewCellSource _wallSource(int cellIndex, MultiviewStreamSource source) {
    final owned = source.ownedSource;
    final lease = owned == null ? source.leaseFor?.call(source.url) : null;
    final room = cells[cellIndex].room;
    final uri = owned == null ? Uri.parse(source.url) : Uri(scheme: 'owned', path: owned.identity);
    final metadata = owned == null
        ? const <String, Object?>{}
        : <String, Object?>{kMediaKitCustomInputKey: owned.createInput};
    return wall.MultiviewCellSource(
      source: mc.PlayerSource(
        id: mc.SourceId('multiview-$cellIndex-${owned?.identity ?? source.url.hashCode}'),
        uri: uri,
        type: mc.SourceType.live,
        protocol: owned == null ? mc.SourceProtocol.unknown : mc.SourceProtocol.custom,
        headers: mc.SourceHeaders(source.headers),
        title: room?.title,
        metadata: metadata,
      ),
      roomId: room?.identityKey,
      qualityLabel: source.qualities.isEmpty ? null : source.qualities[source.qualityIndex].quality,
      expiresAt: lease?.refreshAt,
      renew: owned == null ? _renewWallSource(cellIndex) : null,
    );
  }

  wall.MultiviewSourceRenew _renewWallSource(int cellIndex) {
    return (current) async {
      final context = _sourceContexts[cellIndex];
      if (context == null) return null;
      final loader = context.qualityLoader;
      if (loader == null) return null;
      final quality = context.qualities.isEmpty ? null : context.qualities[context.qualityIndex];
      if (quality == null) return null;
      final next = await loader(quality);
      if (next.ownedSource != null) return null;
      _sourceContexts[cellIndex] = next;
      final fresh = _wallSource(cellIndex, next);
      _updateCell(
        cellIndex,
        cells[cellIndex].copyWith(
          qualities: next.qualities.isEmpty ? null : next.qualities,
          qualityIndex: next.qualityIndex,
          headers: next.headers,
          lines: next.lines,
          sourceQueryPolicies: next.sourceQueryPolicies,
        ),
      );
      return fresh;
    };
  }

  // ---------------------------------------------------------------------------
  // 换画质/线路、播放控制、音量
  // ---------------------------------------------------------------------------

  Future<void> setCellQuality(int cellIndex, int qualityIndex) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final state = cells[cellIndex];
    if (state.qualities.isEmpty) {
      throw StateError('multiview: cell $cellIndex has no quality list');
    }
    if (qualityIndex < 0 || qualityIndex >= state.qualities.length) {
      throw RangeError.range(qualityIndex, 0, state.qualities.length - 1, 'qualityIndex');
    }
    if (qualityIndex == state.qualityIndex) return;

    final context = _sourceContexts[cellIndex];
    final loader = context?.qualityLoader ?? state.qualityLoader;
    if (loader == null) {
      throw StateError('multiview: cell $cellIndex has no quality loader');
    }
    final next = await loader(state.qualities[qualityIndex]);
    _sourceContexts[cellIndex] = next;
    await _wallController.assign(cellIndex, _wallSource(cellIndex, next));
    _updateCell(
      cellIndex,
      cells[cellIndex].copyWith(
        qualities: next.qualities.isEmpty ? null : next.qualities,
        qualityIndex: next.qualities.isEmpty ? qualityIndex : next.qualityIndex,
        headers: next.headers,
        sourceQueryPolicies: next.sourceQueryPolicies,
        lines: next.lines,
        lineIndex: 0,
      ),
    );
  }

  Future<void> setCellLine(int cellIndex, int lineIndex) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final state = cells[cellIndex];
    if (state.lines.isEmpty) {
      throw StateError('multiview: cell $cellIndex has no line list');
    }
    if (lineIndex < 0 || lineIndex >= state.lines.length) {
      throw RangeError.range(lineIndex, 0, state.lines.length - 1, 'lineIndex');
    }
    if (lineIndex == state.lineIndex) return;

    final context = _sourceContexts[cellIndex];
    if (context == null) {
      throw StateError('multiview: cell $cellIndex is not playing');
    }
    final switched = MultiviewStreamSource(
      url: state.lines[lineIndex],
      headers: state.headers,
      qualities: state.qualities,
      qualityIndex: state.qualityIndex,
      qualityLoader: context.qualityLoader,
      lines: state.lines,
      lineIndex: lineIndex,
      sourceQueryPolicies: state.sourceQueryPolicies,
    );
    _sourceContexts[cellIndex] = switched;
    await _wallController.assign(cellIndex, _wallSource(cellIndex, switched));
    _updateCell(cellIndex, cells[cellIndex].copyWith(lineIndex: lineIndex));
  }

  Future<void> toggleCellPlayPause(int cellIndex) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final controller = _wall;
    if (controller == null || cellIndex >= controller.cells.length) {
      throw StateError('multiview: cell $cellIndex is not playing');
    }
    final status = controller.cells[cellIndex].status;
    if (status == wall.MultiviewCellStatus.playing) {
      await controller.pauseCell(cellIndex);
      playingFlags[cellIndex] = false;
    } else if (status == wall.MultiviewCellStatus.paused) {
      await controller.resumeCell(cellIndex);
      playingFlags[cellIndex] = true;
    } else {
      throw StateError('multiview: cell $cellIndex is not playing');
    }
  }

  Future<void> setCellVolume(int cellIndex, double volume) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final resolved = volume.clamp(0.0, 1.0).toDouble();
    _volumes[cellIndex] = resolved;
    await _wallController.setCellVolume(cellIndex, resolved);
    final room = cells[cellIndex].room;
    if (room == null) return;
    try {
      await _roomVolumeSaver(room, resolved);
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: persist room volume failed',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  double cellVolume(int cellIndex) {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final room = cells[cellIndex].room;
    return _volumes[cellIndex] ?? (room == null ? 1.0 : _roomVolumeLoader(room).clamp(0.0, 1.0));
  }

  // ---------------------------------------------------------------------------
  // 音频焦点
  // ---------------------------------------------------------------------------

  Future<void> setAudioFocus(int cellIndex) {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    _audioFocusIndex.value = cellIndex;
    return _wallController.setAudioFocus(cellIndex);
  }

  Future<void> toggleMuteAll() {
    allMuted.toggle();
    return _wallController.muteAll(muted: allMuted.value);
  }

  // ---------------------------------------------------------------------------
  // 释放
  // ---------------------------------------------------------------------------

  Future<void> _teardownSlot(int cellIndex) async {
    await _wall?.clear(cellIndex);
  }

  void _failCell(int cellIndex, MultiviewCellErrorKind kind, String detail) {
    if (_closed || isClosed) return;
    if (cellIndex >= cells.length) return;
    _updateCell(
      cellIndex,
      cells[cellIndex].copyWith(
        status: MultiviewCellStatus.error,
        errorKind: kind,
        errorDetail: detail,
        clearVideoController: true,
      ),
    );
    if (cellIndex < playingFlags.length) {
      playingFlags[cellIndex] = false;
    }
  }

  void _updateCell(int cellIndex, MultiviewCellState state) {
    if (_closed || isClosed) return;
    if (cellIndex >= cells.length) return;
    cells[cellIndex] = state;
  }

  @override
  void onClose() {
    _closed = true;
    for (final worker in _rxWorkers) {
      worker.dispose();
    }
    _rxWorkers.clear();
    _wallSub?.cancel();
    _wallSub = null;
    unawaited(_wall?.dispose());
    _wall = null;
    for (final scope in _discoveryScopes.values) {
      _retireDiscovery(scope);
    }
    _discoveryScopes.clear();
    unawaited(_danmakuSession.disconnect());
    super.onClose();
  }
}
