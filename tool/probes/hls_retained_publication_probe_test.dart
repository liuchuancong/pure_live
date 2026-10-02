// Opt-in native consumer check. The fixture origin is removed after prefetch;
// ffprobe must then read the retained media from complete, leased pool bodies.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/domains/recorder/data/services/hls_body_reader.dart';
import 'package:pure_live/domains/recorder/data/services/hls_prefetch_pool.dart';
import 'package:pure_live/domains/recorder/data/services/hls_retained_manifest.dart';
import 'package:pure_live/domains/recorder/data/services/hls_retained_window.dart';
import 'package:pure_live/core/stream/hls_session_cookies.dart';
import 'package:pure_live/domains/recorder/data/services/hls_upstream_client.dart';

void main() {
  test(
    'native retained publication equals direct packets after the origin is gone',
    () async {
      final fixture = Directory(Platform.environment['PURELIVE_ROLLING_HLS_FIXTURE']!);
      final root = await Directory(
        p.join(
          Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!,
          'publication-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5)
        ..findProxy = (_) => 'DIRECT';
      final pool = HlsPrefetchPool(createDirectory: () => root.createTemp('spool-'));
      final tasks = <Future<void>>{};
      final originBase = Uri.parse('http://127.0.0.1:${origin.port}/');
      final transport = HlsUpstreamClient(
        client: client,
        source: originBase.resolve('master.m3u8'),
        headers: {},
        cookies: HlsSessionCookies(),
      );
      final localBase = Uri.parse('http://127.0.0.1:${local.port}/');
      final sourceManifests = <String, String>{};
      final outputManifests = <String, String>{};
      final windows = <String, HlsRetainedWindow>{};
      final paths = <String>{};
      final served = <String>[];
      var originRequests = 0;
      var originClosed = false;
      void own(Future<void> task) {
        tasks.add(task);
        unawaited(task.whenComplete(() => tasks.remove(task)));
      }

      for (var variant = 0; variant < 2; variant++) {
        final path = '/variant_$variant/index.m3u8';
        final source = originBase.resolve(path);
        final text = await File(p.join(fixture.path, 'variant_$variant', 'index.m3u8')).readAsString();
        final snapshot = HlsMediaSnapshot.parse(text, source);
        final window = HlsRetainedWindow(source, maximumSegments: 3)..merge(snapshot);
        windows[path] = window;
        // Independent direct reference: preserve original initialization and
        // EXTINF/URI text, removing all but the final three media pairs.
        final pairs = RegExp(r'#EXTINF:[^\r\n]+\r?\n[^#\r\n]+').allMatches(text).toList();
        final tail = pairs.skip(pairs.length - 3).map((m) => m.group(0)!).join('\n');
        final map = RegExp(r'^#EXT-X-MAP:[^\r\n]+', multiLine: true).firstMatch(text)!.group(0)!;
        sourceManifests[path] =
            '#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:2\n'
            '#EXT-X-MEDIA-SEQUENCE:${pairs.length - 3}\n$map\n$tail\n#EXT-X-ENDLIST\n';
        for (final segment in window.segments) {
          paths.add(segment.uri.path);
          paths.add(segment.initialization!.uri.path);
        }
      }
      origin.listen(
        (request) => own(() async {
          originRequests++;
          final manifest = sourceManifests[request.uri.path];
          if (manifest != null) {
            request.response.write(manifest);
            await request.response.close();
          } else if (paths.contains(request.uri.path)) {
            final file = File(p.joinAll([fixture.path, ...request.uri.pathSegments]));
            request.response.contentLength = await file.length();
            await file.openRead().pipe(request.response);
          } else {
            request.response.statusCode = 404;
            await request.response.close();
          }
        }()),
      );
      local.listen(
        (request) => own(() async {
          final manifest = outputManifests[request.uri.path];
          if (manifest != null) {
            request.response.write(manifest);
            await request.response.close();
            return;
          }
          final lease = pool.acquire(originBase.resolve(request.uri.path).toString());
          if (lease == null) {
            request.response.statusCode = 503;
            await request.response.close();
            return;
          }
          try {
            served.add(request.uri.path);
            expect(lease.metadata!.statusCode, 200);
            request.response.contentLength = lease.length;
            await lease.writeTo(request.response);
            await request.response.close();
          } finally {
            await lease.release();
          }
        }()),
      );
      Future<Map<String, dynamic>> inspect(Uri uri, String label) async {
        final result = await Process.run(Platform.environment['PURELIVE_FFPROBE_EXE']!, [
          '-v',
          'error',
          '-rw_timeout',
          '5000000',
          '-i',
          uri.toString(),
          '-show_packets',
          '-show_streams',
          '-of',
          'json',
        ]);
        await File(p.join(root.path, '$label.json')).writeAsString(result.stdout as String);
        await File(p.join(root.path, '$label.stderr')).writeAsString(result.stderr as String);
        expect(result.exitCode, 0, reason: label);
        expect(result.stderr, isEmpty, reason: label);
        return jsonDecode(result.stdout as String) as Map<String, dynamic>;
      }

      try {
        final direct = <String, Map<String, dynamic>>{};
        for (final path in windows.keys) {
          direct[path] = await inspect(originBase.resolve(path), 'direct-${path.split('/')[1]}');
        }
        final tickets = <HlsPrefetchTicket>[];
        for (final path in paths) {
          final uri = originBase.resolve(path);
          tickets.add(
            pool.prefetch(
              uri.toString(),
              (cancel) => transport.loadMedia(uri, cancel, budget: HlsResponseBudget(pool.bodyIdleTimeout)),
            )!,
          );
        }
        expect(await Future.wait(tickets.map((t) => t.ready)), everyElement(true));
        expect(pool.ownedEntries, 8);
        final countAtClose = originRequests;
        transport.stop();
        client.close(force: true);
        await origin.close(force: true);
        originClosed = true;
        for (final entry in windows.entries) {
          final rendered = renderHlsRetainedManifest(entry.value, localUri: (uri) => localBase.resolve(uri.path));
          outputManifests[entry.key] = rendered;
          await File(p.join(root.path, '${entry.key.split('/')[1]}.m3u8')).writeAsString(rendered);
          final cached = await inspect(localBase.resolve(entry.key), 'cached-${entry.key.split('/')[1]}');
          final expected = direct[entry.key]!;
          // Container byte positions differ; timestamps, sizes, flags, stream
          // assignment and codec metadata must not be rewritten by retention.
          List<Object?> packets(Map<String, dynamic> data) => [
            for (final raw in data['packets'] as List)
              {
                for (final e in (raw as Map).entries)
                  if (e.key != 'pos') e.key: e.value,
              },
          ];
          expect(packets(cached), packets(expected));
          expect((cached['packets'] as List).length, greaterThan(0));
          expect((cached['streams'] as List).first['codec_name'], (expected['streams'] as List).first['codec_name']);
        }
        expect(originRequests, countAtClose);
        expect(served.toSet(), paths);
        await File(p.join(root.path, 'evidence.json')).writeAsString(
          jsonEncode({
            'originClosedBeforeNativePublication': true,
            'originRequests': originRequests,
            'servedPaths': served,
            'retainedBytes': pool.retainedBytes,
            'entries': pool.ownedEntries,
            'videoPackets': (direct['/variant_0/index.m3u8']!['packets'] as List).length,
            'audioPackets': (direct['/variant_1/index.m3u8']!['packets'] as List).length,
          }),
        );
        // ignore: avoid_print
        print('Retained publication evidence: ${root.path}');
      } finally {
        transport.stop();
        client.close(force: true);
        if (!originClosed) await origin.close(force: true);
        await local.close(force: true);
        await Future.wait(tasks.toList());
        await pool.close();
        transport.clear();
      }
      expect(pool.retainedBytes, 0);
      expect(pool.ownedEntries, 0);
    },
    skip: Platform.environment['PURELIVE_RETAINED_PUBLICATION_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
