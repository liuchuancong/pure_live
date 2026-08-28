import 'dart:io';

class FFmpegCommandBuilder {
  static const String _protocolWhitelist = 'httpproxy,udp,rtp,rtsp,rtmp,rtmps,srt,tcp,tls,data,file,http,https,crypto';

  static String quoteArgument(String value) {
    final escaped = value.replaceAll('\r', '').replaceAll('\n', '').replaceAll('"', r'\"');

    return '"$escaped"';
  }

  /// Local audio-only relay HTTP server.
  static String buildAudioStreamCommand({
    required String remoteStreamUrl,
    required int port,
    int rwTimeout = 15,
    Map<String, String>? headers,
    String? caFile,
  }) => formatArguments(
    buildAudioStreamArguments(
      remoteStreamUrl: remoteStreamUrl,
      port: port,
      rwTimeout: rwTimeout,
      headers: headers,
      caFile: caFile,
    ),
  );

  /// Returns native FFmpeg arguments without shell quoting.
  static List<String> buildAudioStreamArguments({
    required String remoteStreamUrl,
    required int port,
    int rwTimeout = 15,
    Map<String, String>? headers,
    String? caFile,
  }) {
    print('caFile');
    print(caFile);
    final normalizedHeaders = _normalizeHeaders(headers);
    final userAgent = normalizedHeaders.remove('user-agent');
    final headerString = _buildHeader(normalizedHeaders);

    final args = <String>[
      '-hide_banner',
      '-loglevel',
      'info',

      '-protocol_whitelist',
      _protocolWhitelist,

      ..._inputProtocolOptions(remoteStreamUrl, rwTimeout: rwTimeout, caFile: caFile),

      if (userAgent != null && userAgent.isNotEmpty) ...['-user_agent', userAgent],

      if (headerString.isNotEmpty) ...['-headers', headerString],

      '-i',
      remoteStreamUrl,

      '-map',
      '0:a:0',

      '-vn',

      '-c:a',
      'copy',

      '-listen',
      '1',

      '-f',
      'mpegts',

      'http://127.0.0.1:$port/live.ts',
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
    String? caFile,
  }) => formatArguments(
    buildRecordArguments(
      url: url,
      outputDir: outputDir,
      segmentTime: segmentTime,
      preferBestStream: preferBestStream,
      rwTimeout: rwTimeout,
      threadQueueSize: threadQueueSize,
      filePrefix: filePrefix,
      headers: headers,
      caFile: caFile,
    ),
  );

  static List<String> buildRecordArguments({
    required String url,
    required String outputDir,
    required int segmentTime,
    required bool preferBestStream,
    required int rwTimeout,
    required int threadQueueSize,
    String? filePrefix,
    Map<String, String>? headers,
    String? caFile,
  }) {
    final normalizedHeaders = _normalizeHeaders(headers);

    final userAgent = normalizedHeaders.remove('user-agent');

    final headerString = _buildHeader(normalizedHeaders);

    final prefix = _safeFilePrefix(filePrefix ?? _timestampPrefix(DateTime.now()));

    final normalizedOutputPath = '$outputDir${Platform.pathSeparator}${prefix}_%06d.ts';

    final args = <String>[
      '-n',

      '-hide_banner',

      '-loglevel',
      'info',

      '-analyzeduration',
      '5000000',

      '-probesize',
      '5000000',

      '-fflags',
      '+genpts+discardcorrupt',

      '-protocol_whitelist',
      _protocolWhitelist,

      ..._inputProtocolOptions(url, rwTimeout: rwTimeout, caFile: caFile),

      '-thread_queue_size',
      threadQueueSize.clamp(64, 65536).toString(),

      if (userAgent != null && userAgent.isNotEmpty) ...['-user_agent', userAgent],

      if (headerString.isNotEmpty) ...['-headers', headerString],

      '-i',
      url,

      '-map',
      preferBestStream ? '0:v:0?' : '0:v?',

      '-map',
      preferBestStream ? '0:a:0?' : '0:a?',

      '-c',
      'copy',

      '-avoid_negative_ts',
      'make_non_negative',

      '-f',
      'segment',

      '-segment_format',
      'mpegts',

      '-segment_time',
      segmentTime.clamp(10, 86400).toString(),

      '-segment_start_number',
      '0',

      '-reset_timestamps',
      '1',

      normalizedOutputPath,
    ];

    return List<String>.unmodifiable(args);
  }

  static String formatArguments(Iterable<String> arguments) => arguments.map(quoteArgument).join(' ');

  static List<String> _inputProtocolOptions(String rawUrl, {required int rwTimeout, String? caFile}) {
    final scheme = Uri.tryParse(rawUrl.trim())?.scheme.toLowerCase() ?? '';

    final timeoutMicros = (rwTimeout.clamp(1, 3600) * 1000000).clamp(1, 2147483647).toString();

    final options = <String>[];

    if (scheme == 'http' || scheme == 'https') {
      options.addAll([
        '-reconnect',
        '1',

        '-reconnect_streamed',
        '1',

        '-reconnect_on_network_error',
        '1',

        '-reconnect_on_http_error',
        '5xx',

        '-reconnect_delay_max',
        '5',

        '-rw_timeout',
        timeoutMicros,

        if (Platform.isAndroid && scheme == 'https' && caFile != null && caFile.isNotEmpty) ...['-ca_file', caFile],
      ]);
    } else if (scheme == 'rtsp') {
      options.addAll(['-rtsp_transport', 'tcp', '-rw_timeout', timeoutMicros]);
    } else if (scheme == 'udp' || scheme == 'rtp') {
      options.addAll(['-fifo_size', '5000000', '-overrun_nonfatal', '1']);
    } else if (scheme != 'file' && scheme.isNotEmpty) {
      options.addAll(['-rw_timeout', timeoutMicros]);
    }

    return options;
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

  static String _safeFilePrefix(String value) {
    final normalized = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_').replaceAll(RegExp(r'_+'), '_');

    final trimmed = normalized.replaceAll(RegExp(r'^_+|_+$'), '');

    return trimmed.isEmpty ? _timestampPrefix(DateTime.now()) : trimmed;
  }

  static String _timestampPrefix(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');

    return '${time.year}'
        '${two(time.month)}'
        '${two(time.day)}_'
        '${two(time.hour)}'
        '${two(time.minute)}'
        '${two(time.second)}_'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
}
