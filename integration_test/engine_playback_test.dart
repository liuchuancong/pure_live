// Plays a real live stream through a player engine on a real runner:
//   flutter test integration_test/engine_playback_test.dart --device-id=windows
//     [--dart-define=PURELIVE_TEST_ENGINE=fvp|libmpv]   (default libmpv)
// fvp is bundled on Android/iOS only; run it there with -d <device>.
// fvp runs FvpAdapter. libmpv drives media_kit's Player without a
// VideoController (mpv still demuxes and decodes) to check the bundled
// libmpv: MediaKitAdapter's VideoController needs pumped frames, which this
// runAsync-only harness does not provide.
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
import 'package:media_kit/media_kit.dart';
import 'package:pure_live/player/adapters/fvp_adapter.dart';
import 'package:pure_live/player/core/playback_header_resolver.dart';
import 'package:pure_live/player/core/playback_proxy_policy.dart';

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

  const engineName = String.fromEnvironment('PURELIVE_TEST_ENGINE', defaultValue: 'libmpv');
  const sites = String.fromEnvironment('PURELIVE_FVP_SITES', defaultValue: 'bilibili,douyu,huya');
  for (final id in sites.split(',')) {
    testWidgets('$engineName plays a live $id room with video', (tester) async {
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
          if (qualities.isEmpty) continue;
          final LivePlayUrlResolution resolution;
          try {
            resolution = await site.resolvePlayUrls(detail: detail, quality: qualities.last);
          } catch (_) {
            continue; // went offline between detail and play URL
          }
          if (resolution.urls.isEmpty) continue;
          url = resolution.urls.first;
          headers = await PlaybackHeaderResolver.resolve(platform: id, roomId: card.roomId!);
          return;
        }
        fail('no live $id room');
      });

      final sizes = <int>[];
      var playing = false;
      final errors = <String>[];
      var codec = '';
      late Future<void> Function() dispose;
      Future<void> Function()? poll;
      await tester.runAsync(() async {
        if (engineName == 'libmpv') {
          MediaKit.ensureInitialized();
          final player = Player();
          final native = player.platform as NativePlayer;
          // media_kit starts with vid=no until a VideoController attaches.
          await native.setProperty('vo', 'null');
          await native.setProperty('vid', 'auto');
          await native.setProperty('http-proxy', PlaybackProxyPolicy.currentNativeUrl(privateInput: false));
          // Without a VideoController media_kit publishes no size; read the
          // decoder's output parameters instead.
          poll = () async {
            final w = int.tryParse(await native.getProperty('video-params/w'));
            if (w != null && w > 0) sizes.add(w);
            codec = await native.getProperty('current-tracks/video/codec');
          };
          player.stream.playing.listen((p) => playing = playing || p);
          player.stream.error.listen(errors.add);
          await player.open(Media(url, httpHeaders: headers));
          dispose = player.dispose;
        } else {
          final adapter = FvpAdapter();
          await adapter.init();
          adapter.width.listen((w) => w == null ? null : sizes.add(w));
          adapter.onPlaying.listen((p) => playing = playing || p);
          adapter.onError.listen((e) => errors.add(e.message));
          await adapter.setDataSource(url, [url], headers);
          dispose = adapter.hardDispose;
        }
      });
      await tester.runAsync(() async {
        for (var i = 0; i < 60 && !(playing && sizes.isNotEmpty); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          await poll?.call();
        }
      });
      // ignore: avoid_print
      print('$engineName $id playing=$playing width=${sizes.isEmpty ? null : sizes.last} codec=$codec errors=$errors');
      expect(errors, isEmpty);
      expect(playing, isTrue);
      expect(sizes.last, greaterThan(0));
      await tester.runAsync(dispose);
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}
