import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flame_barrage/flame_barrage.dart';
import 'package:media_core/media_core.dart' hide PlatformUtils;
import 'package:media_core_feed/media_core_feed.dart';
import 'package:media_core_list_playback/media_core_list_playback.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/domains/live/domain/global_player_service.dart';
import 'package:pure_live/core/config/danmaku_settings_controller.dart';
import 'package:pure_live/core/platform/file_utils.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:screen_brightness_platform_interface/screen_brightness_platform_interface.dart';
import 'package:pure_live/core/player/kernel/floating_handle_keeper.dart';
import 'package:pure_live/core/player/kernel/player_kernel_service.dart';
import 'package:pure_live/core/player/presentation/danmaku/danmaku_surface_settings.dart';
import 'package:pure_live/core/player/presentation/danmaku/player_danmaku_surface.dart';
import 'package:pure_live/core/player/presentation/fullscreen_window.dart' show WindowService, fullscreenDriver;
import 'package:pure_live/core/player/presentation/player_presentation_actions.dart';
import 'package:pure_live/core/player/presentation/compact_source_orientation.dart';
import 'package:pure_live/core/player/presentation/player_ui_controller.dart';
import 'package:pure_live/core/player/presentation/windows_pip_driver.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/recording_danmaku_track.dart';
import 'package:pure_live/domains/recorder/presentation/pages/local_player/recording_resume.dart';

/// Persistent [PlaybackProgressStore] backed by Hive.
///
/// Each entry maps a file path to the position (in milliseconds) where
/// playback was last left. Entries whose video no longer exists are pruned
/// on load.
final class HivePlaybackProgressStore implements PlaybackProgressStore {
  HivePlaybackProgressStore(this._storageKey);

  final String _storageKey;
  Map<String, int>? _cache;

  Future<Map<String, int>> _load() async {
    if (_cache != null) return _cache!;
    final raw = HivePrefUtil.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _cache = {};
    } else {
      try {
        final decoded = jsonDecode(raw);
        _cache = decoded is Map<String, dynamic>
            ? decoded.map((k, v) => MapEntry(k, (v as num).toInt()))
            : <String, int>{};
      } catch (_) {
        _cache = {};
      }
    }
    return _cache!;
  }

  Future<void> _persist() async {
    await HivePrefUtil.setString(_storageKey, jsonEncode(_cache));
  }

  @override
  Future<Duration?> positionOf(String itemId) async {
    final map = await _load();
    final ms = map[itemId];
    if (ms == null || ms <= 0) return null;
    return Duration(milliseconds: ms);
  }

  @override
  Future<void> save(String itemId, Duration position) async {
    final map = await _load();
    if (position.inSeconds < 5) {
      map.remove(itemId);
    } else {
      map[itemId] = position.inMilliseconds;
    }
    await _persist();
  }

  @override
  Future<void> clear(String itemId) async {
    final map = await _load();
    map.remove(itemId);
    await _persist();
  }

  @override
  Future<void> clearAll() async {
    _cache = {};
    await _persist();
  }
}

/// The recording player's controller.
///
/// It implements both shared contracts Core's player surface talks to:
/// [PlayerUiController] (transport, gestures, the danmaku surface) and
/// [DanmakuSettingsSource] (the danmaku configuration its barrage renders with).
/// A recording has no room, so the danmaku values are the global settings
/// themselves — the same numbers the panel edits, which is what makes the
/// recording and the room show one barrage style.
final class LocalVideoPlayerController extends GetxController implements PlayerUiController, DanmakuSettingsSource {
  LocalVideoPlayerController({required this.directory, this.roomTitle, this.roomNick});

  final String directory;
  final String? roomTitle;
  final String? roomNick;

