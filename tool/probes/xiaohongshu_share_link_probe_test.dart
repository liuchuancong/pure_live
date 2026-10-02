// Opt-in public redirect + room identity probe. No media or phone operations.
import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/domains/live/data/link/live_url_tool.dart';
import 'package:pure_live/core/network/http_client.dart';
import 'package:pure_live/domains/live/data/platforms/xiaohongshu/xiaohongshu_api.dart';
import 'package:pure_live/domains/live/data/platforms/xiaohongshu/xiaohongshu_link.dart';
import 'package:pure_live/domains/live/data/platforms/xiaohongshu/xiaohongshu_share.dart';
import 'package:pure_live/domains/live/data/platforms/xiaohongshu/xiaohongshu_site.dart';

void main() {
  test(
    'public XHS shares resolve only their advertised broadcast identity',
    () async {
      final report = <String, Object?>{
        'utc': DateTime.now().toUtc().toIso8601String(),
        'status': 'failed',
        'scope': 'public-share-identity-not-media-gui-or-android',
        'http': <Map<String, Object?>>[],
        'rooms': <Map<String, Object?>>[],
      };
      await io.HttpOverrides.runWithHttpOverrides(() async {
        Dio create() {
          final dio = Dio()
            ..httpClientAdapter = IOHttpClientAdapter(
              createHttpClient: () => io.HttpClient()..findProxy = (_) => 'DIRECT',
            );
          dio.interceptors.add(
            InterceptorsWrapper(
              onResponse: (response, handler) {
                final target = _liveShortLocation(response.headers.value('location'));
                (report['http'] as List).add({
                  'host': response.requestOptions.uri.host,
                  'path': response.requestOptions.uri.path,
                  'status': response.statusCode,
                  'redirectsDisabled': !response.requestOptions.followRedirects,
                  'locationHost': target?.host,
                  'locationPath': target?.path,
                });
                handler.next(response);
              },
            ),
          );
          return dio;
        }

        final previous = HttpClient.instance.dio;
        final metadata = create();
        HttpClient.instance.dio = metadata;
        try {
          for (final (short, id) in [
            ('https://xhslink.com/m/4vYwu2cQpeP', '570341209400361612'),
            ('https://xhslink.com/m/4cmsziquNGq', '570364455107805790'),
          ]) {
            expect(await LiveUrlTool.parseLiveUrl(short, clientFactory: create), [id, 'xiaohongshu']);
            final room = await XiaohongshuApi().room(id);
            expect(room.requestedRoomId, id);
            expect(room.reportedLive, false);
            expect(room.streams, isEmpty);
            (report['rooms'] as List).add({
              'roomId': id,
              'reportedLive': room.reportedLive,
              'mediaSources': room.streams.length,
            });
          }
          // Expired short redirects to the home page; profile shares are not rooms.
          for (final short in ['https://xhslink.com/zfknEQ', 'https://xhslink.com/m/3ZSCJZAMz0a']) {
            expect(await LiveUrlTool.parseLiveUrl(short, clientFactory: create), isEmpty);
          }
          final found = await XiaohongshuSite(shortLinkClientFactory: create)
              .searchRooms('https://xhslink.com/m/4vYwu2cQpeP');
          expect(found.single.roomId, '570341209400361612');
          expect(found.single.isExplicitlyOfflineNow, true);
          expect(found.single.data, isNull);
          // Compare the actual previously captured dynamic and canonical pages:
          // their recommended live room must not replace the ended target.
          final input = io.Platform.environment['PURELIVE_XHS_LINK_CAPTURE']!;
          for (final name in ['dynamic', 'canonical']) {
            final room = XiaohongshuShare.parsePage(
              await io.File('$input/$name.body').readAsString(),
              roomId: '570341209400361612',
            );
            expect(room.reportedLive, false);
            expect(room.streams, isEmpty);
            expect(room.requestedRoomId, '570341209400361612');
          }
          final requests = (report['http'] as List).cast<Map>();
          expect(requests.where((r) => r['host'] == 'xhslink.com'), hasLength(5));
          expect(requests.where((r) => r['host'] == 'www.xiaohongshu.com'), hasLength(3));
          expect(requests.every((r) => r['redirectsDisabled'] == true), true);
          for (final r in requests.where((r) => r['host'] == 'www.xiaohongshu.com')) {
            expect(XiaohongshuLink.parse('https://www.xiaohongshu.com${r['path']}'), isNotNull);
          }
          report['status'] = 'passed';
        } finally {
          HttpClient.instance.dio = previous;
          metadata.close(force: true);
          await io.File(io.Platform.environment['PURELIVE_XHS_LINK_REPORT']!).writeAsString(jsonEncode(report));
        }
      }, _Network());
    },
    skip: io.Platform.environment['PURELIVE_XHS_LINK_PROBE'] != '1',
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Uri? _liveShortLocation(String? value) => value == null ? null : Uri.tryParse(value);

class _Network extends io.HttpOverrides {}
