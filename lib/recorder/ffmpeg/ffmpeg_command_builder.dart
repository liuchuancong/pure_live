import 'dart:io';

class FFmpegCommandBuilder {
  static const String defaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";
  static String _quote(String value) {
    final escaped = value.replaceAll('"', r'\"');
    return '"$escaped"';
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
    final ua = headers?['user-agent'] ?? defaultUserAgent;
    final headerStr = _buildHeader(headers);
    final normalizedOutputPath = '$outputDir${Platform.pathSeparator}%Y%m%d_%H%M%S.ts';
    final args = <String>[
      '-y',
      '-hide_banner',
      '-loglevel', 'info',
      // 允许的协议白名单，确保直播流能正常加载
      '-protocol_whitelist', 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto',

      // --- 重连与网络优化 ---
      '-reconnect', '1',
      '-reconnect_streamed', '1',
      '-reconnect_delay_max', '2',
      '-reconnect_at_eof', '1',
      '-rw_timeout', '${rwTimeout * 1000000}', // 转化为微秒
      '-max_delay', '5000000',
      '-thread_queue_size', threadQueueSize.toString(),

      // --- 身份伪装 ---
      '-user_agent', _quote(ua),
      if (headerStr.isNotEmpty) ...['-headers', _quote(headerStr)], // headers
      // --- 输入 ---
      '-i', _quote(url),

      // --- 轨道处理 ---
      '-map', preferBestStream ? '0:v:0' : '0:v',
      '-map', preferBestStream ? '0:a:0' : '0:a',
      '-c', 'copy',

      '-f', 'segment',
      '-segment_format', 'mpegts',
      '-segment_time', segmentTime.toString(),
      '-reset_timestamps', '1',
      '-strftime', '1',

      _quote(normalizedOutputPath),
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
