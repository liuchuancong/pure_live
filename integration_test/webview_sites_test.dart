// End-to-end check of the sites whose resolvers need a real WebView (WebView2
// on Windows, Android System WebView on phones). Needs network access; foreign
// sites need a proxy or TUN from mainland China:
//   flutter test integration_test/webview_sites_test.dart --device-id=windows
//     [--dart-define=PURELIVE_TEST_PROXY=127.0.0.1:7897]
// PURELIVE_TEST_PROXY enables the app proxy, as a user in China would; the
// WebView leg follows the system proxy on Windows either way.
// Use the long flag: through tool/flutterw.ps1, PowerShell binds `-d` to its own
// -Debug switch, and flutter then installs, runs and UNINSTALLS the app on any
// connected Android device instead.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pure_live/common/services/settings_service.dart';
import 'package:pure_live/common/utils/hive_pref_util.dart';
import 'package:pure_live/core/interface/live_site.dart';
import 'package:pure_live/core/site/dailymotion/dailymotion_site.dart';
import 'package:pure_live/core/site/nimotv/nimotv_site.dart';
import 'package:pure_live/core/site/rumble/rumble_site.dart';
import 'package:pure_live/core/site/shopeelive/shopeelive_site.dart';
import 'package:pure_live/get/get.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // The shared HTTP client reads the proxy settings. An in-memory box keeps
  // the user's real settings untouched; the system proxy / TUN still applies.
  setUpAll(() async {
    await Hive.openBox<dynamic>('app_settings', bytes: Uint8List(0));
    await HivePrefUtil.init();
    final settings = Get.put(SettingsService(), permanent: true);
    const proxy = String.fromEnvironment('PURELIVE_TEST_PROXY');
    final separator = proxy.lastIndexOf(':');
    if (separator > 0) {
      settings.proxy.appProxyHost.value = proxy.substring(0, separator);
      settings.proxy.appProxyPort.value = int.parse(proxy.substring(separator + 1));
      settings.proxy.enableAppProxy.value = true;
    }
  });
  tearDownAll(Hive.close);

  final sites = <String, LiveSite Function()>{
    'shopeelive': ShopeeLiveSite.new,
    'nimotv': NimoTvSite.new,
    'dailymotion': DailymotionSite.new,
    'rumble': RumbleSite.new,
  };

  for (final entry in sites.entries) {
    testWidgets('${entry.key}: directory, room detail and play URLs resolve', (tester) async {
      await tester.runAsync(() async {
        final site = entry.value();
        final rooms = await site.getRecommendRooms().timeout(const Duration(seconds: 90));
        expect(rooms, isNotEmpty, reason: 'empty directory');
        Object? lastError;
        for (final card in rooms.take(3)) {
          try {
            final detail = await site
                .getRoomDetail(roomId: card.roomId!, platform: entry.key)
                .timeout(const Duration(seconds: 90));
            final qualities = await site.getPlayQualites(detail: detail).timeout(const Duration(seconds: 60));
            expect(qualities, isNotEmpty);
            final urls = await site
                .getPlayUrls(detail: detail, quality: qualities.first)
                .timeout(const Duration(seconds: 60));
            expect(urls, isNotEmpty);
            // ignore: avoid_print
            print('${entry.key} ${card.roomId} ${qualities.first.quality} ${Uri.parse(urls.first).host}');
            return;
          } catch (error) {
            lastError = error;
            // ignore: avoid_print
            print('${entry.key} ${card.roomId} failed: $error');
          }
        }
        fail('no room resolved: $lastError');
      });
    }, timeout: const Timeout(Duration(minutes: 8)));
  }
}
