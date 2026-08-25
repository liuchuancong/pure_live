import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/core/player_manager.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/modules/live_play/states/load_type.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

typedef StreamSourceOpener = Future<void> Function(
  String url,
  List<String> playUrls,
  Map<String, String> headers,
  LiveRoom room,
  bool audioOnly,
);

@immutable
class StreamSelection {
  const StreamSelection({required this.qualityIndex, required this.lineIndex, required this.isValid});

  final int qualityIndex;
  final int lineIndex;
  final bool isValid;
}

/// Normalizes a selection made from a UI snapshot against the latest stream
/// metadata. A quality change can return a different number of CDN lines.
@visibleForTesting
StreamSelection resolveStreamSelection({
  required int qualityCount,
  required int playUrlCount,
  required int requestedQualityIndex,
  required int requestedLineIndex,
}) {
  if (qualityCount <= 0 || playUrlCount <= 0) {
    return const StreamSelection(qualityIndex: 0, lineIndex: 0, isValid: false);
  }
  return StreamSelection(
    qualityIndex: requestedQualityIndex.clamp(0, qualityCount - 1),
    lineIndex: requestedLineIndex.clamp(0, playUrlCount - 1),
    isValid: true,
  );
}

/// Maps a platform-acknowledged quality identifier back to the current UI
/// list. The requested index remains the fallback for adapters whose response
/// does not expose an applied quality.
@visibleForTesting
int resolveAppliedQualityIndex({
  required List<LivePlayQuality> qualities,
  required int requestedIndex,
  required Object? appliedQualityData,
}) {
  if (qualities.isEmpty) return 0;
  final fallback = requestedIndex.clamp(0, qualities.length - 1);
  if (appliedQualityData == null) return fallback;
  final applied = appliedQualityData.toString();
  final index = qualities.indexWhere((quality) => quality.selectionId.toString() == applied);
  return index < 0 ? fallback : index;
}

@visibleForTesting
List<LivePlayQuality> normalizePlayQualities(Iterable<LivePlayQuality> qualities) {
  final unique = <LivePlayQuality>[];
  final ids = <String>{};
  for (final quality in qualities) {
    if (quality.quality.trim().isEmpty || !ids.add(quality.selectionId.toString())) continue;
    unique.add(quality);
  }
  final labelCounts = <String, int>{};
  for (final quality in unique) {
    final label = quality.quality.trim();
    labelCounts.update(label, (count) => count + 1, ifAbsent: () => 1);
  }
  final labelOrdinals = <String, int>{};
  final result = unique.map((quality) {
    final label = quality.quality.trim();
    if (labelCounts[label] == 1) return quality;
    final ordinal = labelOrdinals.update(label, (value) => value + 1, ifAbsent: () => 1);
    return LivePlayQuality(quality: '$label $ordinal', id: quality.id, data: quality.data, sort: quality.sort);
  });
  return List<LivePlayQuality>.unmodifiable(result);
}

@visibleForTesting
bool hasSameStreamChoices(Iterable<String> current, Iterable<String> next) {
  final currentSet = current.map((url) => url.trim()).where((url) => url.isNotEmpty).toSet();
  final nextSet = next.map((url) => url.trim()).where((url) => url.isNotEmpty).toSet();
  return currentSet.isNotEmpty && currentSet.length == nextSet.length && currentSet.containsAll(nextSet);
}

abstract interface class PlayerSessionHost {
  Rx<LivePlayState> get state;

  bool get isClosed;

  void updateRoom({LiveRoom? detail, bool? isLiving, bool? success, bool? isLoading, String? loadError});

  void updatePlayer({
    VideoController? videoController,
    bool clearVideoController = false,
    List<LivePlayQuality>? qualites,
    int? currentQuality,
    List<String>? playUrls,
    int? currentLineIndex,
    bool? isCurrentRoomAudioOnly,
    bool? hasUseDefaultResolution,
  });

  Future<void> setCurrentRoomAudioOnlyFromUser(bool value);
}

