import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/huya_site.dart';
import 'package:pure_live/core/site/bilibili_site.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/player/models/player_exception.dart';
import 'package:pure_live/player/models/player_error_type.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';
import 'package:pure_live/common/utils/latest_async_value_queue.dart';

abstract interface class PlayerSessionHost {
  Rx<LivePlayState> get state;

  bool get isClosed;

  void updateRoom({LiveRoom? detail, bool? isLiving, bool? success, bool? isLoading, String? loadError});

  void updatePlayer({
    VideoController? videoController,
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
  PlayerController(this._main) {
    _audioModeTransitions = LatestAsyncValueQueue<bool>(_applyCurrentRoomAudioOnly);
  }

  final PlayerSessionHost _main;
  late final LatestAsyncValueQueue<bool> _audioModeTransitions;
  late Site currentSite;
  int _loadEpoch = 0;

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

  Future<Map<String, String>> getHeaders({Site? expectedSite, LiveRoom? expectedRoom}) async {
    Map<String, String> headers = {};
    final site = expectedSite ?? currentSite;
    final room = expectedRoom ?? currentRoom;

    if (site.id == Sites.bilibiliSite) {
      final cookie = SettingsService.to.cookieManager.bilibiliCookie.v.trim();
      final roomId = room?.roomId ?? '';
      headers = {
        'user-agent': BiliBiliSite.kDefaultUserAgent,
        'origin': 'https://live.bilibili.com',
        'referer': 'https://live.bilibili.com/$roomId',
        if (cookie.isNotEmpty) 'cookie': cookie,
      };
    } else if (site.id == Sites.huyaSite) {
      final ua = await HuyaSite().getHuYaUA();
      headers = {"user-agent": ua, "origin": "https://www.huya.com"};
    } else if (site.id == Sites.iptvSite) {
      if (SettingsService.to.iptv.customIptvUserAgent.v.isNotEmpty) {
        headers = {"user-agent": SettingsService.to.iptv.customIptvUserAgent.v};
      }
    }

    return headers;
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

  Future<void> getPlayQualites() async {
    final loadEpoch = ++_loadEpoch;
    final room = currentRoom;
    final site = currentSite;
    if (room == null) return;

    try {
      final playQualites = await site.liveSite.getPlayQualites(detail: room);
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

    final playUrl = await site.liveSite.getPlayUrls(
      detail: room,
      quality: playerState.qualites[playerState.currentQuality],
    );
    if (!_isLoadCurrent(loadEpoch, room, site)) return;

    if (playUrl.isEmpty) {
      ToastUtil.show(i18n('cannot_read_play_url'));
      _main.updateRoom(success: false);
      return;
    }

    _main.updatePlayer(playUrls: playUrl);
    final controller = await setPlayer(
      roomId: room.roomId!,
      expectedRoom: room,
      expectedSite: site,
      loadEpoch: loadEpoch,
    );
    if (controller == null || !_isLoadCurrent(loadEpoch, room, site)) return;
    _main.updateRoom(success: true);
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
    await _state.player.videoController?.destory();
    _main.updatePlayer(videoController: null);
  }

  @override
  void onClose() {
    invalidateLoad();
    super.onClose();
  }
}
