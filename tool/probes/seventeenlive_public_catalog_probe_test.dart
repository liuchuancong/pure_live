// Opt-in, read-only probe of the registered 17LIVE public JP feed and search.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/seventeenlive/seventeenlive_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test(
    'registered 17LIVE adapter reads public cursor page and current-live search',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 25)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final site = Sites.of('17live').liveSite as SeventeenLiveSite;
          final first = await site.getDirectoryPageAtCursor(page: 1);
          expect(first.rooms, isNotEmpty);
          expect(first.rooms.every((room) => room.roomId != null && room.data == null), isTrue);
          final search = await site.searchRooms('あ');
          expect(search.every((room) => room.roomId != null && room.data == null), isTrue);
          // ignore: avoid_print
          print(
            jsonEncode({
              'utc': DateTime.now().toUtc().toIso8601String(),
              'directoryRooms': first.rooms.length,
              'hasMore': first.hasMore,
              'searchRooms': search.length,
              'region': 'JP',
              'fullSiteIndex': false,
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
    skip: io.Platform.environment['PURELIVE_SEVENTEEN_CATALOG_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