class PlayerController extends GetxController {
  PlayerController(this._main, {StreamSourceOpener? streamSourceOpener})
    : _streamSourceOpener = streamSourceOpener ?? _openGlobalStream {
    _audioModeTransitions = LatestAsyncValueQueue<bool>(_applyCurrentRoomAudioOnly);
  }

  final PlayerSessionHost _main;
  final StreamSourceOpener _streamSourceOpener;
  late final LatestAsyncValueQueue<bool> _audioModeTransitions;
  late Site currentSite;
  int _loadEpoch = 0;
  int _streamSelectionEpoch = 0;
  final RxBool isStreamSwitching = false.obs;

  static Future<void> _openGlobalStream(
    String url,
    List<String> playUrls,
    Map<String, String> headers,
    LiveRoom room,
    bool audioOnly,
  ) {
    final manager = GlobalPlayerService.instance.player;
    return manager.play(url, playUrls, headers, room: room, audioOnly: audioOnly).then((_) {
      if (manager.hasError.value) {
        throw PlayerException(message: 'Selected stream failed to open', type: PlayerErrorType.source);
      }
    });
  }

  LivePlayState get _state => _main.state.value;
  LiveRoom? get currentRoom => _state.room.detail;

  void initSite(Site site) {
    currentSite = site;
  }

  void invalidateLoad() => _loadEpoch++;

  bool _isLoadCurrent(int epoch, LiveRoom room, Site site) {
    final current = currentRoom;
    return !_main.isClosed &&
        epoch == _loadEpoch &&
        currentSite.id == site.id &&
        current?.roomId == room.roomId &&
        current?.platform == room.platform;
  }

  /// 解析指定站点/房间的播放请求头（单一事实来源）。
  ///
  /// 主房间路径（[getHeaders]）与 multiview 每格解析器共用此入口，
  /// 保证 Cookie/UA/Referer 等鉴权头逻辑不发生漂移。
  static Future<Map<String, String>> resolvePlaybackHeaders({required Site site, required LiveRoom? room}) async {
    return PlaybackHeaderResolver.resolve(platform: site.id, roomId: room?.roomId ?? '');
  }

  Future<Map<String, String>> getHeaders({Site? expectedSite, LiveRoom? expectedRoom}) {
    return resolvePlaybackHeaders(site: expectedSite ?? currentSite, room: expectedRoom ?? currentRoom);
  }

  Future<VideoController?> setPlayer({
    required String roomId,
    LiveRoom? expectedRoom,
    Site? expectedSite,
    int? loadEpoch,
  }) async {
    final room = expectedRoom ?? currentRoom;
    if (room == null) return null;
    final site = expectedSite ?? currentSite;

    final headers = await getHeaders(expectedSite: site, expectedRoom: room);
    if (loadEpoch != null && !_isLoadCurrent(loadEpoch, room, site)) return null;
    final playerState = _state.player;

    // Refresh/line changes replace the route-scoped controller.  The previous
    // implementation only overwrote the Rx field, leaving its barrage engine,
    // paragraph/picture caches, timers and subscriptions alive for the rest of
    // the room session.  Tear it down before attaching the replacement.
    final previousController = playerState.videoController;
    if (previousController != null) {
      await previousController.destory();
      previousController.dispose();
      if (loadEpoch != null && !_isLoadCurrent(loadEpoch, room, site)) return null;
    }

    final videoController = VideoController(
      room: room,
      playUrs: playerState.playUrls,
      datasource: playerState.playUrlSafe,
      allowScreenKeepOn: SettingsService.to.app.enableScreenKeepOn.v,
      headers: headers,
      qualiteName: playerState.qualitySafe.quality,
      currentLineIndex: playerState.currentLineIndex,
      currentQuality: playerState.currentQuality,
      isAudioOnly: playerState.isCurrentRoomAudioOnly,
      onAudioOnlyChanged: _main.setCurrentRoomAudioOnlyFromUser,
    );

    _main.updatePlayer(videoController: videoController);
    return videoController;
  }

