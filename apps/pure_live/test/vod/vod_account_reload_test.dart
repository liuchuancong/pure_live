import 'dart:convert' show jsonEncode, utf8;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_net/live_net.dart' show LiveHttp, LiveRequest, LiveResponse, LiveStreamedResponse;
import 'package:live_platform/live_platform.dart'
    show DesktopDistribution, FormFactor, PlatformBootstrap, PlatformRuntime;
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show BilibiliVodClient;
import 'package:pure_live/app/app.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.dart';
import 'package:pure_live/modules/vod/controller/vod_controller.dart';
import 'package:pure_live/modules/vod/controller/vod_pgc.dart' show vodPgcProvider;
import 'package:pure_live/modules/vod/pages/vod_pgc_page.dart';
import 'package:pure_live/modules/vod/pages/vod_regions_page.dart';

void main() {
  late PlatformRuntime runtime;
  late StorageStores stores;

  setUpAll(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    runtime = PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
  });

  tearDownAll(() => stores.close());

  testWidgets('the open region asks again after an account change', (tester) async {
    final http = _AccountHttp();
    final container = _container(http, runtime);
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container, const VodRegionsPage()));
    await tester.pumpAndSettle();
    expect(http.regionCalls, 1);

    _changeAccount(container, http);
    await tester.pumpAndSettle();

    expect(http.regionCalls, 2);
    expect(container.read(vodFeedProvider.notifier).feedOf('region:1008').videos.single.id, 'BV_new');
  });

  testWidgets('the open cinema catalogue asks again after an account change', (tester) async {
    final http = _AccountHttp();
    final container = _container(http, runtime);
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container, const VodPgcPage()));
    await tester.pumpAndSettle();
    expect(http.pgcCalls, 1);

    _changeAccount(container, http);
    await tester.pumpAndSettle();

    expect(http.pgcCalls, 2);
    expect(container.read(vodPgcProvider)[1]?.seasons.single.seasonId, 2);
  });
}

ProviderContainer _container(_AccountHttp http, PlatformRuntime runtime) => ProviderContainer(
  overrides: [
    platformRuntimeProvider.overrideWithValue(runtime),
    vodClientProvider.overrideWithValue(BilibiliVodClient(http, cookie: 'SESSDATA=old')),
  ],
);

void _changeAccount(ProviderContainer container, _AccountHttp http) {
  container.updateOverrides([
    platformRuntimeProvider.overrideWithValue(container.read(platformRuntimeProvider)),
    vodClientProvider.overrideWithValue(BilibiliVodClient(http, cookie: 'SESSDATA=new')),
  ]);
}

Widget _host(ProviderContainer container, Widget page) => UncontrolledProviderScope(
  container: container,
  child: TranslationProvider(
    child: DsScope(
      child: MaterialApp(
        home: Scaffold(body: SizedBox(width: 1000, height: 700, child: page)),
      ),
    ),
  ),
);

final class _AccountHttp implements LiveHttp {
  int regionCalls = 0;
  int pgcCalls = 0;

  @override
  Future<LiveResponse> send(LiveRequest request) async {
    final Object body;
    if (request.url.path.contains('region/feed/rcmd')) {
      regionCalls += 1;
      body = {
        'code': 0,
        'data': {
          'archives': [
            {'bvid': regionCalls == 1 ? 'BV_old' : 'BV_new', 'title': '分区视频'},
          ],
        },
      };
    } else if (request.url.path.contains('pgc/page/web')) {
      pgcCalls += 1;
      body = {
        'code': 0,
        'data': {
          'items': [
            {'season_id': pgcCalls, 'season_title': '影视 $pgcCalls'},
          ],
          'coursor': pgcCalls * 12,
          'has_next': false,
        },
      };
    } else {
      throw StateError('no answer for ${request.url.path}');
    }
    return LiveResponse(statusCode: 200, headers: const {}, bodyBytes: utf8.encode(jsonEncode(body)));
  }

  @override
  Future<LiveStreamedResponse> open(LiveRequest request) => throw UnimplementedError();

  @override
  void close() {}
}
