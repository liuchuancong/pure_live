import 'dart:io';

class FFmpegCommandBuilder {
  static const String defaultUserAgent =
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

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
      '-rw_timeout', '${rwTimeout * 1000000}', // 转化为微秒
      '-max_delay', '5000000',
      '-thread_queue_size', threadQueueSize.toString(),

      // --- 身份伪装 ---
      '-user_agent', ua,
      if (headerStr.isNotEmpty) ...['-headers', "'$headerStr'"], // 关键：headers必须包裹在引号内
      // --- 输入 ---
      '-i', '"$url"',

      // --- 轨道处理 ---
      // 使用 copy 模式避免 CPU 占用过高
      '-map', preferBestStream ? '0:v:0' : '0:v',
      '-map', preferBestStream ? '0:a:0' : '0:a',
      '-c', 'copy',

      // --- 分段逻辑 ---
      '-f', 'segment',
      '-segment_time', segmentTime.toString(),
      '-reset_timestamps', '1',
      '-strftime', '1',

      // 输出路径 (使用 .ts 格式以防断流导致文件损坏)
      '$outputDir${Platform.pathSeparator}%Y%m%d_%H%M%S.ts',
    ];

    return args.join(' ');
  }

  static String _buildHeader(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return '';
    final lines = headers.entries
        .where((e) => e.key.toLowerCase() != 'user-agent')
        .map((e) => '${e.key}: ${e.value}')
        .join('\r\n');

    // FFmpeg 要求 headers 末尾也必须有换行符
    return lines.isEmpty ? '' : '$lines\r\n';
  }
}