  static const _videoExtensions = {'.mp4', '.mkv', '.flv', '.ts', '.avi', '.mov', '.webm', '.m4v'};
  static const _progressKeyPrefix = 'local_player_progress_';
  static const defaultRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  /// Reactive on purpose: the page renders the list inside `Obx`, and a plain
  /// list would leave those builders with no observable to attach to — which
  /// GetX reports as an error rather than as a stale list. Mutate it in place
  /// (`addAll`, `removeAt`, index assignment) and the list notifies by itself.
  ///
  /// Built from a growable list: `RxList()`'s default initial value is `const []`,
  /// so the obvious constructor produces a list whose length cannot be changed —
  /// `clear()`, `addAll()` and `removeAt()` all throw `UnmodifiableListMixin` at
  /// runtime while still type-checking.
  final RxList<File> videoFiles = RxList<File>(<File>[]);
  final currentIndex = 0.obs;
  final isLoading = true.obs;
  final isPlaying = false.obs;
  final playbackRate = 1.0.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;

  /// Whether the recording being played carries chat (a `<prefix>.xml` beside
  /// it), which is what the danmaku button is offered for.
  final hasDanmaku = false.obs;

  /// The replayed chat of the current recording; see [RecordingDanmakuPlayer].
  final BarrageController danmakuController = BarrageController();
  RecordingDanmakuPlayer? _danmakuPlayer;
  RecordingDanmakuTrack? _danmakuTrack;

  PlayerKernel get _kernel => PlayerKernelService.instance.kernel;
  FeedPlayerController? _feed;
  HivePlaybackProgressStore? _progressStore;
  StreamSubscription<FeedItemState>? _stateSub;
  StreamSubscription<PlayerTransportState>? _transportSub;
  Timer? _positionSaver;

  FeedPlayerController? get feed => _feed;
  PlayerHandle? get handle => _feed?.handle;
  bool get isMobile => PlatformUtils.isMobile;
  bool get hasNext => currentIndex.value < videoFiles.length - 1;
  bool get hasPrevious => currentIndex.value > 0;
  String get currentFileName => videoFiles.isEmpty ? '' : videoFiles[currentIndex.value].uri.pathSegments.last;

  /// The current picture's shape, used to size a "fill the screen" surface.
  ///
  /// Falls back to 16:9 until the first frame reports a size, which is the shape
  /// a recording from a live room almost always has.
  double get videoAspectRatio {
    final size = _feed?.handle?.combinedSnapshot.geometry.videoSize;
    if (size == null || size.width <= 0 || size.height <= 0) return 16 / 9;
    return size.width / size.height;
  }

  /// 从直播间进入本页时，直播间的播放器还挂在路由栈下面继续出声、其视频层
  /// 也仍在合成：录像播放开始前把它暂停，返回直播间时由观众自己继续。
  void _pauseLivePlayback() {
    try {
      final live = GlobalPlayerService.instance.player;
      if (live.isPlayingNow) unawaited(live.pause());
    } catch (_) {
      // 直播内核未初始化（非直播间路径打开）时无事可做。
    }
  }

  @override
  void onInit() {
    super.onInit();
    _pauseLivePlayback();
    _progressStore = HivePlaybackProgressStore('$_progressKeyPrefix$directory');
    // 与直播间同一来源的画中画状态：桌面端窗口被驱动缩成小窗时，页面据此把
    // 自己的内容换成紧凑 overlay（直播的 _PipOverlayView 的录像对应物）。
    _pipStateSub = windowsPipDriver.onPipChanged.listen((pip) => isInPip.value = pip);
    // 全屏的真值是驱动，不是这个控制器里的 Rx —— 直播间就是这么办的
    // （facade 监听 fullscreenDriver 再同步自己的 isSystemFullscreen）。PiP
    // 请求经过内核链时会把全屏释放掉，本地乐观翻转的状态不知道这件事：于是
    // 缩小的窗口里还在渲染"全屏只剩视频区"那一支，退出 PiP 后窗口已经恢复
    // 正常、页面却还留着全屏形状。
    _fullscreenStateSub = fullscreenDriver.onFullscreenChanged.listen((_) => _syncFullscreenFromDriver());
    _syncFullscreenFromDriver();
    _scanAndOpen();
  }

