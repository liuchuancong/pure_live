import 'dart:async';
import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:flame_barrage/flame_barrage.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/common/global/platform_utils.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';
import 'package:pure_live/modules/multiview/models/multiview_models.dart';
import 'package:pure_live/modules/multiview/cells/multiview_cell_player.dart';
import 'package:pure_live/modules/live_play/controllers/player_controller.dart';
import 'package:pure_live/modules/multiview/danmaku/multiview_danmaku_session.dart';

/// 房间对象 → 可播放源解析器。
///
/// 复用站点适配器既有入口（getRoomDetail/getPlayQualites/getPlayUrls），
/// 禁止在 multiview 内复制解析逻辑；测试注入假实现。
/// [preferLowest] 为小格自动降质联动服务：true 时默认取最低档（列表末项）。
typedef MultiviewStreamResolver = Future<MultiviewStreamSource> Function(LiveRoom room, {required bool preferLowest});

/// 进入 multiview 时暂停全局播放器的钩子。
///
/// multiview 自建每格播放器实例，与全局单实例播放系统并存；
/// 两者同时出声不可接受，进入时必须先让全局侧静默。注入以便测试。
typedef MultiviewGlobalPauseHook = Future<void> Function();

/// Loads and saves the per-room volume used by multiview.
///
/// Production reuses the same persistent room-volume store as the normal
/// player. Tests inject deterministic callbacks so the controller remains
/// independent from the GetX settings lifecycle.
typedef MultiviewRoomVolumeLoader = double Function(LiveRoom room);
typedef MultiviewRoomVolumeSaver = Future<void> Function(LiveRoom room, double volume);

/// 多画面同看控制器（无头核心层）。
///
/// 架构决策：
/// - 绕开 PlayerManager/GlobalPlayerService/PlayerPool 的全局单实例假设，
///   通过 [MultiviewCellPlayerFactory] 为每格创建独立 media_kit 实例；
/// - 仅活跃格出声（音频焦点模型），新起播成功的格自动成为焦点；
/// - 所有释放（removeCell/setLayout 缩容/disposeAll）走同一条
///   「pause → 销毁渲染控制器 → 销毁播放内核」路径。
///
/// Remaining enhancement: layout-change render-target renegotiation and
/// optional session persistence.
class MultiviewController extends GetxController {
  MultiviewController({
    MultiviewCellPlayerFactory? playerFactory,
    MultiviewStreamResolver? streamResolver,
    MultiviewGlobalPauseHook? pauseGlobalPlayback,
    MultiviewDanmakuEngineFactory? danmakuEngineFactory,
    MultiviewRoomVolumeLoader? roomVolumeLoader,
    MultiviewRoomVolumeSaver? roomVolumeSaver,
    int? maxCellCount,
  }) : _playerFactory = playerFactory ?? _defaultPlayerFactory,
       _streamResolver = streamResolver ?? _defaultStreamResolver,
       _pauseGlobalPlayback = pauseGlobalPlayback ?? _defaultPauseGlobalPlayback,
       _danmakuEngineFactory = danmakuEngineFactory ?? _defaultDanmakuEngineFactory,
       _roomVolumeLoader = roomVolumeLoader ?? _defaultRoomVolumeLoader,
       _roomVolumeSaver = roomVolumeSaver ?? _defaultRoomVolumeSaver,
       maxCellCount = maxCellCount ?? (PlatformUtils.isDesktop ? maxCells : MultiviewLayout.focus.capacity) {
    if (this.maxCellCount < MultiviewLayout.focus.capacity || this.maxCellCount > maxCells) {
      throw ArgumentError.value(this.maxCellCount, 'maxCellCount', 'must be between 4 and $maxCells');
    }
    _audioFocusTransitions = LatestAsyncValueQueue<int>(_applyAudioFocus);
  }

  /// focus（一大多小）布局的格子数上限。
  ///
  /// 性能护栏：桌面端多实例解码上限取 9 路，超过后 addCell Fail Fast；
  /// 小格滚动呈现由 UI 层负责。
  static const int maxCells = 9;

  /// Effective decoder cap. Mobile remains at four simultaneous cells while
  /// desktop can expand the focus rail to [maxCells].
  final int maxCellCount;

  /// 生产环境每格播放器工厂。
  static MultiviewCellPlayerHandle _defaultPlayerFactory({required int renderWidth, required int renderHeight}) {
    return MultiviewCellPlayer(renderWidth: renderWidth, renderHeight: renderHeight);
  }

