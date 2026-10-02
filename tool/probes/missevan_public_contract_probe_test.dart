// Opt-in anonymous API requests through the registered production adapter.
// This does not prove native playback/recording support.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/domain/live_site.dart';
import 'package:pure_live/domains/live/data/platforms/missevan/missevan_api.dart';
import 'package:pure_live/domains/live/data/platforms/missevan/missevan_site.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/recorder/data/services/stream_resolver_service.dart';

void main() {
  test(
    'Missevan anonymous staged adapter directory/detail/recovery contract',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final site = Sites.of('missevan').liveSite as MissevanSite;
          final categories = (await site.getCategores(1, 30)).single.children;
          expect(categories, isNotEmpty);
          final categoryRooms = await site.getCategoryRooms(categories.first, pageSize: 20);
          final rooms = await site.getRecommendRooms();
          final pageTwo = await site.getRecommendRooms(page: 2);
          expect(rooms, isNotEmpty);
          expect(rooms.length, lessThanOrEqualTo(100));
          expect(pageTwo.length, lessThanOrEqualTo(100));
          final detail = await site.getRoomDetailForRecording(roomId: rooms.first.roomId!, platform: 'missevan');
          expect(detail.isLiveNow, isTrue);
          final qualities = await site.getPlayQualites(detail: detail);
          expect(qualities, isNotEmpty);
          final resolved = await site.resolvePlayUrlsForRecovery(detail: detail, quality: qualities.first);
          expect(resolved.appliedQualityData, qualities.first.selectionId);
          expect(Uri.parse(resolved.urls.single).scheme, 'https');
          expect(site.getPlayUrlInvalidAt(resolved.urls.single), isNotNull);
          final record = await StreamResolverService().resolveStream(
            roomId: detail.roomId!,
            platform: 'missevan',
            preferredQuality: 'hls',
          );
          expect(record.qualityCursorId, 'hls');
          expect(record.invalidAt, isNotNull);
          await expectLater(
            site.getRoomDetail(roomId: '1', platform: 'missevan'),
            throwsA(isA<MissevanException>().having((error) => error.kind, 'kind', MissevanFailure.notFound)),
          );
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'probe': 'missevan-staged-public-contract',
            'categoryCount': categories.length,
            'categoryRooms': categoryRooms.length,
            'pageOneRooms': rooms.length,
            'pageTwoRooms': pageTwo.length,
            'qualityIds': qualities.map((q) => q.selectionId).toList(),
            'freshRecovery': true,
            'leaseMetadata': true,
            'notFoundClassified': true,
            'nativePlaybackOrRecording': false,
            'platformRegistered': Sites.isSupported('missevan'),
            'productionRecorderResolution': true,
            'mediaFetched': false,
            'routing': 'anonymous direct Dio test adapter; application settings/proxy integration not exercised',
          };
          final output = io.Platform.environment['PURELIVE_MISSEVAN_PROBE_OUTPUT'];
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
    skip: io.Platform.environment['PURELIVE_MISSEVAN_LIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
