import 'package:pure_live/common/index.dart';

class FijkHelper {
  static Future<void> setFijkOption(
    FijkPlayer player, {
    bool enableHardwareCodec = false,
    Map<String, String>? headers,
  }) async {
    await player.setOption(FijkOption.playerCategory, 'mediacodec', enableHardwareCodec ? 1 : 0);

    await player.setOption(
      FijkOption.playerCategory,
      'mediacodec-hevc',
      enableHardwareCodec ? 1 : 0,
    );

    await player.setOption(FijkOption.playerCategory, 'min-frames', 50);

    await player.setOption(FijkOption.playerCategory, 'framedrop', 0);

    await player.setOption(FijkOption.playerCategory, 'enable-accurate-seek', 1);

    await player.setOption(FijkOption.playerCategory, 'soundtouch', 1);

    await player.setOption(FijkOption.playerCategory, 'subtitle', 1);

    await player.setOption(FijkOption.hostCategory, 'request-screen-on', 1);

    await player.setOption(FijkOption.hostCategory, 'request-audio-focus', 0);

    await player.setOption(FijkOption.formatCategory, 'reconnect', 1);

    await player.setOption(FijkOption.formatCategory, 'reconnect_delay_max', 5);

    await player.setOption(FijkOption.formatCategory, 'timeout', 15 * 1000 * 1000);

    await player.setOption(FijkOption.formatCategory, 'fflags', 'fastseek');

    await player.setOption(FijkOption.formatCategory, 'rtsp_transport', 'tcp');

    await player.setOption(
      FijkOption.formatCategory,
      'protocol_whitelist',
      'async,cache,crypto,file,http,https,ijkhttphook,ijkinject,ijklivehook,ijklongurl,ijksegment,ijktcphook,pipe,rtp,tcp,tls,udp,ijkurlhook,data',
    );

    String requestHeaders = '';

    headers?.forEach((key, value) {
      if (key.toLowerCase() == 'user-agent') {
        player.setOption(FijkOption.formatCategory, 'user_agent', value);
      } else {
        requestHeaders += '$key:$value\r\n';
      }
    });

    if (requestHeaders.isNotEmpty) {
      await player.setOption(FijkOption.formatCategory, 'headers', requestHeaders);
    }
  }

  static String formatDuration(Duration duration) {
    if (duration.inMilliseconds < 0) {
      return '-: negtive';
    }

    String twoDigits(int n) {
      if (n >= 10) return '$n';
      return '0$n';
    }

    final twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    final twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    final inHours = duration.inHours;

    return inHours > 0
        ? '$inHours:$twoDigitMinutes:$twoDigitSeconds'
        : '$twoDigitMinutes:$twoDigitSeconds';
  }

  static FijkFit getIjkBoxFit(BoxFit videoFit) {
    if (videoFit == BoxFit.contain) {
      return FijkFit.contain;
    }

    if (videoFit == BoxFit.cover) {
      return FijkFit.cover;
    }

    if (videoFit == BoxFit.fill) {
      return FijkFit.fill;
    }

    if (videoFit == BoxFit.fitHeight) {
      return FijkFit.fitHeight;
    }

    if (videoFit == BoxFit.fitWidth) {
      return FijkFit.fitWidth;
    }

    return FijkFit.contain;
  }
}
