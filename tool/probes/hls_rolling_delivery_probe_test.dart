// Opt-in native, loopback-only reproduction of short HLS windows and slow
// whole-fragment delivery. No real platform, device, or user preferences.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/core/config/log_controller.dart';
import 'package:pure_live/core/storage/hive_pref_util.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_command_builder.dart';
import 'package:pure_live/domains/recorder/data/ffmpeg/ffmpeg_manager.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';
import 'package:pure_live/domains/recorder/data/services/hls_body_reader.dart';
import 'package:pure_live/domains/recorder/data/services/hls_prefetch_pool.dart';
import 'package:pure_live/domains/recorder/data/services/hls_prefetch_plan.dart';
import 'package:pure_live/domains/recorder/data/services/hls_prefetch_scheduler.dart';
import 'package:pure_live/core/stream/hls_session_cookies.dart';
import 'package:pure_live/domains/recorder/data/services/hls_upstream_client.dart';
import 'package:pure_live/domains/recorder/data/services/recorder_proxy_routing.dart';

import 'media_packet_timeline.dart';

part 'hls_scheduled_delivery_probe.dart';
part 'hls_start_boundary_probe.dart';
part 'hls_refresh_coverage_probe.dart';
part 'hls_shortest_boundary_probe.dart';

typedef _Scenario = ({String name, int budget, int bodyMs, int headerMs, int runSeconds});

