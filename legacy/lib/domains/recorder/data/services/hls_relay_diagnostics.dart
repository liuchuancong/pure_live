part of 'ffmpeg_hls_input_relay.dart';

/// Opt-in, in-memory capture of the first requests of one relay session.
/// No URLs, headers, cookies, manifest text, exception text or media are kept.
/// A snapshot is detached JSON data; owning probes decide whether to persist it.
final class HlsRelayDiagnostics {
  HlsRelayDiagnostics({int maximumRequests = 512}) : maximumRequests = maximumRequests.clamp(1, 1024);

  final int maximumRequests;
  final Stopwatch _clock = Stopwatch()..start();
  final List<_HlsRequestTrace> _requests = [];
  final List<Map<String, Object?>> _prefetchRefreshFailures = [];
  final List<Map<String, Object?>> _prefetchDownloadCheckpoints = [];
  int _omittedRequests = 0;

  int get elapsedMilliseconds => _clock.elapsedMilliseconds;

  void _prefetchDownloads(String phase, Iterable<Map<String, Object?>> rows) {
    if (_prefetchDownloadCheckpoints.length >= 2) return;
    final kept = <Map<String, Object?>>[];
    var omitted = 0;
    for (final row in rows) {
      if (kept.length < 128) {
        kept.add(row);
      } else {
        omitted++;
      }
    }
    _prefetchDownloadCheckpoints.add({
      'phase': phase,
      'atMs': elapsedMilliseconds,
      'resources': kept,
      'omittedResources': omitted,
    });
  }

  void _prefetchRefreshFailed(String id, HlsPrefetchRefreshStage stage, Object error) {
    // One terminal event per selected feed, at most two feeds per generation.
    // Keep only opaque local IDs and fixed categories, never error.toString().
    if (_prefetchRefreshFailures.length >= 2 || !RegExp(r'^(root|[0-9a-z]{1,16})$').hasMatch(id)) return;
    final kind = switch (error) {
      HlsUpstreamResponseException() => 'http',
      HandshakeException() => 'tls',
      SocketException() => 'socket',
      TimeoutException() => 'timeout',
      FormatException() => 'format',
      StateError() => 'state',
      _ => 'other',
    };
    _prefetchRefreshFailures.add({
      'resourceId': id,
      'atMs': elapsedMilliseconds,
      'stage': stage.name,
      'kind': kind,
      if (error is HlsUpstreamResponseException) 'upstreamStatus': error.statusCode,
      if (error is FormatException)
        'contract': switch (error.message) {
          'Snapshot identity or tag contract differs' => 'snapshot-identity-or-tags',
          'Target duration changed within a source generation' => 'target-changed',
          'Playlist contract changed within a source generation' => 'playlist-contract-changed',
          'Partial target duration changed within a source generation' => 'part-target-changed',
          'Stale or reopened HLS window' => 'stale-or-reopened',
          'Conflicting HLS segment identity' => 'segment-identity',
          'Missing HLS sequence interval' => 'sequence-gap',
          'Partial segment and parent metadata conflict' => 'part-parent-context',
          'Published parent is shorter than its earlier parts' => 'parent-duration',
          'Unfinished parent was skipped' => 'pending-parent-skipped',
          'Unfinished partial prefix disappeared' => 'pending-prefix-disappeared',
          'Unfinished partial identity changed' => 'pending-identity',
          _ => 'other',
        },
    });
  }

  _HlsRequestTrace? _begin(String resourceId, String method) {
    if (_requests.length >= maximumRequests) {
      _omittedRequests++;
      return null;
    }
    final trace = _HlsRequestTrace(_clock, resourceId, method);
    _requests.add(trace);
    return trace;
  }

  Map<String, Object?> snapshot() => {
    'schema': 1,
    'clock': 'monotonic-milliseconds-since-diagnostics-created',
    'deliveryMeaning': 'local-response-close-not-native-consumption',
    'maximumRequests': maximumRequests,
    'omittedRequests': _omittedRequests,
    'requests': [for (final request in _requests) request.snapshot()],
    'prefetchRefreshFailures': [for (final failure in _prefetchRefreshFailures) Map<String, Object?>.of(failure)],
    'prefetchDownloadCheckpoints': jsonDecode(jsonEncode(_prefetchDownloadCheckpoints)),
  };
}

final class _HlsRequestTrace {
  _HlsRequestTrace(this.clock, this.resourceId, this.method) : startedMs = clock.elapsedMilliseconds;
  final Stopwatch clock;
  final String resourceId;
  final String method;
  final int startedMs;
  int? headersMs;
  int? firstBodyMs;
  int? bodyCompleteMs;
  int? deliveredMs;
  int? finishedMs;
  int? upstreamStatus;
  int? localStatus;
  int bytes = 0;
  String outcome = 'active';
  String? manifestSource;
  Map<String, Object?>? manifest;

  void chunk(List<int> value) {
    if (value.isNotEmpty) firstBodyMs ??= clock.elapsedMilliseconds;
    bytes += value.length;
  }

  void completeBody() => bodyCompleteMs = clock.elapsedMilliseconds;
  void delivered() => deliveredMs = clock.elapsedMilliseconds;

  void receivedHeaders(int status) {
    headersMs = clock.elapsedMilliseconds;
    upstreamStatus = status;
  }

