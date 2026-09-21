import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pure_live/core/common/log.dart';
import 'package:pure_live/core/common/hls_source_query_policy.dart';
import 'package:pure_live/core/common/hls_master_selection.dart';

import 'hls_session_cookies.dart';
import 'hls_media_spool.dart';
import 'hls_body_reader.dart';
import 'hls_upstream_client.dart';
import 'hls_prefetch_pool.dart';
import 'hls_prefetch_scheduler.dart';
import 'hls_prefetch_plan.dart';
import 'hls_retained_window.dart';
import 'cancellable_http_connections.dart';
import 'recorder_proxy_routing.dart';

part 'hls_relay_diagnostics.dart';
part 'hls_relay_prefetch.dart';

typedef HlsMediaPrefixTransformer = Uint8List Function(Uint8List prefix);
typedef HlsManifestMediaTransformResolver = HlsMediaPrefixTransform? Function(Uri manifest, String source);

/// A manifest-scoped, length-preserving media prefix transform. It is applied
/// only to plain media URI lines, never to keys, maps or nested playlists.
final class HlsMediaPrefixTransform {
  HlsMediaPrefixTransform({required this.prefixBytes, required this.transform}) {
    if (prefixBytes < 1 || prefixBytes > 64 * 1024) throw ArgumentError('Invalid HLS media prefix length');
  }

  final int prefixBytes;
  final HlsMediaPrefixTransformer transform;
}

/// Relays HLS resources over an app-private loopback server, verifying upstream
/// HTTPS and allowing recording inputs to end without cancelling output IO.
///
/// FFmpeg 9.0.1's HLS demuxer copies headers, cookies and timeouts from the
/// manifest connection to child requests, but not the `ca_file` TLS option.
/// Embedded OpenSSL builds on Android/Linux therefore verify the manifest and
/// can still reject a segment from the same server. Dart uses the platform
/// trust path correctly, so this relay keeps certificate and hostname checks
/// enabled upstream while FFmpeg reads only short-lived loopback HTTP URLs.
class FFmpegHlsInputRelay {
  FFmpegHlsInputRelay._({
    required this._server,
    required this._client,
    required this._connections,
    required Uri upstream,
    required this._headers,
    required this._secret,
    required this.drainOnStop,
    required Duration bodyIdleTimeout,
    required this._createStagingDirectory,
    required HlsSourceQueryPolicy? sourceQueryPolicy,
    required String? Function(Uri)? requestCookies,
    required this._masterSelection,
    required this.diagnostics,
    required this.prefetchEnabled,
    required HlsManifestMediaTransformResolver? manifestMediaTransform,
  }) {
    _bodyIdleTimeout = bodyIdleTimeout;
    _upstream = HlsUpstreamClient(
      client: _client,
      source: upstream,
      headers: _headers,
      cookies: _cookies,
      queryPolicy: sourceQueryPolicy,
      requestCookies: requestCookies,
    );
    _resources['root'] = upstream;
    _manifestMediaTransform = manifestMediaTransform;
  }

  static const int _maximumManifestBytes = 4 * 1024 * 1024;
  static const Duration _connectionTimeout = Duration(seconds: 15);
  static final RegExp _hlsPath = RegExp(r'\.m3u8$', caseSensitive: false);
  static final RegExp _uriAttribute = RegExp(r'URI="([^"]+)"', caseSensitive: false);
  static const Set<String> _allowedMediaExtensions = <String>{
    '3gp',
    'aac',
    'ac3',
    'avi',
    'eac3',
    'flac',
    'm4a',
    'm4s',
    'm4v',
    'mkv',
    'mov',
    'mp2',
    'mp3',
    'mp4',
    'mpeg',
    'mpegts',
    'mpg',
    'mxf',
    'ogg',
    'pls',
    'ts',
    'vob',
    'vtt',
    'wav',
    'webvtt',
  };

  final HttpServer _server;
  final HttpClient _client;
  final CancellableHttpConnections _connections;
  final Map<String, String> _headers;
  final String _secret;
  final bool drainOnStop;
  final bool prefetchEnabled;
  bool _automaticStartHint = false;
  HlsPrefetchScheduler? _prefetch;
  Future<void>? _prefetchPreparation;
  Future<void>? _prefetchDrain;
  HlsPrefetchCancellation? _preparingCancellation;
  final Set<String> _prefetchFeeds = {};
  final Map<String, HlsPrefetchResource> _prefetchResources = {};
  final Map<String, int> _prefetchFailures = {};
  final Map<String, String> _resourceKeys = {};
  void Function()? onCoverageIncomplete;

