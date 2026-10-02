// Opt-in production SSR metadata, not native playback/recording acceptance.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/xiaohongshu/xiaohongshu_api.dart';

void main() {
  test(
    'Xiaohongshu public share production room binding',
    () async {
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'route': 'DIRECT',
        'contract': 'failed',
        'mediaValidated': false,
        'http': <Map<String, Object?>>[],
        'rooms': <Map<String, Object?>>[],
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
                'status': response.statusCode,
                'redirectsDisabled': !response.requestOptions.followRedirects,
                'refererMatches': response.requestOptions.headers['Referer'] == '${XiaohongshuApi.origin}/',
              });
              handler.next(response);
            },
          ),
        );
        HttpClient.instance.dio = dio;
        try {
          final api = XiaohongshuApi();
          for (final id in ['570305058583373361', '570429070963278308']) {
            final room = await api.room(id);
            expect(room.requestedRoomId, id);
            if (room.reportedLive == true) expect(room.responseRoomId, id);
            if (room.reportedLive != true) expect(room.streams, isEmpty);
            (report['rooms'] as List).add({
              'responseIdentityMatches': room.responseRoomId == id,
              'responseIdentityPresent': room.responseRoomId != null,
              'reportedStatus': room.reportedStatus,
              'reportedLive': room.reportedLive,
              'access': room.access.name,
              'declaredSources': room.streams.length,
              'qualities': room.streams.map((s) => '${s.codec}:${s.quality}').toSet().toList(),
            });
          }
          for (final row in report['http'] as List<Map<String, Object?>>) {
            expect(row['redirectsDisabled'], true);
            expect(row['refererMatches'], true);
          }
          report['contract'] = 'passed';
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
          final output = io.Platform.environment['PURELIVE_XHS_OUTPUT'];
          if (output != null) {
            await io.File(output).writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');
          }
          // ignore: avoid_print
          print(jsonEncode(report));
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_XHS_SHARE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
