// Opt-in external probe, deliberately outside the ordinary offline test suite.
// No signed URLs, cookies, room snapshots or media bytes are persisted.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/platforms/huya/huya_site.dart';
import 'package:pure_live/domains/live/data/platforms/huya/huya_transport_policy.dart';
import 'package:pure_live/domains/live/data/playback_header_resolver.dart';
import 'package:pure_live/core/player/utils/live_buffer_policy.dart';

void main() {
  test(
    'production Huya native FLV transport outlives the old short lease',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final room = Platform.environment['PURELIVE_HUYA_ROOM'] ?? '660000';
        final seconds = int.tryParse(Platform.environment['PURELIVE_HUYA_SECONDS'] ?? '') ?? 180;
        final duration = Duration(seconds: seconds.clamp(130, 600));
        final bitRate = int.tryParse(Platform.environment['PURELIVE_HUYA_BITRATE'] ?? '') ?? 500;
        final requestedCdn = Platform.environment['PURELIVE_HUYA_CDN']?.trim().toUpperCase();
        // Fault injection: prove native WUP is independent of the web token.
        // The room/CDN/stream identity and the media request remain real.
        final omitWebToken = Platform.environment['PURELIVE_HUYA_EMPTY_WEB_TOKEN'] == '1';
        expect(bitRate, greaterThanOrEqualTo(0));
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        try {
          final pageRequest = await client.getUrl(Uri.https('www.huya.com', '/$room'));
          pageRequest.headers.set('user-agent', HuyaSite.nativePlayUserAgent);
          final pageResponse = await pageRequest.close().timeout(const Duration(seconds: 20));
          expect(pageResponse.statusCode, 200);
          final page = await utf8.decoder.bind(pageResponse).join().timeout(const Duration(seconds: 20));
          final stream = _extractStream(page);
          final profile = (stream['data'] as List).first as Map;
          final sources = (profile['gameStreamInfoList'] as List).cast<Map>();
          final source = requestedCdn == null || requestedCdn.isEmpty
              ? sources.first
              : sources.firstWhere((source) => source['sCdnType'].toString().toUpperCase() == requestedCdn);
          final info = profile['gameLiveInfo'] as Map;
          final line = HuyaLineModel(
            line: source['sFlvUrl'].toString(),
            lineType: HuyaLineType.flv,
            flvAntiCode: omitWebToken ? '' : source['sFlvAntiCode'].toString(),
            hlsAntiCode: source['sHlsAntiCode'].toString(),
            streamName: source['sStreamName'].toString(),
            cdnType: source['sCdnType'].toString(),
            presenterUid: int.parse((info['lChannelId'] ?? info['uid']).toString()),
          );
          final site = HuyaSite();
          final url = await site.getPlayUrl(line, bitRate);
          expect(HuyaTransportPolicy.hasNativeFlvCredential(url), isTrue);
          final headers = await PlaybackHeaderResolver.resolve(platform: 'huya', roomId: room);
          final nativeLibrary = Platform.environment['PURELIVE_HUYA_PROBE_LIBMPV'];
          if (nativeLibrary != null && nativeLibrary.isNotEmpty) {
            final properties = <String, String>{};
            await LiveBufferPolicy.apply((name, value) async {
              properties[name] = value;
            });
            // Measurement-only candidate; does not change app defaults. A
            // cache size ceiling alone never guarantees a startup reserve.
            final initialBuffer = int.tryParse(Platform.environment['PURELIVE_HUYA_INITIAL_BUFFER_SECONDS'] ?? '');
            if (initialBuffer != null) {
              expect(initialBuffer, inInclusiveRange(1, LiveBufferPolicy.cacheSeconds));
              properties['cache-pause-initial'] = 'yes';
              properties['cache-pause-wait'] = initialBuffer.toString();
            }
            final process = await Process.start('python', ['tool/probes/libmpv_continuity_probe.py']);
            try {
              final output = process.stdout.transform(utf8.decoder).join();
              final errors = process.stderr.drain<void>();
              process.stdin.write(
                jsonEncode({
                  'url': url,
                  'headers': headers,
                  'seconds': duration.inSeconds,
                  'library': nativeLibrary,
                  'bufferProperties': properties,
                  'observeFlvTransport': Platform.environment['PURELIVE_HUYA_OBSERVE_FLV'] == '1',
                }),
              );
              await process.stdin.close();
              final exit = await process.exitCode.timeout(duration + const Duration(seconds: 45));
              final result = jsonDecode(await output) as Map<String, dynamic>;
              result.addAll({
                'room': room,
                'cdn': line.cdnType,
                'requestedBitRate': bitRate,
                'webTokenOmitted': omitWebToken,
              });
              await errors;
              // Sanitized native counters only. This is not texture/audio-device acceptance.
              // ignore: avoid_print
              print(jsonEncode(result));
              expect(exit, 0);
              expect(result['headerRoundTripVerified'], isTrue);
              expect(result['endEvents'], 0);
              expect(result['pauseSamples'], 0);
              expect(result['clockAdvancedSeconds'], greaterThan(duration.inSeconds - 15));
              expect(result['nativeStats']['width'], greaterThan(0));
              expect(result['nativeStats']['height'], greaterThan(0));
              if (Platform.environment['PURELIVE_HUYA_OBSERVE_FLV'] == '1') {
                final transport = result['flvTransport'] as Map<String, dynamic>;
                expect(transport['opens'], 1);
                expect(transport['bytes'], greaterThan(0));
                expect(transport['tags'], greaterThan(0));
                expect(transport['parseError'], isNull);
                expect(transport['handlerFinished'], isTrue);
              }
            } finally {
              process.kill();
            }
            return;
          }
          final request = await client.getUrl(Uri.parse(url));
          headers.forEach(request.headers.set);
          final clock = Stopwatch()..start();
          final response = await request.close().timeout(const Duration(seconds: 20));
          expect(response.statusCode, 200);
          var bytes = 0;
          var chunks = 0;
          var maxGap = Duration.zero;
          var lastChunk = clock.elapsed;
          var reachedLimit = false;
          await for (final chunk in response.timeout(const Duration(seconds: 20))) {
            final gap = clock.elapsed - lastChunk;
            if (gap > maxGap) maxGap = gap;
            lastChunk = clock.elapsed;
            bytes += chunk.length;
            chunks++;
            if (clock.elapsed >= duration) {
              reachedLimit = true;
              break;
            }
          }
          // Token-safe result only: this is transport evidence, not rendered FPS.
          // ignore: avoid_print
          print(
            jsonEncode({
              'probe': 'production-huya-native-flv',
              'room': room,
              'host': Uri.parse(url).host,
              'cdn': line.cdnType,
              'requestedBitRate': bitRate,
              'webTokenOmitted': omitWebToken,
              'durationMs': clock.elapsedMilliseconds,
              'bytes': bytes,
              'chunks': chunks,
              'maxReadGapMs': maxGap.inMilliseconds,
              'reachedLimit': reachedLimit,
              'secretsPersisted': false,
            }),
          );
          expect(reachedLimit, isTrue, reason: 'transport ended before the requested duration');
          expect(bytes, greaterThan(0));
        } catch (error) {
          // Do not let HttpException/DioException print a signed request URI.
          fail('Huya native transport probe failed (${error.runtimeType})');
        } finally {
          client.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_HUYA_LIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 12)),
  );
}

class _RealNetwork extends HttpOverrides {}

Map<String, dynamic> _extractStream(String page) {
  final marker = page.indexOf('stream:');
  if (marker < 0) throw const FormatException('room stream metadata missing');
  final start = page.indexOf('{', marker);
  var depth = 0;
  var quoted = false;
  var escaped = false;
  for (var i = start; i < page.length; i++) {
    final char = page[i];
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        quoted = false;
      }
    } else if (char == '"') {
      quoted = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}' && --depth == 0) {
      return jsonDecode(page.substring(start, i + 1)) as Map<String, dynamic>;
    }
  }
  throw const FormatException('room stream metadata truncated');
}