  void offeredManifest(String rewritten, String source) {
    manifestSource = source;
    try {
      manifest = _manifestWindow(rewritten);
    } on Object {
      // Observation must never change playback, even for pathological dates.
      manifest = {'parseFailed': true};
    }
  }

  Map<String, Object?> snapshot() => {
    'resourceId': resourceId,
    'method': method,
    'startedMs': startedMs,
    'headersMs': headersMs,
    'firstBodyMs': firstBodyMs,
    'bodyCompleteMs': bodyCompleteMs,
    'deliveredMs': deliveredMs,
    'finishedMs': finishedMs,
    'upstreamStatus': upstreamStatus,
    'localStatus': localStatus,
    'receivedBytes': bytes,
    'outcome': outcome,
    'manifestSource': manifestSource,
    // Deep detach the bounded nested lists, not the raw upstream document.
    'manifest': manifest == null ? null : jsonDecode(jsonEncode(manifest)),
  };
}

// Parse only a rewritten playlist. IDs are checked against the relay's opaque
// grammar; unsupported URI schemes or unrewritten lines never enter snapshots.
Map<String, Object?> _manifestWindow(String source) {
  String? idOf(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'http' || uri.host != '127.0.0.1' || uri.pathSegments.length != 2) return null;
    final id = uri.pathSegments.last.split('.').first;
    return RegExp(r'^(root|[0-9a-z]{1,16})$').hasMatch(id) ? id : null;
  }

  double? durationOf(String value) {
    final number = double.tryParse(value.split(',').first);
    return number != null && number.isFinite && number >= 0 && number <= 86400 ? number : null;
  }

  int? sequenceOf(String value) {
    final number = int.tryParse(value);
    return number != null && number >= 0 ? number : null;
  }

  var sequence = 0;
  var discontinuity = 0;
  int? target;
  double? pendingDuration;
  DateTime? programTime;
  var pdtExplicit = false;
  var variant = false;
  var master = false;
  var ended = false;
  var count = 0;
  var childCount = 0;
  double duration = 0;
  final segments = <Map<String, Object?>>[];
  final children = <Map<String, Object?>>[];
  void child(String? id, String role) {
    if (id == null) return;
    childCount++;
    if (children.length < 32) children.add({'resourceId': id, 'role': role});
  }

  for (final raw in const LineSplitter().convert(source)) {
    final line = raw.trim();
    if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
      sequence = sequenceOf(line.substring(22)) ?? 0;
    } else if (line.startsWith('#EXT-X-DISCONTINUITY-SEQUENCE:')) {
      discontinuity = sequenceOf(line.substring(30)) ?? 0;
    } else if (line.startsWith('#EXT-X-TARGETDURATION:')) {
      target = sequenceOf(line.substring(22));
    } else if (line.startsWith('#EXT-X-PROGRAM-DATE-TIME:')) {
      final value = line.substring(25);
      programTime = value.length <= 64 && RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value)
          ? DateTime.tryParse(value)?.toUtc()
          : null;
      pdtExplicit = programTime != null;
    } else if (line == '#EXT-X-DISCONTINUITY') {
      // Do not invent wall time across a discontinuity without a new anchor.
      programTime = null;
      pdtExplicit = false;
    } else if (line.startsWith('#EXTINF:')) {
      pendingDuration = durationOf(line.substring(8));
    } else if (line.startsWith('#EXT-X-STREAM-INF:')) {
      master = true;
      variant = true;
    } else if (line.startsWith('#EXT-X-MEDIA:')) {
      master = true;
      final match = FFmpegHlsInputRelay._uriAttribute.firstMatch(line);
      final type = RegExp(r'(?:[:,])TYPE=(AUDIO|VIDEO|SUBTITLES|CLOSED-CAPTIONS)(?:,|$)').firstMatch(line);
      if (match != null) child(idOf(match.group(1)!), type?.group(1)?.toLowerCase() ?? 'unknown');
    } else if (line.startsWith('#EXT-X-MAP:') || line.startsWith('#EXT-X-KEY:')) {
      final match = FFmpegHlsInputRelay._uriAttribute.firstMatch(line);
      if (match != null) child(idOf(match.group(1)!), line.startsWith('#EXT-X-MAP:') ? 'map' : 'key');
    } else if (line == '#EXT-X-ENDLIST') {
      ended = true;
    } else if (line.isNotEmpty && !line.startsWith('#')) {
      if (variant) {
        child(idOf(line), 'variant');
        variant = false;
      } else if (pendingDuration != null) {
        if (segments.length < 64) {
          segments.add({
            'resourceId': idOf(line),
            'sequence': sequence + count,
            'duration': pendingDuration,
            'programDateTime': programTime?.toIso8601String(),
            'programDateTimeExplicit': pdtExplicit,
          });
        }
        count++;
        duration += pendingDuration;
        programTime = programTime?.add(Duration(microseconds: (pendingDuration * 1000000).round()));
        pdtExplicit = false;
        pendingDuration = null;
      }
    }
  }
  return {
    'kind': master ? 'master' : 'media',
    'mediaSequence': master ? null : sequence,
    'discontinuitySequence': master ? null : discontinuity,
    'targetDuration': target,
    'endList': ended,
    'segmentCount': count,
    'durationSeconds': duration,
    'segments': segments,
    'omittedSegments': count - segments.length,
    'children': children,
    'omittedChildren': childCount - children.length,
  };
}
