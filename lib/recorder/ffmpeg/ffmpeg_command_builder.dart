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
  ///
  /// FFmpegKit has a first-class argument-list API. Using it avoids parsing a
  /// command string a second time on Android, where signed URLs, CRLF-delimited
  /// HTTP headers and storage paths containing spaces could otherwise be split
  /// differently from desktop shells.
  static List<String> buildAudioStreamArguments({
    required String remoteStreamUrl,
    required int port,
    int rwTimeout = 15,
    Map<String, String>? headers,
    String? caFile,
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
      ..._inputProtocolOptions(url, rwTimeout: rwTimeout, caFile: caFile),
      '-thread_queue_size',
      threadQueueSize.clamp(64, 65536).toString(),
      if (userAgent != null && userAgent.isNotEmpty) ...['-user_agent', userAgent],
      if (headerString.isNotEmpty) ...['-headers', headerString],
      // Preserve the source cadence while correcting only discontinuities.
      // `use_wallclock_as_timestamps` is intentionally avoided: HLS/HTTP
      // downloads packets in bursts, so arrival time collapses many frames
      // into near-identical timestamps and produces visibly uneven playback.
      // FFmpeg applies dts_delta_threshold to discontinuity-aware inputs such
      // as HLS/MPEG-TS and dts_error_threshold to formats such as live FLV;
      // together with +genpts above this removes a CDN timestamp jump without
      // replacing every valid source timestamp.
      if (_usesNetworkInput(url)) ...['-dts_delta_threshold', '2', '-dts_error_threshold', '2'],
      '-i',
      url,
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
      normalizedOutputPath,
    ];

    return List<String>.unmodifiable(args);
  }

  /// Human-readable representation for logs and deterministic tests only.
  /// Native execution always receives the original argument list.
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
        // Authentication and signed-URL failures need a fresh platform URL;
        // only retry server failures inside FFmpeg.
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

  static bool _usesNetworkInput(String rawUrl) {
    final scheme = Uri.tryParse(rawUrl.trim())?.scheme.toLowerCase() ?? '';
    return const <String>{'http', 'https', 'rtmp', 'rtmps', 'rtsp', 'rtp', 'udp', 'srt'}.contains(scheme);
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
