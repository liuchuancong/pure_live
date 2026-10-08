part of 'ffmpeg_hls_input_relay.dart';

extension _HlsRelayPrefetch on FFmpegHlsInputRelay {
  void _diagnosePrefetchDownloads(String phase) {
    final observer = diagnostics;
    final prefetch = _prefetch;
    if (observer == null || prefetch == null) return;
    try {
      observer._prefetchDownloads(
        phase,
        _prefetchResources.entries.map(
          (entry) => {
            'resourceId': entry.key,
            'kind': entry.value.kind.name,
            'feedId': entry.value.feedId,
            'sequence': entry.value.sequence,
            ...prefetch.describeDownload(entry.value.key),
          },
        ),
      );
    } on Object {
      /* Observation must not affect drain, cancellation or file ownership. */
    }
  }

  Future<void> _preparePrefetch(String master, Uri source) async {
    final cancellation = HlsPrefetchCancellation();
    _preparingCancellation = cancellation;
    HlsPrefetchScheduler? candidate;
    try {
      final plan = HlsPrefetchPlan.fromMaster(master, source);
      final selections = <HlsPrefetchSelection>[];
      if (plan == null) {
        selections.add((id: 'root', source: _resources['root']!, snapshot: HlsMediaSnapshot.parse(master, source)));
      } else {
        // The plan contains at most two already selected feeds. Serial initial
        // reads age the first short live window while waiting for the second.
        // Share cancellation and await every loader, including a cancelled peer,
        // before admitting the whole set or returning to the original path.
        Future<HlsMediaSnapshot> load(Uri uri) async {
          try {
            return await _upstream.loadSnapshot(uri, cancellation, budget: HlsResponseBudget(_bodyIdleTimeout));
          } on Object {
            cancellation.cancel();
            rethrow;
          }
        }

        final snapshots = await Future.wait(plan.sources.map(load));
        cancellation.throwIfCancelled();
        // Future.wait preserves selection order even if audio finishes first.
        for (var i = 0; i < plan.sources.length; i++) {
          final uri = plan.sources[i];
          final local = _localResource(uri, {});
          if (local == null) throw const FormatException('Invalid selected source');
          final id = Uri.parse(local).pathSegments.last.split('.').first;
          selections.add((id: id, source: uri, snapshot: snapshots[i]));
        }
      }
      if (_closed || _finishing || cancellation.isCancelled) return;
      final pool = HlsPrefetchPool(
        createDirectory: _createStagingDirectory,
        maximumEntries: 32,
        maximumConcurrent: 16,
        memoryBytesPerBody: 512 * 1024,
        bodyIdleTimeout: _bodyIdleTimeout,
        enableDiagnostics: diagnostics != null,
      );
      candidate = HlsPrefetchScheduler(
        pool: pool,
        maximumFeeds: selections.length,
        fetchSnapshot: (uri, token) async {
          try {
            return await _upstream.loadSnapshot(uri, token, budget: HlsResponseBudget(_bodyIdleTimeout));
          } on HlsUpstreamResponseException catch (error) {
            _prefetchFailures['manifest:$uri'] = error.statusCode;
            rethrow;
          }
        },
        loadResource: (resource, token) async {
          try {
            return await _upstream.loadMedia(
              resource.uri,
              token,
              range: resource.range,
              budget: HlsResponseBudget(_bodyIdleTimeout),
            );
          } on HlsUpstreamResponseException catch (error) {
            if (_prefetchFailures.length < 512) _prefetchFailures[resource.key] = error.statusCode;
            rethrow;
          }
        },
        onCoverageGap: () => onCoverageIncomplete?.call(),
        onRefreshFailure: diagnostics?._prefetchRefreshFailed,
      );
      if (!candidate.selectAll(selections)) return;
      _prefetch = candidate;
      _prefetchFeeds.addAll(selections.map((s) => s.id));
      candidate = null; // Ownership transferred to relay.close.
    } on Object {
      // Failure before atomic selection preserves the entire original path.
      // No partially enabled A/V set and no guessed quality/language choice.
    } finally {
      await candidate?.close();
      _preparingCancellation = null;
    }
  }

  Future<void> _servePrefetchManifest(HttpRequest request, String id, _HlsRequestTrace? trace) async {
    final references = <String>{};
    final String text;
    try {
      text = _prefetch!.publish(id, (resource) {
        final local = _localResource(resource.uri, references, identity: resource.key)!;
        final resourceId = Uri.parse(local).pathSegments.last.split('.').first;
        _prefetchResources[resourceId] = resource;
        return Uri.parse(local);
      }, startAtFirst: _automaticStartHint);
    } on StateError {
      await FFmpegHlsInputRelay._replyStatus(request, _prefetchFailures['manifest:${_resources[id]}'] ?? 502);
      return;
    }
    _rememberManifest(text, text, id, references);
    trace?.offeredManifest(text, 'upstream');
    await FFmpegHlsInputRelay._replyManifest(request, text);
    trace?.delivered();
  }

  Future<void> _servePrefetchBody(
    HttpRequest request,
    HlsPrefetchResource resource,
    String? range,
    _HlsRequestTrace? trace,
  ) async {
    final lease = await _prefetch!.acquire(resource.key);
    if (lease == null) {
      if (_finishing && !_closed) _inputTailDiscarded = true;
      await FFmpegHlsInputRelay._replyStatus(request, _prefetchFailures[resource.key] ?? (_finishing ? 410 : 503));
      return;
    }
    try {
      final metadata = lease.metadata!;
      if (metadata.contentType != null) {
        request.response.headers.set(HttpHeaders.contentTypeHeader, metadata.contentType!);
      }
      if (request.method == 'HEAD') {
        // Range is defined for GET. HEAD reports whole-representation
        // metadata, never the size/status of our internally cached slice.
        request.response.statusCode = HttpStatus.ok;
        final length = resource.range == null
            ? lease.length
            : int.tryParse(metadata.contentRange?.split('/').last ?? '');
        if (length != null) request.response.contentLength = length;
        trace?.receivedHeaders(HttpStatus.ok);
        await request.response.close();
        trace?.delivered();
        return;
      }
      // Whole objects may ignore Range and return 200. A cached absolute
      // BYTERANGE is only the declared slice: never label it a full object.
      if (resource.range != null && range != resource.range!.requestHeader) {
        await FFmpegHlsInputRelay._replyStatus(request, HttpStatus.requestedRangeNotSatisfiable);
        return;
      }
      request.response.statusCode = metadata.statusCode;
      trace?.receivedHeaders(metadata.statusCode);
      if (metadata.contentRange != null) {
        request.response.headers.set(HttpHeaders.contentRangeHeader, metadata.contentRange!);
      }
      request.response.contentLength = lease.length;
      await lease.writeTo(_PrefetchTraceConsumer(request.response, trace));
      trace?.completeBody();
      await request.response.close();
      if (request.method == 'GET') _prefetch!.delivered(resource.key);
      trace?.delivered();
    } finally {
      await lease.release();
    }
  }
}

final class _PrefetchTraceConsumer implements StreamConsumer<List<int>> {
  _PrefetchTraceConsumer(this.response, this.trace);
  final HttpResponse response;
  final _HlsRequestTrace? trace;
  @override
  Future<void> addStream(Stream<List<int>> stream) => response.addStream(
    stream.map((chunk) {
      trace?.chunk(chunk);
      return chunk;
    }),
  );
  @override
  Future<void> close() => response.close();
}
