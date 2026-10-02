// Opt-in production BYTERANGE input acceptance using fixed local CMAF bytes.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';

void main() {
  test(
    'production ranged MAP and implicit media offsets preserve native packets after origin removal',
    () async {
      final withDateRanges = Platform.environment['PURELIVE_HLS_DATERANGE_PROBE'] == '1';
      final withLowLatency = Platform.environment['PURELIVE_HLS_LL_RECORDING_PROBE'] == '1';
      final fixture = Directory(Platform.environment['PURELIVE_ROLLING_HLS_FIXTURE']!);
      final output = await Directory(
        p.join(
          Platform.environment['PURELIVE_RECORDING_PROBE_OUTPUT']!,
          'range-${DateTime.now().microsecondsSinceEpoch}',
        ),
      ).create(recursive: true);
      final master = await File(p.join(fixture.path, 'master.m3u8')).readAsString();
      final bodies = <String, List<int>>{};
      final manifests = <String, String>{'/direct/master.m3u8': master, '/range/master.m3u8': master};
      final ranges = <String, List<String>>{};
      for (var track = 0; track < 2; track++) {
        final prefix = 'variant_$track';
        final text = await File(p.join(fixture.path, prefix, 'index.m3u8')).readAsString();
        final pairs = RegExp(r'(#EXTINF:[^\r\n]+)\r?\n([^#\r\n]+)').allMatches(text).take(3).toList();
        expect(pairs, hasLength(3));
        final initialization = await File(p.join(fixture.path, prefix, 'init_$track.mp4')).readAsBytes();
        bodies['/direct/$prefix/init_$track.mp4'] = initialization;
        // A nonzero MAP offset detects accidental relative/absolute translation.
        final combined = <int>[...List.filled(13, 0), ...initialization];
        final direct = StringBuffer(
          '#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:2\n'
          '#EXT-X-MAP:URI="init_$track.mp4"\n',
        );
        final ranged = StringBuffer(
          '#EXTM3U\n#EXT-X-VERSION:7\n#EXT-X-TARGETDURATION:2\n'
          '#EXT-X-MAP:URI="bundle.mp4",BYTERANGE="${initialization.length}@13"\n',
        );
        if (withDateRanges) {
          ranged.write(
            '#EXT-X-PROGRAM-DATE-TIME:2026-09-09T00:00:00Z\n'
            '#EXT-X-DATERANGE:ID="event-$track",START-DATE="2026-09-09T00:00:00Z",'
            'PLANNED-DURATION=4,X-NOTE="native,metadata",SCTE35-OUT=0xFC12\n',
          );
        }
        final expected = <String>['bytes=13-${12 + initialization.length}'];
        if (withLowLatency) {
          ranged.write(
            '#EXT-X-PART-INF:PART-TARGET=1.1\n#EXT-X-SERVER-CONTROL:PART-HOLD-BACK=3.3,CAN-BLOCK-RELOAD=YES\n',
          );
        }
        for (var i = 0; i < pairs.length; i++) {
          final pair = pairs[i];
          final name = pair.group(2)!;
          final bytes = await File(p.join(fixture.path, prefix, name)).readAsBytes();
          bodies['/direct/$prefix/$name'] = bytes;
          direct.write('${pair.group(1)}\n$name\n');
          final offset = combined.length;
          if (withLowLatency) {
            final duration = double.parse(pair.group(1)!.substring('#EXTINF:'.length).split(',').first) / 2;
            for (var part = 0; part < 2; part++) {
              ranged.write('#EXT-X-PART:DURATION=$duration,URI="unused-$i-$part.m4s",INDEPENDENT=YES\n');
            }
          }
          // First media offset is explicit, subsequent ranges are implicit.
          ranged.write('${pair.group(1)}\n#EXT-X-BYTERANGE:${bytes.length}${i == 0 ? '@$offset' : ''}\nbundle.mp4\n');
          expected.add('bytes=$offset-${offset + bytes.length - 1}');
          combined.addAll(bytes);
        }
        direct.write('#EXT-X-ENDLIST\n');
        if (withDateRanges) ranged.write('#EXT-X-DATERANGE:ID="event-$track",DURATION=6\n');
        ranged.write('#EXT-X-ENDLIST\n');
        manifests['/direct/$prefix/index.m3u8'] = direct.toString();
        manifests['/range/$prefix/index.m3u8'] = ranged.toString();
        bodies['/range/$prefix/bundle.mp4'] = combined;
        ranges['/range/$prefix/bundle.mp4'] = expected;
        await File(p.join(output.path, '$prefix.m3u8')).writeAsString(ranged.toString());
      }
      final origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final originUri = Uri.parse('http://127.0.0.1:${origin.port}/');
      final requests = <Map<String, Object?>>[];
      final jobs = <Future<void>>{};
      final subscription = origin.listen((request) {
        final row = <String, Object?>{
          'path': request.uri.path,
          'method': request.method,
          'range': request.headers.value('Range'),
        };
        if (requests.length < 128) requests.add(row);
        late Future<void> job;
        job = () async {
          try {
            final manifest = manifests[request.uri.path];
            final bytes = bodies[request.uri.path];
            if (manifest != null) {
              request.response.write(manifest);
            } else if (bytes != null) {
              final range = request.headers.value('Range');
              var start = 0;
              var end = bytes.length - 1;
              if (range != null && request.method == 'GET') {
                final match = RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
                if (match == null) throw const FormatException('Unexpected fixture range');
                start = int.parse(match.group(1)!);
                end = match.group(2)!.isEmpty ? end : int.parse(match.group(2)!);
                if (start < 0 || end < start || end >= bytes.length) {
                  throw const FormatException('Invalid fixture range');
                }
                request.response.statusCode = 206;
                request.response.headers.set('Content-Range', 'bytes $start-$end/${bytes.length}');
              }
              request.response.contentLength = end - start + 1;
              if (request.method == 'GET') request.response.add(bytes.sublist(start, end + 1));
            } else {
              request.response.statusCode = 404;
            }
            row['status'] = request.response.statusCode;
            await request.response.close();
          } on Object catch (error) {
            row['error'] = error.runtimeType.toString();
            try {
              await request.response.close();
            } on Object {
              /* Writer already ended. */
            }
          }
        }().whenComplete(() => jobs.remove(job));
        jobs.add(job);
      });
      final client = HttpClient()..findProxy = (_) => 'DIRECT';
      final diagnostics = HlsRelayDiagnostics();
      FFmpegHlsInputRelay? relay;
      var originClosed = false;
      Future<String> text(Uri uri) async {
        final response = await (await client.getUrl(uri)).close();
        expect(response.statusCode, 200);
        return response.transform(utf8.decoder).join();
      }

      Future<Map<String, dynamic>> inspect(Uri uri, String label) async {
        final result = await runNative(Platform.environment['PURELIVE_FFPROBE_EXE']!, [
          '-v',
          'error',
          '-rw_timeout',
          '5000000',
          '-i',
          uri.toString(),
          '-show_packets',
          '-show_streams',
          '-show_data_hash',
          'sha256',
          '-of',
          'json',
        ]);
        await File(p.join(output.path, '$label.json')).writeAsString(result.$2);
        await File(p.join(output.path, '$label.stderr')).writeAsString(result.$3);
        expect(result.$1, 0, reason: label);
        expect(result.$3, isEmpty, reason: label);
        return jsonDecode(result.$2) as Map<String, dynamic>;
      }

      try {
        final direct = await inspect(originUri.resolve('direct/master.m3u8'), 'direct');
        relay = (await FFmpegHlsInputRelay.startForArguments(
          ['-i', originUri.resolve('range/master.m3u8').toString()],
          drainOnStop: true,
          enablePrefetch: true,
          diagnostics: diagnostics,
        ))!;
        final selected = await text(relay.inputUri);
        final children = <Uri>{
          for (final match in RegExp(r'URI="([^"]+)"').allMatches(selected)) Uri.parse(match.group(1)!),
          for (final line in const LineSplitter().convert(selected))
            if (line.isNotEmpty && !line.startsWith('#')) Uri.parse(line),
        };
        expect(children, hasLength(2));
        final localBodies = <Uri>{};
        for (final child in children) {
          final playlist = await text(child);
          if (withLowLatency) {
            expect(playlist, isNot(contains('#EXT-X-PART')));
            expect(playlist, isNot(contains('#EXT-X-SERVER-CONTROL')));
            expect(playlist, isNot(contains('unused-')));
          }
          if (withDateRanges) {
            expect(RegExp(r'^#EXT-X-DATERANGE:', multiLine: true).allMatches(playlist), hasLength(1));
            expect(playlist, contains('DURATION=6'));
            expect(playlist, contains('X-NOTE="native,metadata"'));
            await File(p.join(output.path, 'published-${localBodies.length}.m3u8')).writeAsString(playlist);
          }
          localBodies.addAll([
            for (final match in RegExp(r'URI="([^"]+)"').allMatches(playlist)) Uri.parse(match.group(1)!),
            for (final line in const LineSplitter().convert(playlist))
              if (line.isNotEmpty && !line.startsWith('#')) Uri.parse(line),
          ]);
        }
        expect(localBodies, hasLength(8));
        // HEAD awaits sealing without marking these media consumed by native.
        for (final uri in localBodies) {
          final response = await (await client.headUrl(uri)).close();
          expect(response.statusCode, 200);
          expect(response.headers.value('Content-Range'), isNull);
          await response.drain<void>();
        }
        for (final entry in ranges.entries) {
          expect(requests.where((r) => r['path'] == entry.key).map((r) => r['range']), unorderedEquals(entry.value));
        }
        final count = requests.length;
        await relay.finish();
        await origin.close(force: true);
        originClosed = true;
        for (var pass = 0; pass < 2; pass++) {
          final cached = await inspect(relay.inputUri, 'cached-$pass');
          expect(packetIdentity(cached), packetIdentity(direct));
          expect((cached['packets'] as List).length, greaterThan(400));
          expect(
            (cached['streams'] as List).map((s) => (s as Map)['codec_name']),
            (direct['streams'] as List).map((s) => (s as Map)['codec_name']),
          );
        }
        final decode = await runNative(Platform.environment['PURELIVE_FFMPEG_EXE']!, [
          '-v',
          'error',
          '-xerror',
          '-rw_timeout',
          '5000000',
          '-i',
          relay.inputUri.toString(),
          '-map',
          '0:v:0',
          '-map',
          '0:a:0',
          '-f',
          'null',
          'NUL',
        ]);
        await File(p.join(output.path, 'decode.stderr')).writeAsString(decode.$3);
        expect(decode.$1, 0);
        expect(decode.$3, isEmpty);
        expect(requests.length, count);
        expect(relay.inputTailDiscarded, false);
        await File(p.join(output.path, 'evidence.json')).writeAsString(
          jsonEncode({
            'originRemovedBeforeCachedNativeReads': true,
            'dateRangesPreserved': withDateRanges,
            'lowLatencyCompleteParents': withLowLatency,
            'cachedNativePasses': 2,
            'packetCount': (direct['packets'] as List).length,
            'localBodies': localBodies.length,
            'originRequestCount': count,
            'expectedRanges': ranges,
            'decodeExitCode': decode.$1,
          }),
        );
      } finally {
        client.close(force: true);
        await relay?.close();
        if (!originClosed) await origin.close(force: true);
        await subscription.cancel();
        await Future.wait(jobs.toList());
        await File(p.join(output.path, 'origin.json')).writeAsString(jsonEncode(requests));
        await File(p.join(output.path, 'timeline.json')).writeAsString(jsonEncode(diagnostics.snapshot()));
      }
      // ignore: invalid_use_of_visible_for_testing_member
      expect(relay.prefetchBodyCount, 0);
      // ignore: invalid_use_of_visible_for_testing_member
      expect(relay.prefetchBytes, 0);
      // ignore: avoid_print
      print('Production BYTERANGE evidence: ${output.path}');
    },
    skip: Platform.environment['PURELIVE_HLS_BYTERANGE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

List<Object?> packetIdentity(Map<String, dynamic> data) => [
  for (final raw in data['packets'] as List)
    {
      for (final e in (raw as Map).entries)
        if (e.key != 'pos') e.key: e.value,
    },
];

Future<(int, String, String)> runNative(String executable, List<String> arguments) async {
  final process = await Process.start(executable, arguments);
  final stdout = process.stdout.transform(utf8.decoder).join();
  final stderr = process.stderr.transform(utf8.decoder).join();
  final int code;
  try {
    code = await process.exitCode.timeout(const Duration(seconds: 30));
  } on TimeoutException {
    process.kill();
    await process.exitCode;
    rethrow;
  } finally {
    // Observe the streams even if the owned native process reaches its deadline.
    await Future.wait([stdout, stderr]);
  }
  return (code, await stdout, await stderr);
}
