// Opt-in metadata contract only. No registration, credentials or media read.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/bigo/bigo_api.dart';

void main() {
  test(
    'Bigo production directory and studio preserve access-gated unknown status',
    () async {
      final output = io.Platform.environment['PURELIVE_BIGO_OUTPUT'];
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'route': 'PROXY 127.0.0.1:7897',
        'contract': 'failed',
        'stage': 'directory',
        'mediaValidated': false,
        'http': <Map<String, Object?>>[],
      };
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)))
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: () => io.HttpClient()..findProxy = (_) => 'PROXY 127.0.0.1:7897',
          );
        dio.interceptors.add(
          InterceptorsWrapper(
            onResponse: (response, handler) {
              (report['http'] as List).add({
                'method': response.requestOptions.method,
                'kind': response.requestOptions.uri.path.endsWith('/72') ? 'directory' : 'studio',
                'status': response.statusCode,
              });
              handler.next(response);
            },
          ),
        );
        HttpClient.instance.dio = dio;
        try {
          final api = BigoApi();
          final cards = await api.directory();
          report['directoryCards'] = cards.length;
          expect(cards, isNotEmpty);
          final selected = cards.firstWhere((card) => !card.locked);
          report['stage'] = 'studio';
          final status = await api.studioStatus(siteId: selected.siteId, expectedOwnerId: selected.ownerId);
          expect(status.ownerId == selected.ownerId, isTrue);
          if (status.access != BigoAccess.public) {
            expect(status.reportedAlive, isNull);
          }
          report.addAll({
            'contract': 'passed',
            'stage': 'complete',
            'ownerMatch': true,
            'access': status.access.name,
            'reportedAlive': status.reportedAlive,
            'roomStatus': status.roomStatus,
            'roomType': status.roomType,
            'requestedAndCanonicalAliasDiffer': status.requestedSiteId != status.canonicalSiteId,
          });
        } on BigoException catch (error) {
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
    skip: io.Platform.environment['PURELIVE_BIGO_METADATA_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
