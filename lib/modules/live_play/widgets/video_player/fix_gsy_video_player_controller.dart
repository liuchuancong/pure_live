import 'dart:ui';

import 'package:gsy_video_player/gsy_video_player.dart';
import 'package:pure_live/core/common/core_log.dart';

class FixGsyVideoPlayerController extends GsyVideoPlayerController {
  FixGsyVideoPlayerController({super.allowBackgroundPlayback, super.player});

  @override
  Future<void> pause() async {
    try {
      await super.pause();
    } catch (e) {
      CoreLog.error(e);
    }
  }

  @override
  playOrPause() async {
    try {
      await super.playOrPause();
    } catch (e) {
      CoreLog.error(e);
    }
  }

  @override
  Future<void> resume() async {
    try {
      await super.resume();
    } catch (e) {
      CoreLog.error(e);
    }
  }


  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!value.allowBackgroundPlayback) {
      if ([
        AppLifecycleState.paused,
        AppLifecycleState.detached,
      ].contains(state)) {
        if (value.isPlaying) {
          pause();
        }
      } else if (state == AppLifecycleState.resumed) {
        if (!value.isPlaying) {
          resume();
        }
      }
    }
  }

}
