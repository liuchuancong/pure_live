// Opt-in captured-response replay plus real anonymous directory/search traffic.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_directory.dart';

void main() {
  final enabled = io.Platform.environment['PURELIVE_NICONICO_DIRECTORY_PROBE'] == '1';
  test('captured official recent and search payloads parse without watch bootstrap', () async {
    final base = io.Platform.environment['PURELIVE_NICONICO_DIRECTORY_CAPTURE']!;
    final files = [
      'recent0',
      'recent1',
      'recent-try',
      'recent-live',
      'recent-req',
      'recent-face',
      'recent-totu',
      'recent-vtuber',
      'keyword',
      'keyword2',
      'live1',
      'live2',
      'channel',
    ];
    var rows = 0;
    for (final name in files) {
      final search = !name.startsWith('recent');
      final page = name == 'recent1' || name == 'keyword2' || name == 'live2' ? 2 : 1;
      final body = await io.File('$base/$name.json').readAsString();
      final result = NiconicoDirectory.parse(body, page: page, search: search);
      rows += result.rooms.length;
      for (final room in result.rooms) {
        expect(room.isLiveNow, isTrue);
        expect(room.data, isNull);
        expect(room.platform, 'niconico');
        expect(room.roomId, startsWith('lv'));
      }
    }
    expect(rows, greaterThan(0));
    // ignore: avoid_print
    print(jsonEncode({'capturedFiles': files.length, 'capturedRows': rows}));
  }, skip: !enabled);

  test(
    'production recent categories and paginated keyword search stay public and bounded',
    () async {
      final output = io.Platform.environment['PURELIVE_NICONICO_DIRECTORY_OUTPUT']!;
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'result': 'failed',
        'route': 'PROXY 127.0.0.1:7897',
        'mediaDecoded': false,
        'watchSeats': 0,
      };
      final results = <Map<String, Object?>>[];
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => io.HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:7897',
          );
        HttpClient.instance.dio = dio;
        try {
          final directory = NiconicoDirectory();
          for (final tab in NiconicoDirectory.categories) {
            final page = await directory.recent(tab: tab);
            expect(page.rooms.length, lessThanOrEqualTo(70));
            results.add({'tab': tab, 'page': 1, 'rows': page.rooms.length, 'hasMore': page.hasMore});
          }
          final next = await directory.recent(page: 2);
          results.add({'tab': 'common', 'page': 2, 'rows': next.rooms.length, 'hasMore': next.hasMore});
          for (final index in [1, 2]) {
            final page = await directory.search('ゲーム', page: index);
            expect(page.rooms.length, lessThanOrEqualTo(40));
            expect(page.rooms, isNotEmpty);
            results.add({'keyword': 'ゲーム', 'page': index, 'rows': page.rooms.length, 'hasMore': page.hasMore});
          }
          report['result'] = 'passed';
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
          report['results'] = results;
          await io.File(output).writeAsString(jsonEncode(report));
          // ignore: avoid_print
          print(jsonEncode(report));
        }
      }, _RealNetwork());
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
