import 'package:audio_service/audio_service.dart';

class MyAudioHandler extends BaseAudioHandler {
  // 更新播放状态
  void updateState(bool playing) {
    playbackState.add(
      playbackState.value.copyWith(
        controls: [], // 不显示任何【播放/暂停】按钮
        systemActions: {}, // 不响应系统手势
        playing: playing,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> stop() async {
    // 退出播放时彻底清除媒体状态
    playbackState.add(playbackState.value.copyWith(playing: false, processingState: AudioProcessingState.idle));
    await super.stop();
  }
}