  /// 生产环境解析器：完整复用 LivePlayController 同一条站点解析链路。
  ///
  /// 同时取回清晰度列表并构造换档加载器闭包（捕获 detail/site/headers），
  /// 后续 setCellQuality 无需重走 getRoomDetail/getPlayQualites。
  static Future<MultiviewStreamSource> _defaultStreamResolver(LiveRoom room, {required bool preferLowest}) async {
    final platform = room.platform!;
    final site = Sites.of(platform);

    // Multiview must not use the UI-oriented fallback lookup for platforms
    // that expose a strict playback-complete resolver. The fallback can turn
    // a transport/shape failure into an offline-looking room; the strict path
    // preserves the difference between "platform says offline" and "request
    // failed" while retaining all signed playback fields.
    final liveSite = site.liveSite;
    final detail = liveSite is LiveSiteRecordRoomResolver
        ? await (liveSite as LiveSiteRecordRoomResolver).getRoomDetailForRecording(
            roomId: room.roomId!,
            platform: platform,
          )
        : await liveSite.getRoomDetail(roomId: room.roomId!, platform: platform);
    if (detail.isExplicitlyOfflineNow) {
      throw MultiviewRoomOffline(detail);
    }
    if (!detail.isPlayableNow) {
      throw StateError('multiview: room status is ${detail.effectiveLiveStatus.name} for $platform/${room.roomId}');
    }
    final qualities = await site.liveSite.getPlayQualites(detail: detail);
    if (qualities.isEmpty) {
      throw StateError('multiview: no play qualities for $platform/${room.roomId}');
    }

    // 默认最高档（列表首项）；小格自动降质联动开启时小格取最低档（末项）。
    final qualityIndex = preferLowest ? qualities.length - 1 : 0;
    final urls = await site.liveSite.getPlayUrls(detail: detail, quality: qualities[qualityIndex]);
    if (urls.isEmpty) {
      throw StateError('multiview: no play urls for $platform/${room.roomId}');
    }

    final headers = await PlayerController.resolvePlaybackHeaders(site: site, room: detail);

    // 换档加载器：同房间各清晰度通用同一组 headers；URL 取空视为解析失败。
    // 返回源携带完整线路列表（lineIndex 归 0），由控制器按当前线路校正。
    Future<MultiviewStreamSource> loadQuality(LivePlayQuality quality) async {
      final nextUrls = await site.liveSite.getPlayUrls(detail: detail, quality: quality);
      if (nextUrls.isEmpty) {
        throw StateError('multiview: no play urls for $platform/${room.roomId} @ ${quality.quality}');
      }
      return MultiviewStreamSource(url: nextUrls.first, headers: headers, lines: nextUrls);
    }

    return MultiviewStreamSource(
      url: urls.first,
      headers: headers,
      qualities: qualities,
      qualityIndex: qualityIndex,
      qualityLoader: loadQuality,
      lines: urls,
    );
  }

  /// 生产环境弹幕引擎工厂：复用站点适配器的 getDanmaku()。
  static LiveDanmaku _defaultDanmakuEngineFactory(LiveRoom room) {
    return Sites.of(room.platform!).liveSite.getDanmaku();
  }

  static double _defaultRoomVolumeLoader(LiveRoom room) => room.getSavedVolume();

  static Future<void> _defaultRoomVolumeSaver(LiveRoom room, double volume) {
    return room.saveCurrentVolume(volume);
  }

  /// 生产环境全局播放静默钩子。
  ///
  /// 全局播放服务尚未初始化说明当前没有全局会话，无需处理。
  /// app 浮窗激活时仅 pause 会留下冻结画面悬浮在网格上方，用户点浮窗播放
  /// 即双出声；语义与 AppNavigator.toLiveRoomDetail 进入直播间前一致，
  /// 直接关闭浮窗。其余情况维持暂停行为。
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

  /// 当前布局；初始为四画面（本功能的核心形态）。
  final Rx<MultiviewLayout> layout = MultiviewLayout.quad.obs;

  /// focus（一大多小）布局下当前显示为大画面的格子下标，默认 0。
  ///
  /// 仅在 focus 布局下有语义；其他布局下无意义但保持合法值
  /// （始终在当前容量内），供切换布局时无损恢复。
  final RxInt focusedCellIndex = 0.obs;

  /// 单格状态列表，长度恒等于 [layout] 容量。
  final RxList<MultiviewCellState> cells = RxList<MultiviewCellState>(
    List.generate(MultiviewLayout.quad.capacity, MultiviewCellState.empty),
  );

  /// 每格播放器句柄，与 cells 一一对应；空格为 null。
  final List<MultiviewCellPlayerHandle?> _players = List<MultiviewCellPlayerHandle?>.generate(
    MultiviewLayout.quad.capacity,
    (_) => null,
    growable: true,
  );

  /// 每格加载纪元，用于丢弃迟到的解析/起播结果（竞态防护）。
  final List<int> _cellEpochs = List<int>.generate(MultiviewLayout.quad.capacity, (_) => 0, growable: true);

