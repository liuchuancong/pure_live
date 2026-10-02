import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/kilakila/kilakila_api.dart';
import 'package:pure_live/domains/live/data/platforms/kilakila/kilakila_link.dart';

void main() {
  test(
    'official current room redirect resolves a signed link and owner',
    () async {
      await io.HttpOverrides.runWithHttpOverrides(() async {
        final previous = HttpClient.instance.dio;
        final dio = Dio(
          BaseOptions(connectTimeout: const Duration(seconds: 15), receiveTimeout: const Duration(seconds: 20)),
        )..httpClientAdapter = IOHttpClientAdapter(createHttpClient: () => io.HttpClient());
        HttpClient.instance.dio = dio;
        try {
          final api = KilakilaApi();
          final page = await api.directory();
          final sample = page.rooms.firstWhere((r) => r.isLive && r.goldPrice == 0);
          final response = await dio.get<String>(
            sample.link,
            options: Options(
              responseType: ResponseType.plain,
              followRedirects: false,
              validateStatus: (s) => s != null && s >= 200 && s < 400,
            ),
          );
          expect(response.statusCode, inInclusiveRange(300, 399));
          final location = response.headers.value('location');
          expect(location, isNotNull);
          final target = Uri.parse(sample.link).resolve(location!);
          expect(target.host, 'live.kilakila.cn');
          expect(target.queryParameters.containsKey('_specific_parameter'), isTrue);
          final parsed = KilakilaLink.parse(target.toString());
          expect(parsed?.kind, KilakilaLinkKind.broadcast);
          expect(parsed?.id, sample.roomId);
          final owner = await api.ownerFromLink(target.toString());
          expect(owner.userId, sample.userId);
          final direct = await api.ownerFromLink('${KilakilaApi.ownerOrigin}/index/roomuser/uid/${sample.userId}');
          expect(direct.userId, owner.userId);
          final result = {
            'utc': DateTime.now().toUtc().toIso8601String(),
            'redirectStatus': response.statusCode,
            'officialSignedLinkMatchedBroadcast': true,
            'broadcastResolvedToOwner': true,
            'directOwnerLinkMatched': true,
            'ownerAdvertisesSameBroadcast': owner.currentRoom?.roomId == sample.roomId,
            'mediaFetched': false,
            'nativePlaybackOrRecording': false,
            'routing': 'anonymous direct Dio; application proxy not exercised',
          };
          final path = io.Platform.environment['PURELIVE_KILAKILA_LINK_OUTPUT'];
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
    skip: io.Platform.environment['PURELIVE_KILAKILA_LINK_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

class _RealNetwork extends io.HttpOverrides {}
