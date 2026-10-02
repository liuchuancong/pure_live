import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/domain/live_site.dart';
import 'package:pure_live/domains/live/data/platforms/kilakila/kilakila_site.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/data/link/live_url_tool.dart';
import 'package:pure_live/domains/recorder/data/services/stream_resolver_service.dart';

void main() {
  test(
    'registered Kilakila adapter resolves UID playback and recording metadata',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final site = Sites.of('kilakila').liveSite as KilakilaSite;
          final page = await site.getDirectoryPage();
          expect(page.rooms, isNotEmpty);
          final uid = page.rooms.firstWhere((r) => r.isLiveNow).roomId!;
          final categories = (await site.getCategores(1, 30)).single.children;
          final newcomers = await site.getDirectoryPage(category: categories.last);
          expect(newcomers.rooms, isNotEmpty, reason: 'This probe requires an available rising-star live sample');
          final metadata = await site.getRoomDetailForRefresh(roomId: uid, platform: site.id);
          expect(metadata.roomId, uid);
          expect(metadata.data, isNull);
          final detail = await site.getRoomDetail(roomId: uid, platform: site.id);
          final qualities = await site.getPlayQualites(detail: detail);
          expect(qualities, isNotEmpty);
          final resolution = await site.resolvePlayUrls(detail: detail, quality: qualities.first);
          expect(resolution.urls, isNotEmpty);
          final renewal = await site.resolvePlayUrlsForRecovery(detail: detail, quality: qualities.first);
          expect(renewal.urls, isNotEmpty);
          final recorded = await StreamResolverService().resolveStream(
            roomId: uid,
            platform: site.id,
            preferredQuality: qualities.first.selectionId.toString(),
          );
          expect(recorded.url, startsWith('https://pull.live.hongrenshuo.com.cn/'));
          expect(await LiveUrlTool.parseLiveUrl(detail.link!), [uid, site.id]);
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'registeredAdapter': true,
            'hotCount': page.rooms.length,
            'hotHasMore': page.hasMore,
            'newcomerCount': newcomers.rooms.length,
            'newcomerHasMore': newcomers.hasMore,
            'uidIdentity': true,
            'metadataOmitsMedia': true,
            'qualityIds': qualities.map((q) => q.selectionId.toString()).toList(),
            'playbackResolution': true,
            'recoveryResolution': true,
            'recorderResolution': true,
            'mediaFetched': false,
            'nativePlaybackOrRecording': false,
            'routing': 'anonymous direct Dio; application proxy not exercised',
          };
          final path = io.Platform.environment['PURELIVE_KILAKILA_APP_OUTPUT'];
          if (path != null) {
            await io.File(path).writeAsString('${const JsonEncoder.withIndent('  ').convert(result)}\n');
          }
          // ignore: avoid_print
          print(jsonEncode(result));
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_KILAKILA_APP_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
