
import 'dart:io';

import 'package:gsy_video_player/gsy_video_player.dart';
import 'package:pure_live/common/l10n/generated/l10n.dart';

import 'fvp_video_play.dart';
import 'gsy_video_play.dart';
import 'mpv_video_play.dart';
import 'video_play_impl.dart';

final class VideoPlayerFactory{
  static List<VideoPlayerInterFace> allVideoPlayerList() {
    var list = <VideoPlayerInterFace>[
      GsyVideoPlay(playerName: "Exo ${S.current.player}", playerType: GsyVideoPlayerType.exo),
      GsyVideoPlay(playerName: "${S.current.player_system} ${S.current.player}", playerType: GsyVideoPlayerType.sysytem),
      GsyVideoPlay(playerName: "IJK ${S.current.player}", playerType: GsyVideoPlayerType.ijk),
      GsyVideoPlay(playerName: "${S.current.player_ali} ${S.current.player}", playerType: GsyVideoPlayerType.ali),
      MpvVideoPlay(playerName: "MPV ${S.current.player}",),
      FvpVideoPlay(playerName: "FVP ${S.current.player}",),
    ];
    return list;
  }

  static List<VideoPlayerInterFace> getSupportVideoPlayerList() {
    return allVideoPlayerList().where((videoPlayer)=>videoPlayer.supportPlatformList.contains(Platform.operatingSystem))
        .toList();
  }

}