  /// 每格播放状态（供 UI 播放/暂停按钮态），与 cells 平行维护；
  /// 由句柄的播放状态流订阅驱动，临时暂停/恢复即时翻转。
  final RxList<bool> playingFlags = RxList<bool>(
    List.generate(MultiviewLayout.quad.capacity, (_) => false, growable: true),
  );

  /// 每格播放状态流订阅；随句柄创建/释放同步管理，防泄漏。
  final List<StreamSubscription<bool>?> _playingSubs = List<StreamSubscription<bool>?>.generate(
    MultiviewLayout.quad.capacity,
    (_) => null,
    growable: true,
  );

  /// 音频焦点格下标，默认 0。
  ///
  /// 必须是响应式状态：非 focus 布局点击格子后，顶部音量入口、声音来源
  /// 标识和弹幕目标需要在同一帧切换。旧实现使用普通 int，只能依赖页面
  /// 手工 setState，导致页级弹幕按钮在 1×1/1×2/2×2 下没有有效目标。
  final RxInt _audioFocusIndex = 0.obs;

  /// Serializes native mute calls and coalesces rapid focus taps to the latest
  /// cell, preventing out-of-order futures from leaving multiple cells audible.
  late final LatestAsyncValueQueue<int> _audioFocusTransitions;

  /// 小格自动降质联动开关（仅 focus 布局生效）。
  ///
  /// 开启时：向非大画面格分配房间默认取最低档；晋升格自动换最高档、
  /// 被降格的原大画面自动换最低档。关闭时一切维持默认（全部最高档，
  /// 晋升不换流）。
  final RxBool smallCellsLowQuality = false.obs;

  /// multiview 页级弹幕开关，默认关。
  ///
  /// 用户决策：只有大画面开弹幕；本开关同时控制显隐与连接。
  final RxBool danmakuEnabled = false.obs;

  /// 大画面弹幕渲染入口：UI 直接接 FlameBarrageWidget(controller: ...)。
  ///
  /// 会话过滤后的聊天消息经 [BarrageItem] 注入；样式/速度调优归 UI 层。
  final BarrageController barrageController = BarrageController();

  final MultiviewCellPlayerFactory _playerFactory;
  final MultiviewStreamResolver _streamResolver;
  final MultiviewGlobalPauseHook _pauseGlobalPlayback;
  final MultiviewDanmakuEngineFactory _danmakuEngineFactory;
  final MultiviewRoomVolumeLoader _roomVolumeLoader;
  final MultiviewRoomVolumeSaver _roomVolumeSaver;

  /// 大画面弹幕会话：异常自容错（记日志不外抛），绝不影响播放主链路。
  late final MultiviewDanmakuSession _danmakuSession = MultiviewDanmakuSession(
    engineFactory: _danmakuEngineFactory,
    onChatMessage: _forwardChatMessage,
  );

  /// 响应式监听（onInit 注册，onClose 释放）：弹幕生命周期 + 降质开关 reconcile。
  final List<Worker> _rxWorkers = <Worker>[];

  /// 当前持有音频焦点的格子下标。
  int get audioFocusIndex => _audioFocusIndex.value;

  /// UI-only reactive source for selected-cell controls.
  RxInt get audioFocusIndexState => _audioFocusIndex;

  /// focus 布局下是否还能追加小格。
  bool get canAddCell => layout.value == MultiviewLayout.focus && cells.length < maxCellCount;

  @override
  void onInit() {
    super.onInit();
    // 进入 multiview 时先让全局播放器静默，避免双系统同时出声。
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
    // 弹幕会话跟随页级开关与大画面切换；房间变化由各变更点显式触发同步。
    _rxWorkers.add(
      everAll([danmakuEnabled, layout, focusedCellIndex, _audioFocusIndex], (_) => unawaited(_syncDanmakuSession())),
    );
    // 降质开关切换后即时 reconcile 在播小格，避免开关只影响后续分配。
    _rxWorkers.add(ever(smallCellsLowQuality, (_) => unawaited(_reconcileSmallCellQualities())));
  }

  /// 降质开关切换后的即时 reconcile（仅 focus 布局）。
  ///
  /// 开启→在播小格非最低档者降到最低档；关闭→非最高档者升到最高档。
  /// 走 [setCellQuality] 既有纪元防护与错误态呈现，不绕过任何防护。
  Future<void> _reconcileSmallCellQualities() async {
    if (layout.value != MultiviewLayout.focus) return;
    for (var i = 0; i < cells.length; i++) {
      if (i == focusedCellIndex.value) continue;
      final cell = cells[i];
      if (cell.status != MultiviewCellStatus.playing || _players[i] == null) continue;
      if (cell.qualities.isEmpty) continue;
      final targetIndex = smallCellsLowQuality.value ? cell.qualities.length - 1 : 0;
      if (cell.qualityIndex == targetIndex) continue;
      await setCellQuality(i, targetIndex);
    }
  }

