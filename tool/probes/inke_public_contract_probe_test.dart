// Opt-in anonymous API probe. Does not register a platform or claim native
// playback, recording, application proxy or complete platform acceptance.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/inke/inke_api.dart';
import 'package:pure_live/core/models/live_play_quality.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/data/platforms/inke/inke_site.dart';
import 'package:pure_live/domains/recorder/data/services/stream_resolver_service.dart';

void main() {
  test(
    'Inke production parser resolves current anonymous showcase media',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final api = InkeApi();
          final site = Sites.of('inke').liveSite as InkeSite;
          final categories = await api.categories();
          expect(categories, isNotEmpty);
          final category = await api.directoryPage(category: categories.first);
          final top = await api.directoryPage();
          expect(top.rooms, isNotEmpty);
          expect(top.hasMore, isFalse);
          final uid = top.rooms.first.roomId!;
          final metadata = await api.detail(uid, playback: false);
          expect(metadata.isLiveNow, isTrue);
          expect(metadata.data, isNull);
          final playable = await site.getRoomDetailForRecording(roomId: uid, platform: 'inke');
          expect(playable.isLiveNow, isTrue);
          final quality = (playable.data as List<LivePlayQuality>).single;
          final urls = quality.data as List<String>;
          expect(urls, isNotEmpty);
          expect(Uri.parse(urls.first).path, endsWith('_t.flv'));
          final fresh = await api.detail(uid);
          expect(fresh.roomId, uid);
          final record = await StreamResolverService().resolveStream(
            roomId: uid,
            platform: 'inke',
            preferredQuality: 'flv',
          );
          expect(record.qualityCursorId, 'flv');
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'categories': categories.length,
            'categoryShowcaseRooms': category.rooms.length,
            'topShowcaseRooms': top.rooms.length,
            'qualityIds': [quality.selectionId],
            'metadataSeparatedFromMedia': true,
            'reacquiredCurrentBroadcast': true,
            'showcaseIsFullPlatformIndex': false,
            'mediaFetched': false,
            'nativePlaybackOrRecording': false,
            'platformRegistered': Sites.isSupported('inke'),
            'productionRecorderResolution': true,
            'routing': 'anonymous direct Dio test adapter; application proxy settings not exercised',
          };
          final output = io.Platform.environment['PURELIVE_INKE_PROBE_OUTPUT'];
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
    skip: io.Platform.environment['PURELIVE_INKE_LIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
