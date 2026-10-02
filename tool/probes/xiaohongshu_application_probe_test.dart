// Opt-in registered adapter + recorder resolution + bounded HLS read.
// This is not native playback, GUI acceptance or an actual recording.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/domain/live_site.dart';
import 'package:pure_live/domains/live/data/platforms/xiaohongshu/xiaohongshu_api.dart';
import 'package:pure_live/domains/live/data/platforms/xiaohongshu/xiaohongshu_site.dart';
import 'package:pure_live/domains/live/data/platforms/sites.dart';
import 'package:pure_live/domains/live/data/playback_header_resolver.dart';
import 'package:pure_live/domains/recorder/data/services/stream_resolver_service.dart';

void main() {
  test(
    'Xiaohongshu registered playback and recording source contract',
    () async {
      const id = '570429070963278308';
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'route': 'DIRECT',
        'contract': 'failed',
        'stage': 'detail',
        'nativePlayback': false,
        'nativeRecording': false,
        'http': <Map<String, Object?>>[],
      };
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => io.HttpClient()..findProxy = (_) => 'DIRECT',
          );
        dio.interceptors.add(
          InterceptorsWrapper(
            onResponse: (response, handler) {
              (report['http'] as List).add({
                'kind': response.requestOptions.uri.host == 'www.xiaohongshu.com' ? 'room' : 'media',
                'status': response.statusCode,
                'redirectsDisabled': !response.requestOptions.followRedirects,
              });
              handler.next(response);
            },
          ),
        );
        HttpClient.instance.dio = dio;
        try {
          final site = Sites.of('xiaohongshu').liveSite;
          expect(site, isA<XiaohongshuSite>());
          final room = await site.getRoomDetail(roomId: id, platform: 'xiaohongshu');
          expect(room.roomId, id);
          expect(room.isLiveNow, true);
          final qualities = await site.getPlayQualites(detail: room);
          expect(qualities, isNotEmpty);
          final quality = qualities.first;
          final play = await site.resolvePlayUrls(detail: room, quality: quality);
          expect(play.urls, isNotEmpty);
          report.addAll({
            'stage': 'recording-source',
            'qualities': qualities.map((q) => q.selectionId.toString()).toList(),
            'playbackSources': play.urls.length,
          });
          final record = await StreamResolverService(siteResolver: (_) => site)
              .resolveStream(roomId: id, platform: 'xiaohongshu', preferredQuality: quality.quality);
          expect(record.quality.selectionId, quality.selectionId);
          expect(Uri.parse(record.url).path, '/live/$id.m3u8');
          final headers = await PlaybackHeaderResolver.resolve(platform: 'xiaohongshu', roomId: id);
          report['stage'] = 'hls';
          final response = await dio.get<ResponseBody>(
            record.url,
            options: Options(
              responseType: ResponseType.stream,
              followRedirects: false,
              headers: headers,
              validateStatus: (_) => true,
            ),
          );
          final body = response.data!;
          if (response.statusCode != 200) {
            await body.stream.listen((_) {}).cancel();
            fail('HLS HTTP ${response.statusCode}');
          }
          final text = await XiaohongshuApi.readBody(body.stream);
          expect(text.trimLeft(), startsWith('#EXTM3U'));
          expect(text, contains('#EXTINF:'));
          expect(text, contains('$id-'));
          report.addAll({
            'contract': 'passed',
            'stage': 'complete',
            'recordingSources': record.candidateUrls.length,
            'recordingQuality': record.qualityCursorId,
            'hlsBytes': utf8.encode(text).length,
            'segments': const LineSplitter().convert(text).where((s) => s.isNotEmpty && !s.startsWith('#')).length,
            'endList': text.contains('#EXT-X-ENDLIST'),
            'headersMatch': headers['referer'] == 'https://www.xiaohongshu.com/',
          });
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
          final output = io.Platform.environment['PURELIVE_XHS_APP_OUTPUT'];
          if (output != null) {
            await io.File(output).writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');
          }
          // ignore: avoid_print
          print(jsonEncode(report));
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_XHS_APP_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
