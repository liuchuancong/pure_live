import 'package:pure_live/player/core/playback_header_resolver.dart';

class FFmpegHeaderFactory {
  static Future<Map<String, String>> build({required String platform, String roomId = ''}) {
    return PlaybackHeaderResolver.resolve(platform: platform, roomId: roomId);
  }
}
