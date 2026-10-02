// Opt-in real HTTP requests using the production Picarto adapter and Dio
// request implementation. No account cookies or media segments are fetched.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/domain/live_site.dart';
import 'package:pure_live/domains/live/data/platforms/picarto/picarto_api.dart';
import 'package:pure_live/domains/live/data/platforms/picarto/picarto_site.dart';
import 'package:pure_live/domains/recorder/data/services/stream_resolver_service.dart';

void main() {
  test(
    'Picarto production directory, playback, recorder and fresh recovery contracts',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final proxy = Uri.parse(io.Platform.environment['PURELIVE_PROBE_PROXY']!);
        final previous = HttpClient.instance.dio;
        final dio =
            Dio(BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)))
              ..httpClientAdapter = IOHttpClientAdapter(
                createHttpClient: () => io.HttpClient()..findProxy = (_) => 'PROXY ${proxy.host}:${proxy.port}',
              );
        HttpClient.instance.dio = dio;
        try {
          final site = PicartoSite();
          final rooms = await site.getRecommendRooms(pageSize: 10);
          expect(rooms, isNotEmpty);
          final room = await site.getRoomDetailForRecording(roomId: rooms.first.roomId!, platform: 'picarto');
          expect(room.isPlayableNow, isTrue);
          final qualities = await site.getPlayQualites(detail: room);
          expect(qualities, isNotEmpty);
          final urls = await site.getPlayUrls(detail: room, quality: qualities.first);
          final child = await PicartoApi().read(Uri.parse(urls.first));
          expect(child.trimLeft(), startsWith('#EXTM3U'));
          expect(child, contains('#EXTINF:'));
          final recovered = await site.resolvePlayUrlsForRecovery(detail: room, quality: qualities.first);
          expect(recovered.urls, isNotEmpty);
          expect(recovered.appliedQualityData, qualities.first.selectionId);
          final recorded = await StreamResolverService(siteResolver: (_) => site)
              .resolveStream(roomId: room.roomId!, platform: 'picarto', preferredQuality: 'best');
          expect(Uri.parse(recorded.url).scheme, 'https');
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'probe': 'picarto-production-contract',
            'directoryCount': rooms.length,
            'qualityCount': qualities.length,
            'qualityLabels': qualities.map((q) => q.quality).toList(),
            'mediaPlaylist': true,
            'mediaPlaylistBytes': utf8.encode(child).length,
            'recorderInputResolved': true,
            'freshRecoveryResolved': true,
            'proxyConfigured': true,
            'mediaSegmentsFetched': false,
            'evidenceLayer': 'adapter-and-http-not-native-playback-or-recording',
          };
          final output = io.Platform.environment['PURELIVE_PICARTO_PROBE_OUTPUT'];
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
    skip: io.Platform.environment['PURELIVE_PICARTO_LIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
