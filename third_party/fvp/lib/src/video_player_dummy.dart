import 'dart:typed_data';

import 'media_info_dummy.dart';

/// A dummy class for web
class MdkVideoPlayerPlatform {
  static void registerVideoPlayerPlatformsWith({dynamic options}) {}

  // for FVPController
  bool isLive(int playerId) {
    return false;
  }

  MediaInfo? getMediaInfo(int playerId) {
    return null;
  }

  void setProperty(int playerId, String name, String value) {}

  void setAudioDecoders(int playerId, List<String> value) {}

  void setVideoDecoders(int playerId, List<String> value) {}

  void record(int playerId, {String? to, String? format}) {}

  Future<Uint8List?> snapshot(int playerId, {int? width, int? height}) async {
    return null;
  }

  void setRange(int playerId, {required int from, int to = -1}) {}

  void setBufferRange(
    int playerId, {
    int min = -1,
    int max = -1,
    bool drop = false,
  }) {}

  Future<void> fastSeekTo(int playerId, Duration position) async {}

  Future<void> step(int playerId, int frames) async {}

  void setBrightness(int playerId, double value) {}

  void setContrast(int playerId, double value) {}

  void setHue(int playerId, double value) {}

  void setSaturation(int playerId, double value) {}

  void setProgram(int playerId, int programId) {}

  void setAudioTracks(int playerId, List<int> value) {}

  List<int>? getActiveAudioTracks(int playerId) {
    return null;
  }

  void setVideoTracks(int playerId, List<int> value) {}

  List<int>? getActiveVideoTracks(int playerId) {
    return null;
  }

  void setSubtitleTracks(int playerId, List<int> value) {}

  List<int>? getActiveSubtitleTracks(int playerId) {
    return null;
  }

  void setExternalAudio(int playerId, String uri) {}

  void setExternalVideo(int playerId, String uri) {}

  void setExternalSubtitle(int playerId, String uri) {}

  void onSubtitleText(
    int playerId,
    void Function(double start, double end, List<String> text)? callback,
  ) {}
}
