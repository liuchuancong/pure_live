import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/plugins/race_http.dart';

void main() {
  group('RaceHttp.findFastestUrl', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        if (request.uri.path == '/ok') {
          request.response.statusCode = HttpStatus.partialContent;
          request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes 0-0/1');
          request.response.add([1]);
        } else {
          request.response.statusCode = HttpStatus.serviceUnavailable;
        }
        await request.response.close();
      });
    });

    tearDown(() => server.close(force: true));

    test('uses a ranged GET and returns the first healthy mirror', () async {
      final base = 'http://${server.address.address}:${server.port}';

      final winner = await RaceHttp.findFastestUrl([
        '$base/bad',
        '$base/ok',
      ], timeout: const Duration(seconds: 1));

      expect(winner, '$base/ok');
    });

    test('returns null after all mirrors fail instead of hanging', () async {
      final base = 'http://${server.address.address}:${server.port}';
      final stopwatch = Stopwatch()..start();

      final winner = await RaceHttp.findFastestUrl([
        '$base/bad',
        '$base/also-bad',
      ], timeout: const Duration(milliseconds: 300));

      expect(winner, isNull);
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 1)));
    });

    test('returns null immediately for an empty mirror list', () async {
      expect(await RaceHttp.findFastestUrl(const []), isNull);
    });
  });
}
