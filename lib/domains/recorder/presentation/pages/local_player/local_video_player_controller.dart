import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:media_core/media_core.dart' hide PlatformUtils;
import 'package:media_core_feed/media_core_feed.dart';
import 'package:media_core_list_playback/media_core_list_playback.dart';
import 'package:pure_live/core/index.dart';
import 'package:pure_live/core/platform/file_utils.dart';
import 'package:pure_live/core/platform/platform_utils.dart';
import 'package:pure_live/core/player/kernel/floating_handle_keeper.dart';
import 'package:pure_live/core/player/kernel/player_kernel_service.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';

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

final class LocalVideoPlayerController extends GetxController {
  LocalVideoPlayerController({required this.directory, this.roomTitle, this.roomNick});

  final String directory;
  final String? roomTitle;
  final String? roomNick;

  static const _videoExtensions = {'.mp4', '.mkv', '.flv', '.ts', '.avi', '.mov', '.webm', '.m4v'};
  static const _progressKeyPrefix = 'local_player_progress_';
  static const defaultRates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  final List<File> videoFiles = <File>[];
  final currentIndex = 0.obs;
  final isLoading = true.obs;
  final isPlaying = false.obs;
  final playbackRate = 1.0.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;

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

  @override
  void onInit() {
    super.onInit();
    _progressStore = HivePlaybackProgressStore('$_progressKeyPrefix$directory');
    _scanAndOpen();
  }

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
          (f) => PlayerSource(
            id: SourceId(f.path),
            uri: f.uri,
            type: SourceType.file,
            title: f.uri.pathSegments.last,
          ),
        )
        .toList();

    _feed = FeedPlayerController(_kernel, preloadAhead: !PlatformUtils.isMobile);
    _stateSub = _feed!.onItemStateChanged.listen(_onItemState);
    _transportSub = _feed!.onPlaybackStateChanged.listen(_onTransport);
    _feed!.onIndexChanged.listen((i) => currentIndex.value = i);

    final initialIndex = await _resumeIndex();
    await _feed!.load(sources, initialIndex: initialIndex);
    currentIndex.value = initialIndex;

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

  Future<void> resumePosition() async {
    final store = _progressStore;
    final handle = _feed?.handle;
    if (store == null || handle == null || videoFiles.isEmpty) return;
    final file = videoFiles[currentIndex.value];
    final saved = await store.positionOf(file.path);
    if (saved != null && saved.inSeconds > 5 && saved < handle.duration - const Duration(seconds: 10)) {
      await handle.seek(saved);
    }
  }

  void _onItemState(FeedItemState state) {
    isPlaying.value = state == FeedItemState.playing;
    if (state == FeedItemState.playing) {
      unawaited(resumePosition());
    }
  }

  void _onTransport(PlayerTransportState transport) {
    position.value = transport.position;
    duration.value = transport.duration;
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
    await handle.seek(clamped);
  }

  Future<void> setRate(double rate) async {
    playbackRate.value = rate;
    await _feed?.handle?.setRate(rate);
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
            .map((f) => PlayerSource(id: SourceId(f.path), uri: f.uri, type: SourceType.file, title: f.uri.pathSegments.last))
            .toList(),
        initialIndex: nextIndex,
      );
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
        _feed?.dispose();
        _feed = null;
      },
      // Expanding the window means "give me the page back", so it reopens this
      // folder's player; the file itself resumes from the saved position.
      onExpand: () async {
        Get.toNamed(
          RoutePath.kLocalVideoPlayer,
          arguments: <String, dynamic>{'dir': directory, 'title': roomTitle, 'nick': roomNick},
        );
      },
    );
    await _kernel.enterFloating(handle.id);
    if (Get.currentRoute == RoutePath.kLocalVideoPlayer) Get.back();
  }

  /// Whether the feed now belongs to the small window rather than this page.
  bool _handedToFloating = false;

  @override
  void onClose() {
    if (_handedToFloating) {
      // The window is showing this feed: leave the handle and the position
      // saver alone, and keep the window up while the page disappears.
      _stateSub?.cancel();
      _transportSub?.cancel();
      super.onClose();
      return;
    }
    _positionSaver?.cancel();
    unawaited(_savePosition());
    _stateSub?.cancel();
    _transportSub?.cancel();
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
