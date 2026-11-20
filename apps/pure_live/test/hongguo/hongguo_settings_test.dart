import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_card_settings.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_settings.dart';

/// The station's two small preferences: the series card's piece visibility
/// (what it restores from a partial or damaged set, and what the designed
/// default hides) and the opening rendition choice (the enum name stored,
/// an unknown name falling back to the reference's best).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  group('the card visibility', () {
    test('the stored set round-trips, and what it cannot read leaves the piece drawn', () {
      const hidden = {HongguoCardElement.rank, HongguoCardElement.hot};
      final stored = HongguoCardVisibility.hiding(hidden);
      expect(HongguoCardVisibility.fromJson(stored.toJson()), stored); // the round trip

      // A set written before a piece existed keeps that piece to the
      // default; an unknown name is skipped, not a crash.
      final older = HongguoCardVisibility.fromJson(const {
        'hidden': ['rank', 'noSuchPiece'],
      });
      expect(older.shows(HongguoCardElement.rank), isFalse);
      expect(older.shows(HongguoCardElement.hot), isTrue); // absent means drawn
      expect(older.shows(HongguoCardElement.score), isTrue);

      // Anything unreadable falls back to the designed default.
      expect(HongguoCardVisibility.fromJson('a string'), HongguoCardVisibility.standard);
      expect(HongguoCardVisibility.fromJson(const {'hidden': 'junk'}), HongguoCardVisibility.standard);
      expect(HongguoCardVisibility.fromJson(null), HongguoCardVisibility.standard);
    });

    test('the default hides the episode count and the score, and one piece flips at a time', () {
      const standard = HongguoCardVisibility.standard;
      expect(standard.shows(HongguoCardElement.episodes), isFalse);
      expect(standard.shows(HongguoCardElement.score), isFalse);
      expect(standard.shows(HongguoCardElement.rank), isTrue);
      expect(standard.shows(HongguoCardElement.today), isTrue);

      final favoriteOn = standard.withElement(HongguoCardElement.favorite, visible: false);
      expect(favoriteOn.shows(HongguoCardElement.favorite), isFalse);
      expect(favoriteOn.shows(HongguoCardElement.rank), isTrue); // the rest kept

      final episodesOn = standard.withElement(HongguoCardElement.episodes, visible: true);
      expect(episodesOn.shows(HongguoCardElement.episodes), isTrue);
      expect(episodesOn.shows(HongguoCardElement.score), isFalse); // the other hidden piece kept

      // The flip rides on the default's own hidden pieces.
      expect(favoriteOn, HongguoCardVisibility.hiding([HongguoCardElement.favorite, ...standard.hidden]));
      expect(favoriteOn, isNot(standard));
    });

    test('the controller restores the stored set, writes through, and resets', () async {
      await StoragePrefs.setString(
        kHongguoCardPrefsKey,
        jsonEncode({
          'hidden': ['rank', 'hot'],
        }),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.listen(hongguoCardSettingsProvider, (_, _) {});
      final controller = container.read(hongguoCardSettingsProvider.notifier);

      expect(container.read(hongguoCardSettingsProvider).shows(HongguoCardElement.rank), isFalse);
      expect(container.read(hongguoCardSettingsProvider).shows(HongguoCardElement.hot), isFalse);

      await controller.setElement(HongguoCardElement.score, visible: false);
      expect(container.read(hongguoCardSettingsProvider).shows(HongguoCardElement.score), isFalse);
      await pumpEventQueue();
      // The stored form walks the enum's own order.
      expect(jsonDecode(StoragePrefs.getString(kHongguoCardPrefsKey)!), {
        'hidden': ['rank', 'score', 'hot'],
      });

      await controller.reset();
      final reset = container.read(hongguoCardSettingsProvider);
      expect(reset, HongguoCardVisibility.standard);
      expect(reset.shows(HongguoCardElement.episodes), isFalse); // the default's own hidden pieces
      await pumpEventQueue();
      expect(jsonDecode(StoragePrefs.getString(kHongguoCardPrefsKey)!), {
        'hidden': ['score', 'episodes'],
      });
    });

    test('a damaged store falls back to the designed default', () async {
      for (final raw in ['not json', '{"hidden":"junk"}', '   ']) {
        await StoragePrefs.setString(kHongguoCardPrefsKey, raw);
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.listen(hongguoCardSettingsProvider, (_, _) {});
        expect(container.read(hongguoCardSettingsProvider), HongguoCardVisibility.standard, reason: 'raw: $raw');
      }
    });
  });

  group('the opening rendition', () {
    test('the stored name reads back, an unknown one falls to best, and the write persists', () async {
      // The reference's default when nothing is stored.
      final fresh = ProviderContainer();
      addTearDown(fresh.dispose);
      fresh.listen(hongguoSettingsProvider, (_, _) {});
      expect(fresh.read(hongguoSettingsProvider).quality, HongguoQualityChoice.best);

      await StoragePrefs.setString(kHongguoQualityPrefsKey, 'p720');
      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      restored.listen(hongguoSettingsProvider, (_, _) {});
      expect(restored.read(hongguoSettingsProvider).quality, HongguoQualityChoice.p720);

      // An unknown name is the default, not a crash.
      await StoragePrefs.setString(kHongguoQualityPrefsKey, 'p9000');
      final unknown = ProviderContainer();
      addTearDown(unknown.dispose);
      unknown.listen(hongguoSettingsProvider, (_, _) {});
      expect(unknown.read(hongguoSettingsProvider).quality, HongguoQualityChoice.best);

      // The choice writes the enum's name.
      await unknown.read(hongguoSettingsProvider.notifier).setQuality(HongguoQualityChoice.p540);
      expect(unknown.read(hongguoSettingsProvider).quality, HongguoQualityChoice.p540);
      await pumpEventQueue();
      expect(StoragePrefs.getString(kHongguoQualityPrefsKey), 'p540');
    });

    test('the tiers carry the ceiling their name says', () {
      expect(HongguoQualityChoice.best.maxHeight, 1080);
      expect(HongguoQualityChoice.p1080.maxHeight, 1080);
      expect(HongguoQualityChoice.p720.maxHeight, 720);
      expect(HongguoQualityChoice.p540.maxHeight, 540);
      expect(HongguoQualityChoice.p480.maxHeight, 480);
      expect(HongguoQualityChoice.p360.maxHeight, 360);
    });
  });
}