  @visibleForTesting
  int get prefetchFeedCount => _prefetch?.feedCount ?? 0;
  @visibleForTesting
  int get prefetchBodyCount => _prefetch?.pool.ownedEntries ?? 0;
  @visibleForTesting
  int get prefetchBytes => _prefetch?.pool.retainedBytes ?? 0;
  late final Duration _bodyIdleTimeout;
  final HlsRelayDiagnostics? diagnostics;
  final Future<Directory> Function() _createStagingDirectory;
  final HlsSessionCookies _cookies = HlsSessionCookies();
  late final HlsUpstreamClient _upstream;
  HlsMasterSelection? _masterSelection;
  final Map<String, Uri> _resources = <String, Uri>{};
  final Map<String, HlsMediaPrefixTransform> _resourceTransforms = <String, HlsMediaPrefixTransform>{};
  final Map<String, String> _resourceIds = <String, String>{};
  final Map<String, String> _manifests = <String, String>{};
  HlsManifestMediaTransformResolver? _manifestMediaTransform;
  // Retain current and previous playlist generations, including keys/maps and
  // all nested renditions. Never retain every segment seen since startup.
  final Map<String, List<Set<String>>> _manifestReferences = {};
  final Map<String, int> _activeResources = {};
  final Set<void Function()> _fetchAborters = {};
  final Set<Future<void>> _handlers = {};
  Timer? _finishTimer;
  bool _fetchStopped = false;
  bool _inputTailDiscarded = false;
  int _stagingBodies = 0;
  StreamSubscription<HttpRequest>? _subscription;
  Future<void>? _closing;
  var _nextResourceId = 0;
  var _closed = false;
  var _finishing = false;
  var _targetSeconds = 1;

  bool get finishRequested => _finishing;

  /// An input resource was retired at stop before publication. This is not
  /// packet corruption, but successful remux must not hide the missing input.
  bool get inputTailDiscarded => _inputTailDiscarded;

  // Native HLS reloads on the playlist's target duration. Do not impose FLV's
  // shorter drain budget and cancel before a healthy playlist can be reloaded.
  Duration get drainTimeout =>
      Duration(seconds: (2 * _targetSeconds + 2).clamp(3, 20)) +
      (_prefetch == null ? Duration.zero : _prefetchDownloadGrace);

  // Preserve admitted published bodies within their existing network budgets,
  // with a separate hard 20s shutdown ceiling. Native still has its original
  // playlist reload/flush allowance after this bounded download phase.
  Duration get _prefetchDownloadGrace =>
      Duration(milliseconds: HlsResponseBudget.totalFor(_bodyIdleTimeout).inMilliseconds.clamp(1, 20000));

  @visibleForTesting
  int get resourceCount => _resources.length;

  @visibleForTesting
  int get stagingBodyCount => _stagingBodies;

  @visibleForTesting
  int get sessionCookieCount => _cookies.count;

  Uri get inputUri =>
      Uri(scheme: 'http', host: InternetAddress.loopbackIPv4.address, port: _server.port, path: '/$_secret/root.m3u8');

