import 'dart:io';

class FFmpegCommandBuilder {
  static String _quote(String value) {
    final escaped = value.replaceAll('"', r'\"');
    return '"$escaped"';
  }

  /// 本地音频流 HTTP Server
  static String buildAudioStreamCommand({
    required String remoteStreamUrl,
    required int port,
    int rwTimeout = 15,
    Map<String, String>? headers,
  }) {
    final ua = headers?['user-agent'];
    final headerStr = _buildHeader(headers);

    final rwTimeoutMicro = (rwTimeout * 1000000).clamp(0, 2147483647);

    final args = <String>[
      // 基础
      '-hide_banner',
      '-loglevel', 'info',

      // 重连
      '-reconnect', '1',
      '-reconnect_streamed', '1',
      '-reconnect_delay_max', '10',
      '-reconnect_at_eof', '1',

      // 网络
      '-rw_timeout', rwTimeoutMicro.toString(),

      // UA
      if (ua != null && ua.isNotEmpty) ...['-user_agent', _quote(ua)],

      // Headers
      if (headerStr.isNotEmpty) ...['-headers', _quote(headerStr)],
      // 仅音频
      '-select_streams', 'a',
      '-allowed_extensions', 'ALL',
      // 输入流
      '-i', remoteStreamUrl,
      '-map', '0:a',
      '-vn',
      '-acodec', 'copy',
      '-listen', '1',
      // 输出 MPEGTS HTTP Server
      '-f', 'mpegts',
      'http://0.0.0.0:$port/live.ts',
    ];

    return args.join(' ');
  }

  static String buildRecordCommand({
    required String url,
    required String outputDir,
    required int segmentTime,
    required bool preferBestStream,
    required int rwTimeout,
    required int threadQueueSize,
    Map<String, String>? headers,
  }) {
    final ua = headers?['user-agent'];
    final headerStr = _buildHeader(headers);
    final normalizedOutputPath = '$outputDir${Platform.pathSeparator}%Y%m%d_%H%M%S.ts';
    final rwTimeoutMicro = (rwTimeout * 1000000).clamp(0, 2147483647);

    final args = <String>[
      '-y',
      '-hide_banner',
      '-loglevel', 'info',
      '-analyzeduration', '1000000',
      '-probesize', '1048576',
      '-fflags', 'igndts+genpts+nobuffer+flush_packets+fastseek',
      '-flags', 'low_delay',
      '-seekable', '1',
      '-protocol_whitelist', 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto',
      '-reconnect', '1',
      '-reconnect_streamed', '1',
      '-reconnect_delay_max', '10',
      '-reconnect_at_eof', '1',
      '-rw_timeout', rwTimeoutMicro.toString(),
      '-max_delay', '5000000',
      '-thread_queue_size', threadQueueSize.toString(),
      if (ua != null && ua.isNotEmpty) ...['-user_agent', _quote(ua)], //ua
      if (headerStr.isNotEmpty) ...['-headers', _quote(headerStr)], //headers
      '-i', url,
      '-map', preferBestStream ? '0:v:0' : '0:v',
      '-map', preferBestStream ? '0:a:0' : '0:a',
      '-c', 'copy',
      '-f', 'segment',
      '-segment_format', 'mpegts',
      '-segment_time', segmentTime.toString(),
      '-reset_timestamps', '1',
      '-strftime', '1',
      normalizedOutputPath,
    ];

    return args.join(' ');
  }

  static String _buildHeader(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return '';
    final lines = headers.entries
        .where((e) => e.key.toLowerCase() != 'user-agent')
        .map((e) => '${e.key}: ${e.value}')
        .join('\r\n');
    return lines.isEmpty ? '' : '$lines\r\n';
  }
}
