// Opt-in public metadata probe. No media is opened or downloaded.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/inke/inke_api.dart';
import 'package:pure_live/core/site/inke/inke_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test(
    'registered Inke adapter finds a current public showcase nickname',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final api = InkeApi();
          final top = await api.directoryPage();
          expect(top.rooms, isNotEmpty);
          final sample = top.rooms.first;
          final site = Sites.of('inke').liveSite as InkeSite;
          final matches = await site.searchRooms(sample.nick!, pageSize: 60);
          expect(matches.any((room) => room.roomId == sample.roomId), isTrue);
          expect(matches.every((room) => room.data == null && room.isLiveNow), isTrue);
          expect(await site.searchRooms(sample.nick!, page: 2, pageSize: 60), isEmpty);
          // ignore: avoid_print
          print(
            jsonEncode({
              'utc': DateTime.now().toUtc().toIso8601String(),
              'topRows': top.rooms.length,
              'nicknameMatches': matches.length,
              'registeredAdapter': true,
              'fullSiteIndex': false,
              'mediaFetched': false,
            }),
          );
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_INKE_SEARCH_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