  void _forwardChatMessage(LiveMessage message) {
    // 与 live_play 的弹幕上屏同构：仅注入内容与颜色，速度等样式归 UI 层。
    barrageController.send(
      BarrageItem(
        content: message.message,
        userId: message.userId,
        userName: message.userName,
        textColor: Color.fromARGB(255, message.color.r, message.color.g, message.color.b),
      ),
    );
  }

  int get _selectedCellIndex {
    if (cells.isEmpty) return 0;
    final selected = layout.value == MultiviewLayout.focus ? focusedCellIndex.value : _audioFocusIndex.value;
    return selected.clamp(0, cells.length - 1);
  }

  /// 按当前开关/布局/所选房间同步弹幕会话（幂等）。
  ///
  /// focus 布局的目标是大画面；1×1/1×2/2×2 的目标是当前声音来源格。
  /// 因而顶部弹幕按钮在所有布局中都有明确、唯一且可见的渲染目标。
  Future<void> _syncDanmakuSession() async {
    try {
      final room = danmakuEnabled.value && cells.isNotEmpty ? cells[_selectedCellIndex].room : null;
      if (room == null || !MultiviewDanmakuSession.supportsRoom(room)) {
        await _danmakuSession.disconnect();
        return;
      }
      await _danmakuSession.connect(room);
    } catch (error, stackTrace) {
      // 弹幕故障不得影响播放主链路：记录后会话自身状态已由其内部回滚。
      developer.log(
        'MultiviewController: danmaku session sync failed',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 切换布局。
  ///
  /// 缩容时按同一条释放路径销毁多余格；保留前 N 格的播放状态不重建。
  /// 扩容时追加空白格。已有格不重设渲染分辨率（TODO: 布局切换后重设，
  /// 当前接受暂时模糊）。
  Future<void> setLayout(MultiviewLayout newLayout) async {
    if (newLayout == layout.value) return;
    final capacity = newLayout.capacity;

    for (var i = capacity; i < _players.length; i++) {
      await _releaseSlot(i);
    }

    while (cells.length > capacity) {
      _playingSubs.removeLast()?.cancel();
      playingFlags.removeLast();
      cells.removeLast();
      _players.removeLast();
      _cellEpochs.removeLast();
    }
    while (cells.length < capacity) {
      cells.add(MultiviewCellState.empty(cells.length));
      _players.add(null);
      _cellEpochs.add(0);
      playingFlags.add(false);
      _playingSubs.add(null);
    }

    layout.value = newLayout;

    // 进入 focus 布局时视觉跟随既有声源（零音频扰动），
    // 避免出现「大画面无声、声音来自某个小格」的失同步。
    // 进入 focus 时容量为 4，_audioFocusIndex 必在其内，故先同步后钳制安全。
    if (newLayout == MultiviewLayout.focus) {
      focusedCellIndex.value = _audioFocusIndex.value;
    }

    // 缩容后旧的大画面格可能越界，钳制到新容量内
    // （与页面选台目标 _targetCell 的整改同一模式，防越界）。
    if (focusedCellIndex.value >= capacity) {
      focusedCellIndex.value = capacity - 1;
    }

    if (_audioFocusIndex.value >= capacity) {
      _refocusToFirstPlaying(fallback: 0);
    }

    // 布局变化可能改变大画面格（进入/离开 focus），同步弹幕会话。
    unawaited(_syncDanmakuSession());
  }

  /// focus 布局下追加一个空白小格（动态容量，滚动呈现由 UI 层负责）。
  ///
  /// 仅 focus 布局且未达 [maxCellCount] 时有效；否则 Fail Fast。
  Future<void> addCell() async {
    if (layout.value != MultiviewLayout.focus) {
      throw StateError('multiview: addCell is only available in focus layout');
    }
    if (!canAddCell) {
      throw StateError('multiview: cell limit reached ($maxCellCount)');
    }
    cells.add(MultiviewCellState.empty(cells.length));
    _players.add(null);
    _cellEpochs.add(0);
    playingFlags.add(false);
    _playingSubs.add(null);
  }

  /// focus 布局下把 [cellIndex] 格晋升为大画面。
  ///
  /// 交互模型（YouTube TV 聚焦式）：只切换「哪个格显示为大」，
  /// 播放器实例不迁移、不重建、不重新解析，各路播放状态完整保留；
  /// 音频焦点跟随新的大画面，即大画面成为唯一声音来源。
  ///
  /// 小格自动降质联动开启时（仅 focus 布局）：晋升格非最高档则自动换
  /// 最高档，被降格的原大画面非最低档则自动换最低档——均走同实例换流，
  /// 不重建播放器。可能触发换流故为异步；UI 层无需等待其完成。
  Future<void> promoteCell(int cellIndex) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final previousFocused = focusedCellIndex.value;
    focusedCellIndex.value = cellIndex;
    await setAudioFocus(cellIndex);

    if (!smallCellsLowQuality.value || layout.value != MultiviewLayout.focus) return;

    // 晋升格：非最高档自动换最高档。
    final promoted = cells[cellIndex];
    if (_players[cellIndex] != null && promoted.qualities.isNotEmpty && promoted.qualityIndex != 0) {
      await setCellQuality(cellIndex, 0);
    }
    // 被降格的原大画面：非最低档自动换最低档。
    if (previousFocused == cellIndex || previousFocused < 0 || previousFocused >= cells.length) return;
    final demoted = cells[previousFocused];
    if (_players[previousFocused] != null &&
        demoted.qualities.isNotEmpty &&
        demoted.qualityIndex != demoted.qualities.length - 1) {
      await setCellQuality(previousFocused, demoted.qualities.length - 1);
    }
  }

  /// 向指定格分配房间并起播；成功后该格自动成为音频焦点。
  ///
  /// 若该格已被占用，先走统一释放路径再重新分配。
  /// 解析失败/起播失败置 status=error 并记录错误种类与原始详情，不吞异常。
  Future<void> assignRoom(int cellIndex, LiveRoom room) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    if (room.platform == null || !Sites.isSupported(room.platform!)) {
      throw ArgumentError.value(room.platform, 'room.platform', 'Unsupported live platform');
    }
    if (room.roomId == null || room.roomId!.isEmpty) {
      throw ArgumentError.value(room.roomId, 'room.roomId', 'Room id is required');
    }

    // 先推进纪元使该格任何在途解析/起播失效，再释放旧句柄。
    // 旧句柄的销毁不再推进纪元：本此分配已独占该格。
    final epoch = ++_cellEpochs[cellIndex];
    final previousHandle = _players[cellIndex];
    _players[cellIndex] = null;
    if (previousHandle != null) {
      await _teardown(previousHandle);
    }

    _updateCell(
      cellIndex,
      cells[cellIndex].copyWith(
        room: room,
        status: MultiviewCellStatus.resolving,
        clearError: true,
        clearVideoController: true,
        // 清空旧房间的清晰度上下文：解析失败时错误态快照不得残留
        // 旧清晰度表/换档闭包，否则 UI 会展示与新房间无关的档位。
        clearQuality: true,
      ),
    );

    // A room already verified as offline is a valid picker result. Do not hit
    // playback APIs or construct a native decoder only to surface a generic
    // error card.
    if (room.isExplicitlyOfflineNow) {
      _setOfflineCell(cellIndex, epoch, room);
      return;
    }

    // 小格自动降质联动（仅 focus 布局）：向非大画面格分配时默认取最低档。
    final preferLowest =
        smallCellsLowQuality.value && layout.value == MultiviewLayout.focus && cellIndex != focusedCellIndex.value;

    final MultiviewStreamSource source;
    try {
      source = await _streamResolver(room, preferLowest: preferLowest);
    } on MultiviewRoomOffline catch (offline) {
      _setOfflineCell(cellIndex, epoch, offline.room.fillFromDetail(room));
      return;
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: resolve stream failed for ${room.platform}/${room.roomId}',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
      _failCell(cellIndex, epoch, MultiviewCellErrorKind.resolveFailure, error.toString());
      return;
    }
    if (_isStale(cellIndex, epoch)) return;

    final target = _resolveRenderTarget(layout.value);
    final handle = _playerFactory(renderWidth: target.width.toInt(), renderHeight: target.height.toInt());

    try {
      await handle.start(url: source.url, headers: source.headers);
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: start playback failed for ${room.platform}/${room.roomId}',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
      await _teardown(handle);
      _failCell(cellIndex, epoch, MultiviewCellErrorKind.startFailure, error.toString());
      return;
    }

    // Restore the same per-room volume used by the normal player before this
    // handle can receive audio focus. All multiview handles start muted, so
    // this cannot create a first-frame volume burst.
    try {
      await handle.setVolume(_roomVolumeLoader(room).clamp(0.0, 1.0));
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: restore room volume failed',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (_isStale(cellIndex, epoch)) {
      await _teardown(handle);
      return;
    }

    _players[cellIndex] = handle;
    _playingSubs[cellIndex]?.cancel();
    _playingSubs[cellIndex] = handle.playingStream.listen((playing) {
      if (!_isStale(cellIndex, epoch) && cellIndex < playingFlags.length) {
        playingFlags[cellIndex] = playing;
      }
    });
    playingFlags[cellIndex] = true;
    _updateCell(
      cellIndex,
      cells[cellIndex].copyWith(
        status: MultiviewCellStatus.playing,
        videoController: handle.videoController,
        qualities: source.qualities,
        qualityIndex: source.qualityIndex,
        qualityLoader: source.qualityLoader,
        headers: source.headers,
        lines: source.lines,
        lineIndex: source.lineIndex,
      ),
    );
    // focus 布局下向非大格分配房间时，新流保持静音起播、不抢声源，
    // 用户点击晋升（promoteCell）才出声；其余布局维持「新格即声源」。
    final shouldTakeAudioFocus = layout.value != MultiviewLayout.focus || cellIndex == focusedCellIndex.value;
    if (shouldTakeAudioFocus) {
      await setAudioFocus(cellIndex);
    }
    // 大画面房间可能已变化，同步弹幕会话（幂等）。
    unawaited(_syncDanmakuSession());
  }

  /// 切换指定格的清晰度：同 Player 换流，不重建播放器实例。
  ///
  /// 纪元推进防竞态——换流期间该格被重新分配时，迟到的换流结果被丢弃。
  /// URL 取回失败置 resolveFailure、open 失败置 startFailure，
  /// 均按 [_failCell] 既有模式呈现。
  Future<void> setCellQuality(int cellIndex, int qualityIndex) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final state = cells[cellIndex];
    if (state.qualities.isEmpty) {
      throw StateError('multiview: cell $cellIndex has no quality list');
    }
    if (qualityIndex < 0 || qualityIndex >= state.qualities.length) {
      throw RangeError.range(qualityIndex, 0, state.qualities.length - 1, 'qualityIndex');
    }
    final loader = state.qualityLoader;
    if (loader == null) {
      throw StateError('multiview: cell $cellIndex has no quality loader');
    }
    if (qualityIndex == state.qualityIndex) return;
    final handle = _players[cellIndex];
    if (handle == null) {
      throw StateError('multiview: cell $cellIndex is not playing');
    }

    final epoch = ++_cellEpochs[cellIndex];
    final MultiviewStreamSource next;
    try {
      next = await loader(state.qualities[qualityIndex]);
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: quality url resolve failed for cell $cellIndex',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
      _failCell(cellIndex, epoch, MultiviewCellErrorKind.resolveFailure, error.toString());
      return;
    }
    if (_isStale(cellIndex, epoch)) return;

    // 换清晰度尽量保持当前线路：新档位线路数不足时回退首线路；
    // 加载器未提供线路列表时维持原状（兼容假实现/旧解析器）。
    final hasLines = next.lines.isNotEmpty;
    final keepLine = hasLines ? (state.lineIndex < next.lines.length ? state.lineIndex : 0) : state.lineIndex;
    final openUrl = hasLines ? next.lines[keepLine] : next.url;

    try {
      await handle.open(url: openUrl, headers: next.headers);
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: quality switch open failed for cell $cellIndex',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
      _failCell(cellIndex, epoch, MultiviewCellErrorKind.startFailure, error.toString());
      return;
    }
    if (_isStale(cellIndex, epoch)) return;

    _updateCell(
      cellIndex,
      cells[cellIndex].copyWith(
        qualityIndex: qualityIndex,
        lines: hasLines ? next.lines : null,
        lineIndex: hasLines ? keepLine : null,
      ),
    );
  }

