import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/recorder/services/ffmpeg_hls_input_relay.dart';

const master =
    '#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="a",URI="audio.m3u8"\n'
    '#EXT-X-STREAM-INF:BANDWIDTH=1,AUDIO="a"\nvideo.m3u8\n';
String media(String feed, int first, {bool ended = false}) =>
    '#EXTM3U\n#EXT-X-TARGETDURATION:1\n#EXT-X-MEDIA-SEQUENCE:$first\n'
    '${List.generate(3, (i) => '#EXTINF:1,\n$feed-${first + i}.ts\n').join()}'
    '${ended ? '#EXT-X-ENDLIST\n' : ''}';

Future<(int, String)> fetch(HttpClient client, Uri uri) async {
  final response = await (await client.getUrl(uri)).close();
  return (response.statusCode, await utf8.decoder.bind(response).join());
}

final class Origin {
  Origin(this.server, this.subscription, this.jobs);
  final HttpServer server;
  final StreamSubscription<HttpRequest> subscription;
  final Set<Future<void>> jobs;
  static Future<Origin> start(Future<void> Function(HttpRequest) serve) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final jobs = <Future<void>>{};
    final subscription = server.listen((request) {
      late Future<void> job;
      job = () async {
        try {
          if (request.uri.path == '/root.m3u8') {
            request.response.write(master);
          } else {
            await serve(request);
          }
          await request.response.close();
        } on IOException {
          // A test may close a deliberately held response from the client.
        }
      }().whenComplete(() => jobs.remove(job));
      jobs.add(job);
    });
    return Origin(server, subscription, jobs);
  }

  Future<FFmpegHlsInputRelay> relay(HlsRelayDiagnostics diagnostics) async =>
      (await FFmpegHlsInputRelay.startForArguments(
        ['-i', 'http://127.0.0.1:${server.port}/root.m3u8'],
        drainOnStop: true,
        enablePrefetch: true,
        diagnostics: diagnostics,
      ))!;

  Future<void> close() async {
    await server.close(force: true);
    await subscription.cancel();
    // A handler whose client aborted mid-response can keep response.flush/close
    // pending after the forced server close (seen under heavy load). The relay
    // assertions are already done; do not let origin teardown hang the test.
    await Future.wait(jobs.toList()).timeout(const Duration(seconds: 2), onTimeout: () => const <void>[]);
  }
}