void main() {
  _registerScheduledDeliveryProbe();
  _registerStartBoundaryProbe();
  _registerRefreshCoverageProbe();
  _registerShortestBoundaryProbe();
  test('whole-media accounting excludes empty HTTP failures and unfinished bodies', () {
    final traces = <Map<String, Object?>>[
      {'upstreamStatus': 200, 'bodyCompleteMs': 12000},
      {'upstreamStatus': 206, 'bodyCompleteMs': 12000},
      {'upstreamStatus': 410, 'bodyCompleteMs': 1},
      {'upstreamStatus': 503, 'bodyCompleteMs': 1},
      {'upstreamStatus': 206, 'bodyCompleteMs': null},
    ];
    expect(_completedMedia(traces), traces.take(2));
  });
  test('request overlap ignores rejected and unfinished media', () {
    expect(
      _requestOverlap([
        {'path': '/variant_0/segment_000.m4s', 'requestMs': 0, 'closedMs': 12000, 'bytes': 10},
        {'path': '/variant_0/segment_001.m4s', 'requestMs': 1, 'expiredAtRequest': true},
        {'path': '/variant_0/segment_002.m4s', 'requestMs': 13000},
      ])['overlapped'],
      false,
    );
    expect(
      _requestOverlap([
        {'path': '/variant_0/segment_000.m4s', 'requestMs': 0, 'closedMs': 12000, 'bytes': 10},
        {'path': '/variant_0/segment_001.m4s', 'requestMs': 10, 'closedMs': 12010, 'bytes': 10},
      ])['overlapped'],
      true,
    );
  });
  test(
    'native request overlap distinguishes early headers from complete staging',
    () async {
      final fixture = Directory(Platform.environment['PURELIVE_ROLLING_HLS_FIXTURE']!);
      final root = await Directory(
        p.join(
          Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!,
          'scheduling-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      Hive.init((await Directory(p.join(root.path, 'hive')).create()).path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      configureRecorderProxyRouting((_) => 'DIRECT');
      final reports = <Map<String, Object?>>[];
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          for (final config in [
            (name: 'direct-body-multiple', relay: false, multiple: 1, header: false),
            (name: 'direct-body-single', relay: false, multiple: 0, header: false),
            (name: 'direct-headers-multiple', relay: false, multiple: 1, header: true),
            (name: 'relay-body-multiple', relay: true, multiple: 1, header: false),
          ]) {
            reports.add(
              await _captureScheduling(
                fixture,
                root,
                name: config.name,
                useRelay: config.relay,
                multiple: config.multiple,
                delayHeaders: config.header,
              ),
            );
          }
        }, _RealNetwork());
        expect(reports.map((r) => (r['overlap'] as Map)['overlapped']), [true, false, false, false]);
        for (final report in reports) {
          expect(report['nativeReadTimeoutMicros'], 60000000);
          expect(report['nativeHttpMultiple'], report['httpMultiple']);
          expect((report['overlap'] as Map)['completeVideoRequests'] as int, greaterThanOrEqualTo(2));
        }
      } finally {
        await File(p.join(root.path, 'summary.json'))
            .writeAsString(const JsonEncoder.withIndent('  ').convert(reports));
        // ignore: avoid_print
        print(jsonEncode(reports));
        configureRecorderProxyRouting(null);
        Get.reset();
        await Hive.close();
      }
    },
    skip: Platform.environment['PURELIVE_HLS_SCHEDULING_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
  test(
    'rolling CMAF separates read budget from sustained delivery deficit',
    () async {
      final fixture = Directory(Platform.environment['PURELIVE_ROLLING_HLS_FIXTURE']!);
      final root = await Directory(
        p.join(
          Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!,
          'rolling-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      Hive.init((await Directory(p.join(root.path, 'hive')).create()).path);
      await HivePrefUtil.init();
      Get.testMode = true;
      Get.put(LogController());
      configureRecorderProxyRouting((_) => 'DIRECT');
      final reports = <Map<String, Object?>>[];
      try {
        await HttpOverrides.runWithHttpOverrides(() async {
          for (final config in <_Scenario>[
            (name: 'healthy-10', budget: 10, bodyMs: 0, headerMs: 0, runSeconds: 12),
            (name: 'continuous-body-10', budget: 10, bodyMs: 12000, headerMs: 0, runSeconds: 34),
            (name: 'continuous-body-15', budget: 15, bodyMs: 12000, headerMs: 0, runSeconds: 34),
            (name: 'delayed-headers-15', budget: 15, bodyMs: 0, headerMs: 12000, runSeconds: 34),
          ]) {
            reports.add(await _capture(config, fixture, root));
          }
        }, _RealNetwork());
        final baseline = reports.first;
        expect(baseline['started'], true);
        expect(baseline['inputCoverageIncomplete'], false);
        expect(baseline['coverageWarningCount'], 0);
        expect(baseline['outputBytes'] as int, greaterThan(0));
        expect((baseline['inspection'] as Map)['exitCode'], 0);
        for (final report in reports.skip(1)) {
          expect(report['inputCoverageIncomplete'], true);
          expect(report['coverageWarningCount'], 1);
          expect(report['completedUpstreamVideoRequests'] as int, greaterThanOrEqualTo(1));
          expect(report['windowDurationSeconds'], 6);
          expect(report['minimumWholeBodyMs'] as int, greaterThanOrEqualTo(12000));
        }
        // Upstream idle budget no longer doubles as the whole-body loopback
        // wait. Both now receive the same continuously arriving 12s response.
        expect(reports[1]['refreshBeforeFirstVideoComplete'], false);
        expect(reports[1]['started'], true);
        expect(reports[1]['outputBytes'] as int, greaterThan(0));
        expect(reports[2]['refreshBeforeFirstVideoComplete'], false);
        expect(reports[3]['refreshBeforeFirstVideoComplete'], false);
        for (final report in reports) {
          expect(report['nativeReadTimeoutMicros'], ((report['rwTimeout'] as int) * 4 + 20) * 1000000);
          final terminal = (report['events'] as List).last as Map;
          expect(terminal['forcedCancel'], false);
          expect(terminal['inputDrained'], true);
          expect(terminal['inputIntegrityError'], false);
        }
        expect(
          reports[2]['receivedVideoSequenceGaps'],
          true,
          reason: 'A longer local budget does not restore expired intermediate media.',
        );
      } finally {
        await File(p.join(root.path, 'summary.json'))
            .writeAsString(const JsonEncoder.withIndent('  ').convert(reports));
        // ignore: avoid_print
        print(jsonEncode(reports));
        configureRecorderProxyRouting(null);
        Get.reset();
        await Hive.close();
      }
    },
    skip: Platform.environment['PURELIVE_ROLLING_HLS_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<Map<String, Object?>> _capture(
  _Scenario config,
  Directory fixture,
  Directory root, {
  bool scheduled = false,
  bool productionPrefetch = false,
  ({int video, int audio})? fixedCounts,
  int? liveStartIndex,
  int? preferStartHint,
  bool sourceStartHint = false,
  bool distinctSequences = false,
  String? failRefreshBeforeStop,
  bool shortestOutput = false,
  bool audioEnded = false,
}) async {
  final output = await Directory(p.join(root.path, config.name)).create();
  final origin = await _RollingOrigin.start(
    fixture,
    config,
    fixedCounts: fixedCounts,
    distinctSequences: distinctSequences,
    sourceStartHint: sourceStartHint,
    audioEnded: audioEnded,
  );
  final native = FFmpegManager.to;
  final diagnostics = HlsRelayDiagnostics();
  final taskId = 'rolling_${config.name}';
  final events = <Map<String, Object?>>[];
  FFmpegHlsInputRelay? relay;
  String? observedNativeCommand;
  final subscription = native.stream.listen((event) {
    if (event.taskId == taskId && events.length < 512) {
      // A controlled output policy may finish before the exposure checkpoint.
      // Retain this session's evidence while it is still registered.
      final session = native.getSession(taskId);
      relay ??= session?.inputRelay;
      observedNativeCommand ??= session?.session.getCommand();
      events.add({
        'type': event.type.name,
        'atMs': diagnostics.elapsedMilliseconds,
        'code': event.data['code'],
        'manualStop': event.data['manualStop'],
        for (final key in [
          'inputCoverageIncomplete',
          'inputTailDiscarded',
          'inputIntegrityError',
          'inputDrained',
          'forcedCancel',
        ])
          if (event.data.containsKey(key)) key: event.data[key],
      });
    }
  });
  Future<void>? execution;
  _ScheduledRelay? prefetch;
  final report = <String, Object?>{
    'case': config.name,
    'rwTimeout': config.budget,
    'bodyDelayMs': config.bodyMs,
    'headerDelayMs': config.headerMs,
    'windowDurationSeconds': fixedCounts == null ? 6 : null,
    if (fixedCounts != null) 'fixedCounts': {'video': fixedCounts.video, 'audio': fixedCounts.audio},
    'distinctSequences': distinctSequences,
    'audioEnded': audioEnded,
  };
  try {
    if (scheduled) prefetch = await _ScheduledRelay.start(origin.input, output, config.budget);
    final arguments = FFmpegCommandBuilder.buildRecordArguments(
      url: (prefetch?.input ?? origin.input).toString(),
      outputDir: output.path,
      segmentTime: 86400,
      preferBestStream: true,
      rwTimeout: config.budget,
      threadQueueSize: 512,
      filePrefix: 'capture',
    ).toList();
    if (liveStartIndex != null) {
      arguments.insertAll(arguments.indexOf('-i'), ['-live_start_index', '$liveStartIndex']);
    }
    if (preferStartHint != null) {
      arguments.insertAll(arguments.indexOf('-i'), ['-prefer_x_start', '$preferStartHint']);
    }
    if (shortestOutput) {
      arguments.insertAll(arguments.length - 1, ['-shortest', '-shortest_buf_duration', '10']);
    }
    execution = native.start(
      taskId: taskId,
      arguments: arguments,
      liveRecording: true,
      hlsDiagnostics: diagnostics,
      hlsPrefetch: productionPrefetch,
    );
    // Fixed controlled exposure, not a claim of healthy live coverage.
    await Future<void>.delayed(Duration(seconds: config.runSeconds));
    if (failRefreshBeforeStop != null) {
      origin.refreshFailure = failRefreshBeforeStop;
      final wait = Stopwatch()..start();
      while ((diagnostics.snapshot()['prefetchRefreshFailures']! as List).isEmpty &&
          wait.elapsed < const Duration(seconds: 3)) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final failures = diagnostics.snapshot()['prefetchRefreshFailures']! as List;
      expect(failures, hasLength(1));
      report['refreshFailuresBeforeStop'] = failures;
    }
    // Persist only this numeric native argument, never the full command/URLs.
    final nativeCommand = native.getSession(taskId)?.session.getCommand() ?? observedNativeCommand ?? '';
    report['nativeShortest'] = RegExp(r'(?:^|\s)-shortest(?:\s|$)').hasMatch(nativeCommand);
    report['nativeStartIndex'] = int.tryParse(
      RegExp(r'-live_start_index\s+(-?\d+)').firstMatch(nativeCommand)?.group(1) ?? '',
    );
    report['nativePreferStartHint'] = int.tryParse(
      RegExp(r'-prefer_x_start\s+(\d+)').firstMatch(nativeCommand)?.group(1) ?? '',
    );
    report['nativeReadTimeoutMicros'] = int.tryParse(
      RegExp(r'-rw_timeout\s+(\d+)').firstMatch(nativeCommand)?.group(1) ?? '',
    );
    relay ??= native.getSession(taskId)?.inputRelay;
    if (productionPrefetch) {
      report['prefetch'] = {
        // ignore: invalid_use_of_visible_for_testing_member
        'feeds': relay?.prefetchFeedCount,
        // ignore: invalid_use_of_visible_for_testing_member
        'entriesAtStop': relay?.prefetchBodyCount,
        'scope': 'production relay, no experimental HTTP adapter',
      };
    }
    report['stopRequestedMs'] = diagnostics.elapsedMilliseconds;
    prefetch?.freeze();
    final stopIssued = native.isRunning(taskId);
    report['stopIssued'] = stopIssued;
    if (stopIssued) await native.stop(taskId);
    await execution.timeout(const Duration(seconds: 20));
    await relay?.close();
    report['stoppedMs'] = diagnostics.elapsedMilliseconds;
    if (productionPrefetch) {
      report['prefetchAfterClose'] = {
        // ignore: invalid_use_of_visible_for_testing_member
        'feeds': relay?.prefetchFeedCount,
        // ignore: invalid_use_of_visible_for_testing_member
        'entries': relay?.prefetchBodyCount,
        // ignore: invalid_use_of_visible_for_testing_member
        'bytes': relay?.prefetchBytes,
      };
      final firstVideo = origin.requests.firstWhere(
        (r) => r['path'] == '/variant_0/segment_000.m4s' && r['closedMs'] != null,
      );
      (report['prefetch'] as Map)['refreshBeforeFirstVideoComplete'] = origin.requests.any(
        (r) =>
            r['path'] == '/variant_0/index.m3u8' &&
            (r['requestMs'] as int) > (firstVideo['requestMs'] as int) &&
            (r['requestMs'] as int) < (firstVideo['closedMs'] as int),
      );
    }
    report['started'] = events.any((event) => event['type'] == 'started');
    report['events'] = events;
    final terminal = events.lastWhere((event) => event['type'] == 'complete' || event['type'] == 'error');
    report['inputCoverageIncomplete'] = terminal['inputCoverageIncomplete'];
    report['coverageWarningCount'] = events.where((event) => event['type'] == 'inputCoverage').length;
    final snapshot = diagnostics.snapshot();
    final traces = (snapshot['requests'] as List).cast<Map<String, Object?>>();
    report['requestCount'] = traces.length;
    report['omittedRequests'] = snapshot['omittedRequests'];
    final master = traces.firstWhere((trace) => (trace['manifest'] as Map?)?['kind'] == 'master')['manifest'] as Map;
    final videoId = (master['children'] as List).singleWhere((child) => child['role'] == 'variant')['resourceId'];
    final videoPlaylists = traces
        .where((trace) => trace['resourceId'] == videoId && trace['manifestSource'] == 'upstream')
        .toList();
    final segmentIds = <String>{};
    final sequenceById = <String, int>{};
    for (final playlist in videoPlaylists) {
      for (final segment in ((playlist['manifest'] as Map)['segments'] as List)) {
        final id = segment['resourceId'] as String;
        segmentIds.add(id);
        sequenceById[id] = segment['sequence'] as int;
      }
    }
    final videoRequests = traces.where((trace) => segmentIds.contains(trace['resourceId'])).toList();
    final complete = _completedMedia(videoRequests);
    report['videoSequencesRequested'] = [for (final trace in videoRequests) sequenceById[trace['resourceId']]];
    report['completedUpstreamVideoRequests'] = complete.length;
    final receivedSequences = [for (final trace in complete) sequenceById[trace['resourceId']]!];
    report['completedUpstreamVideoSequences'] = receivedSequences;
    report['receivedVideoSequenceGaps'] = false;
    for (var i = 1; i < receivedSequences.length; i++) {
      if (receivedSequences[i] > receivedSequences[i - 1] + 1) report['receivedVideoSequenceGaps'] = true;
    }
    if (complete.isNotEmpty) {
      final durations = complete.map((trace) => (trace['bodyCompleteMs'] as int) - (trace['startedMs'] as int)).toList()
        ..sort();
      report['minimumWholeBodyMs'] = durations.first;
      final first = complete.first;
      report['firstVideoRequestMs'] = first['startedMs'];
      report['firstVideoBodyMs'] = first['firstBodyMs'];
      report['firstVideoBodyCompleteMs'] = first['bodyCompleteMs'];
      report['firstVideoDeliveryMs'] = first['deliveredMs'];
      report['refreshBeforeFirstVideoComplete'] = videoPlaylists.any(
        (trace) =>
            (trace['startedMs'] as int) > (first['startedMs'] as int) &&
            (trace['startedMs'] as int) < (first['bodyCompleteMs'] as int),
      );
    }
    final files = await output
        .list()
        .where((file) => file is File && p.extension(file.path) == '.ts')
        .cast<File>()
        .toList();
    var bytes = 0;
    for (final file in files) {
      bytes += await file.length();
    }
    report['outputBytes'] = bytes;
    report['outputFiles'] = files.length;
    if (bytes > 0) {
      report['inspection'] = await _inspect(files.first, output);
    }
    await File(p.join(output.path, 'hls-timeline.json')).writeAsString(jsonEncode(snapshot));
    expect(snapshot['omittedRequests'], 0);
    expect(native.isRunning(taskId), false);
    // This opt-in native test is under tool/probes rather than test/.
    // ignore: invalid_use_of_visible_for_testing_member
    expect(relay?.stagingBodyCount ?? 0, 0);
  } finally {
    relay ??= native.getSession(taskId)?.inputRelay;
    try {
      if (native.isRunning(taskId)) await native.stop(taskId);
      await execution?.timeout(const Duration(seconds: 20));
    } finally {
      await relay?.close();
      await subscription.cancel();
      if (prefetch != null) {
        report['prefetch'] = prefetch.snapshot();
        await prefetch.close();
        report['prefetchAfterClose'] = prefetch.snapshot();
      }
      await origin.close();
      await File(p.join(output.path, 'hls-timeline.json')).writeAsString(jsonEncode(diagnostics.snapshot()));
      await File(p.join(output.path, 'origin.json')).writeAsString(jsonEncode(origin.requests));
      await File(p.join(output.path, 'result.json')).writeAsString(jsonEncode(report));
    }
  }
  return report;
}

typedef _Segment = ({String path, int index, double start, double duration});

List<Map<String, Object?>> _completedMedia(List<Map<String, Object?>> requests) => requests
    .where((trace) => const {200, 206}.contains(trace['upstreamStatus']) && trace['bodyCompleteMs'] != null)
    .toList();

class _RollingOrigin {
  _RollingOrigin(
    this.server,
    this.files,
    this.playlists,
    this.config,
    this.fixedCounts,
    this.distinctSequences,
    this.sourceStartHint,
    this.audioEnded,
  );
  final HttpServer server;
  final Map<String, File> files;
  final Map<String, List<_Segment>> playlists;
  final _Scenario config;
  final ({int video, int audio})? fixedCounts;
  final bool distinctSequences;
  final bool sourceStartHint;
  final bool audioEnded;
  String? refreshFailure;
  final clock = Stopwatch();
  final ended = Completer<void>();
  final requests = <Map<String, Object?>>[];
  final handlers = <Future<void>>{};
  late StreamSubscription<HttpRequest> subscription;
  Uri get input => Uri.parse('http://127.0.0.1:${server.port}/master.m3u8');
  double get edge => 6.1 + clock.elapsedMilliseconds / 1000;

  static Future<_RollingOrigin> start(
    Directory fixture,
    _Scenario config, {
    ({int video, int audio})? fixedCounts,
    bool distinctSequences = false,
    bool sourceStartHint = false,
    bool audioEnded = false,
  }) async {
    final files = <String, File>{};
    await for (final file in fixture.list(recursive: true, followLinks: false)) {
      if (file is File) files['/${p.relative(file.path, from: fixture.path).replaceAll('\\', '/')}'] = file;
    }
    final playlists = <String, List<_Segment>>{};
    for (final variant in [0, 1]) {
      final key = '/variant_$variant/index.m3u8';
      final lines = const LineSplitter().convert(await files[key]!.readAsString()).toList();
      final segments = <_Segment>[];
      double start = 0;
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].startsWith('#EXTINF:')) continue;
        final duration = double.parse(lines[i].substring(8).split(',').first);
        segments.add((
          path: '/variant_$variant/${lines[++i]}',
          index: segments.length,
          start: start,
          duration: duration,
        ));
        start += duration;
      }
      expect(start, greaterThanOrEqualTo(59));
      playlists[key] = segments;
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final origin = _RollingOrigin(
      server,
      files,
      playlists,
      config,
      fixedCounts,
      distinctSequences,
      sourceStartHint,
      audioEnded,
    );
    origin.subscription = server.listen((request) {
      if (!origin.clock.isRunning) origin.clock.start();
      late Future<void> work;
      work = origin.serve(request).whenComplete(() => origin.handlers.remove(work));
      origin.handlers.add(work);
    });
    return origin;
  }

  List<_Segment> window(List<_Segment> segments) {
    final counts = fixedCounts;
    if (counts != null) {
      final count = segments.first.path.startsWith('/variant_0/') ? counts.video : counts.audio;
      if (count < 3 || count > 8) throw StateError('Invalid fixed start-boundary fixture');
      return segments.take(count).toList();
    }
    final now = edge;
    return segments
        .where((segment) => segment.start + segment.duration <= now && segment.start + segment.duration > now - 6)
        .toList();
  }

  Future<void> delay(int milliseconds) async {
    final elapsed = Completer<void>();
    final timer = Timer(Duration(milliseconds: milliseconds), elapsed.complete);
    try {
      await Future.any([elapsed.future, ended.future]);
    } finally {
      timer.cancel();
    }
    if (ended.isCompleted) throw const HttpException('Fixture stopped');
  }

  Future<void> serve(HttpRequest request) async {
    final row = <String, Object?>{'path': request.uri.path, 'requestMs': clock.elapsedMilliseconds};
    if (requests.length < 512) requests.add(row);
    try {
      final file = files[request.uri.path];
      final playlist = playlists[request.uri.path];
      if (file == null) {
        request.response.statusCode = 404;
      } else if (playlist != null) {
        final failure = request.uri.path.contains('variant_0') ? refreshFailure : null;
        if (failure == 'http') {
          request.response.statusCode = 503;
          row['injectedFailure'] = failure;
          await request.response.close();
          row['closedMs'] = clock.elapsedMilliseconds;
          return;
        }
        final current = window(playlist);
        final variant = request.uri.path.contains('variant_0') ? 0 : 1;
        final firstSequence =
            current.first.index +
            (distinctSequences ? (variant + 1) * 1000 : 0) +
            (failure == 'sequence-gap' ? 100 : 0);
        if (failure != null) row['injectedFailure'] = failure;
        row['sequence'] = firstSequence;
        final content = StringBuffer(
          '#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:2\n'
          '#EXT-X-MEDIA-SEQUENCE:$firstSequence\n#EXT-X-MAP:URI="init_$variant.mp4"\n',
        );
        if (sourceStartHint) content.write('#EXT-X-START:TIME-OFFSET=0,PRECISE=NO\n');
        for (final segment in current) {
          final pdt = DateTime.utc(2026, 9, 9).add(Duration(microseconds: (segment.start * 1000000).round()));
          content.write(
            '#EXT-X-PROGRAM-DATE-TIME:${pdt.toIso8601String()}\n#EXTINF:${segment.duration},\n${p.basename(segment.path)}\n',
          );
        }
        if (variant == 1 && audioEnded) content.write('#EXT-X-ENDLIST\n');
        request.response.headers.contentType = ContentType('application', 'vnd.apple.mpegurl');
        request.response.write(content);
      } else {
        final isVideo = request.uri.path.startsWith('/variant_0/') && request.uri.path.endsWith('.m4s');
        if (request.uri.path.endsWith('.m4s')) {
          final key = request.uri.path.startsWith('/variant_0/') ? '/variant_0/index.m3u8' : '/variant_1/index.m3u8';
          if (!window(playlists[key]!).any((segment) => segment.path == request.uri.path)) {
            row['expiredAtRequest'] = true;
            request.response.statusCode = 410;
            await request.response.close();
            return;
          }
        }
        final bytes = await file.readAsBytes();
        if (isVideo && config.headerMs > 0) await delay(config.headerMs);
        request.response.contentLength = bytes.length;
        request.response.bufferOutput = false;
        if (isVideo && config.bodyMs > 0) {
          for (var part = 0; part < 13; part++) {
            if (part > 0) await delay(config.bodyMs ~/ 12);
            request.response.add(bytes.sublist(part * bytes.length ~/ 13, (part + 1) * bytes.length ~/ 13));
            await request.response.flush();
            row['firstBodyMs'] ??= clock.elapsedMilliseconds;
          }
        } else {
          request.response.add(bytes);
          row['firstBodyMs'] = clock.elapsedMilliseconds;
        }
        row['bytes'] = bytes.length;
      }
      await request.response.close();
      row['closedMs'] = clock.elapsedMilliseconds;
    } on Object {
      row['connectionEnded'] = true;
      try {
        await request.response.close();
      } on Object {
        /* Owned reader ended. */
      }
    }
  }

  Future<void> close() async {
    if (!ended.isCompleted) ended.complete();
    await server.close(force: true);
    await subscription.cancel();
    await Future.wait(handlers.toList());
    clock.stop();
  }
}

class _RealNetwork extends HttpOverrides {}

Future<Map<String, Object?>> _inspect(File input, Directory output) async {
  final process = await Process.start(Platform.environment['PURELIVE_FFPROBE']!, [
    '-v',
    'error',
    '-show_packets',
    '-show_streams',
    '-show_entries',
    'packet=stream_index,pts_time,dts_time,duration_time:stream=index,codec_type',
    '-of',
    'json',
    input.path,
  ]);
  var done = false;
  Future<String> read(Stream<List<int>> source) async {
    final bytes = <int>[];
    await for (final chunk in source) {
      if (bytes.length + chunk.length > 4 * 1024 * 1024) throw StateError('Packet inspection size limit');
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  try {
    final result = await Future.wait<Object>([
      process.exitCode,
      read(process.stdout),
      read(process.stderr),
    ], eagerError: true).timeout(const Duration(seconds: 20));
    done = true;
    await File(p.join(output.path, 'packets.json')).writeAsString(result[1] as String);
    final report = <String, Object?>{'exitCode': result[0], 'stderr': result[2]};
    if (result[0] == 0) {
      final json = jsonDecode(result[1] as String) as Map;
      report.addAll(inspectMediaPacketTimeline(json));
    }
    return report;
  } finally {
    if (!done) {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
  }
}

// This experiment isolates requests before stop. Direct-input cancellation has
// no whole-body protection: its output is diagnostic, never a recording PASS.
Future<Map<String, Object?>> _captureScheduling(
  Directory fixture,
  Directory root, {
  required String name,
  required bool useRelay,
  required int multiple,
  required bool delayHeaders,
}) async {
  final output = await Directory(p.join(root.path, name)).create();
  final origin = await _RollingOrigin.start(fixture, (
    name: name,
    budget: 10,
    bodyMs: delayHeaders ? 0 : 12000,
    headerMs: delayHeaders ? 12000 : 0,
    runSeconds: 34,
  ));
  final manager = FFmpegManager.to;
  final events = <Map<String, Object?>>[];
  final subscription = manager.stream.listen((event) {
    if (event.taskId == name && events.length < 512) {
      events.add({
        'type': event.type.name,
        'atMs': origin.clock.elapsedMilliseconds,
        for (final key in ['code', 'manualStop', 'forcedCancel', 'inputDrained', 'inputIntegrityError'])
          if (event.data.containsKey(key)) key: event.data[key],
      });
    }
  });
  Future<void>? execution;
  FFmpegHlsInputRelay? relay;
  final report = <String, Object?>{
    'case': name,
    'useRelay': useRelay,
    'httpMultiple': multiple,
    'bodyDelayMs': delayHeaders ? 0 : 12000,
    'headerDelayMs': delayHeaders ? 12000 : 0,
    'scope': 'pre-stop request scheduling, not output integrity or complete live coverage',
  };
  try {
    final arguments = FFmpegCommandBuilder.buildRecordArguments(
      url: origin.input.toString(),
      outputDir: output.path,
      segmentTime: 86400,
      preferBestStream: true,
      rwTimeout: useRelay ? 10 : 60,
      threadQueueSize: 512,
      filePrefix: 'diagnostic',
    ).toList();
    arguments.insertAll(arguments.indexOf('-i'), ['-http_multiple', '$multiple']);
    execution = manager.start(taskId: name, arguments: arguments, liveRecording: useRelay);
    await Future<void>.delayed(const Duration(seconds: 34));
    final session = manager.getSession(name);
    relay = session?.inputRelay;
    report['actualRelay'] = relay != null;
    final command = session?.session.getCommand() ?? '';
    report['nativeReadTimeoutMicros'] = int.tryParse(
      RegExp(r'-rw_timeout\s+(\d+)').firstMatch(command)?.group(1) ?? '',
    );
    report['nativeHttpMultiple'] = int.tryParse(RegExp(r'-http_multiple\s+(\d+)').firstMatch(command)?.group(1) ?? '');
    report['stopRequestedMs'] = origin.clock.elapsedMilliseconds;
    final beforeStop = [for (final request in origin.requests) Map<String, Object?>.of(request)];
    report['overlap'] = _requestOverlap(beforeStop);
    await File(p.join(output.path, 'origin-before-stop.json')).writeAsString(jsonEncode(beforeStop));
    expect(relay != null, useRelay);
  } finally {
    relay ??= manager.getSession(name)?.inputRelay;
    try {
      if (manager.isRunning(name)) await manager.stop(name);
      await execution?.timeout(const Duration(seconds: 20));
    } finally {
      await relay?.close();
      report['stoppedMs'] = origin.clock.elapsedMilliseconds;
      await subscription.cancel();
      await origin.close();
      report['events'] = events;
      await File(p.join(output.path, 'origin.json')).writeAsString(jsonEncode(origin.requests));
      await File(p.join(output.path, 'result.json')).writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    }
  }
  return report;
}

Map<String, Object?> _requestOverlap(List<Map<String, Object?>> traces) {
  final complete =
      traces
          .where(
            (r) =>
                (r['path'] as String).startsWith('/variant_0/') &&
                (r['path'] as String).endsWith('.m4s') &&
                r['expiredAtRequest'] != true &&
                r['closedMs'] is int &&
                r['bytes'] is int &&
                (r['bytes'] as int) > 0,
          )
          .toList()
        ..sort((a, b) => (a['requestMs'] as int).compareTo(b['requestMs'] as int));
  var overlapped = false;
  for (var i = 1; i < complete.length; i++) {
    if ((complete[i]['requestMs'] as int) < (complete[i - 1]['closedMs'] as int)) overlapped = true;
  }
  return {
    'overlapped': overlapped,
    'completeVideoRequests': complete.length,
    'completeVideoPaths': [for (final r in complete) r['path']],
    'completeVideoRequestMs': [for (final r in complete) r['requestMs']],
    'completeVideoClosedMs': [for (final r in complete) r['closedMs']],
    'completeVideoBytes': complete.fold<int>(0, (sum, r) => sum + (r['bytes'] as int)),
    'expiredVideoRequests': traces
        .where((r) => (r['path'] as String).startsWith('/variant_0/') && r['expiredAtRequest'] == true)
        .length,
  };
}