  /// Attaches a new route-scoped UI controller to the native player retained by
  /// [PlayerManager] while the app floating window was visible.
  ///
  /// No room endpoint or media source is opened here. The previous page's
  /// controller has already been disposed; only the global native player and
  /// immutable session metadata cross the route boundary.
  Future<VideoController?> attachCurrentSession(RoomSessionSnapshot session) async {
    final manager = GlobalPlayerService.instance.player;
    if (_main.isClosed || manager.currentPlayer == null || manager.currentFloatRoom != session.room) return null;

    final qualities = session.qualities.isEmpty
        ? <LivePlayQuality>[LivePlayQuality(quality: '原画')]
        : List<LivePlayQuality>.unmodifiable(session.qualities);
    final playUrls = session.playUrls.isEmpty && session.dataSource.isNotEmpty
        ? <String>[session.dataSource]
        : List<String>.unmodifiable(session.playUrls);
    final currentQuality = session.currentQuality.clamp(0, qualities.length - 1);
    final currentLineIndex = playUrls.isEmpty ? 0 : session.currentLineIndex.clamp(0, playUrls.length - 1);

    _main.updatePlayer(
      qualites: qualities,
      currentQuality: currentQuality,
      playUrls: playUrls,
      currentLineIndex: currentLineIndex,
      isCurrentRoomAudioOnly: manager.desiredAudioOnlyMode,
      hasUseDefaultResolution: session.hasUseDefaultResolution,
    );

    final videoController = VideoController(
      room: session.room,
      playUrs: playUrls,
      datasource: session.dataSource.isNotEmpty
          ? session.dataSource
          : (playUrls.isEmpty ? '' : playUrls[currentLineIndex]),
      allowScreenKeepOn: SettingsService.to.app.enableScreenKeepOn.v,
      headers: session.headers,
      qualiteName: qualities[currentQuality].quality,
      currentLineIndex: currentLineIndex,
      currentQuality: currentQuality,
      isAudioOnly: manager.desiredAudioOnlyMode,
      reuseCurrentSession: true,
      onAudioOnlyChanged: _main.setCurrentRoomAudioOnlyFromUser,
    );
    _main.updatePlayer(videoController: videoController);
    return videoController;
  }

  Future<void> getPlayQualites() async {
    final loadEpoch = ++_loadEpoch;
    final room = currentRoom;
    final site = currentSite;
    if (room == null) return;

    try {
      final playQualites = normalizePlayQualities(await site.liveSite.getPlayQualites(detail: room));
      if (!_isLoadCurrent(loadEpoch, room, site)) return;

      if (playQualites.isEmpty) {
        ToastUtil.show(i18n('cannot_read_video_info'));
        _main.updateRoom(success: false);
        return;
      }

      _main.updatePlayer(qualites: playQualites);

      if (!_state.player.hasUseDefaultResolution) {
        await _setDefaultResolution(playQualites, isCurrent: () => _isLoadCurrent(loadEpoch, room, site));
      }
      if (!_isLoadCurrent(loadEpoch, room, site)) return;

      await _getPlayUrl(loadEpoch: loadEpoch, room: room, site: site);
    } catch (error, stackTrace) {
      if (!_isLoadCurrent(loadEpoch, room, site)) return;
      developer.log(
        'Play quality loading failed (${error.runtimeType})',
        name: 'PlayerController',
        stackTrace: stackTrace,
      );
      ToastUtil.show(i18n('read_video_failed'));
      _main.updateRoom(success: false);
    }
  }

  Future<void> _setDefaultResolution(List<LivePlayQuality> playQualites, {required bool Function() isCurrent}) async {
    String userPrefer;
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
    if (!isCurrent()) return;

    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      userPrefer = SettingsService.to.player.preferResolutionCellular.v;
    } else {
      userPrefer = SettingsService.to.player.preferResolution.v;
    }

    final availableQualities = playQualites.map((e) => e.quality).toList();
    final matchedIndex = availableQualities.indexOf(userPrefer);

    if (matchedIndex != -1) {
      _main.updatePlayer(currentQuality: matchedIndex, hasUseDefaultResolution: true);
      return;
    }

    final systemResolutions = PlayerConsts.resolutions;
    final preferLevel = systemResolutions.indexOf(userPrefer);
    final preferRatio = preferLevel / (systemResolutions.length - 1);
    final targetIndex = (preferRatio * (availableQualities.length - 1)).round().clamp(0, availableQualities.length - 1);

