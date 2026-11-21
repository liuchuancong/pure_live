import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/features/settings/playback/playback_settings_providers.dart';

/// The playback preferences' arithmetic and its store: a saved tier by any
/// of its older names, the tier's place mapped onto whatever qualities a
/// site actually offers, a sleep length in the reference's words, the box
/// fit by name or by number, and the stored choices' floors and ceilings.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  group('the saved tier', () {
    test('a tier by any of its names reads as the tier it is now', () {
      expect(normalizePreferredResolution(null), '原画'); // nothing saved: the reference's top
      expect(normalizePreferredResolution(''), '原画');
      expect(normalizePreferredResolution(' 蓝光4m '), '蓝光4M'); // the same word, any case, any padding
      expect(normalizePreferredResolution('蓝光'), '蓝光8M'); // the old build's name
      expect(normalizePreferredResolution('高清'), '超清');
      expect(normalizePreferredResolution('标清'), '流畅');
      expect(normalizePreferredResolution('8K'), '原画'); // a stranger: the top
    });

    test('the tier finds its place on whatever the site offers', () {
      expect(preferredQualityIndex([], '原画'), 0); // nothing offered: the first

      const three = ['原画', '超清', '流畅'];
      expect(preferredQualityIndex(three, '超清'), 1); // an exact hit
      expect(preferredQualityIndex(['原画 ', '超清', '流畅'], ' 流畅 '), 2); // trimmed both ways

      // a site with other names: the saved tier's level carries over
      const four = ['高清A', '高清B', '高清C', '高清D'];
      expect(preferredQualityIndex(four, '原画'), 0); // the top asks for the top
      expect(preferredQualityIndex(four, '蓝光8M'), 1);
      expect(preferredQualityIndex(four, '蓝光4M'), 2);
      expect(preferredQualityIndex(four, '超清'), 2);
      expect(preferredQualityIndex(four, '流畅'), 3); // the bottom asks for the bottom

      const two = ['低', '高'];
      expect(preferredQualityIndex(two, '蓝光4M'), 1); // the middle tier rounds to the upper half
      expect(preferredQualityIndex(two, '原画'), 0);

      expect(preferredQualityIndex(['只此一档'], '流畅'), 0); // one offer: it
      expect(preferredQualityIndex(const ['只此一档'], '不认识的档'), 0); // and a stranger asks the top
    });
  });

  group('the sleep length', () {
    test('minutes under the hour, whole hours over it, halves as a decimal', () {
      expect(asmrSleepDurationLabel(45), '45 min');
      expect(asmrSleepDurationLabel(60), '1 h');
      expect(asmrSleepDurationLabel(90), '1.5 h');
      expect(asmrSleepDurationLabel(1440), '24 h');
      expect(asmrSleepDurationLabel(50), '50 min'); // not on the half hour: minutes
    });
  });

  group('the box fit', () {
    test('the fit by name, by its old number, or the default', () {
      expect(normalizePlaybackFit('cover'), PlaybackFit.cover);
      expect(normalizePlaybackFit(' fitWidth '), PlaybackFit.fitWidth); // trimmed, by its enum name
      expect(normalizePlaybackFit('2'), PlaybackFit.fill); // the old builds stored a number
      expect(normalizePlaybackFit('9'), PlaybackFit.contain); // a number off the list
      expect(normalizePlaybackFit('junk'), PlaybackFit.contain);
      expect(normalizePlaybackFit(null), PlaybackFit.contain);
    });
  });

  group('the store', () {
    test('a tier saved under an older name reads as the tier it is now', () async {
      await StoragePrefs.setString('playback.quality', '蓝光');
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(playbackSettingsProvider).preferredQuality, '蓝光8M');
    });

    test('every stored choice keeps to its floor and ceiling', () async {
      await StoragePrefs.setDouble('playback.windowsPipBaseSize', 9999);
      await StoragePrefs.setInt('playback.asmrMinutes', 0);
      await StoragePrefs.setInt('playback.controlsAutoHide', -5);
      await StoragePrefs.setInt('playback.volumeWheelStep', 99);
      await StoragePrefs.setDouble('playback.volume', 1.7); // the older single slider
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(playbackSettingsProvider);
      expect(settings.windowsPipBaseSize, 720); // the ceiling
      expect(settings.asmrSleepMinutes, 15); // the floor
      expect(settings.controlsAutoHideSeconds, 0); // the floor: 常显
      expect(settings.volumeWheelStepPercent, 10); // the wheel's last step
      // the legacy slider seeds the mobile side on this platform's default
      expect(settings.mobileVolume, 1.0); // clamped from 1.7
    });

    test('a change in another window lands through reload', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(playbackSettingsProvider).preferredQuality, '原画');

      await StoragePrefs.setString('playback.quality', '流畅');
      container.read(playbackSettingsProvider.notifier).reload();
      expect(container.read(playbackSettingsProvider).preferredQuality, '流畅'); // the mirror's landing
    });
  });
}