  /// Whether the desktop window is currently in the picture-in-picture shape.
  final isInPip = false.obs;

  /// 仅音频（省电）：画面黑掉、声音继续。直播同款语义，录像没有专门
  /// presentation，直接在表面盖黑。
  final isAudioOnly = false.obs;

  /// 把当前帧截图存进录像目录，返回提示用的文件名。
  Future<String?> saveScreenshot() async {
    final handle = _feed?.handle;
    if (handle == null || handle.disposed) return null;
    try {
      final shot = await handle.captureScreenshot();
      if (shot == null || shot.bytes.isEmpty) return null;
      final dir = Directory(directory);
      if (!await dir.exists()) await dir.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('$directory${Platform.pathSeparator}screenshot_$stamp.png');
      await file.writeAsBytes(shot.bytes);
      return file.uri.pathSegments.last;
    } catch (_) {
      return null;
    }
  }

  /// 桌面端的全屏形态：为真时页面只渲染视频区（直播全屏的同款行为）。
  final isFullscreen = false.obs;

  /// The fullscreen keeps the picture's own vertical shape: a portrait
  /// recording goes fullscreen without being rotated or stretched into a
  /// landscape window, the way the live room's portrait panel fullscreen does.
  final portraitFullscreen = false.obs;

  /// Whether the picture currently open is taller than it is wide.
  bool get isPortraitVideo {
    final size = _feed?.handle?.combinedSnapshot.geometry.videoSize;
    if (size == null) return false;
    return CompactSourceOrientation.isPortraitSize(size.width.toDouble(), size.height.toDouble());
  }

  /// 控制栏显隐的单一来源：画面里那条覆盖式底栏按这里走。
  ///
  /// 点一下出现、无操作 5 秒淡出、再点一下立刻收起；桌面鼠标停在画面上时保持
  /// 显示。暂停不再把栏留住 —— 直播间的自动隐藏同样不看播放状态，停在暂停画
  /// 面上的一条常驻栏只会挡住画面。
  final controlsVisible = true.obs;

  static const Duration controlsHideDelay = Duration(seconds: 5);

  Timer? _controlsHideTimer;
  bool _controlsHovering = false;

  void revealControls({bool armTimer = true}) {
    controlsVisible.value = true;
    if (armTimer) armControlsHide();
  }

