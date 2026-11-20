import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/vod/controller/vod_playback_settings.dart';

/// The station's playback choices: the nearest-choice read a stored rate
/// takes, the seven choices writing through to their own keys, the damaged
/// values that fall back, and the reset that returns the reference's
/// defaults.
void main() {
  late StorageStores stores;
  late ProviderContainer container;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  tearDown(() => stores.close());

  group('the nearest choice for a stored rate', () {
    test('exact rates land on themselves', () {
      for (final choice in VodSpeedChoice.values) {
        expect(VodSpeedChoice.nearest(choice.value), choice);
      }
    });

    test('an in-between rate lands on its nearest neighbour', () {
      expect(VodSpeedChoice.nearest(1.3), VodSpeedChoice.oneAndQuarter);
      expect(VodSpeedChoice.nearest(1.4), VodSpeedChoice.oneAndHalf);
      expect(VodSpeedChoice.nearest(1.8), VodSpeedChoice.doubleSpeed);
    });

    test('a damaged rate reads as normal, not a crash', () {
      expect(VodSpeedChoice.nearest(double.nan), VodSpeedChoice.normal);
      // The reader refuses these before the choice: only positive finite
      // rates reach it. The choice itself would send the far values to the
      // ends of the list.
      expect(VodSpeedChoice.nearest(-1), VodSpeedChoice.half);
      expect(VodSpeedChoice.nearest(0), VodSpeedChoice.half);
    });
  });

  group('the choices', () {
    test('the defaults are the reference standard', () {
      expect(container.read(vodPlaybackSettingsProvider), VodPlaybackSettings.standard);
    });

    test('every choice writes through to its own key', () async {
      final controller = container.read(vodPlaybackSettingsProvider.notifier);
      await controller.setSpeed(VodSpeedChoice.oneAndHalf);
      await controller.setFinish(VodFinishAction.exit);
      await controller.setShowDetails(value: false);
      await controller.setApiType(VodApiType.app);
      await controller.setSkipHeadTail(value: false);
      await controller.setLongPressSpeed(VodSpeedChoice.doubleSpeed);
      await controller.setSeekPreview(value: false);

      final state = container.read(vodPlaybackSettingsProvider);
      expect(state.speed, VodSpeedChoice.oneAndHalf);
      expect(state.finish, VodFinishAction.exit);
      expect(state.showDetails, isFalse);
      expect(state.apiType, VodApiType.app);
      expect(state.skipHeadTail, isFalse);
      expect(state.longPressSpeed, VodSpeedChoice.doubleSpeed);
      expect(state.seekPreview, isFalse);

      await pumpEventQueue();
      expect(StoragePrefs.getDouble(kVodSpeedPrefsKey), 1.5);
      expect(StoragePrefs.getString(kVodFinishPrefsKey), 'exit');
      expect(StoragePrefs.getBool(kVodShowDetailsPrefsKey), isFalse);
      expect(StoragePrefs.getString(kVodApiTypePrefsKey), 'app');
      expect(StoragePrefs.getBool(kVodSkipHeadTailPrefsKey), isFalse);
      expect(StoragePrefs.getDouble(kVodLongPressSpeedPrefsKey), 2.0);
      expect(StoragePrefs.getBool(kVodSeekPreviewPrefsKey), isFalse);

      // A fresh read of the same store lands on the same choices.
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(vodPlaybackSettingsProvider), state);
    });

    test('a damaged stored rate falls back, not a crash', () async {
      // A rate a hand edit or an older build left behind: the reader only
      // takes positive finite values, everything else keeps the default.
      await StoragePrefs.setDouble(kVodSpeedPrefsKey, -2);
      await StoragePrefs.setDouble(kVodLongPressSpeedPrefsKey, 0);
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(vodPlaybackSettingsProvider).speed, VodSpeedChoice.normal);
      expect(next.read(vodPlaybackSettingsProvider).longPressSpeed, VodSpeedChoice.triple);
    });

    test('a stored name the choices lost keeps the default', () async {
      await StoragePrefs.setString(kVodFinishPrefsKey, 'loopTheVideo');
      await StoragePrefs.setString(kVodApiTypePrefsKey, 'grpc');
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(vodPlaybackSettingsProvider).finish, VodFinishAction.nextPart);
      expect(next.read(vodPlaybackSettingsProvider).apiType, VodApiType.web);
    });

    test('a stored rate lands on the nearest offered choice', () async {
      await StoragePrefs.setDouble(kVodSpeedPrefsKey, 1.3);
      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(vodPlaybackSettingsProvider).speed, VodSpeedChoice.oneAndQuarter);
    });

    test('the reset returns every choice to the standard', () async {
      final controller = container.read(vodPlaybackSettingsProvider.notifier);
      await controller.setSpeed(VodSpeedChoice.triple);
      await controller.setFinish(VodFinishAction.playRelated);
      await controller.setShowDetails(value: false);
      await controller.setApiType(VodApiType.app);
      await controller.setSkipHeadTail(value: false);
      await controller.setLongPressSpeed(VodSpeedChoice.half);
      await controller.setSeekPreview(value: false);

      await controller.reset();
      expect(container.read(vodPlaybackSettingsProvider), VodPlaybackSettings.standard);
      await pumpEventQueue();
      expect(StoragePrefs.getDouble(kVodSpeedPrefsKey), 1.0);
      expect(StoragePrefs.getString(kVodFinishPrefsKey), 'nextPart');

      final next = ProviderContainer();
      addTearDown(next.dispose);
      expect(next.read(vodPlaybackSettingsProvider), VodPlaybackSettings.standard);
    });
  });
}
