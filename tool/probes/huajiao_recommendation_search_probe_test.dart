// Opt-in, read-only search probe for the current public Huajiao feed.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/huajiao/huajiao_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test(
    'registered Huajiao adapter filters a current public recommendation',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio =
            Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)))
              ..httpClientAdapter = IOHttpClientAdapter(
                createHttpClient: () => io.HttpClient()..findProxy = (_) => 'DIRECT',
              );
        HttpClient.instance.dio = dio;
        try {
          final site = Sites.of(Sites.huajiaoSite).liveSite as HuajiaoSite;
          final publicPage = await site.getDirectoryPageAtCursor(page: 1);
          expect(publicPage.rooms, isNotEmpty);
          final sample = publicPage.rooms.firstWhere(
            (room) =>
                room.nick != null &&
                room.nick!.isNotEmpty &&
                room.nick!.length <= 100 &&
                !RegExp(r'^[0-9]+$').hasMatch(room.nick!),
          );
          final elapsed = Stopwatch()..start();
          final matches = await site.searchRooms(sample.nick!, pageSize: 20);
          elapsed.stop();
          expect(matches.any((room) => room.roomId == sample.roomId), isTrue);
          expect(matches.every((room) => room.data == null), isTrue);
          // ignore: avoid_print
          print(
            jsonEncode({
              'utc': DateTime.now().toUtc().toIso8601String(),
              'publicFirstPage': publicPage.rooms.length,
              'searchMatches': matches.length,
              'matchedSample': true,
              'searchElapsedMs': elapsed.elapsedMilliseconds,
              'maxRecommendationPages': HuajiaoSite.searchRecommendationPages,
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
    skip: io.Platform.environment['PURELIVE_HUAJIAO_SEARCH_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
