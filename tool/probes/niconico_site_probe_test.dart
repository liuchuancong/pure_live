// Opt-in production metadata + short-lived quality discovery, not media decode.
import 'dart:convert';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/domain/live_site.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_api.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_quality_catalog.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_session.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_site.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_stream.dart';
import 'package:pure_live/domains/recorder/data/services/niconico_hls_input.dart';

void main() {
  test(
    'Niconico production site returns observed choices and releases discovery seats',
    () async {
      final id = io.Platform.environment['PURELIVE_NICONICO_PROGRAM']!;
      final output = io.Platform.environment['PURELIVE_NICONICO_OUTPUT']!;
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'programId': id,
        'result': 'failed',
        'route': 'PROXY 127.0.0.1:7897',
        'mediaDecoded': false,
      };
      final seats = <NiconicoSession>[];
      final grants = <NiconicoStream>[];
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => io.HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:7897',
          );
        HttpClient.instance.dio = dio;
        try {
          final api = NiconicoApi();
          final catalog = NiconicoQualityCatalog(
            api: api,
            findProxy: (_) => 'PROXY 127.0.0.1:7897',
            openSeat: (watch, cancel, proxy) async {
              final seat = await NiconicoSession.open(watch, cancel: cancel, findProxy: proxy);
              seats.add(seat);
              grants.add(seat.current);
              return seat;
            },
            readMaster: (source, cookies, cancel, proxy) async {
              final text = await readNiconicoMaster(source, cookies, cancel, proxy);
              report['masterBytes'] = utf8.encode(text).length;
              report['masterSha256'] = sha256.convert(utf8.encode(text)).toString();
              return text;
            },
          );
          final site = NiconicoSite(api: api, catalog: catalog);
          final room = await site.getRoomDetailForRecording(roomId: id, platform: 'niconico');
          expect(room.roomId, id);
          expect(room.isLiveNow, isTrue);
          expect(jsonEncode(room.toJson()), isNot(contains('audience_token')));
          final choices = await site.getPlayQualites(detail: room);
          expect(choices, isNotEmpty);
          for (final quality in choices) {
            final result = await site.resolvePlayUrls(detail: room, quality: quality);
            expect(result.inputRecipe, isNotNull);
            expect(result.urls, isEmpty);
            expect(result.appliedQualityData, quality.selectionId);
          }
          expect(seats, hasLength(1));
          expect(seats.single.cleanupSucceeded, isTrue);
          expect(seats.single.isClosed, isTrue);
          expect(grants.single.retainedCookieCount, 0);
          report.addAll({
            'result': 'passed',
            'qualities': choices.map((e) => {'id': e.selectionId, 'label': e.quality}).toList(),
            'hasCover': room.cover?.isNotEmpty == true,
            'hasAvatar': room.avatar?.isNotEmpty == true,
            'metric': room.effectiveAudienceMetricType.name,
          });
        } finally {
          try {
            for (final seat in seats) {
              await seat.close();
            }
          } finally {
            HttpClient.instance.dio = previous;
            dio.close(force: true);
          }
          report['seatsClosed'] = seats.every((seat) => seat.isClosed && seat.cleanupSucceeded);
          report['retainedCookies'] = grants.fold<int>(0, (total, grant) => total + grant.retainedCookieCount);
          await io.File(output).writeAsString(jsonEncode(report));
          // ignore: avoid_print
          print(jsonEncode(report));
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_NICONICO_SITE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
