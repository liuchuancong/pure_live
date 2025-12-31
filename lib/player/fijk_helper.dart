import 'package:pure_live/common/index.dart';

/// FijkPlayer Helper
/// [FijkHelper]
class FijkHelper {
  /// setFijkOption
  /// [player]
  static Future<void> setFijkOption(FijkPlayer player, {enableCodec = true, Map<String, String>? headers}) async {
    await player.setOption(FijkOption.playerCategory, 'framedrop', 1);
    await player.setOption(FijkOption.playerCategory, 'mediacodec', enableCodec ? 1 : 0);
    await player.setOption(FijkOption.playerCategory, 'mediacodec-hevc', enableCodec ? 1 : 0);
    await player.setOption(FijkOption.playerCategory, 'videotoolbox', enableCodec ? 1 : 0);
    await player.setOption(FijkOption.playerCategory, 'enable-accurate-seek', 1);
    await player.setOption(FijkOption.hostCategory, "enable-background-play", 1);
    await player.setOption(FijkOption.playerCategory, "start-on-prepared", 1);
    await player.setOption(FijkOption.playerCategory, "mediacodec-all-videos", 1);
    await player.setOption(FijkOption.playerCategory, 'soundtouch', 1);
    await player.setOption(FijkOption.playerCategory, 'subtitle', 1);
    await player.setOption(FijkOption.hostCategory, "request-screen-on", 1);
    await player.setOption(FijkOption.hostCategory, "request-audio-focus", 1);
    // Set format
    await player.setOption(FijkOption.formatCategory, 'reconnect', 1);
    await player.setOption(FijkOption.formatCategory, 'timeout', 30 * 1000 * 1000);
    await player.setOption(FijkOption.formatCategory, 'fflags', 'fastseek');
    await player.setOption(FijkOption.formatCategory, 'rtsp_transport', 'tcp');
    await player.setOption(FijkOption.formatCategory, 'packet-buffering', 1);
    await player.setOption(FijkOption.playerCategory, "min-frames", 25);
    // Set request headers
    String requestHeaders = '';
    headers?.forEach((key, value) {
      key.toLowerCase() == 'user-agent'
          ? player.setOption(FijkOption.formatCategory, 'user_agent', value)
          : requestHeaders += '$key:$value\r\n';
    });
    player.setOption(FijkOption.formatCategory, 'headers', requestHeaders);
  }

  /// 播放器时间转字符串
  /// [duration]
  static String formatDuration(Duration duration) {
    if (duration.inMilliseconds < 0) return "-: negtive";

    String twoDigits(int n) {
      if (n >= 10) return '$n';
      return '0$n';
    }

    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    int inHours = duration.inHours;
    return inHours > 0 ? '$inHours:$twoDigitMinutes:$twoDigitSeconds' : '$twoDigitMinutes:$twoDigitSeconds';
  }

  static FijkFit getIjkBoxFit(BoxFit videoFit) {
    if (videoFit == BoxFit.contain) {
      return FijkFit.contain;
    } else if (videoFit == BoxFit.cover) {
      return FijkFit.cover;
    } else if (videoFit == BoxFit.fill) {
      return FijkFit.fill;
    } else if (videoFit == BoxFit.fitHeight) {
      return FijkFit.fitHeight;
    } else if (videoFit == BoxFit.fitWidth) {
      return FijkFit.fitWidth;
    } else {
      return FijkFit.contain;
    }
  }
}
