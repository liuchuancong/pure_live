import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_area.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/cc/cc_site.dart';

void main() {
  test(
    'CC production category reader uses current public paginated feeds',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        final offsets = <Object?>[];
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.uri.host, 'cc.163.com');
              expect(options.uri.path, startsWith('/api/category/'));
              offsets.add(options.queryParameters['start']);
              handler.next(options);
            },
          ),
        );
        HttpClient.instance.dio = dio;
        try {
          final site = CCSite();
          final results = <Map<String, Object?>>[];
          var total = 0;
          for (final id in ['3', '1005']) {
            final area = LiveArea(platform: 'cc', areaId: id, areaType: '2');
            final first = await site.getCategoryRooms(area, page: 1, pageSize: 2);
            final second = await site.getCategoryRooms(area, page: 2, pageSize: 2);
            final rows = [...first, ...second];
            total += rows.length;
            expect(rows.every((r) => r.platform == 'cc' && r.roomId?.isNotEmpty == true && r.data == null), isTrue);
            results.add({
              'category': id,
              'firstRows': first.length,
              'secondRows': second.length,
              'validMetadataOnly': true,
            });
          }
          expect(offsets, [0, 2, 0, 2]);
          expect(total, greaterThan(0), reason: 'At least one current public live sample is required');
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'pages': results,
            'offsets': offsets,
            'routing': 'anonymous direct Dio; app proxy settings not exercised',
            'taxonomyMigrationComplete': false,
            'mediaFetched': false,
            'nativeVerified': false,
          };
          final output = io.Platform.environment['PURELIVE_CC_CATEGORY_PROBE_OUTPUT'];
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
    skip: io.Platform.environment['PURELIVE_CC_CATEGORY_LIVE_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
