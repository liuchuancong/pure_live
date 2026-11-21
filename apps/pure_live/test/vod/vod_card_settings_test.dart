import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/vod/controller/vod_card_settings.dart';

/// The Bilibili cards' visibility: the designed default draws every piece,
/// a choice hides exactly what it names, the stored form round-trips with
/// the unknown names dropped, and the controller holds it over the store —
/// a closed store loses the write but not the choice.
void main() {
  group('the visibility set', () {
    test('the default draws every piece', () {
      const visibility = VodCardVisibility.standard;
      for (final element in VodCardElement.values) {
        expect(visibility.shows(element), isTrue, reason: '${element.name} should show');
      }
      expect(visibility.hidden, isEmpty);
    });

    test('a choice hides exactly what it names, and a toggle round-trips', () {
      final hiding = VodCardVisibility.hiding(const [VodCardElement.plays, VodCardElement.avatar]);
      expect(hiding.shows(VodCardElement.plays), isFalse);
      expect(hiding.shows(VodCardElement.avatar), isFalse);
      expect(hiding.shows(VodCardElement.duration), isTrue); // the rest draw on

      final restored = hiding.withElement(VodCardElement.plays, visible: true);
      expect(restored.shows(VodCardElement.plays), isTrue);
      expect(restored.shows(VodCardElement.avatar), isFalse); // the other choice kept

      final hidden = hiding.withElement(VodCardElement.avatar, visible: false);
      expect(identical(hidden, hiding), isFalse);
      expect(hidden, equals(hiding)); // the same set is the same choice
    });

    test('two choices equal on their sets equal outright, order and all', () {
      final one = VodCardVisibility.hiding(const [VodCardElement.plays, VodCardElement.duration]);
      final two = VodCardVisibility.hiding(const [VodCardElement.duration, VodCardElement.plays]);
      expect(one, equals(two));
      expect(one.hashCode, two.hashCode);
    });

    test('the stored form round-trips, unknown names dropped', () {
      final visibility = VodCardVisibility.hiding(const [VodCardElement.uploader, VodCardElement.seasonScore]);
      final read = VodCardVisibility.fromJson(jsonDecode(jsonEncode(visibility.toJson())));
      expect(read, equals(visibility));

      final withStray = VodCardVisibility.fromJson(const {
        'hidden': ['uploader', 'noSuchPiece', 42, 'seasonScore'],
      });
      expect(withStray.hidden, const {VodCardElement.uploader, VodCardElement.seasonScore}); // the strays never landed

      expect(VodCardVisibility.fromJson('junk'), same(VodCardVisibility.standard));
      expect(VodCardVisibility.fromJson(const {'hidden': 'not-a-list'}), same(VodCardVisibility.standard));
      expect(VodCardVisibility.fromJson(null), same(VodCardVisibility.standard));
    });
  });

  group('the controller', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    test('the store starts at the default, a choice lands and survives a re-read', () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      expect(first.read(vodCardSettingsProvider).hidden, isEmpty); // the default

      await first.read(vodCardSettingsProvider.notifier).setElement(VodCardElement.duration, visible: false);
      await first.read(vodCardSettingsProvider.notifier).setElement(VodCardElement.uploader, visible: false);
      expect(first.read(vodCardSettingsProvider).hidden, {VodCardElement.duration, VodCardElement.uploader});

      final second = ProviderContainer();
      addTearDown(second.dispose);
      expect(
        second.read(vodCardSettingsProvider).hidden,
        {VodCardElement.duration, VodCardElement.uploader}, // the store's answer, read back
      );
    });

    test('a stored choice unreadable falls back to the default', () async {
      await StoragePrefs.setString(kVodCardPrefsKey, 'not-json');
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(vodCardSettingsProvider).hidden, isEmpty);
      expect(container.read(vodCardSettingsProvider).shows(VodCardElement.plays), isTrue);
    });
  });
}