  /// TLS relay: first HTTPS HLS input on Android/Linux. Live recordings opt in
  /// on every native platform so ENDLIST can finish input without cancel IO.
  /// [force] exists for deterministic loopback unit tests on desktop hosts.
  static Future<FFmpegHlsInputRelay?> startForArguments(
    Iterable<String> source, {
    bool force = false,
    bool drainOnStop = false,
    // Explicit selected-source capability, never inferred from a query name.
    HlsSourceQueryPolicy? sourceQueryPolicy,
    // Authoritative live cookie grant; called for every actual upstream URI,
    // including redirects and prefetch. Null means no cookie, not a fallback.
    // Caller owns session lifetime and closes this relay when the session ends.
    String? Function(Uri)? requestCookies,
    // Caller-selected exact video/audio pair. Never infer a quality from order.
    HlsMasterSelection? masterSelection,
    // Playback uses the media proxy; recording retains its existing app proxy.
    String Function(Uri)? findProxy,
    // Tests supply an isolated owned directory or controlled storage failure.
    Future<Directory> Function()? createStagingDirectory,
    HlsRelayDiagnostics? diagnostics,
    bool enablePrefetch = false,
    // Custom media transforms stay on the direct relay path until the
    // prefetch cache can retain manifest-scoped transform ownership.
    HlsManifestMediaTransformResolver? manifestMediaTransform,
  }) async {
    final arguments = List<String>.of(source);
    final inputIndex = arguments.indexOf('-i');
    if (inputIndex < 0 || inputIndex + 1 >= arguments.length) {
      if (sourceQueryPolicy != null || requestCookies != null || masterSelection != null) {
        throw const FormatException('Missing policy-bound HLS input');
      }
      return null;
    }

    final upstream = Uri.tryParse(arguments[inputIndex + 1].trim());
    if (masterSelection != null && upstream != masterSelection.source) {
      throw const FormatException('Selected HLS master does not match input');
    }
    if (sourceQueryPolicy != null &&
        (upstream == null || !_isHlsUri(upstream) || !sourceQueryPolicy.matchesSource(upstream))) {
      throw const FormatException('HLS query policy does not match selected input');
    }
    if (upstream == null || !_isHlsUri(upstream)) {
      if (requestCookies != null || masterSelection != null) throw const FormatException('Missing runtime HLS input');
      return null;
    }
    if (manifestMediaTransform != null && enablePrefetch) {
      throw ArgumentError('HLS media transforms are not supported with prefetch');
    }
    final supportedHost = !kIsWeb && (Platform.isAndroid || Platform.isLinux);
    if (!force &&
        !drainOnStop &&
        sourceQueryPolicy == null &&
        requestCookies == null &&
        masterSelection == null &&
        (!supportedHost || upstream.scheme.toLowerCase() != 'https')) {
      return null;
    }

    final connections = CancellableHttpConnections();
    final client = HttpClient()
      ..connectionFactory = connections.connect
      ..findProxy = findProxy ?? resolveRecorderProxyDirective
      ..connectionTimeout = _connectionTimeout
      ..idleTimeout = const Duration(seconds: 20)
      ..autoUncompress = true;
    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0, shared: false);
    } catch (_) {
      client.close(force: true);
      connections.cancel();
      await connections.settled;
      rethrow;
    }
    final relay = FFmpegHlsInputRelay._(
      server: server,
      client: client,
      connections: connections,
      upstream: upstream,
      headers: _readInputHeaders(arguments, inputIndex),
      secret: _newSecret(),
      drainOnStop: drainOnStop,
      bodyIdleTimeout: _readBodyIdleTimeout(arguments, inputIndex),
      createStagingDirectory: createStagingDirectory ?? _defaultStagingDirectory,
      sourceQueryPolicy: sourceQueryPolicy,
      requestCookies: requestCookies,
      masterSelection: masterSelection,
      diagnostics: diagnostics,
      prefetchEnabled: enablePrefetch && drainOnStop,
      manifestMediaTransform: manifestMediaTransform,
    );
    relay._subscription = server.listen(relay._acceptRequest, onError: relay._handleServerError);
    return relay;
  }

  List<String> replaceFirstInput(Iterable<String> source) {
    final arguments = List<String>.of(source);
    final inputIndex = arguments.indexOf('-i');
    if (inputIndex >= 0 && inputIndex + 1 < arguments.length) {
      arguments[inputIndex + 1] = inputUri.toString();
      if (drainOnStop) {
        // This socket waits for a whole response, not individual upstream
        // packets. Keep upstream idle enforcement in the relay. One pending
        // connection may finish after the response deadline; allow its owned
        // connection timeout and 5s local scheduling margin, never infinity.
        final localTimeout =
            (HlsResponseBudget.totalFor(_bodyIdleTimeout) + _connectionTimeout + const Duration(seconds: 5))
                .inMicroseconds
                .toString();
        var replaced = false;
        for (var i = 0; i < inputIndex - 1; i++) {
          if (arguments[i] == '-rw_timeout') {
            arguments[++i] = localTimeout;
            replaced = true;
          }
        }
        if (!replaced) arguments.insertAll(inputIndex, ['-rw_timeout', localTimeout]);
      }
      final beforeInput = arguments.take(arguments.indexOf('-i'));
      if (prefetchEnabled && !beforeInput.contains('-live_start_index') && !beforeInput.contains('-prefer_x_start')) {
        // Admission occurs on the first GET, after native arguments are fixed.
        // Enable hints, not a global zero index: only selected media publishes
        // our zero-offset hint. Caller-specified native policy stays explicit.
        _automaticStartHint = true;
        arguments.insertAll(arguments.indexOf('-i'), ['-prefer_x_start', '1']);
      }
    }
    return List<String>.unmodifiable(arguments);
  }

  /// Freeze each media playlist at the last published generation with ENDLIST.
  /// Legacy inputs get one target duration. Prefetched inputs settle the fixed
  /// set of already offered dependencies within a bounded download phase.
  Future<void> finish() async {
    if (!drainOnStop || _finishing || _closed) return;
    _finishing = true;
    _preparingCancellation?.cancel();
    final prefetch = _prefetch;
    if (prefetch == null) {
      _finishTimer = Timer(Duration(seconds: _targetSeconds.clamp(1, 10)), _stopFetching);
    } else {
      _diagnosePrefetchDownloads('stop-requested');
      _prefetchDrain = prefetch.drainPublished(timeout: _prefetchDownloadGrace).then((complete) {
        _diagnosePrefetchDownloads('downloads-ended');
        if (!complete && !_closed) _inputTailDiscarded = true;
        _stopFetching();
      });
    }
  }

  void _stopFetching() {
    _fetchStopped = true;
    _preparingCancellation?.cancel();
    _prefetch?.stopFetching();
    _upstream.stop();
    for (final abort in _fetchAborters.toList()) {
      abort();
    }
    _connections.cancel();
    _client.close(force: true);
  }

  void _acceptRequest(HttpRequest request) {
    final handling = _handleRequest(request);
    _handlers.add(handling);
    unawaited(
      handling.whenComplete(() => _handlers.remove(handling)).catchError((Object error, StackTrace stack) {
        _handleServerError(error, stack);
      }),
    );
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    _closed = true;
    _finishTimer?.cancel();
    _stopFetching();
    _cookies.clear();
    _client.close(force: true);
    await _server.close(force: true);
    await _subscription?.cancel();
    await Future.wait(_handlers.toList());
    await _prefetchDrain;
    await _prefetch?.close();
    await _connections.settled;
    _upstream.clear();
    _masterSelection = null;
    _manifestMediaTransform = null;
    _resources.clear();
    _resourceTransforms.clear();
    _resourceIds.clear();
    _manifests.clear();
    _manifestReferences.clear();
    _resourceKeys.clear();
    _prefetchResources.clear();
    _prefetchFeeds.clear();
    _prefetchFailures.clear();
    onCoverageIncomplete = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final segments = request.uri.pathSegments;
    if (_closed || segments.length != 2 || segments.first != _secret) {
      await _replyStatus(request, HttpStatus.notFound);
      return;
    }
    final resourceId = segments.last.split('.').first;
    final upstream = _resources[resourceId];
    if (upstream == null || (request.method != 'GET' && request.method != 'HEAD')) {
      await _replyStatus(request, upstream == null ? HttpStatus.notFound : HttpStatus.methodNotAllowed);
      return;
    }

    _activeResources.update(resourceId, (count) => count + 1, ifAbsent: () => 1);
    final prefixTransform = _resourceTransforms[resourceId];
    final trace = diagnostics?._begin(resourceId, request.method);
    final budget = drainOnStop ? HlsResponseBudget(_bodyIdleTimeout) : null;
    var outcome = 'completed';
    try {
      final cached = _manifests[resourceId];
      if (_finishing && (cached != null || _isHlsUri(upstream))) {
        final ended = _endedManifest(cached);
        trace?.offeredManifest(ended, 'cached-stop');
        await _replyManifest(request, ended);
        trace?.delivered();
        return;
      }
      final range = request.headers.value(HttpHeaders.rangeHeader);
      if (prefixTransform != null && range != null && range != 'bytes=0-') {
        await _replyStatus(request, HttpStatus.requestedRangeNotSatisfiable);
        return;
      }
      if (_prefetch != null) {
        if (_prefetchFeeds.contains(resourceId)) {
          await _servePrefetchManifest(request, resourceId, trace);
        } else if (_prefetchResources.containsKey(resourceId)) {
          await _servePrefetchBody(request, _prefetchResources[resourceId]!, range, trace);
        } else if (resourceId == 'root' && cached != null) {
          trace?.offeredManifest(cached, 'selected-master');
          await _replyManifest(request, cached);
          trace?.delivered();
        } else {
          // A selected generation has one media pool. Do not create a parallel
          // legacy spool budget for unselected/comment-only resource IDs.
          await _replyStatus(request, HttpStatus.gone);
        }
        return;
      }
      // FFmpeg probes even playlists with Range: bytes=0-. A CDN may return
      // 206, which is not a complete rewritten manifest response: forwarding
      // its relative segment paths makes FFmpeg request unknown loopback IDs.
      // Fetch known playlists whole; retain byte ranges for media/key inputs.
      final (upstreamResponse, finalUri) = await _openUpstream(
        request.method,
        upstream,
        budget: budget,
        range: prefixTransform != null || _isHlsUri(upstream) || _manifests.containsKey(resourceId) ? null : range,
      );
      request.response.statusCode = upstreamResponse.statusCode;
      trace?.receivedHeaders(upstreamResponse.statusCode);
      final contentType = upstreamResponse.headers.contentType;
      if (contentType != null) request.response.headers.contentType = contentType;
      _copyResponseHeader(upstreamResponse, request.response, HttpHeaders.acceptRangesHeader);
      _copyResponseHeader(upstreamResponse, request.response, HttpHeaders.contentRangeHeader);

      if (request.method == 'HEAD') {
        if (budget == null) {
          await upstreamResponse.drain<void>();
        } else {
          await _discardResponse(upstreamResponse, budget);
        }
        await request.response.close();
        trace?.delivered();
        return;
      }

      if (upstreamResponse.statusCode == HttpStatus.ok && _isManifest(finalUri, contentType)) {
        final bytes = await _readManifest(upstreamResponse, trace, budget);
        if (_closed) return;
        var manifest = utf8.decode(bytes, allowMalformed: _masterSelection == null);
        if (resourceId == 'root' && _masterSelection != null) {
          manifest = _masterSelection!.rewrite(finalUri, manifest);
        }
        if (resourceId == 'root' && prefetchEnabled && !_finishing) {
          await (_prefetchPreparation ??= _preparePrefetch(manifest, finalUri));
          if (_prefetchFeeds.contains(resourceId) && !_finishing && !_closed) {
            await _servePrefetchManifest(request, resourceId, trace);
            return;
          }
        }
        // A root response opened before selection may finish after another
        // request committed the master. Keep that selected generation intact.
        final selectedMaster = _manifests[resourceId];
        if (resourceId == 'root' && _prefetch != null && selectedMaster != null) {
          final offered = _finishing ? _endedManifest(selectedMaster) : selectedMaster;
          trace?.offeredManifest(offered, 'selected-master');
          await _replyManifest(request, offered);
          trace?.delivered();
          return;
        }
        // Stop may arrive while a refresh is in flight. Do not extend the
        // recording by publishing its newer generation after the stop intent.
        final previous = _manifests[resourceId];
        final rewritten = _finishing && previous != null ? previous : _rewriteManifest(manifest, finalUri, resourceId);
        final offered = _finishing ? _endedManifest(rewritten) : rewritten;
        trace?.offeredManifest(offered, _finishing && previous != null ? 'previous-stop' : 'upstream');
        await _replyManifest(request, offered);
        trace?.delivered();
        return;
      }

      final length = upstreamResponse.contentLength;
      if (drainOnStop && const {HttpStatus.ok, HttpStatus.partialContent}.contains(upstreamResponse.statusCode)) {
        await _publishCompleteBody(request, upstreamResponse, trace, budget, prefixTransform);
        return;
      }
      if (budget != null) {
        // Native needs the HTTP error status, not an unbounded CDN error body.
        await _discardResponse(upstreamResponse, budget);
        await _replyStatus(request, upstreamResponse.statusCode);
        trace?.delivered();
        return;
      }
      if (length >= 0) request.response.contentLength = length;
      request.response.bufferOutput = false;
      final body = prefixTransform == null
          ? upstreamResponse
          : _transformMediaPrefix(upstreamResponse, prefixTransform);
      if (trace == null) {
        await body.pipe(request.response);
      } else {
        await body
            .map((chunk) {
              trace.chunk(chunk);
              return chunk;
            })
            .pipe(request.response);
        // For streaming responses completion includes the local writer.
        trace.completeBody();
        trace.delivered();
      }
    } on _HlsFetchStopped {
      outcome = 'stopped';
      final cached = _manifests[resourceId];
      if (cached != null || _isHlsUri(upstream)) {
        final ended = _endedManifest(cached);
        trace?.offeredManifest(ended, 'cached-stop');
        await _replyManifest(request, ended);
        trace?.delivered();
      } else {
        // A missing whole tail fragment is not a corrupt partially delivered one.
        if (_finishing && !_closed) _inputTailDiscarded = true;
        await _replyStatus(request, HttpStatus.gone);
      }
    } on TimeoutException {
      outcome = 'timedOut';
      await _replyStatus(request, HttpStatus.gatewayTimeout);
    } on Object catch (error) {
      outcome = 'failed';
      if (!_closed) Log.w('FFmpeg HLS relay request failed for ${upstream.host}: ${error.runtimeType}');
      await _replyStatus(request, HttpStatus.badGateway);
    } finally {
      if (trace != null) {
        trace.finishedMs = trace.clock.elapsedMilliseconds;
        trace.localStatus = request.response.statusCode;
        trace.outcome = outcome;
      }
      final count = _activeResources[resourceId] ?? 1;
      if (count <= 1) {
        _activeResources.remove(resourceId);
      } else {
        _activeResources[resourceId] = count - 1;
      }
      _pruneResources();
    }
  }

  Future<void> _publishCompleteBody(
    HttpRequest request,
    HttpClientResponse upstream,
    _HlsRequestTrace? trace,
    HlsResponseBudget? budget,
    HlsMediaPrefixTransform? prefixTransform,
  ) async {
    final iterator = HlsBodyReader(upstream);
    final body = HlsMediaSpool(createDirectory: _createStagingDirectory);
    final transformer = prefixTransform == null ? null : _HlsMediaPrefixState(prefixTransform);
    var stopped = _fetchStopped;
    void abort() {
      stopped = true;
      unawaited(iterator.cancel().catchError((Object _) {}));
    }

    // Bound per-relay staging memory (8 x 2 MiB) and spool-file ownership.
    final admitted = _stagingBodies < 8;
    if (admitted) _stagingBodies++;
    try {
      if (!admitted) {
        await _replyStatus(request, HttpStatus.serviceUnavailable);
        return;
      }
      if (stopped) throw const _HlsFetchStopped();
      _fetchAborters.add(abort);
      while (await _nextBodyChunk(iterator, budget)) {
        if (stopped) throw const _HlsFetchStopped();
        for (final chunk in transformer?.add(iterator.current) ?? <List<int>>[iterator.current]) {
          trace?.chunk(chunk);
          await body.add(chunk);
        }
      }
      transformer?.finish();
      if (stopped) throw const _HlsFetchStopped();
      trace?.completeBody();
      await body.seal(
        expectedLength: upstream.compressionState == HttpClientResponseCompressionState.decompressed
            ? -1
            : upstream.contentLength,
      );
      if (stopped) throw const _HlsFetchStopped();
      budget?.check();
      _fetchAborters.remove(abort);
      request.response.contentLength = body.length;
      request.response.bufferOutput = false;
      await request.response.addStream(body.read());
      await request.response.close();
      trace?.delivered();
    } finally {
      _fetchAborters.remove(abort);
      try {
        await iterator.cancel();
      } finally {
        try {
          await body.dispose();
        } finally {
          if (admitted) _stagingBodies--;
        }
      }
    }
  }

  static Future<Directory> _defaultStagingDirectory() async {
    final root = Platform.isAndroid ? await getTemporaryDirectory() : Directory.systemTemp;
    return root.createTemp('purelive-hls-media-');
  }

  Future<(HttpClientResponse, Uri)> _openUpstream(
    String method,
    Uri upstream, {
    String? range,
    HlsResponseBudget? budget,
  }) async {
    try {
      return await _upstream.open(method, upstream, range: range, budget: budget);
    } on HlsUpstreamStopped {
      throw const _HlsFetchStopped();
    }
  }

  String _rewriteManifest(String source, Uri baseUri, String manifestId) {
    final hadTrailingNewline = source.endsWith('\n');
    final output = <String>[];
    final referenced = <String>{};
    final mediaTransform = _manifestMediaTransform?.call(baseUri, source);
    for (final rawLine in const LineSplitter().convert(source)) {
      final line = rawLine.endsWith('\r') ? rawLine.substring(0, rawLine.length - 1) : rawLine;
      final trimmed = line.trim();
      // Native's default ignores source START hints. When we introduce hint
      // support for selected caches, keep unselected/legacy sources at that
      // same default instead of accidentally honoring their DVR seek hint.
      if (_automaticStartHint && trimmed.startsWith('#EXT-X-START:')) continue;
      if (trimmed.isEmpty) {
        output.add('');
      } else if (trimmed.startsWith('#')) {
        output.add(
          line.replaceAllMapped(_uriAttribute, (match) {
            final replacement = _localResource(baseUri.resolve(match.group(1)!), referenced);
            return replacement == null ? match.group(0)! : 'URI="$replacement"';
          }),
        );
      } else {
        output.add(_localResource(baseUri.resolve(trimmed), referenced, mediaTransform: mediaTransform) ?? line);
      }
    }
    final value = output.join('\n');
    final rewritten = hadTrailingNewline ? '$value\n' : value;
    return _rememberManifest(rewritten, source, manifestId, referenced);
  }

  String _rememberManifest(String rewritten, String source, String manifestId, Set<String> referenced) {
    // Per-response cap plus aggregate cap bound malicious/oversized trees.
    final retainedCharacters = _manifests.entries
        .where((entry) => entry.key != manifestId)
        .fold<int>(0, (total, entry) => total + entry.value.length);
    if (retainedCharacters + rewritten.length > 8 * 1024 * 1024) {
      throw const FormatException('HLS manifest tree exceeds the relay limit');
    }
    _manifests[manifestId] = rewritten;
    final previous = _manifestReferences[manifestId];
    _manifestReferences[manifestId] = [referenced, if (previous != null) previous.first];
    final target = RegExp(r'^#EXT-X-TARGETDURATION:(\d+)', multiLine: true).firstMatch(source);
    _targetSeconds = max(_targetSeconds, int.tryParse(target?.group(1) ?? '') ?? 1);
    // Publish a generation only after its registry is reconciled. Waiting for
    // response.close lets the next request observe an obsolete third window.
    _pruneResources();
    return rewritten;
  }

  String? _localResource(
    Uri upstream,
    Set<String> referenced, {
    String? identity,
    HlsMediaPrefixTransform? mediaTransform,
  }) {
    if (!const <String>{'http', 'https'}.contains(upstream.scheme.toLowerCase())) return null;
    final key = identity == null ? upstream.toString() : 'prefetch:$identity';
    final id = _resourceIds.putIfAbsent(key, () {
      final value = (++_nextResourceId).toRadixString(36);
      _resources[value] = upstream;
      _resourceKeys[value] = key;
      return value;
    });
    if (mediaTransform != null) _resourceTransforms[id] = mediaTransform;
    referenced.add(id);
    final extension = _localExtension(upstream);
    return Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _server.port,
      path: '/$_secret/$id$extension',
    ).toString();
  }

  void _pruneResources() {
    if (_closed) return;
    final reachable = <String>{};
    final required = _prefetch?.requiredKeys ?? <String>{};
    final pending = <String>[
      'root',
      ..._activeResources.keys,
      ..._prefetchFeeds,
      for (final entry in _prefetchResources.entries)
        if (required.contains(entry.value.key)) entry.key,
    ];
    while (pending.isNotEmpty) {
      final id = pending.removeLast();
      if (!reachable.add(id)) continue;
      for (final generation in _manifestReferences[id] ?? <Set<String>>[]) {
        pending.addAll(generation);
      }
    }
    for (final id in _resources.keys.where((id) => !reachable.contains(id)).toList()) {
      _resources.remove(id);
      _resourceTransforms.remove(id);
      final key = _resourceKeys.remove(id);
      if (key != null) _resourceIds.remove(key);
      _prefetchResources.remove(id);
      _manifests.remove(id);
      _manifestReferences.remove(id);
    }
    _prefetchFailures.removeWhere((key, _) => !key.startsWith('manifest:') && !required.contains(key));
  }

  static String _endedManifest(String? cached) {
    if (cached == null) return '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-ENDLIST\n';
    // ENDLIST belongs to media playlists, never a master variant catalogue.
    if (!cached.contains('#EXT-X-TARGETDURATION:') || cached.contains('#EXT-X-ENDLIST')) return cached;
    return '${cached.trimRight()}\n#EXT-X-ENDLIST\n';
  }

  static Future<void> _replyManifest(HttpRequest request, String manifest) async {
    request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl', charset: 'utf-8');
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    if (request.method != 'HEAD') request.response.write(manifest);
    await request.response.close();
  }

  static bool _isHlsUri(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return const <String>{'http', 'https'}.contains(scheme) && _hlsPath.hasMatch(uri.path);
  }

  /// FFmpeg validates an HLS child URL's suffix before opening it. Opaque
  /// loopback IDs therefore keep a known media suffix even when a CDN uses a
  /// suffix-less or script-style URL. The response bytes remain authoritative
  /// for demuxing; this only passes FFmpeg's pre-open allow-list.
  static String _localExtension(Uri upstream) {
    if (_isHlsUri(upstream)) return '.m3u8';
    final lastSegment = upstream.pathSegments.isEmpty ? '' : upstream.pathSegments.last;
    final separator = lastSegment.lastIndexOf('.');
    if (separator >= 0 && separator + 1 < lastSegment.length) {
      final extension = lastSegment.substring(separator + 1).toLowerCase();
      if (_allowedMediaExtensions.contains(extension)) return '.$extension';
    }
    return '.ts';
  }

  static bool _isManifest(Uri uri, ContentType? contentType) {
    if (_isHlsUri(uri)) return true;
    final mime = contentType?.mimeType.toLowerCase() ?? '';
    return mime.contains('mpegurl') || mime == 'application/x-mpegurl';
  }

  static Map<String, String> _readInputHeaders(List<String> arguments, int inputIndex) {
    final headers = <String, String>{};
    for (var index = 0; index < inputIndex - 1; index++) {
      final option = arguments[index];
      final value = arguments[index + 1];
      if (option == '-user_agent' && value.trim().isNotEmpty) {
        headers[HttpHeaders.userAgentHeader] = value.trim();
      } else if (option == '-headers') {
        for (final line in value.split(RegExp(r'[\r\n]+'))) {
          final separator = line.indexOf(':');
          if (separator <= 0) continue;
          final name = line.substring(0, separator).trim();
          final headerValue = line.substring(separator + 1).trim();
          if (name.isEmpty || headerValue.isEmpty || _isHopByHopHeader(name)) continue;
          headers[name] = headerValue;
        }
      }
    }
    return Map<String, String>.unmodifiable(headers);
  }

  static Duration _readBodyIdleTimeout(List<String> arguments, int inputIndex) {
    // Production command construction supplies a positive input rw_timeout.
    // Only inspect this input's options; later output options are unrelated.
    var microseconds = const Duration(seconds: 15).inMicroseconds;
    for (var index = 0; index < inputIndex - 1; index++) {
      if (arguments[index] != '-rw_timeout') continue;
      final value = int.tryParse(arguments[index + 1]);
      if (value != null && value > 0) microseconds = value.clamp(1, 2147483647);
    }
    return Duration(microseconds: microseconds);
  }

  Future<bool> _nextBodyChunk(StreamIterator<List<int>> iterator, HlsResponseBudget? budget) async {
    if (!drainOnStop) return iterator.moveNext();
    try {
      // The body is invisible to the native socket until completely staged.
      // Observe upstream idleness here, rather than mistaking the whole
      // transfer duration for inactivity. Disk backpressure is not network
      // idle time. Both callers cancel their iterator in finally on timeout.
      return await budget!.wait(iterator.moveNext);
    } on TimeoutException {
      if (_fetchStopped) throw const _HlsFetchStopped();
      rethrow;
    }
  }

  Future<void> _discardResponse(HttpClientResponse response, HlsResponseBudget budget) async {
    final iterator = HlsBodyReader(response);
    var stopped = _fetchStopped;
    void abort() {
      stopped = true;
      unawaited(iterator.cancel().catchError((Object _) {}));
    }

    _fetchAborters.add(abort);
    try {
      if (stopped) throw const _HlsFetchStopped();
      while (await _nextBodyChunk(iterator, budget)) {
        if (stopped) throw const _HlsFetchStopped();
      }
      if (stopped) throw const _HlsFetchStopped();
    } finally {
      _fetchAborters.remove(abort);
      await iterator.cancel();
    }
  }

  static bool _isHopByHopHeader(String name) {
    return const <String>{
      'connection',
      'content-length',
      'host',
      'keep-alive',
      'proxy-authenticate',
      'proxy-authorization',
      'te',
      'trailer',
      'transfer-encoding',
      'upgrade',
    }.contains(name.toLowerCase());
  }

  static String _newSecret() {
    final random = Random.secure();
    final bytes = Uint8List.fromList(List<int>.generate(18, (_) => random.nextInt(256), growable: false));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  Future<Uint8List> _readManifest(
    HttpClientResponse response,
    _HlsRequestTrace? trace,
    HlsResponseBudget? budget,
  ) async {
    final builder = BytesBuilder(copy: false);
    var length = 0;
    final iterator = HlsBodyReader(response);
    var stopped = _fetchStopped;
    void abort() {
      stopped = true;
      unawaited(iterator.cancel().catchError((Object _) {}));
    }

    _fetchAborters.add(abort);
    try {
      if (stopped) throw const _HlsFetchStopped();
      while (await _nextBodyChunk(iterator, budget)) {
        if (stopped) throw const _HlsFetchStopped();
        final chunk = iterator.current;
        trace?.chunk(chunk);
        length += chunk.length;
        if (length > _maximumManifestBytes) throw const FormatException('HLS manifest exceeds the relay limit');
        builder.add(chunk);
      }
      if (stopped) throw const _HlsFetchStopped();
      trace?.completeBody();
      return builder.takeBytes();
    } finally {
      _fetchAborters.remove(abort);
      await iterator.cancel();
    }
  }

  static void _copyResponseHeader(HttpClientResponse source, HttpResponse destination, String name) {
    final value = source.headers.value(name);
    if (value != null && value.isNotEmpty) destination.headers.set(name, value);
  }

  static Future<void> _replyStatus(HttpRequest request, int status) async {
    try {
      request.response.statusCode = status;
      request.response.headers.contentLength = 0;
    } on StateError {
      // A streaming response may already have committed its headers. Closing
      // it still wakes FFmpeg immediately instead of leaving a partial request
      // waiting for the read timeout.
    }
    try {
      await request.response.close();
    } on Object {
      // The native reader or service close may already have ended this socket.
    }
  }

  void _handleServerError(Object error, StackTrace stackTrace) {
    if (!_closed) Log.w('FFmpeg HLS relay server failed: $error\n$stackTrace');
  }
}

