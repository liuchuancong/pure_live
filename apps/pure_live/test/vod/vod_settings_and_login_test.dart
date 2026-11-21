import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:live_vod/live_vod.dart' show TvLoginResult;
import 'package:pure_live/modules/vod/controller/vod_app_login.dart';
import 'package:pure_live/modules/vod/controller/vod_settings.dart';

/// The station's own preferences: the starting quality a video opens with
/// (a request, not a promise — an unknown stored number is the default),
/// and the app interface's sign-in, held for as long as both halves exist
/// and forgotten whole.
void main() {
  group('the starting quality', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    test('the store starts at 1080P, and a choice lands and survives a re-read', () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      expect(first.read(vodQualityProvider), VodQualityChoice.p1080); // the signed-in default

      first.read(vodQualityProvider.notifier).select(VodQualityChoice.p4k);
      await pumpEventQueue(); // the write is fire-and-forget; let it land
      expect(first.read(vodQualityProvider), VodQualityChoice.p4k);

      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(second.read(vodQualityProvider), VodQualityChoice.p4k); // the store's answer, read back
    });

    test('choosing the current quality is a no-op', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final before = container.read(vodQualityProvider);
      container.read(vodQualityProvider.notifier).select(before);
      expect(identical(container.read(vodQualityProvider), before), isTrue);
    });

    test('a stored number no tier names falls back to the default', () async {
      await StoragePrefs.setInt('vod.quality.qn', 999);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(vodQualityProvider), VodQualityChoice.p1080);
    });
  });

  group('the app sign-in', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    TvLoginResult login({int mid = 42}) =>
        TvLoginResult(mid: mid, accessToken: 'token-1', refreshToken: 'refresh-1', expiresIn: 86400);

    test('an empty store signs nobody in, a confirmed scan holds, and clear forgets whole', () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      expect(first.read(vodAppSessionProvider), isNull);

      await first.read(vodAppSessionProvider.notifier).save(login(), deviceId: 'device-9');
      expect(first.read(vodAppSessionProvider), (accessKey: 'token-1', deviceId: 'device-9', mid: 42));

      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(second.read(vodAppSessionProvider), (accessKey: 'token-1', deviceId: 'device-9', mid: 42));

      await second.read(vodAppSessionProvider.notifier).clear();
      expect(second.read(vodAppSessionProvider), isNull);

      final third = ProviderContainer();
      addTearDown(third.dispose);
      expect(third.read(vodAppSessionProvider), isNull); // the keys went with the session
    });

    test('half a session is no session', () async {
      await StoragePrefs.setString('vod.app.accessKey', 'token-only');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(vodAppSessionProvider), isNull); // no device id, no sign-in

      await StoragePrefs.setString('vod.app.deviceId', '  ');
      expect(container.read(vodAppSessionProvider), isNull); // a blank device id is none
    });

    test('the playback client lives with the session and dies with it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(vodAppClientProvider), isNull); // nobody signed in

      await container.read(vodAppSessionProvider.notifier).save(login(), deviceId: 'device-9');
      final client = container.read(vodAppClientProvider);
      expect(client, isNotNull); // the client the gRPC channel speaks

      await container.read(vodAppSessionProvider.notifier).clear();
      expect(container.read(vodAppClientProvider), isNull); // the session gone, the client gone
    });
  });
}
