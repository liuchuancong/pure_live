// Opt-in real watch-page HTTP path; never starts a websocket or reads media.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/niconico/niconico_api.dart';

void main() {
  test(
    'Niconico production HTTP preserves program identity and access status',
    () async {
      final id = io.Platform.environment['PURELIVE_NICONICO_PROGRAM']!;
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'route': 'PROXY 127.0.0.1:7897',
        'result': 'failed',
        'mediaValidated': false,
      };
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => io.HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:7897',
          );
        dio.interceptors.add(
          InterceptorsWrapper(
            onResponse: (response, handler) {
              report['httpStatus'] = response.statusCode;
              handler.next(response);
            },
          ),
        );
        HttpClient.instance.dio = dio;
        try {
          final result = await NiconicoApi().room(id);
          expect(result.programId, id);
          report.addAll({
            'result': 'passed',
            'identityMatch': true,
            'status': result.status.name,
            'access': result.access.name,
            'socketHost': result.webSocketUri?.host,
          });
        } finally {
          HttpClient.instance.dio = previous;
          dio.close(force: true);
          final output = io.Platform.environment['PURELIVE_NICONICO_OUTPUT'];
          if (output != null) await io.File(output).writeAsString(jsonEncode(report));
          // ignore: avoid_print
          print(jsonEncode(report));
        }
      }, _RealNetwork());
    },
    skip: io.Platform.environment['PURELIVE_NICONICO_METADATA_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 1)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
