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
  }) {
    final normalizedHeaders = _normalizeHeaders(headers);
    final userAgent = normalizedHeaders.remove('user-agent');
    final headerString = _buildHeader(normalizedHeaders);
    final args = <String>[
      '-hide_banner',
      '-loglevel',
      'info',
      '-protocol_whitelist',
      _protocolWhitelist,
      ..._inputProtocolOptions(remoteStreamUrl, rwTimeout: rwTimeout),
      if (userAgent != null && userAgent.isNotEmpty) ...['-user_agent', quoteArgument(userAgent)],
      if (headerString.isNotEmpty) ...['-headers', _quoteGeneratedHeaders(headerString)],
      '-i',
      quoteArgument(remoteStreamUrl),
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

    return args.join(' ');
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
    final normalizedHeaders = _normalizeHeaders(headers);
    final userAgent = normalizedHeaders.remove('user-agent');
    final headerString = _buildHeader(normalizedHeaders);
    final prefix = _safeFilePrefix(filePrefix ?? _timestampPrefix(DateTime.now()));
    final normalizedOutputPath = '$outputDir${Platform.pathSeparator}${prefix}_%06d.ts';

    final args = <String>[
      // Unique prefixes make overwriting a previous recording unnecessary.
      // `-n` turns an unexpected collision into a visible local error.
      '-n',
      '-hide_banner',
      '-loglevel',
      'info',
      // Recording favours complete stream discovery over playback latency.
      '-analyzeduration',
      '5000000',
      '-probesize',
      '5000000',
      '-fflags',
      '+genpts+discardcorrupt',
      '-protocol_whitelist',
      _protocolWhitelist,
      ..._inputProtocolOptions(url, rwTimeout: rwTimeout),
      '-thread_queue_size',
      threadQueueSize.clamp(64, 65536).toString(),
      if (userAgent != null && userAgent.isNotEmpty) ...['-user_agent', quoteArgument(userAgent)],
      if (headerString.isNotEmpty) ...['-headers', _quoteGeneratedHeaders(headerString)],
      '-i',
      quoteArgument(url),
      // Optional mappings support audio-only rooms and temporarily missing
      // video tracks without selecting metadata/data streams.
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
      quoteArgument(normalizedOutputPath),
    ];

    return args.join(' ');
  }

  static List<String> _inputProtocolOptions(String rawUrl, {required int rwTimeout}) {
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
        // Authentication and signed-URL failures need a fresh platform URL;
        // only retry server failures inside FFmpeg.
        '-reconnect_on_http_error',
        '5xx',
        '-reconnect_delay_max',
        '5',
        '-rw_timeout',
        timeoutMicros,
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
    if (headers == null || headers.isEmpty) return <String, String>{};
    final normalized = <String, String>{};
    final validName = RegExp(r'^[A-Za-z0-9-]+$');
    for (final entry in headers.entries) {
      final name = entry.key.trim().toLowerCase();
      final value = entry.value.replaceAll(RegExp(r'[\r\n\u0000]+'), ' ').trim();
      if (name.isEmpty || value.isEmpty || !validName.hasMatch(name)) continue;
      normalized[name] = value;
    }
    return normalized;
  }

  static String _buildHeader(Map<String, String> headers) {
    if (headers.isEmpty) return '';
    return '${headers.entries.map((entry) => '${entry.key}: ${entry.value}').join('\r\n')}\r\n';
  }

  /// Header values are sanitized before this string is generated, so the only
  /// newlines left here are the CRLF delimiters FFmpeg requires between HTTP
  /// fields. The generic argument quoting intentionally strips newlines and
  /// therefore must not be used for this generated block.
  static String _quoteGeneratedHeaders(String value) => '"${value.replaceAll('"', r'\"')}"';

  static String _safeFilePrefix(String value) {
    final normalized = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_').replaceAll(RegExp(r'_+'), '_');
    final trimmed = normalized.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? _timestampPrefix(DateTime.now()) : trimmed;
  }

  static String _timestampPrefix(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}_'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}_'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
}
