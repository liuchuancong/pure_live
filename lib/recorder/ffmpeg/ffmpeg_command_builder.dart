import 'dart:io';

import 'package:pure_live/common/global/platform_utils.dart';

class FFmpegCommandBuilder {
  static const String _protocolWhitelist = 'httpproxy,udp,rtp,tcp,tls,data,file,http,https,crypto';

  static String quoteArgument(String value) {
    final escaped = value.replaceAll('\r', '').replaceAll('\n', '').replaceAll('"', r'\"');
    return '"$escaped"';
  }

  /// 本地音频流 HTTP Server
  static String buildAudioStreamCommand({
    required String remoteStreamUrl,
    required int port,
    int rwTimeout = 15,
    Map<String, String>? headers,
  }) {
    return formatArguments(
      buildAudioStreamArguments(remoteStreamUrl: remoteStreamUrl, port: port, rwTimeout: rwTimeout, headers: headers),
    );
  }

  static List<String> buildAudioStreamArguments({
    required String remoteStreamUrl,
    required int port,
    int rwTimeout = 15,
    Map<String, String>? headers,
  }) {
    final ua = headers?['user-agent'];
    final headerStr = _buildHeader(headers);
    final rwTimeoutMicro = (rwTimeout * 1000000).clamp(0, 2147483647);

    final args = <String>[
      '-hide_banner',
      '-loglevel',
      'info',
      if (PlatformUtils.isAndroid) ...['-tls_verify', '0'],
      '-reconnect',
      '1',
      '-reconnect_streamed',
      '1',
      '-reconnect_delay_max',
      '10',
      '-reconnect_at_eof',
      '1',
      '-rw_timeout',
      rwTimeoutMicro.toString(),
      if (ua != null && ua.isNotEmpty) ...['-user_agent', quoteArgument(ua)],
      if (headerStr.isNotEmpty) ...['-headers', quoteArgument(headerStr)],
      '-i',
      quoteArgument(remoteStreamUrl),
      '-map',
      '0:a',
      '-vn',
      '-acodec',
      'copy',
      '-listen',
      '1',
      '-f',
      'mpegts',
      'http://0.0.0.0:$port/live.ts',
    ];

    return List<String>.unmodifiable(args);
  }

  static String buildRecordCommand({
    required String url,
    required String outputDir,
    required int segmentTime,
    required bool preferBestStream,
    required int rwTimeout,
    required int threadQueueSize,
    String? filePrefix,
    Map<String, String>? headers,
  }) {
    return formatArguments(
      buildRecordArguments(
        url: url,
        outputDir: outputDir,
        segmentTime: segmentTime,
        preferBestStream: preferBestStream,
        rwTimeout: rwTimeout,
        threadQueueSize: threadQueueSize,
        filePrefix: filePrefix,
        headers: headers,
      ),
    );
  }

  static List<String> buildRecordArguments({
    required String url,
    required String outputDir,
    required int segmentTime,
    required bool preferBestStream,
    required int rwTimeout,
    required int threadQueueSize,
    String? filePrefix,
    Map<String, String>? headers,
  }) {
    final ua = headers?['user-agent'];
    final headerStr = _buildHeader(headers);

    String fileNamePattern;
    if (filePrefix != null && filePrefix.isNotEmpty) {
      fileNamePattern = '${filePrefix}_%Y%m%d_%H%M%S.ts';
    } else {
      fileNamePattern = '%Y%m%d_%H%M%S.ts';
    }

    final normalizedOutputPath = '$outputDir${Platform.pathSeparator}$fileNamePattern';
    final rwTimeoutMicro = (rwTimeout * 1000000).clamp(0, 2147483647);

    final args = <String>[
      '-y',
      '-hide_banner',
      '-loglevel',
      'info',
      if (PlatformUtils.isAndroid) ...['-tls_verify', '0'],
      '-analyzeduration',
      '1000000',
      '-probesize',
      '1048576',
      '-fflags',
      'igndts+genpts+nobuffer+flush_packets+fastseek',
      '-flags',
      'low_delay',
      '-seekable',
      '1',
      '-protocol_whitelist',
      _protocolWhitelist,
      '-reconnect',
      '1',
      '-reconnect_streamed',
      '1',
      '-reconnect_delay_max',
      '10',
      '-reconnect_at_eof',
      '1',
      '-rw_timeout',
      rwTimeoutMicro.toString(),
      '-max_delay',
      '5000000',
      '-thread_queue_size',
      threadQueueSize.toString(),
      if (ua != null && ua.isNotEmpty) ...['-user_agent', quoteArgument(ua)],
      if (headerStr.isNotEmpty) ...['-headers', quoteArgument(headerStr)],
      '-i',
      quoteArgument(url),
      '-map',
      preferBestStream ? '0:v:0?' : '0:v?',
      '-map',
      preferBestStream ? '0:a:0?' : '0:a?',
      '-c',
      'copy',
      '-f',
      'segment',
      '-segment_format',
      'mpegts',
      '-segment_time',
      segmentTime.toString(),
      '-reset_timestamps',
      '1',
      '-strftime',
      '1',
      quoteArgument(normalizedOutputPath),
    ];

    return List<String>.unmodifiable(args);
  }

  static String formatArguments(Iterable<String> arguments) {
    return arguments.join(' ');
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
