// Opt-in public website search probe. Reads profile metadata only.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/kilakila/kilakila_api.dart';
import 'package:pure_live/core/site/kilakila/kilakila_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test(
    'registered Kilakila adapter reads two official user-search pages',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final site = Sites.of('kilakila').liveSite as KilakilaSite;
          final first = await site.searchRooms('音乐', page: 1);
          final second = await site.searchRooms('音乐', page: 2);
          expect(first, isNotEmpty);
          expect(second, isNotEmpty);
          expect(first.every((room) => room.roomId != null && room.data == null), isTrue);
          expect(second.every((room) => room.roomId != null && room.data == null), isTrue);
          final owner = await KilakilaApi().owner(first.first.roomId!);
          expect(owner.userId, first.first.roomId);
          // ignore: avoid_print
          print(
            jsonEncode({
              'utc': DateTime.now().toUtc().toIso8601String(),
              'firstPageRows': first.length,
              'secondPageRows': second.length,
              'firstOwnerMatched': true,
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
    skip: io.Platform.environment['PURELIVE_KILAKILA_SEARCH_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
