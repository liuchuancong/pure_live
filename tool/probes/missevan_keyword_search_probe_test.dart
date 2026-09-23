// Opt-in anonymous production search through the registered application adapter.
// It verifies public metadata, not native playback or recording.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/missevan/missevan_site.dart';
import 'package:pure_live/core/sites.dart';

void main() {
  test(
    'Missevan public keyword search pages use the registered adapter',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final site = Sites.of('missevan').liveSite as MissevanSite;
          final first = await site.searchRooms('音乐', page: 1, pageSize: 20);
          final second = await site.searchRooms('音乐', page: 2, pageSize: 20);
          expect(first, isNotEmpty);
          expect(second, isNotEmpty);
          expect(first.length, lessThanOrEqualTo(20));
          expect(second.length, lessThanOrEqualTo(20));
          final ids = first.map((room) => room.roomId).toSet();
          expect(second.any((room) => !ids.contains(room.roomId)), isTrue);
          expect([...first, ...second].every((room) => room.platform == 'missevan' && room.data == null), isTrue);
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'probe': 'missevan-public-keyword-search',
            'pageOneRooms': first.length,
            'pageTwoRooms': second.length,
            'liveRooms': [...first, ...second].where((room) => room.isLiveNow).length,
            'offlineRooms': [...first, ...second].where((room) => room.isExplicitlyOfflineNow).length,
            'mediaFetched': false,
            'platformRegistered': Sites.isSupported('missevan'),
          };
          final output = io.Platform.environment['PURELIVE_MISSEVAN_SEARCH_PROBE_OUTPUT'];
          if (output != null && output.isNotEmpty) {
            final file = io.File(output);
            await file.parent.create(recursive: true);
            await file.writeAsString('${const JsonEncoder.withIndent('  ').convert(result)}\n');
          }
          // ignore: avoid_print
          print(jsonEncode(result));
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_MISSEVAN_SEARCH_LIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
