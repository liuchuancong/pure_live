// Opt-in metadata contract only. No registration, credentials or media read.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/weibo/weibo_api.dart';
import 'package:pure_live/core/site/weibo/weibo_site.dart';

void main() {
  test(
    'Weibo production directory and detail correlate broadcast and owner',
    () async {
      final output = io.Platform.environment['PURELIVE_WEIBO_OUTPUT'];
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'route': 'DIRECT',
        'contract': 'failed',
        'stage': 'directory',
        'mediaValidated': false,
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
                'method': response.requestOptions.method,
                'kind': response.requestOptions.uri.path.contains('pc_recommend') ? 'directory' : 'detail',
                'status': response.statusCode,
              });
              handler.next(response);
            },
          ),
        );
        HttpClient.instance.dio = dio;
        try {
          final api = WeiboApi();
          final cards = await api.directory();
          report['directoryCards'] = cards.length;
          expect(cards, isNotEmpty);
          final selected = cards.first;
          report['stage'] = 'snapshot-search';
          final matches = await WeiboSite(api: api).searchRooms(selected.nickname);
          expect(matches.any((room) => room.roomId == selected.liveId), isTrue);
          expect(matches.every((room) => room.liveStatus == LiveStatus.unknown), isTrue);
          report['nicknameSnapshotMatches'] = matches.length;
          report['nicknameTargetPresent'] = true;
          report['stage'] = 'detail';
          final status = await api.detail(selected.liveId, expectedOwnerId: selected.ownerId);
          expect(status.ownerId == selected.ownerId, isTrue);
          if (status.access != WeiboAccess.public) {
            expect(status.state, WeiboBroadcastState.unknown);
            expect(status.mediaUrls, isEmpty);
          }
          report.addAll({
            'contract': 'passed',
            'stage': 'complete',
            'ownerMatch': true,
            'access': status.access.name,
            'state': status.state.name,
            'reportedStatus': status.reportedStatus,
            'broadcastMatch': status.liveId == selected.liveId,
            'declaredMediaCount': status.mediaUrls.length,
          });
        } on WeiboException catch (error) {
          report['failure'] = error.kind.name;
          rethrow;
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
          if (output != null) {
            await io.File(output).writeAsString('${const JsonEncoder.withIndent('  ').convert(report)}\n');
          }
          // ignore: avoid_print
          print(jsonEncode(report));
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_WEIBO_METADATA_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
