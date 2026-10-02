// Opt-in anonymous API contract probe, not a native playback/recording test.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/kilakila/kilakila_api.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';

void main() {
  test(
    'Kilakila production API parses native pages and current free room media',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final api = KilakilaApi();
          final first = await api.directory();
          expect(first.rooms, isNotEmpty);
          expect(first.page, 1);
          expect(first.rooms.every((r) => r.media.isEmpty), isTrue);
          final second = first.hasMore ? await api.directory(page: 2) : null;
          final recommendations = await api.recommendations();
          KilakilaRoomSnapshot? playable;
          for (final candidate in first.rooms.where((r) => r.isLive && r.goldPrice == 0).take(3)) {
            try {
              final metadata = await api.detail(candidate.roomId, expectedUserId: candidate.userId, playback: false);
              expect(metadata.media, isEmpty);
              playable = await api.detail(candidate.roomId, expectedUserId: candidate.userId);
              break;
            } on KilakilaException catch (error) {
              if (!{KilakilaFailure.historicalReplay, KilakilaFailure.stateUnsupported}.contains(error.kind)) rethrow;
            }
          }
          expect(playable, isNotNull, reason: 'No current free sample resolved within three directory candidates');
          final room = playable!;
          expect(room.media, isNotEmpty);
          expect(KilakilaApi.numericRoomFromUri(Uri.parse(room.link)), room.roomId);
          final fresh = await api.detail(room.roomId, expectedUserId: room.userId);
          expect(fresh.roomId, room.roomId);
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'firstPageRows': first.rooms.length,
            'firstHasMore': first.hasMore,
            'secondPageRows': second?.rooms.length,
            'secondHasMore': second?.hasMore,
            'recommendationRows': recommendations.length,
            'protocolIds': room.media.keys.toList(),
            'metadataSeparatedFromMedia': true,
            'reacquiredCurrentRoom': true,
            'crossBroadcastOwnerLookupVerified': false,
            'opaqueShareDecodingVerified': false,
            'mediaFetched': false,
            'nativePlaybackOrRecording': false,
            'platformRegistered': Sites.isSupported('kilakila'),
            'routing': 'anonymous direct Dio test adapter; application proxy settings not exercised',
          };
          final output = io.Platform.environment['PURELIVE_KILAKILA_PROBE_OUTPUT'];
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
    skip: io.Platform.environment['PURELIVE_KILAKILA_LIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