  /// 切换指定格的线路：同 Player 换流，不重建播放器实例。
  ///
  /// 线路列表来自解析阶段 getPlayUrls 的完整返回；换清晰度时线路下标
  /// 尽量保持（见 [setCellQuality] 的线路保持逻辑）。
  Future<void> setCellLine(int cellIndex, int lineIndex) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final state = cells[cellIndex];
    if (state.status != MultiviewCellStatus.playing) {
      throw StateError('multiview: cell $cellIndex is not playing');
    }
    if (state.lines.isEmpty) {
      throw StateError('multiview: cell $cellIndex has no line list');
    }
    if (lineIndex < 0 || lineIndex >= state.lines.length) {
      throw RangeError.range(lineIndex, 0, state.lines.length - 1, 'lineIndex');
    }
    if (lineIndex == state.lineIndex) return;
    final handle = _players[cellIndex];
    if (handle == null) {
      throw StateError('multiview: cell $cellIndex is not playing');
    }

    final epoch = ++_cellEpochs[cellIndex];
    try {
      await handle.open(url: state.lines[lineIndex], headers: state.headers);
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: line switch open failed for cell $cellIndex',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
      _failCell(cellIndex, epoch, MultiviewCellErrorKind.startFailure, error.toString());
      return;
    }
    if (_isStale(cellIndex, epoch)) return;

