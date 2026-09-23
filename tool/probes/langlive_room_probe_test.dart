// Opt-in, read-only verification of the current public Lang Live room contract.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/common/http_client.dart';
import 'package:pure_live/core/site/langlive/langlive_api.dart';

void main() {
  test(
    'Lang Live public room identity and state parse through the production adapter',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => io.HttpClient()..findProxy = (_) => 'DIRECT',
          );
        HttpClient.instance.dio = dio;
        try {
          final report = <String, Object?>{
            'utc': DateTime.now().toUtc().toIso8601String(),
            'route': 'DIRECT',
            'mediaPrefixValidated': false,
            'playbackOrRecording': false,
          };
          try {
            final room = await LangLiveApi().room('5461380');
            expect(room.roomId, '5461380');
            if (room.state != LangLiveState.live) expect(room.media, isEmpty);
            report.addAll({
              'contract': 'passed',
              'roomIdentityMatches': true,
              'reportedState': room.state.name,
              'declaredMediaCount': room.media.length,
            });
          } on LangLiveException catch (error) {
            if (error.kind != LangLiveFailure.access) rethrow;
            report.addAll({'contract': 'edge_access_blocked', 'failure': error.kind.name});
          }
          // ignore: avoid_print
          print(jsonEncode(report));
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_LANGLIVE_ROOM_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