    _main.updatePlayer(currentQuality: targetIndex, hasUseDefaultResolution: true);
  }

  Future<void> _getPlayUrl({required int loadEpoch, required LiveRoom room, required Site site}) async {
    if (!_isLoadCurrent(loadEpoch, room, site)) return;
    final playerState = _state.player;
    if (playerState.qualites.isEmpty || playerState.currentQuality >= playerState.qualites.length) return;

    final resolution = await site.liveSite.resolvePlayUrls(
      detail: room,
      quality: playerState.qualites[playerState.currentQuality],
    );
    if (!_isLoadCurrent(loadEpoch, room, site)) return;

    if (resolution.urls.isEmpty) {
      ToastUtil.show(i18n('cannot_read_play_url'));
      _main.updateRoom(success: false);
      return;
    }

    final appliedQuality = resolveAppliedQualityIndex(
      qualities: playerState.qualites,
      requestedIndex: playerState.currentQuality,
      appliedQualityData: resolution.appliedQualityData,
    );
    final lineIndex = playerState.currentLineIndex.clamp(0, resolution.urls.length - 1);
    _main.updatePlayer(
      playUrls: List<String>.unmodifiable(resolution.urls),
      currentQuality: appliedQuality,
      currentLineIndex: lineIndex,
    );
    final controller = await setPlayer(
      roomId: room.roomId!,
      expectedRoom: room,
      expectedSite: site,
      loadEpoch: loadEpoch,
    );
    if (controller == null || !_isLoadCurrent(loadEpoch, room, site)) return;
    _main.updateRoom(success: true);
  }

  /// Changes quality or CDN line on the active native player without
  /// refetching room metadata or destroying the route-scoped controller.
  ///
  /// The current stream remains active while a new quality URL is resolved.
  /// Rapid taps are latest-wins and the chosen line is clamped against the URL
  /// count returned by the newly selected quality.
  Future<bool> switchStreamSelection({
    required ReloadDataType type,
    required int qualityIndex,
    required int lineIndex,
  }) async {
    if (type != ReloadDataType.changeQuality && type != ReloadDataType.changeLine) return false;

    final room = currentRoom;
    final site = currentSite;
    final before = _state.player;
    if (room == null || before.qualites.isEmpty || before.playUrls.isEmpty) return false;

    final requestedQuality = type == ReloadDataType.changeLine
        ? before.currentQuality.clamp(0, before.qualites.length - 1)
        : qualityIndex.clamp(0, before.qualites.length - 1);
    if (requestedQuality == before.currentQuality && lineIndex == before.currentLineIndex) return true;

    final selectionEpoch = ++_streamSelectionEpoch;
    final loadEpoch = ++_loadEpoch;
    isStreamSwitching.value = true;

    try {
      final resolution = type == ReloadDataType.changeQuality
          ? await site.liveSite.resolvePlayUrls(detail: room, quality: before.qualites[requestedQuality])
          : LivePlayUrlResolution(
              urls: List<String>.from(before.playUrls),
              appliedQualityData: before.qualites[before.currentQuality].selectionId,
            );
      if (!_isLoadCurrent(loadEpoch, room, site) || selectionEpoch != _streamSelectionEpoch) return false;
      final urls = resolution.urls;
      if (urls.isEmpty) {
        ToastUtil.show(i18n('cannot_read_play_url'));
        return false;
      }

      final appliedQuality = resolveAppliedQualityIndex(
        qualities: before.qualites,
        requestedIndex: requestedQuality,
        appliedQualityData: resolution.appliedQualityData,
      );
      final qualityAdjusted = type == ReloadDataType.changeQuality && appliedQuality != requestedQuality;
      if (qualityAdjusted && appliedQuality == before.currentQuality) {
        ToastUtil.show(i18n('quality_limited_to', args: {'quality': before.qualites[appliedQuality].quality}));
        return false;
      }

      final selection = resolveStreamSelection(
        qualityCount: before.qualites.length,
        playUrlCount: urls.length,
        requestedQualityIndex: appliedQuality,
        requestedLineIndex: lineIndex,
      );
      if (!selection.isValid) return false;
      if (type == ReloadDataType.changeQuality &&
          selection.qualityIndex != before.currentQuality &&
          hasSameStreamChoices(before.playUrls, urls)) {
        ToastUtil.show(i18n('quality_stream_unchanged'));
        return false;
      }

      final cachedHeaders = before.videoController?.headers;
      final headers = cachedHeaders == null || cachedHeaders.isEmpty
          ? await getHeaders(expectedSite: site, expectedRoom: room)
          : Map<String, String>.from(cachedHeaders);
      if (!_isLoadCurrent(loadEpoch, room, site) || selectionEpoch != _streamSelectionEpoch) return false;

      final immutableUrls = List<String>.unmodifiable(urls);
      await _streamSourceOpener(
        immutableUrls[selection.lineIndex],
        immutableUrls,
        Map<String, String>.unmodifiable(headers),
        room,
        _state.player.isCurrentRoomAudioOnly,
      );
      if (!_isLoadCurrent(loadEpoch, room, site) || selectionEpoch != _streamSelectionEpoch) return false;
      _main.updatePlayer(
        currentQuality: selection.qualityIndex,
        playUrls: immutableUrls,
        currentLineIndex: selection.lineIndex,
        hasUseDefaultResolution: true,
      );
      _main.updateRoom(success: true, isLoading: false, loadError: null);
      if (qualityAdjusted) {
        ToastUtil.show(i18n('quality_limited_to', args: {'quality': before.qualites[selection.qualityIndex].quality}));
      }
      return true;
    } catch (error, stackTrace) {
      if (_isLoadCurrent(loadEpoch, room, site) && selectionEpoch == _streamSelectionEpoch) {
        _main.updatePlayer(
          currentQuality: before.currentQuality,
          playUrls: before.playUrls,
          currentLineIndex: before.currentLineIndex,
          hasUseDefaultResolution: before.hasUseDefaultResolution,
        );
        developer.log(
          'Stream selection failed (${error.runtimeType})',
          name: 'PlayerController',
          error: error,
          stackTrace: stackTrace,
        );
        ToastUtil.show(i18n('read_video_failed'));
      }
      return false;
    } finally {
      if (selectionEpoch == _streamSelectionEpoch) isStreamSwitching.value = false;
    }
  }

  Future<void> changeCurrentRoomAudioOnly(bool value) async {
    await _audioModeTransitions.submit(value);
  }

  Future<void> _applyCurrentRoomAudioOnly(bool value) async {
    if (_state.player.isCurrentRoomAudioOnly == value) return;
    final controller = _state.player.videoController;
    final room = currentRoom;
    final previous = _state.player.isCurrentRoomAudioOnly;

    try {
      if (controller == null) {
        throw PlayerException(message: 'Room video controller is null', type: PlayerErrorType.lifecycle);
      }
      await controller.changeAudioOnlyMode(value);

      // The route may have been popped while the native call was pending.
      if (_main.isClosed || !identical(_state.player.videoController, controller) || currentRoom != room) return;
      _main.updatePlayer(isCurrentRoomAudioOnly: controller.isAudioOnly);
      _main.updateRoom(success: true, isLoading: false);
    } catch (error, stackTrace) {
      developer.log('Audio mode switch failed', name: 'PlayerController', error: error, stackTrace: stackTrace);
      if (!_main.isClosed && identical(_state.player.videoController, controller) && currentRoom == room) {
        _main.updatePlayer(isCurrentRoomAudioOnly: previous);
        _main.updateRoom(success: true, isLoading: false);
        ToastUtil.show(i18n('error_lifecycle'));
      }
    }
  }

  Future<void> destroyPlayer() async {
    invalidateLoad();
    final controller = _state.player.videoController;
    await controller?.destory();
    controller?.dispose();
    _main.updatePlayer(clearVideoController: true);
  }

  @override
  void onClose() {
    _streamSelectionEpoch++;
    isStreamSwitching.value = false;
    invalidateLoad();
    super.onClose();
  }
}