Stream<List<int>> _transformMediaPrefix(Stream<List<int>> source, HlsMediaPrefixTransform transform) async* {
  final state = _HlsMediaPrefixState(transform);
  await for (final chunk in source) {
    for (final output in state.add(chunk)) {
      yield output;
    }
  }
  state.finish();
}

final class _HlsMediaPrefixState {
  _HlsMediaPrefixState(this.transform);

  final HlsMediaPrefixTransform transform;
  final BytesBuilder _prefix = BytesBuilder(copy: false);
  bool _complete = false;

  Iterable<List<int>> add(List<int> chunk) {
    if (_complete) return <List<int>>[chunk];
    final needed = transform.prefixBytes - _prefix.length;
    if (chunk.length < needed) {
      _prefix.add(chunk);
      return const <List<int>>[];
    }
    _prefix.add(chunk.sublist(0, needed));
    final original = _prefix.takeBytes();
    final transformed = transform.transform(original);
    if (transformed.length != transform.prefixBytes) {
      throw const FormatException('HLS media prefix transform changed the body length');
    }
    _complete = true;
    return <List<int>>[transformed, if (chunk.length > needed) chunk.sublist(needed)];
  }

  void finish() {
    if (!_complete) throw const FormatException('HLS media body ended before its transform prefix');
  }
}

class _HlsFetchStopped implements Exception {
  const _HlsFetchStopped();
}