  void hideControls() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
    controlsVisible.value = false;
  }

  /// 触屏的一次点击：有栏就收掉，没栏就亮出来。
  void toggleControls() {
    if (controlsVisible.value) {
      hideControls();
    } else {
      revealControls();
    }
  }

  /// 重新计时；鼠标还停在画面上时不倒计时。
  void armControlsHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
    if (_controlsHovering) return;
    _controlsHideTimer = Timer(controlsHideDelay, () {
      _controlsHideTimer = null;
      if (_controlsHovering) return;
      controlsVisible.value = false;
    });
  }

  void setControlsHovering(bool hovering) {
    _controlsHovering = hovering;
    if (hovering) {
      _controlsHideTimer?.cancel();
      _controlsHideTimer = null;
      controlsVisible.value = true;
    } else {
      armControlsHide();
    }
  }

  /// 全屏切换的单一事实状态：库条的全屏按钮按 canExit 恒定分流到 exit 闭包，
  /// 所以 enter/exit 两个闭包都必须是“按当前状态翻转”的切换器。
  final fullscreenActive = false.obs;

  /// 桌面的全屏形状由驱动说了算：镜像过来，页面和切换按钮都读同一份真值。
  /// 移动端的全屏是方向锁，不在这条链上，保持原来的本地语义。
  void _syncFullscreenFromDriver() {
    if (PlatformUtils.isMobile) return;
    final active = fullscreenDriver.isSystemFullscreen;
    fullscreenActive.value = active;
    isFullscreen.value = active;
    if (!active) portraitFullscreen.value = false;
  }

  Future<void> toggleFullscreen() => fullscreenActive.value ? exitFullscreen() : enterFullscreen();

  /// Leaving any fullscreen shape. Returns true when there was one to leave.
  Future<bool> exitFullscreen() async {
    if (!fullscreenActive.value) return false;
    final isMobile = PlatformUtils.isMobile;
    if (isMobile) {
      if (!portraitFullscreen.value) {
        await WindowService().verticalScreen();
        await WindowService().followSystemOrientation();
      }
      await WindowService().doExitFullScreen();
    } else {
      await WindowService().doExitFullScreen();
    }
    fullscreenActive.value = false;
    portraitFullscreen.value = false;
    isFullscreen.value = false;
    return true;
  }

  Future<void> enterFullscreen() async {
    final isMobile = PlatformUtils.isMobile;
    final portrait = isPortraitVideo;
    fullscreenActive.value = true;
    portraitFullscreen.value = portrait;
    if (isMobile) {
      // A landscape recording rotates the whole page into the landscape shape;
      // a portrait one goes immersive in place, like the room's portrait panel
      // fullscreen, so the picture stays vertical instead of being stretched.
      if (!portrait) await WindowService().landScape();
      await WindowService().doEnterFullScreen();
      isFullscreen.value = false;
      return;
    }
    await WindowService().doEnterFullScreen();
    isFullscreen.value = true;
  }

  StreamSubscription<bool>? _pipStateSub;

  StreamSubscription<bool>? _fullscreenStateSub;

  Future<void> _scanAndOpen() async {
    isLoading.value = true;
    final dir = Directory(directory);
    if (!await dir.exists()) {
      isLoading.value = false;
      return;
    }

    final files = <File>[];
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File) {
        final dotIndex = entity.path.lastIndexOf('.');
        if (dotIndex > 0) {
          final ext = entity.path.substring(dotIndex).toLowerCase();
          if (_videoExtensions.contains(ext)) files.add(entity);
        }
      }
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    videoFiles
      ..clear()
      ..addAll(files);

    if (videoFiles.isEmpty) {
      isLoading.value = false;
      return;
    }

    final sources = videoFiles
        .map(
          (f) => PlayerSource(id: SourceId(f.path), uri: f.uri, type: SourceType.file, title: f.uri.pathSegments.last),
        )
        .toList();

    _feed = FeedPlayerController(_kernel, preloadAhead: !PlatformUtils.isMobile);
    _danmakuPlayer = RecordingDanmakuPlayer(controller: danmakuController);
    _stateSub = _feed!.onItemStateChanged.listen(_onItemState);
    _transportSub = _feed!.onPlaybackStateChanged.listen(_onTransport);
    _feed!.onIndexChanged.listen((i) => currentIndex.value = i);

    final initialIndex = await _resumeIndex();
    await _feed!.load(sources, initialIndex: initialIndex);
    currentIndex.value = initialIndex;
    // 打开即播：feed 的 autoPlay 已请求播放，这里再显式补一次，防止打开后
    // 停在暂停态（引擎在 surface 就绪前的 pause 竞态）。
    unawaited(_feed!.play());

    _positionSaver = Timer.periodic(const Duration(seconds: 5), (_) => _savePosition());

    isLoading.value = false;
    update();
  }

  Future<int> _resumeIndex() async {
    final store = _progressStore;
    if (store == null) return 0;
    for (var i = videoFiles.length - 1; i >= 0; i--) {
      final pos = await store.positionOf(videoFiles[i].path);
      if (pos != null && pos.inSeconds > 5) return i;
    }
    return 0;
  }

  Future<Duration?> resumePosition() async {
    final store = _progressStore;
    final handle = _feed?.handle;
    if (store == null || handle == null || videoFiles.isEmpty) return null;
    final file = videoFiles[currentIndex.value];
    final saved = await store.positionOf(file.path);
    final target = recordingResumeTarget(saved: saved, duration: handle.duration);
    if (target == null) return null;
    await handle.seek(target);
    return target;
  }

  /// Starts parsing the chat file that belongs to the recording at [index].
  ///
  /// Reading and parsing run off the critical path: the video opens first and
  /// the chat appears a moment later, and a recording without a chat file simply
  /// leaves [hasDanmaku] false.
  Future<void> _loadDanmakuFor(int index) async {
    final player = _danmakuPlayer;
    if (player == null) return;
    if (index < 0 || index >= videoFiles.length) {
      _danmakuTrack = null;
      hasDanmaku.value = false;
      player.use(null);
      return;
    }
    // Drop the previous file's chat immediately: showing it over the new video
    // for the length of a file read looks like the wrong recording's chat.
    _danmakuTrack = null;
    hasDanmaku.value = false;
    player.clear();
    final chat = RecordingDanmakuTrack.chatFileFor(videoFiles[index]);
    if (chat == null) {
      player.use(null);
      return;
    }
    final track = await RecordingDanmakuTrack.load(chat);
    if (isClosed) return;
    // A slow read must not attach the previous file's chat to this one.
    if (currentIndex.value != index) return;
    _danmakuTrack = track.isEmpty ? null : track;
    hasDanmaku.value = _danmakuTrack != null;
    player.use(_danmakuTrack);
    // The video is usually already playing by now, and its next transport
    // sample lands within a few hundred milliseconds; re-aligning here only
    // matters when the viewer resumed from a saved position and the sample
    // arrives before the parse finishes.
    player.seekTo(_feed?.handle?.position.inMilliseconds ?? 0);
  }

  void _onItemState(FeedItemState state) {
    isPlaying.value = state == FeedItemState.playing;
    if (state == FeedItemState.playing) {
      // 时长不依赖第一条 transport 样本：开始播就同步一次，进度条立刻有总时长。
      final handle = _feed?.handle;
      if (handle != null && handle.duration > Duration.zero) {
        duration.value = handle.duration;
      }
      final index = currentIndex.value;
      unawaited(
        resumePosition().then((resumed) {
          if (isClosed) return;
          unawaited(_loadDanmakuFor(index));
          _danmakuPlayer?.seekTo((resumed ?? Duration.zero).inMilliseconds);
        }),
      );
    }
  }

  void _onTransport(PlayerTransportState transport) {
    position.value = transport.position;
    duration.value = transport.duration;
    _danmakuPlayer?.position(transport.position.inMilliseconds);
  }

  Future<void> showIndex(int index) async {
    if (index < 0 || index >= videoFiles.length) return;
    await _savePosition();
    await _feed?.showIndex(index);
    currentIndex.value = index;
    update();
  }

  Future<void> next() => showIndex(currentIndex.value + 1);
  Future<void> previous() => showIndex(currentIndex.value - 1);

  Future<void> togglePlayPause() async {
    if (isPlaying.value) {
      await _feed?.pause();
    } else {
      await _feed?.play();
    }
  }

  Future<void> seekBy(Duration offset) => seekTo((_feed?.handle?.position ?? Duration.zero) + offset);

  /// Seeks to an absolute position, clamped to the file.
  Future<void> seekTo(Duration target) async {
    final handle = _feed?.handle;
    if (handle == null) return;
    final duration = handle.duration;
    final clamped = target < Duration.zero ? Duration.zero : (target > duration ? duration : target);
    try {
      await handle.seek(clamped);
    } catch (_) {
      // 拖进度条会密集触发 seek，被新目标取代的旧 seek 以取消异常完成——正常信号。
      // 弹幕光标仍要对齐最后一次请求的位置。
      _danmakuPlayer?.seekTo(clamped.inMilliseconds);
      return;
    }
    // Replayed chat is position-driven: a seek must move the cursor too, or the
    // next sample looks like a 40-minute jump and the whole recording replays.
    _danmakuPlayer?.seekTo(clamped.inMilliseconds);
  }

  Future<void> setRate(double rate) async {
    playbackRate.value = rate;
    try {
      await _feed?.handle?.setRate(rate);
    } catch (_) {
      // 与 seek 同一族：被新请求取代的旧写入以取消异常完成，不是错误。
    }
  }

  Future<void> cycleRate() async {
    final idx = defaultRates.indexOf(playbackRate.value);
    final nextIdx = (idx + 1) % defaultRates.length;
    await setRate(defaultRates[nextIdx]);
  }

  Future<void> _savePosition() async {
    final store = _progressStore;
    final handle = _feed?.handle;
    if (store == null || handle == null || videoFiles.isEmpty) return;
    final idx = _feed?.currentIndex ?? currentIndex.value;
    if (idx < 0 || idx >= videoFiles.length) return;
    final pos = handle.position;
    if (pos.inSeconds > 0) {
      await store.save(videoFiles[idx].path, pos);
    }
  }

  Future<void> openFileDir() async {
    await FileUtils.openFileOrUrl(directory);
  }

  Future<void> renameFile(int index, String newName) async {
    if (index < 0 || index >= videoFiles.length) return;
    final file = videoFiles[index];
    final dir = file.parent.path;
    final newPath = '$dir${Platform.pathSeparator}$newName';
    try {
      await file.rename(newPath);
      final oldPath = file.path;
      videoFiles[index] = File(newPath);
      if (index == currentIndex.value) update();
      final store = _progressStore;
      if (store != null) {
        final saved = await store.positionOf(oldPath);
        if (saved != null) {
          await store.save(newPath, saved);
          await store.clear(oldPath);
        }
      }
    } catch (_) {
      ToastUtil.show(i18n('local_player_rename_failed'));
    }
  }

  Future<void> deleteFile(int index) async {
    if (index < 0 || index >= videoFiles.length) return;
    final file = videoFiles[index];
    final wasActive = index == currentIndex.value;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      ToastUtil.show(i18n('local_player_delete_failed'));
      return;
    }
    await _progressStore?.clear(file.path);
    videoFiles.removeAt(index);
    if (videoFiles.isEmpty) {
      currentIndex.value = 0;
      update();
      return;
    }
    if (wasActive) {
      final nextIndex = index.clamp(0, videoFiles.length - 1);
      currentIndex.value = nextIndex;
      await _feed?.load(
        videoFiles
            .map(
              (f) =>
                  PlayerSource(id: SourceId(f.path), uri: f.uri, type: SourceType.file, title: f.uri.pathSegments.last),
            )
            .toList(),
        initialIndex: nextIndex,
      );
      unawaited(_loadDanmakuFor(nextIndex));
    } else if (index < currentIndex.value) {
      currentIndex.value--;
    }
    update();
  }

  /// Hands the current video to the in-app small window and leaves the page.
  ///
  /// The feed is the player's owner, and this controller dies with its route:
  /// without the handover the window would show a handle that the page's
  /// disposal released a frame later. [FloatingHandleKeeper] owns it from here
  /// until the window is expanded or closed.
  Future<void> enterFloating() async {
    final feed = _feed;
    final handle = feed?.handle;
    if (feed == null || handle == null || handle.disposed) return;
    await _savePosition();
    _handedToFloating = true;
    FloatingHandleKeeper.instance.own(
      handle.id.value,
      () async {
        // 关窗（✕）也要落一次盘：小窗期间没有那条 5 秒定时器在写进度（它随页面
        // 控制器一起销毁了），不落的话在小窗里看的这段位置就丢了。展开那条已经
        // 先落盘，这是另一半。
        await _savePosition();
        _feed?.dispose();
        _feed = null;
      },
      // Expanding the window means "give me the page back", so it reopens this
      // folder's player; the file itself resumes from the saved position.
      // That position has to be written *here*: the periodic saver died with the
      // page, so without this the reopened page resumes from the moment the
      // window was opened — and if the viewer floated inside the first five
      // seconds, the handover save removed the entry entirely and the recording
      // starts over from zero.
      onExpand: () async {
        await _savePosition();
        Get.toNamed(
          RoutePath.kLocalVideoPlayer,
          arguments: <String, dynamic>{'dir': directory, 'title': roomTitle, 'nick': roomNick},
        );
      },
    );
    await _kernel.enterFloating(handle.id);
    if (Get.currentRoute == RoutePath.kLocalVideoPlayer) Get.back();
  }

  /// The system picture-in-picture window, the same presentation the live room
  /// uses ("小窗播放" on Android, the compact always-on-top window on Windows).
  ///
  /// The transitions themselves are Core's ([enterSystemPip]); this only says
  /// which player and which picture shape they apply to.
  Future<void> enterPip() async {
    final handle = _feed?.handle;
    if (handle == null || handle.disposed) return;
    final size = handle.combinedSnapshot.geometry.videoSize;
    await enterSystemPip(
      _kernel,
      playerId: handle.id,
      videoWidth: size?.width.round() ?? 0,
      videoHeight: size?.height.round() ?? 0,
    );
  }

  /// "全屏观看": lock to landscape. The portrait layout shows the picture over
  /// a context panel; in landscape the same page renders the fullscreen shape
  /// (picture owns the screen), so an orientation lock is the whole transition.
  Future<void> enterLandscapeFullscreen() async {
    await WindowService().landScape();
  }

  /// Leaves picture-in-picture and restores the window.
  Future<void> exitPip() async {
    final handle = _feed?.handle;
    if (handle == null) return;
    await exitSystemPip(_kernel, playerId: handle.id);
  }

  // ---------------------------------------------------------------------------
  // PlayerUiController: what the shared Core player surface drives.
  // ---------------------------------------------------------------------------

  /// A recording has no room of its own, so the shared danmaku button toggles
  /// the global switch — the same one the danmaku settings panel shows.
  @override
  RxBool get danmakuHidden => SettingsService.to.danmaku.hideDanmaku;

  // The rest of [DanmakuSettingsSource]: a recording has no room overrides, so
  // every value is the global setting the danmaku panel edits.
  DanmakuSettingsController get _danmakuSettings => SettingsService.to.danmaku;

  @override
  RxBool get noEmojiMode => _danmakuSettings.noEmojiMode;

  @override
  RxDouble get danmakuArea => _danmakuSettings.danmakuArea;

  @override
  RxDouble get danmakuTopArea => _danmakuSettings.danmakuTopArea;

  @override
  RxDouble get danmakuBottomArea => _danmakuSettings.danmakuBottomArea;

  @override
  RxDouble get danmakuSpeed => _danmakuSettings.danmakuSpeed;

  @override
  RxDouble get danmakuFontSize => _danmakuSettings.danmakuFontSize;

  @override
  RxInt get danmakuFontWeight => _danmakuSettings.danmakuFontWeight;

  @override
  RxDouble get danmakuFontBorder => _danmakuSettings.danmakuFontBorder;

  @override
  RxBool get danmakuMassMode => _danmakuSettings.danmakuMassMode;

  @override
  RxDouble get danmakuLetterSpacing => _danmakuSettings.danmakuLetterSpacing;

  @override
  RxInt get danmakuMaxVisibleCount => _danmakuSettings.danmakuMaxVisibleCount;

  @override
  RxDouble get danmakuOpacity => _danmakuSettings.danmakuOpacity;

  @override
  RxBool get pipDanmakuScaleAuto => _danmakuSettings.pipDanmakuScaleAuto;

  @override
  RxDouble get pipDanmakuScaleValue => _danmakuSettings.pipDanmakuScaleValue;

  @override
  RxBool get enableDanmakuStroke => _danmakuSettings.enableDanmakuStroke;

  @override
  RxInt get danmakuFps => _danmakuSettings.danmakuFps;

  @override
  String? get danmakuFontFamilyName => _danmakuSettings.danmakuFontFamilyName.v;

  @override
  bool get uiIsPlaying => isPlaying.value;

  @override
  Duration get uiPosition => position.value;

  @override
  Duration get uiDuration => duration.value;

  @override
  double get uiRate => playbackRate.value;

  @override
  Future<void> uiPlay() async {
    await _feed?.play();
  }

  @override
  Future<void> uiPause() async {
    await _feed?.pause();
  }

  @override
  Future<void> uiSeekTo(Duration target) => seekTo(target);

  @override
  Future<void> uiSetRate(double rate) => setRate(rate);

  /// "Leave the picture" on a recording means the small window, which is what
  /// the live room's own exit control offers first (fullscreen is a separate
  /// button in the library's bar and stays available on its own).
  @override
  Future<bool> uiRequestExit() async {
    await enterFloating();
    return true;
  }

  @override
  Future<double?> uiVolume() async => _feed?.handle?.volume;

  @override
  Future<void> uiSetVolume(double value) async {
    try {
      await _feed?.handle?.setVolume(value.clamp(0.0, 1.0));
    } catch (_) {
      // 音量手势连续触发时，内核会把被新请求取代的旧写入以取消异常完成——
      // 这是"这条已过期"的正常信号，不是错误，不该打断手势或冒未处理异常。
    }
  }

  @override
  Future<double?> uiBrightness() async {
    if (!platformSupportsBrightness) return null;
    try {
      return await ScreenBrightnessPlatform.instance.application;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> uiSetBrightness(double value) async {
    if (!platformSupportsBrightness) return;
    try {
      await ScreenBrightnessPlatform.instance.setApplicationScreenBrightness(value.clamp(0.0, 1.0));
    } catch (_) {
      // A platform that refuses the write must not take the gesture down.
    }
  }

  @override
  bool get uiSupportsBrightnessGesture => platformSupportsBrightness;

  /// The replayed chat of the recording, drawn by the same Core renderer the
  /// live room uses.
  @override
  Widget? buildDanmakuSurface(BuildContext context) {
    if (!hasDanmaku.value || danmakuHidden.value) return null;
    return PlayerDanmakuSurface(controller: danmakuController, settings: this, isVerticalVideo: false);
  }

  /// Whether the feed now belongs to the small window rather than this page.
  bool _handedToFloating = false;

  /// 返回的统一语义（与直播间一致）：设置里开了"小窗播放"且正在播放时，
  /// 退出页面转交小窗。返回 true 表示真的离开页面。
  Future<bool> handleBackRequest() async {
    if (isClosed || _handedToFloating) return true;
    // Fullscreen first, page second: back leaves the fullscreen shape and
    // stays on the page, exactly like the live room. Only a page that is not
    // fullscreen is allowed to be left.
    if (fullscreenActive.value) {
      await exitFullscreen();
      return false;
    }
    final floatPlayEnabled = SettingsService.to.player.floatPlay.v;
    if (!floatPlayEnabled || !isPlaying.value) return true;
    _handedToFloating = true;
    await enterFloating();
    return false;
  }

  @override
  void onClose() {
    _pipStateSub?.cancel();
    _fullscreenStateSub?.cancel();
    if (_handedToFloating) {
      // The window is showing this feed: leave the handle and the position
      // saver alone, and keep the window up while the page disappears.
      _stateSub?.cancel();
      _transportSub?.cancel();
      _danmakuPlayer?.clear();
      super.onClose();
      return;
    }
    _positionSaver?.cancel();
    _controlsHideTimer?.cancel();
    unawaited(_savePosition());
    _stateSub?.cancel();
    _transportSub?.cancel();
    _danmakuPlayer?.clear();
    // Leave the small window before the handle goes away; an open overlay
    // pointing at a disposed player would linger showing black and never be
    // removed. exitFloating drives the driver back to normal, which hides the
    // host presenter's overlay entry.
    final openHandle = _feed?.handle;
    if (openHandle != null && !openHandle.disposed) {
      unawaited(_kernel.exitFloating(openHandle.id));
    }
    _feed?.dispose();
    _feed = null;
    super.onClose();
  }
}
