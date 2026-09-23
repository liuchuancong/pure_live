// Opt-in, read-only check of registered Bigo snapshot keyword search.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/bigo/bigo_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test(
    'registered Bigo adapter finds a current public recommendation by nickname',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio =
            Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)))
              ..httpClientAdapter = IOHttpClientAdapter(
                createHttpClient: () => io.HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:7897',
              );
        HttpClient.instance.dio = dio;
        try {
          final site = Sites.of(Sites.bigoSite).liveSite as BigoSite;
          final page = await site.getDirectoryPage();
          expect(page.rooms, isNotEmpty);
          final sample = page.rooms.firstWhere(
            (room) => room.nick != null && room.nick!.isNotEmpty && room.nick!.length <= 100,
          );
          final stopwatch = Stopwatch()..start();
          final matches = await site.searchRooms(sample.nick!);
          stopwatch.stop();
          expect(matches.any((room) => room.roomId == sample.roomId), isTrue);
          expect(matches.every((room) => room.data == null), isTrue);
          // ignore: avoid_print
          print(
            jsonEncode({
              'utc': DateTime.now().toUtc().toIso8601String(),
              'publicSnapshotRows': page.rooms.length,
              'keywordMatches': matches.length,
              'matchedCurrentRoom': true,
              'searchElapsedMs': stopwatch.elapsedMilliseconds,
              'mediaFetched': false,
              'nativePlaybackOrRecording': false,
            }),
          );
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_BIGO_SNAPSHOT_SEARCH_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