void main() {
  for (final allowCache in ['YES', 'NO']) {
    test('single media prefetch respects legacy ALLOW-CACHE:$allowCache', () async {
      var bodies = 0;
      final origin = await Origin.start((request) async {
        if (request.uri.path.endsWith('.m3u8')) {
          request.response.write(
            media(
              '/video',
              0,
              ended: true,
            ).replaceFirst('#EXT-X-MEDIA-SEQUENCE:0\n', '#EXT-X-MEDIA-SEQUENCE:0\n#EXT-X-ALLOW-CACHE:$allowCache\n'),
          );
        } else {
          bodies++;
          request.response.write('body');
        }
      });
      final args = ['-i', 'http://127.0.0.1:${origin.server.port}/video.m3u8'];
      final relay = (await FFmpegHlsInputRelay.startForArguments(args, drainOnStop: true, enablePrefetch: true))!;
      final client = HttpClient();
      try {
        final response = await fetch(client, relay.inputUri);
        expect(response.$1, 200);
        expect(relay.prefetchFeedCount, allowCache == 'YES' ? 1 : 0);
        if (allowCache == 'YES') {
          expect(response.$2, contains('#EXT-X-DISCONTINUITY-SEQUENCE:0'));
          expect(response.$2, isNot(contains('#EXT-X-ALLOW-CACHE')));
        } else {
          expect(response.$2, contains('#EXT-X-ALLOW-CACHE:NO'));
        }
        if (allowCache == 'NO') expect(bodies, 0);
      } finally {
        client.close(force: true);
        await relay.close();
        await origin.close();
      }
      expect(relay.prefetchBodyCount, 0);
    });
  }
  for (final config in [
    (enabled: true, sourceHint: false, override: <String>[], automatic: true),
    (enabled: false, sourceHint: false, override: <String>[], automatic: false),
    (enabled: true, sourceHint: true, override: <String>[], automatic: true),
    (enabled: true, sourceHint: true, override: ['-prefer_x_start', '1'], automatic: false),
    (enabled: true, sourceHint: true, override: ['-prefer_x_start', '0'], automatic: false),
    (enabled: true, sourceHint: true, override: ['-live_start_index', '2'], automatic: false),
    (enabled: true, sourceHint: false, override: ['-live_start_index', '1'], automatic: false),
  ]) {
    test('start hint is selected-only and preserves explicit/native fallback intent: $config', () async {
      var bodies = 0;
      final origin = await Origin.start((request) async {
        if (request.uri.path.endsWith('.m3u8')) {
          request.response.write(media(request.uri.path, 0, ended: true));
          if (config.sourceHint) request.response.write('#EXT-X-START:TIME-OFFSET=2\n');
        } else {
          bodies++;
          request.response.write('body');
        }
      });
      final args = [...config.override, '-i', 'http://127.0.0.1:${origin.server.port}/video.m3u8'];
      final relay = (await FFmpegHlsInputRelay.startForArguments(
        args,
        drainOnStop: true,
        enablePrefetch: config.enabled,
      ))!;
      final client = HttpClient();
      try {
        final rewrittenArgs = relay.replaceFirstInput(args);
        if (config.automatic) {
          expect(rewrittenArgs, contains('-prefer_x_start'));
          expect(rewrittenArgs[rewrittenArgs.indexOf('-prefer_x_start') + 1], '1');
          expect(rewrittenArgs, isNot(contains('-live_start_index')));
        } else {
          for (final option in ['-prefer_x_start', '-live_start_index']) {
            expect(rewrittenArgs.contains(option), config.override.contains(option));
            if (config.override.contains(option)) {
              expect(
                rewrittenArgs[rewrittenArgs.indexOf(option) + 1],
                config.override[config.override.indexOf(option) + 1],
              );
            }
          }
        }
        final text = (await fetch(client, relay.inputUri)).$2;
        final selected = config.enabled && !config.sourceHint;
        expect(relay.prefetchFeedCount, selected ? 1 : 0);
        if (config.automatic && selected) {
          expect(text, contains('#EXT-X-START:TIME-OFFSET=0,PRECISE=NO'));
        } else if (config.sourceHint && !config.automatic) {
          expect(text, contains('#EXT-X-START:TIME-OFFSET=2'));
        } else {
          expect(text, isNot(contains('#EXT-X-START:')));
        }
        if (!selected) expect(bodies, 0);
        await relay.finish();
        expect((await fetch(client, relay.inputUri)).$2, text);
      } finally {
        client.close(force: true);
        await relay.close();
        await origin.close();
      }
      expect(relay.prefetchBodyCount, 0);
    });
  }
  for (final ending in ['failed-peer', 'finish', 'close']) {
    test('initial two-feed reads are cancelled and awaited on $ending without admitting late media', () async {
      final release = Completer<void>();
      final both = Completer<void>();
      final entered = <String>{};
      var bodies = 0;
      final origin = await Origin.start((request) async {
        final path = request.uri.path;
        if (path.endsWith('.m3u8')) {
          entered.add(path);
          if (entered.length == 2 && !both.isCompleted) both.complete();
          if (ending == 'failed-peer' && path == '/audio.m3u8') {
            request.response.statusCode = 503;
            return;
          }
          request.response.write('#EXTM3U\n');
          await request.response.flush();
          await release.future;
          request.response.write(media(path, 0, ended: true).substring('#EXTM3U\n'.length));
        } else {
          bodies++;
          request.response.write('body');
        }
      });
      final diagnostics = HlsRelayDiagnostics();
      final relay = await origin.relay(diagnostics);
      final client = HttpClient();
      Object? rootError;
      final root = fetch(client, relay.inputUri).then<(int, String)?>(
        (value) => value,
        onError: (Object error) {
          rootError = error;
          return null;
        },
      );
      try {
        await both.future.timeout(const Duration(seconds: 2));
        if (ending == 'finish') await relay.finish();
        if (ending == 'close') await relay.close().timeout(const Duration(seconds: 2));
        final response = await root.timeout(const Duration(seconds: 2));
        if (ending == 'failed-peer') {
          expect(rootError, isNull);
          expect(response!.$1, 200);
          expect(response.$2, contains('#EXT-X-STREAM-INF'));
        }
        expect(relay.prefetchFeedCount, 0);
        expect(relay.prefetchBodyCount, 0);
        expect(bodies, 0);
        expect(diagnostics.snapshot()['prefetchRefreshFailures'], isEmpty);
        release.complete();
      } finally {
        if (!release.isCompleted) release.complete();
        await root;
        client.close(force: true);
        await relay.close();
        await origin.close();
      }
      expect(bodies, 0);
    });
  }
  test('both selected snapshots start before either completes; media waits for atomic admission', () async {
    final release = Completer<void>();
    final both = Completer<void>();
    final entered = <String>{};
    var bodies = 0;
    final origin = await Origin.start((request) async {
      final path = request.uri.path;
      if (path.endsWith('.m3u8')) {
        entered.add(path);
        if (entered.length == 2 && !both.isCompleted) both.complete();
        await release.future;
        request.response.write(media(path, 0, ended: true));
      } else {
        bodies++;
        request.response.write('body');
      }
    });
    final relay = await origin.relay(HlsRelayDiagnostics());
    final client = HttpClient();
    final root = fetch(client, relay.inputUri);
    try {
      await both.future.timeout(const Duration(seconds: 2));
      expect(entered, {'/video.m3u8', '/audio.m3u8'});
      expect(relay.prefetchFeedCount, 0);
      expect(bodies, 0);
      release.complete();
      expect((await root).$1, 200);
      expect(relay.prefetchFeedCount, 2);
    } finally {
      if (!release.isCompleted) release.complete();
      await root;
      client.close(force: true);
      await relay.close();
      await origin.close();
    }
    expect(relay.prefetchBodyCount, 0);
  });

  test('two delayed initial snapshots do not lose a three-second rolling window before first refresh', () async {
    final clock = Stopwatch();
    final reads = <String, int>{};
    final samples = <Map<String, Object>>[];
    final refreshed = Completer<void>();
    var refreshes = 0;
    final origin = await Origin.start((request) async {
      final path = request.uri.path;
      if (path.endsWith('.m3u8')) {
        if (!clock.isRunning) clock.start();
        final count = reads.update(path, (value) => value + 1, ifAbsent: () => 1);
        final first = clock.elapsedMilliseconds ~/ 1000;
        samples.add({'feed': path, 'read': count, 'startedMs': clock.elapsedMilliseconds, 'first': first});
        // Metadata is current at request arrival; response latency consumes
        // two seconds of the three-segment source window, independently per feed.
        if (count == 1) await Future<void>.delayed(const Duration(seconds: 2));
        request.response.write(media(path, first, ended: count > 1));
        if (count > 1 && ++refreshes == 2) refreshed.complete();
      } else {
        request.response.write('body');
      }
    });
    final diagnostics = HlsRelayDiagnostics();
    final relay = await origin.relay(diagnostics);
    final client = HttpClient();
    try {
      final root = await fetch(client, relay.inputUri);
      expect(root.$1, 200);
      expect(relay.prefetchFeedCount, 2);
      final video = Uri.parse(root.$2.trim().split('\n').last);
      await refreshed.future.timeout(const Duration(seconds: 3));
      // Observe the committed refresh, not just receipt at the test origin.
      final deadline = Stopwatch()..start();
      (int, String) current;
      do {
        current = await fetch(client, video);
        if (current.$1 != 200 || current.$2.contains('#EXT-X-ENDLIST')) break;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      } while (deadline.elapsed < const Duration(seconds: 2));
      expect(diagnostics.snapshot()['prefetchRefreshFailures'], isEmpty, reason: jsonEncode(samples));
      expect(current.$1, 200);
      expect(current.$2, contains('#EXT-X-ENDLIST'));
      expect(current.$2, contains('#EXT-X-MEDIA-SEQUENCE:0'));
      expect(RegExp(r'^#EXTINF:', multiLine: true).allMatches(current.$2).length, greaterThan(3));
    } finally {
      client.close(force: true);
      await relay.close();
      await origin.close();
    }
    expect(relay.prefetchBodyCount, 0);
  });
}
