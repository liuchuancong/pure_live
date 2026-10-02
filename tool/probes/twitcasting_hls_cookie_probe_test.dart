// Opt-in HTTP-only verification of the production relay. Saves only counts
// and status codes, never session cookie values or a claim of native playback.
// This opt-in test lives under tool/probes rather than the default test tree.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/platforms/twitcasting/twitcasting_api.dart';
import 'package:pure_live/domains/recorder/data/services/ffmpeg_hls_input_relay.dart';
import 'package:pure_live/domains/recorder/data/services/recorder_proxy_routing.dart';

void main() {
  test(
    'TwitCasting production relay retains anonymous HLS session cookies',
    () async {
      await HttpOverrides.runWithHttpOverrides(() async {
        final proxy = Uri.parse(Platform.environment['PURELIVE_PROBE_PROXY']!);
        final channel = Platform.environment['PURELIVE_TWITCASTING_CHANNEL']!;
        final output = File(Platform.environment['PURELIVE_TWITCASTING_COOKIE_OUTPUT']!);
        final remote = HttpClient()..findProxy = (_) => 'PROXY ${proxy.host}:${proxy.port}';
        final local = HttpClient()..findProxy = (_) => 'DIRECT';
        configureRecorderProxyRouting((_) => 'PROXY ${proxy.host}:${proxy.port}');
        FFmpegHlsInputRelay? relay;
        try {
          final endpoint = Uri.https('twitcasting.tv', '/streamserver.php', {
            'target': channel,
            'mode': 'client',
            'player': 'pc_web',
          });
          final request = await remote.getUrl(endpoint);
          TwitcastingApi.playHeaders.forEach(request.headers.set);
          final response = await request.close();
          expect(response.statusCode, HttpStatus.ok);
          final stream = jsonDecode(utf8.decode(await _boundedBytes(response))) as Map<String, dynamic>;
          expect(stream['movie']['live'], true, reason: 'Selected public channel must still be live');
          final url = Uri.parse(stream['tc-hls']['streams']['high'] as String);
          expect(url.scheme, 'https');
          expect(url.host.endsWith('.twitcasting.tv'), true);
          relay = (await FFmpegHlsInputRelay.startForArguments([
            '-headers',
            TwitcastingApi.playHeaders.entries.map((e) => '${e.key}: ${e.value}\r\n').join(),
            '-i',
            url.toString(),
          ], force: true))!;
          final root = await (await local.getUrl(relay.inputUri)).close();
          expect(root.statusCode, HttpStatus.ok);
          expect(root.headers[HttpHeaders.setCookieHeader], isNull);
          final manifest = utf8.decode(await _boundedBytes(root));
          final init = RegExp(r'#EXT-X-MAP:URI="([^"]+)"').firstMatch(manifest)!.group(1)!;
          final media = const LineSplitter().convert(manifest).firstWhere((s) => s.isNotEmpty && !s.startsWith('#'));
          final rows = <Map<String, Object>>[];
          for (final (kind, resource) in [('init', init), ('media', media)]) {
            final resourceUri = Uri.parse(resource);
            expect(resourceUri.origin, relay.inputUri.origin);
            final part = await (await local.getUrl(resourceUri)).close();
            expect(part.statusCode, HttpStatus.ok);
            expect(part.headers[HttpHeaders.setCookieHeader], isNull);
            final bytes = await _boundedBytes(part);
            expect(bytes.length, greaterThan(0));
            rows.add({'resource': kind, 'status': part.statusCode, 'bytes': bytes.length});
          }
          expect(relay.sessionCookieCount, greaterThan(0));
          final count = relay.sessionCookieCount;
          await relay.close();
          expect(relay.sessionCookieCount, 0);
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'channel': channel,
            'movieId': stream['movie']['id'],
            'resources': rows,
            'cookieCount': count,
            'cookieCountAfterClose': relay.sessionCookieCount,
            'cookieValuesSaved': false,
            'evidenceLayer': 'production-relay-http-not-native-playback-or-recording',
          };
          await output.parent.create(recursive: true);
          await output.writeAsString('${const JsonEncoder.withIndent('  ').convert(result)}\n');
          // ignore: avoid_print
          print(jsonEncode(result));
        } finally {
          await relay?.close();
          configureRecorderProxyRouting(null);
          remote.close(force: true);
          local.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: Platform.environment['PURELIVE_TWITCASTING_COOKIE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<List<int>> _boundedBytes(HttpClientResponse response) async {
  final bytes = <int>[];
  await for (final chunk in response.timeout(const Duration(seconds: 20))) {
    if (bytes.length + chunk.length > 2 * 1024 * 1024) throw const FormatException('Probe read limit');
    bytes.addAll(chunk);
  }
  return bytes;
}

class _RealNetwork extends HttpOverrides {}