    _updateCell(cellIndex, cells[cellIndex].copyWith(lineIndex: lineIndex));
  }

  /// 临时暂停/恢复指定格（不触发释放流程，格状态保持 playing）。
  Future<void> toggleCellPlayPause(int cellIndex) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    if (cells[cellIndex].status != MultiviewCellStatus.playing) {
      throw StateError('multiview: cell $cellIndex is not playing');
    }
    final handle = _players[cellIndex];
    if (handle == null) {
      throw StateError('multiview: cell $cellIndex is not playing');
    }
    if (cellIndex >= playingFlags.length) {
      throw StateError('multiview: playing flag missing for cell $cellIndex');
    }
    if (handle.isPlaying) {
      await handle.pause();
      playingFlags[cellIndex] = false;
    } else {
      await handle.resume();
      playingFlags[cellIndex] = true;
    }
  }

  /// 设置指定格的音量（0.0-1.0）并写入普通播放器共用的房间音量存储。
  /// 静音状态独立于音量值。
  Future<void> setCellVolume(int cellIndex, double volume) async {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    if (cells[cellIndex].status != MultiviewCellStatus.playing) {
      throw StateError('multiview: cell $cellIndex is not playing');
    }
    final handle = _players[cellIndex];
    if (handle == null) {
      throw StateError('multiview: cell $cellIndex is not playing');
    }
    final resolved = volume.clamp(0.0, 1.0).toDouble();
    await handle.setVolume(resolved);
    final room = cells[cellIndex].room;
    if (room == null) return;
    try {
      await _roomVolumeSaver(room, resolved);
    } catch (error, stackTrace) {
      // A damaged preference store must not turn a working volume adjustment
      // into a playback failure. The active player has already applied it.
      developer.log(
        'MultiviewController: persist room volume failed',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// 读取指定格的会话音量当前值（供 UI 音量控件初始化）；未起播返回 1.0。
  double cellVolume(int cellIndex) {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    return _players[cellIndex]?.volume ?? 1.0;
  }

  /// 释放指定格并回到 empty。
  ///
  /// 契约为同步签名：状态立即回到 empty，原生释放按同一条路径在后台完成。
  void removeCell(int cellIndex) {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    final handle = _captureSlot(cellIndex);
    if (_audioFocusIndex.value == cellIndex) {
      _refocusToFirstPlaying(fallback: cellIndex);
    }
    // 关闭大画面格后显示焦点不能空置：转移到第一个播放中的格，无播放格归 0
    // （与音频焦点的重定位语义对齐）。
    if (focusedCellIndex.value == cellIndex) {
      focusedCellIndex.value = _findPlayingCell() ?? 0;
    }
    if (handle != null) {
      unawaited(_teardown(handle));
    }
    // 大画面格可能被关闭或焦点转移，同步弹幕会话（幂等）。
    unawaited(_syncDanmakuSession());
  }

  /// 切换音频焦点：仅目标格出声，其余全部静音。
  Future<void> setAudioFocus(int cellIndex) {
    RangeError.checkValidIndex(cellIndex, cells, 'cellIndex');
    _audioFocusIndex.value = cellIndex;
    return _audioFocusTransitions.submit(cellIndex).catchError((Object error, StackTrace stackTrace) {
      developer.log(
        'MultiviewController: audio focus transition failed',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
    });
  }

  Future<void> _applyAudioFocus(int targetIndex) async {
    // Mute every non-target handle, not just the previously remembered one:
    // this also repairs any inconsistent state left by a native call failure.
    for (var index = 0; index < _players.length; index++) {
      if (index == targetIndex) continue;
      final handle = _players[index];
      if (handle == null) continue;
      try {
        await handle.setMuted(true);
      } catch (error, stackTrace) {
        developer.log(
          'MultiviewController: failed to mute cell $index',
          name: 'MultiviewController',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    // A newer tap arrived while native mute calls were in flight. The queue
    // will apply that pending target next, so never unmute this stale target.
    if (_audioFocusIndex.value != targetIndex || targetIndex >= _players.length) return;
    final target = _players[targetIndex];
    if (target != null) await target.setMuted(false);
  }

  /// 释放全部格子（页面 onClose 调用），cells 全部回到 empty。
  ///
  /// 状态清理同步前置：pop 动画期间 Video widget 可能仍在树中监听渲染
  /// notifier，必须先摘除全部渲染引用再开始原生销毁；句柄随后在后台
  /// 串行 teardown，onClose 场景不阻塞路由 pop。
  Future<void> disposeAll() async {
    final handles = <MultiviewCellPlayerHandle>[];
    for (var i = 0; i < _players.length; i++) {
      final handle = _captureSlot(i);
      if (handle != null) {
        handles.add(handle);
      }
    }
    _audioFocusIndex.value = 0;
    focusedCellIndex.value = 0;

    // 弹幕会话先行断开：网络栈清理与播放器销毁互不依赖。
    unawaited(_danmakuSession.disconnect());

    for (final handle in handles) {
      try {
        await _teardown(handle);
      } catch (error, stackTrace) {
        // 单个句柄销毁失败不得中断循环，否则后续句柄泄漏；
        // 记录后继续处理剩余句柄。
        developer.log(
          'MultiviewController: cell teardown failed during disposeAll',
          name: 'MultiviewController',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  @override
  void onClose() {
    for (final worker in _rxWorkers) {
      worker.dispose();
    }
    _rxWorkers.clear();
    unawaited(disposeAll());
    super.onClose();
  }

  bool _isStale(int cellIndex, int epoch) => cellIndex >= _cellEpochs.length || _cellEpochs[cellIndex] != epoch;

  /// 记录失败种类与原始错误文本；展示文案由 UI 按语言映射，核心层不拼自然语言。
  void _failCell(int cellIndex, int epoch, MultiviewCellErrorKind kind, String detail) {
    if (_isStale(cellIndex, epoch)) return;
    _updateCell(
      cellIndex,
      cells[cellIndex].copyWith(status: MultiviewCellStatus.error, errorKind: kind, errorDetail: detail),
    );
    // 大画面解析/起播失败时其房间状态已不可用，同步弹幕会话
    // （幂等入口：健康同键会话保持，失效则按当前大画面房间按需重连）。
    if (cellIndex == _selectedCellIndex) {
      unawaited(_syncDanmakuSession());
    }
  }

  void _setOfflineCell(int cellIndex, int epoch, LiveRoom room) {
    if (_isStale(cellIndex, epoch)) return;
    playingFlags[cellIndex] = false;
    _updateCell(
      cellIndex,
      cells[cellIndex].copyWith(
        room: room,
        status: MultiviewCellStatus.offline,
        clearError: true,
        clearVideoController: true,
        clearQuality: true,
      ),
    );
    unawaited(_syncDanmakuSession());
  }

  /// 统一释放路径：捕获句柄置空 → pause → 销毁播放内核
  /// （渲染控制器原生清理随 player.dispose 的 release 钩子完成）。
  Future<void> _releaseSlot(int cellIndex) async {
    final handle = _captureSlot(cellIndex);
    if (handle != null) {
      await _teardown(handle);
    }
  }

  /// 同步捕获并清空一格：句柄置空、纪元推进、状态回到 empty。
  MultiviewCellPlayerHandle? _captureSlot(int cellIndex) {
    final handle = _players[cellIndex];
    _players[cellIndex] = null;
    _cellEpochs[cellIndex]++;
    _playingSubs[cellIndex]?.cancel();
    _playingSubs[cellIndex] = null;
    if (cellIndex < playingFlags.length) {
      playingFlags[cellIndex] = false;
    }
    _updateCell(cellIndex, MultiviewCellState.empty(cellIndex));
    return handle;
  }

  Future<void> _teardown(MultiviewCellPlayerHandle handle) async {
    try {
      await handle.pause();
    } finally {
      await handle.disposePlayer();
    }
  }

  /// 第一个播放中的格下标；没有则返回 null。
  int? _findPlayingCell() {
    for (var i = 0; i < cells.length; i++) {
      if (cells[i].status == MultiviewCellStatus.playing && _players[i] != null) {
        return i;
      }
    }
    return null;
  }

  /// 焦点格失效后转移到第一个播放中的格；没有则落到 [fallback]。
  void _refocusToFirstPlaying({required int fallback}) {
    final target = _findPlayingCell();
    if (target != null) {
      setAudioFocus(target);
    } else {
      _audioFocusIndex.value = fallback;
    }
  }

  void _updateCell(int cellIndex, MultiviewCellState state) {
    cells[cellIndex] = state;
  }

  /// 按当前布局把屏幕物理像素均分，得到每格固定渲染分辨率。
  Size _resolveRenderTarget(MultiviewLayout l) {
    final screen = _probeScreenMetrics();
    // ponytail: 无窗口树（纯 Dart 测试/极早期调用）退回 720p 基线，
    // 保证分辨率计算可确定性验证。
    final width = ((screen.logical.width * screen.dpr) / l.columns).round().clamp(320, 3840);
    final height = ((screen.logical.height * screen.dpr) / l.rows).round().clamp(180, 2160);
    return Size(width.toDouble(), height.toDouble());
  }

  /// 探测当前窗口的逻辑尺寸与像素密度。
  ///
  /// GetX 的 Get.context 在根路由未挂载时抛出而非返回 null（vendored 实现），
  /// 该场景只出现在无窗口树的纯 Dart 测试或极早期调用，属预期环境状态，
  /// 记录后退回 720p 基线，不视为错误。
  ({Size logical, double dpr}) _probeScreenMetrics() {
    try {
      final context = Get.context;
      if (context == null) {
        return (logical: const Size(1280, 720), dpr: 1.0);
      }
      return (logical: MediaQuery.sizeOf(context), dpr: MediaQuery.devicePixelRatioOf(context));
    } catch (error, stackTrace) {
      developer.log(
        'MultiviewController: window tree unavailable, using baseline render metrics',
        name: 'MultiviewController',
        error: error,
        stackTrace: stackTrace,
      );
      return (logical: const Size(1280, 720), dpr: 1.0);
    }
  }
}
