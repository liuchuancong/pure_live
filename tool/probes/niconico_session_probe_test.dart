// Opt-in: public watch page, one owned WebSocket seat, bounded HLS metadata/key
// requests and one advertised keepalive interval. No login or media recording.
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/core/network/web_socket_util.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_api.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_session.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_stream.dart';

void main() {
  test('probe preserves NONE and resolves ordinary identity keys', () {
    final base = Uri.parse('https://example.test/video/index.m3u8');
    expect(_identityKeys('#EXT-X-KEY:METHOD=NONE', base), isEmpty);
    expect(_identityKeys('#EXT-X-KEY:METHOD=NONE\n#EXT-X-KEY:METHOD=AES-128,URI="key"', base), [base.resolve('key')]);
  });
  test('probe rejects malformed and unhandled key contracts', () {
    final base = Uri.parse('https://example.test/video/index.m3u8');
    for (final line in [
      '#EXT-X-KEY:METHOD=NONE,URI="key"',
      '#EXT-X-KEY:METHOD=AES-128',
      '#EXT-X-KEY:METHOD=SAMPLE-AES,URI="key"',
      '#EXT-X-KEY:METHOD=AES-128,URI="key",KEYFORMAT="unhandled"',
    ]) {
      expect(() => _identityKeys(line, base), throwsFormatException);
    }
  });
  test(
    'Niconico production session keeps its seat and scopes HLS cookies',
    () async {
      final id = io.Platform.environment['PURELIVE_NICONICO_PROGRAM']!;
      final output = io.Platform.environment['PURELIVE_NICONICO_OUTPUT'];
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'result': 'failed',
        'route': 'PROXY 127.0.0.1:7897',
        'stage': 'watch',
        'decoded': false,
        'requests': <Map<String, Object?>>[],
      };
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => io.HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:7897',
          );
        final media = io.HttpClient()
          ..connectionTimeout = const Duration(seconds: 10)
          ..findProxy = (_) => 'PROXY 127.0.0.1:7897';
        NiconicoSession? session;
        NiconicoStream? grant;
        Timer? holdTimer;
        HttpClient.instance.dio = dio;
        configureWebSocketProxyRouting((_) => 'PROXY 127.0.0.1:7897');
        try {
          final watch = await NiconicoApi().room(id);
          report['stage'] = 'session';
          session = await NiconicoSession.open(watch);
          grant = session.current;
          report['cookieCount'] = grant.retainedCookieCount;
          report['qualityChoices'] = grant.availableQualities;
          report['seatIntervalSeconds'] = session.seatIntervalSeconds;
          expect(session.seatIntervalSeconds, inInclusiveRange(1, 60));
          final hold = Completer<void>();
          holdTimer = Timer(Duration(seconds: session.seatIntervalSeconds! + 1), hold.complete);

          Future<Uint8List> fetch(Uri uri, String kind) async {
            if (uri.scheme != 'https' ||
                uri.host != 'livedelivery.dlive.nicovideo.jp' ||
                uri.userInfo.isNotEmpty ||
                uri.hasPort) {
              throw StateError('Unverified media origin');
            }
            final request = await media.getUrl(uri);
            final deadline = Timer(
              const Duration(seconds: 20),
              () => request.abort(TimeoutException('response deadline')),
            );
            unawaited(request.done.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
            try {
              request.followRedirects = false;
              final cookie = session!.current.cookieHeaderFor(uri);
              if (cookie != null) request.headers.set(io.HttpHeaders.cookieHeader, cookie);
              final response = await request.close().timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  request.abort();
                  throw TimeoutException('headers');
                },
              );
              final bytes = BytesBuilder(copy: false);
              await for (final chunk in response.timeout(const Duration(seconds: 10))) {
                if (bytes.length + chunk.length > 2 * 1024 * 1024) throw StateError('Response byte limit');
                bytes.add(chunk);
              }
              (report['requests'] as List).add({
                'kind': kind,
                'status': response.statusCode,
                'bytes': bytes.length,
                'cookieAttached': cookie != null,
              });
              expect(response.statusCode, 200, reason: kind);
              return bytes.takeBytes();
            } finally {
              deadline.cancel();
              request.abort();
            }
          }

          report['stage'] = 'master';
          final master = utf8.decode(await fetch(grant.uri, 'master'));
          expect(master.startsWith('#EXTM3U'), isTrue);
          final variants = <Uri>[];
          final lines = const LineSplitter().convert(master);
          for (var i = 0; i + 1 < lines.length; i++) {
            if (lines[i].startsWith('#EXT-X-STREAM-INF:')) variants.add(grant.uri.resolve(lines[i + 1]));
          }
          expect(variants, isNotEmpty);
          report['variantCount'] = variants.length;
          report['stage'] = 'video-playlist';
          final video = utf8.decode(await fetch(variants.last, 'video-playlist'));
          expect(video.startsWith('#EXTM3U'), isTrue);
          expect(video, contains('#EXTINF:'));
          final audioLine = lines.firstWhere((line) => line.startsWith('#EXT-X-MEDIA:') && line.contains('TYPE=AUDIO'));
          final audioRef = RegExp(r'URI="([^"]+)"').firstMatch(audioLine)!;
          report['stage'] = 'audio-playlist';
          final audioUri = grant.uri.resolve(audioRef.group(1)!);
          final audio = utf8.decode(await fetch(audioUri, 'audio-playlist'));
          report['audioHasExtinf'] = audio.contains('#EXTINF:');
          expect(audio, contains('#EXTINF:'));
          report['stage'] = 'key-contract';
          report['keyMethods'] = RegExp(r'#EXT-X-KEY:METHOD=([^,\r\n]+)')
              .allMatches('$video\n$audio')
              .map((m) => m.group(1))
              .toSet()
              .toList();
          final keys = {..._identityKeys(video, variants.last), ..._identityKeys(audio, audioUri)};
          expect(keys.length, lessThanOrEqualTo(4));
          report['keyCount'] = keys.length;
          for (final key in keys) {
            report['stage'] = 'key';
            final bytes = await fetch(key, 'key');
            expect(bytes.length, 16);
            bytes.fillRange(0, bytes.length, 0);
          }
          report['stage'] = 'keepalive';
          await Future.any<void>([
            hold.future,
            session.done.then<void>((_) => throw StateError('Seat ended before keepalive check')),
          ]);
          expect(session.isClosed, isFalse);
          expect(session.seatKeepAlivesSent, greaterThanOrEqualTo(1));
          report['keepSeatSent'] = session.seatKeepAlivesSent;
          report['pongSent'] = session.pongsSent;
          report['stage'] = 'master-after-keepalive';
          expect(utf8.decode(await fetch(session.current.uri, 'master-after-keepalive')), startsWith('#EXTM3U'));
          report['result'] = 'passed';
        } catch (error) {
          report['failureType'] = error.runtimeType.toString();
          // Do not print signed media URLs or websocket/cookie values on failure.
          fail('Niconico session probe failed at ${report['stage']} (${report['failureType']})');
        } finally {
          holdTimer?.cancel();
          await session?.close();
          report['sessionClosed'] = session?.isClosed;
          report['cleanupSucceeded'] = session?.cleanupSucceeded;
          report['retainedCookiesAfterClose'] = grant?.retainedCookieCount;
          if (session != null && !session.cleanupSucceeded) {
            report['result'] = 'failed';
            report['failureType'] = 'Cleanup';
          }
          media.close(force: true);
          HttpClient.instance.dio = previous;
          dio.close(force: true);
          configureWebSocketProxyRouting(null);
          if (output != null) await io.File(output).writeAsString(jsonEncode(report));
          // ignore: avoid_print
          print(jsonEncode(report));
          if (session != null) expect(session.cleanupSucceeded, isTrue);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_NICONICO_SESSION_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends io.HttpOverrides {}

List<Uri> _identityKeys(String playlist, Uri base) {
  final keys = <Uri>[];
  for (final line in const LineSplitter().convert(playlist)) {
    if (!line.startsWith('#EXT-X-KEY:')) continue;
    if (line == '#EXT-X-KEY:METHOD=NONE') continue;
    final method = RegExp(r'METHOD=([^,]+)').firstMatch(line)?.group(1);
    final format = RegExp(r'KEYFORMAT="([^"]+)"').firstMatch(line)?.group(1);
    final uri = RegExp(r'URI="([^"]+)"').firstMatch(line)?.group(1);
    if (method != 'AES-128' || (format != null && format != 'identity') || uri == null) {
      throw const FormatException('Unhandled HLS key contract');
    }
    keys.add(base.resolve(uri));
  }
  return keys;
}
