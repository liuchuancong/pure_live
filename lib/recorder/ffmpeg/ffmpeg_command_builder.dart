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
    final normalizedHeaders = _normalizeHeaders(headers);

    final userAgent = normalizedHeaders.remove('user-agent');
    final headerString = _buildHeader(normalizedHeaders);

    final rwTimeoutMicro = (rwTimeout * 1000000).clamp(0, 2147483647);

    final args = <String>[
      // 基础
      '-hide_banner',
      '-loglevel',
      'info',

      // Android 录制/播放需要关闭 TLS 证书校验
      if (PlatformUtils.isAndroid) ...['-tls_verify', '0'],

      // 重连
      '-reconnect',
      '1',
      '-reconnect_streamed',
      '1',
      '-reconnect_delay_max',
      '10',
      '-reconnect_at_eof',
      '1',

      // 网络
      '-rw_timeout',
      rwTimeoutMicro.toString(),

      // UA
      if (userAgent != null && userAgent.isNotEmpty) ...['-user_agent', userAgent],

      // Headers
      if (headerString.isNotEmpty) ...['-headers', headerString],

      // 输入流
      '-i',
      remoteStreamUrl,

      '-map',
      '0:a',

      '-vn',

      '-acodec',
      'copy',

      '-listen',
      '1',

      // 输出 MPEGTS HTTP Server
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
    final normalizedHeaders = _normalizeHeaders(headers);

    final userAgent = normalizedHeaders.remove('user-agent');
    final headerString = _buildHeader(normalizedHeaders);

    final normalizedOutputPath = '$outputDir${Platform.pathSeparator}%Y%m%d_%H%M%S.ts';

    final rwTimeoutMicro = (rwTimeout * 1000000).clamp(0, 2147483647);

    final args = <String>[
      '-y',

      '-hide_banner',
      '-loglevel',
      'info',
      // Android 录制需要关闭 TLS 证书校验
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

      // UA
      if (userAgent != null && userAgent.isNotEmpty) ...['-user_agent', userAgent],

      // Headers
      if (headerString.isNotEmpty) ...['-headers', headerString],

      // 输入
      '-i',
      url,

      // 保持原来的 map
      '-map',
      preferBestStream ? '0:v:0?' : '0:v?',

      '-map',
      preferBestStream ? '0:a:0?' : '0:a?',

      // 原来的 copy 模式
      '-c',
      'copy',

      // 分段输出
      '-f',
      'segment',

      '-segment_format',
      'mpegts',

      '-segment_time',
      segmentTime.toString(),

      '-reset_timestamps',
      '1',

      // 恢复原来的时间戳文件名
      '-strftime',
      '1',

      normalizedOutputPath,
    ];

    return List<String>.unmodifiable(args);
  }

  static String formatArguments(Iterable<String> arguments) {
    return arguments.map(quoteArgument).join(' ');
  }

  static Map<String, String> _normalizeHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return <String, String>{};
    }

    final normalized = <String, String>{};

    final validName = RegExp(r'^[A-Za-z0-9-]+$');

    for (final entry in headers.entries) {
      final name = entry.key.trim().toLowerCase();

      final value = entry.value.replaceAll(RegExp(r'[\r\n\u0000]+'), ' ').trim();

      if (name.isEmpty || value.isEmpty || !validName.hasMatch(name)) {
        continue;
      }

      normalized[name] = value;
    }

    return normalized;
  }

  static String _buildHeader(Map<String, String> headers) {
    if (headers.isEmpty) {
      return '';
    }

    return '${headers.entries.map((entry) => '${entry.key}: ${entry.value}').join('\r\n')}\r\n';
  }
}
