import 'dart:async';

// The gift banner, pinned at the widget level: a local gift raises the card
// with its gift, count and level, it leaves on its own after the linger, and
// the switch turns it off.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_storage/live_storage.dart' show StorageRepository;
import 'package:pure_live/app/app_delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/features/room/local/local_catalog.dart';
import 'package:pure_live/features/room/local/local_gift_overlay.dart';
import 'package:pure_live/features/room/room_providers.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_uikit/pure_uikit.dart';

typedef _Identity = ({String siteId, String roomId});

const _Identity _identity = (siteId: 'douyu', roomId: '1');

void main() {
  test('the facade constructor carries the switch', () {
    expect(AppPreferences(localInteractionGiftBanner: false).localInteractionGiftBanner, isFalse);
    expect(AppPreferences(localInteractionGiftBanner: false).localInteraction.localInteractionGiftBanner, isFalse);
  });

  // Regression: an update that only flips the switch must not compare equal
  // to the defaults — the props list has to carry every domain field.
  test('a change that only flips the switch reaches the store', () {
    final store = AppPreferencesStore(repository: _MemoryRepository());
    unawaited(store.update((_) => AppPreferences(localInteractionGiftBanner: false)));
    expect(store.value.localInteractionGiftBanner, isFalse);
    final container = ProviderContainer(overrides: [appPreferencesStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    expect(container.read(appPreferencesProvider).localInteractionGiftBanner, isFalse);
  });

  test('a change that only picks a preset reaches the store', () {
    final store = AppPreferencesStore(repository: _MemoryRepository());
    unawaited(store.update((_) => AppPreferences(localInteractionPreset: 'neon')));
    expect(store.value.localInteractionPreset, 'neon');
  });

  testWidgets('a local gift raises the banner and it leaves by itself', (tester) async {
    await tester.pumpWidget(_host(const LocalGiftOverlay(identity: _identity)));
    expect(find.byKey(const ValueKey('local-gift-banner-count')), findsNothing);

    _sendGift(tester, LocalCatalog.gifts.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('local-gift-banner-count')), findsOneWidget);
    expect(find.text('×1'), findsOneWidget);
    expect(find.textContaining(LocalCatalog.gifts.last.name), findsOneWidget);
    expect(find.text('Lv.1'), findsOneWidget);

    await tester.pump(localGiftBannerLinger);
    await tester.pump();
    expect(find.byKey(const ValueKey('local-gift-banner-count')), findsNothing);
  });

  testWidgets('the switch keeps the banner quiet', (tester) async {
    await tester.pumpWidget(
      _host(
        const LocalGiftOverlay(identity: _identity),
        preferences: AppPreferences(localInteractionGiftBanner: false),
      ),
    );

    _sendGift(tester, LocalCatalog.gifts.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('local-gift-banner-count')), findsNothing);
  });
}

/// Sends a gift through the bus the overlay listens to.
void _sendGift(WidgetTester tester, LocalGift gift) {
  final container = ProviderScope.containerOf(tester.element(find.byType(LocalGiftOverlay)));
  container
      .read(roomLocalMessageBusProvider(_identity))
      .sendGift(gift: gift, count: 1, userName: '我', colorArgb: 0xFFFFFFFF);
}

Widget _host(Widget child, {AppPreferences? preferences}) {
  final store = AppPreferencesStore(repository: _MemoryRepository());
  unawaited(store.update((_) => preferences ?? AppPreferences()));
  return _providerHost(child, store);
}

Widget _providerHost(Widget child, AppPreferencesStore store) => ProviderScope(
  overrides: [appPreferencesStoreProvider.overrideWithValue(store)],
  child: PureConfigProvider(
    config: const UiConfig(language: PureDesignLanguage.material),
    child: MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: TranslationProvider(
        child: Scaffold(body: SizedBox(width: 400, height: 300, child: child)),
      ),
    ),
  ),
);

final class _MemoryRepository implements StorageRepository<Map<dynamic, dynamic>> {
  final Map<String, Map<dynamic, dynamic>> documents = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> watch({String? key}) => _changes.stream;

  @override
  Map<dynamic, dynamic>? get(String key) => documents[key];

  @override
  Map<String, Map<dynamic, dynamic>> getMany(Iterable<String> keys) => {
    for (final key in keys)
      if (documents.containsKey(key)) key: documents[key]!,
  };

  @override
  List<Map<dynamic, dynamic>> getAll() => List.of(documents.values);

  @override
  Map<String, Map<dynamic, dynamic>> getAllEntries() => Map.of(documents);

  @override
  List<String> getAllKeys() => List.of(documents.keys);

  @override
  bool contains(String key) => documents.containsKey(key);

  @override
  bool containsAll(Iterable<String> keys) => keys.every(documents.containsKey);

  @override
  Future<void> save(String key, Map<dynamic, dynamic> value) async {
    documents[key] = value;
    _changes.add(null);
  }

  @override
  Future<void> saveAll(Map<String, Map<dynamic, dynamic>> values) async {
    documents.addAll(values);
    _changes.add(null);
  }

  @override
  Future<bool> insertIfAbsent(String key, Map<dynamic, dynamic> value) async {
    final inserted = !documents.containsKey(key);
    if (inserted) {
      documents[key] = value;
      _changes.add(null);
    }
    return inserted;
  }

  @override
  Future<bool> update(String key, Map<dynamic, dynamic> Function(Map<dynamic, dynamic> current) updater) async {
    if (!documents.containsKey(key)) {
      return false;
    }
    documents[key] = updater(documents[key]!);
    _changes.add(null);
    return true;
  }

  @override
  Future<void> delete(String key) async {
    documents.remove(key);
    _changes.add(null);
  }

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    keys.forEach(documents.remove);
    _changes.add(null);
  }

  @override
  Future<int> deleteWhere(bool Function(String key, Map<dynamic, dynamic> value) test) async {
    final doomed = [
      for (final entry in documents.entries)
        if (test(entry.key, entry.value)) entry.key,
    ]..forEach(documents.remove);
    _changes.add(null);
    return doomed.length;
  }

  @override
  int get count => documents.length;

  @override
  bool get isEmpty => documents.isEmpty;

  @override
  bool get isNotEmpty => documents.isNotEmpty;

  @override
  Future<void> clear() async {
    documents.clear();
    _changes.add(null);
  }

  @override
  Future<void> flush() async {}
}
