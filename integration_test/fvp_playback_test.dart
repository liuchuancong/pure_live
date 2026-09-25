// Plays a real live stream through FvpAdapter (libmdk) on a real runner:
//   flutter test integration_test/fvp_playback_test.dart --device-id=windows
//     [--dart-define=PURELIVE_FVP_SITES=shopeelive,17live]
//     [--dart-define=PURELIVE_TEST_PROXY=127.0.0.1:7897]
// PURELIVE_TEST_PROXY sets the app and playback proxy, as a user in China
// would. Use the long device flag (see webview_sites_test.dart).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/sites.dart';
import 'package:pure_live/get/get.dart';
import 'package:pure_live/player/adapters/fvp_adapter.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    final settings = Get.put(SettingsService(), permanent: true);
    const proxy = String.fromEnvironment('PURELIVE_TEST_PROXY');
    final separator = proxy.lastIndexOf(':');
    if (separator > 0) {
      final host = proxy.substring(0, separator);
      final port = int.parse(proxy.substring(separator + 1));
      settings.proxy
        ..appProxyHost.value = host
        ..appProxyPort.value = port
        ..enableAppProxy.value = true
        ..proxyHost.value = host
        ..proxyPort.value = port
        ..enableProxy.value = true;
    }
  });
  tearDownAll(Hive.close);

  const sites = String.fromEnvironment('PURELIVE_FVP_SITES', defaultValue: 'bilibili,douyu,huya');
  for (final id in sites.split(',')) {
    testWidgets('fvp plays a live $id room with video', (tester) async {
      final site = Sites.of(id).liveSite;
      late String url;
      late Map<String, String> headers;
      await tester.runAsync(() async {
        final rooms = await site.getRecommendRooms(page: 1, pageSize: 10);
        for (final card in rooms) {
          if (card.liveStatus == LiveStatus.offline) continue;
          final detail = await site.getRoomDetail(roomId: card.roomId!, platform: id);
          if (detail.liveStatus != LiveStatus.live) continue;
          final qualities = await site.getPlayQualites(detail: detail);
          final resolution = await site.resolvePlayUrls(detail: detail, quality: qualities.last);
          if (resolution.urls.isEmpty) continue;
          url = resolution.urls.first;
          headers = await PlaybackHeaderResolver.resolve(platform: id, roomId: card.roomId!);
          return;
        }
        fail('no live $id room');
      });

      final adapter = FvpAdapter();
      final sizes = <int>[];
      var playing = false;
      final errors = <String>[];
      await tester.runAsync(() async {
        await adapter.init();
        adapter.width.listen((w) => w == null ? null : sizes.add(w));
        adapter.onPlaying.listen((p) => playing = playing || p);
        adapter.onError.listen((e) => errors.add(e.message));
        await adapter.setDataSource(url, [url], headers);
      });
      await tester.runAsync(() async {
        for (var i = 0; i < 60 && !(playing && sizes.isNotEmpty); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      });
      // ignore: avoid_print
      print('fvp $id playing=$playing width=${sizes.isEmpty ? null : sizes.last} errors=$errors');
      expect(errors, isEmpty);
      expect(playing, isTrue);
      expect(sizes.last, greaterThan(0));
      await tester.runAsync(adapter.hardDispose);
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
