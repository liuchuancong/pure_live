import 'dart:developer' as developer;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/site/huya_site.dart';
import 'package:pure_live/core/site/bilibili_site.dart';
import 'package:pure_live/model/live_play_quality.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pure_live/player/utils/player_consts.dart';
import 'package:pure_live/modules/live_play/states/live_play_state.dart';
import 'package:pure_live/modules/live_play/controllers/player_state.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/video_controller.dart';

class PlayerController extends GetxController {
  PlayerController(this._main);

  final LivePlayController _main;
  late Site currentSite;

  LivePlayState get _state => _main.state.value;
  LiveRoom? get currentRoom => _state.room.detail;

  void initSite(Site site) {
    currentSite = site;
  }

  Future<Map<String, String>> getHeaders() async {
    Map<String, String> headers = {};

    if (currentSite.id == Sites.bilibiliSite) {
      final cookie = SettingsService.to.cookieManager.bilibiliCookie.v.trim();
      final roomId = currentRoom?.roomId ?? '';
      headers = {
        'user-agent': BiliBiliSite.kDefaultUserAgent,
        'origin': 'https://live.bilibili.com',
        'referer': 'https://live.bilibili.com/$roomId',
        if (cookie.isNotEmpty) 'cookie': cookie,
      };
    } else if (currentSite.id == Sites.huyaSite) {
      final ua = await HuyaSite().getHuYaUA();
      headers = {"user-agent": ua, "origin": "https://www.huya.com"};
    } else if (currentSite.id == Sites.iptvSite) {
      if (SettingsService.to.iptv.customIptvUserAgent.v.isNotEmpty) {
        headers = {"user-agent": SettingsService.to.iptv.customIptvUserAgent.v};
      }
    }

    return headers;
  }

  Future<void> setPlayer({required String roomId}) async {
    final room = currentRoom;
    if (room == null) return;

    final headers = await getHeaders();
    final playerState = _state.player;

    GlobalPlayerState().setCurrentRoom(roomId);

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
  }

  Future<void> getPlayQualites() async {
    try {
      final room = currentRoom;
      if (room == null) return;

      final playQualites = await currentSite.liveSite.getPlayQualites(detail: room);

      if (playQualites.isEmpty) {
        ToastUtil.show(i18n('cannot_read_video_info'));
        _main.updateRoom(success: false);
        return;
      }

      _main.updatePlayer(qualites: playQualites);

      if (!_state.player.hasUseDefaultResolution) {
        await _setDefaultResolution(playQualites);
      }

      await getPlayUrl();
    } catch (error, stackTrace) {
      developer.log(
        'Play quality loading failed (${error.runtimeType})',
        name: 'PlayerController',
        stackTrace: stackTrace,
      );
      ToastUtil.show(i18n('read_video_failed'));
      _main.updateRoom(success: false);
    }
  }

  Future<void> _setDefaultResolution(List<LivePlayQuality> playQualites) async {
    String userPrefer;
    final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

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

  Future<void> getPlayUrl() async {
    final room = currentRoom;
    if (room == null) return;

    final playerState = _state.player;
    if (playerState.qualites.isEmpty || playerState.currentQuality >= playerState.qualites.length) return;

    final playUrl = await currentSite.liveSite.getPlayUrls(
      detail: room,
      quality: playerState.qualites[playerState.currentQuality],
    );

    if (playUrl.isEmpty) {
      ToastUtil.show(i18n('cannot_read_play_url'));
      _main.updateRoom(success: false);
      return;
    }

    _main.updatePlayer(playUrls: playUrl);
    await setPlayer(roomId: room.roomId!);
    _main.updateRoom(success: true);
  }

  Future<void> changeCurrentRoomAudioOnly(bool value) async {
    if (_state.player.isCurrentRoomAudioOnly == value) return;
    await GlobalPlayerService.instance.playerManager.hardDispose();
    await destroyPlayer();
    _main.updatePlayer(isCurrentRoomAudioOnly: value);

    final room = currentRoom;
    if (room != null && _state.player.playUrls.isNotEmpty) {
      await setPlayer(roomId: room.roomId!);
      _main.updateRoom(success: true);
      return;
    }
    await _main.onInitPlayerState();
  }

  Future<void> destroyPlayer() async {
    await _state.player.videoController?.destory();
    _main.updatePlayer(videoController: null);
  }
}
