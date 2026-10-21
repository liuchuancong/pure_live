import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:live_library/live_library.dart';
import 'package:live_net/live_net.dart' show DioFactory;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart' show StorageRepository;

import 'package:pure_live/app/app_delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/app_providers.dart' show sitesProvider;
import 'package:pure_live/app/composition/sites.dart' show AppSites;
import 'package:pure_live/features/remote_receiver/remote_sync_device.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_page.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_providers.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_service.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_uikit/pure_uikit.dart';

final class _MapRepository implements StorageRepository<Map<dynamic, dynamic>> {
  final Map<String, Map<dynamic, dynamic>> documents = {};

  @override
  Stream<void> watch({String? key}) => const Stream.empty();

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
  Future<void> save(String key, Map<dynamic, dynamic> value) async => documents[key] = value;

  @override
  Future<void> saveAll(Map<String, Map<dynamic, dynamic>> values) async => documents.addAll(values);

  @override
  Future<bool> insertIfAbsent(String key, Map<dynamic, dynamic> value) async {
    final inserted = !documents.containsKey(key);
    if (inserted) {
      documents[key] = value;
    }
    return inserted;
  }

  @override
  Future<bool> update(String key, Map<dynamic, dynamic> Function(Map<dynamic, dynamic> current) updater) async {
    if (!documents.containsKey(key)) {
      return false;
    }
    documents[key] = updater(documents[key]!);
    return true;
  }

  @override
  Future<void> delete(String key) async => documents.remove(key);

  @override
  Future<void> deleteAll(Iterable<String> keys) async => keys.forEach(documents.remove);

  @override
  Future<int> deleteWhere(bool Function(String key, Map<dynamic, dynamic> value) test) async {
    final doomed = [
      for (final entry in documents.entries)
        if (test(entry.key, entry.value)) entry.key,
    ]..forEach(documents.remove);
    return doomed.length;
  }

  @override
  int get count => documents.length;

  @override
  bool get isEmpty => documents.isEmpty;

  @override
  bool get isNotEmpty => documents.isNotEmpty;

  @override
  Future<void> clear() async => documents.clear();

  @override
  Future<void> flush() async {}
}

Future<void> pumpSyncPage(WidgetTester tester, RemoteSyncService service) async {
  addTearDown(service.dispose);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1000, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sitesProvider.overrideWithValue(
          AppSites(factory: DioFactory(), http: DioFactory().create(), registry: LiveSiteRegistry(const [])),
        ),
        remoteSyncServiceProvider.overrideWithValue(service),
      ],
      child: PureConfigProvider(
        config: const UiConfig(language: PureDesignLanguage.material),
        child: PureApp(
          routerConfig: GoRouter(
            routes: [GoRoute(path: '/', builder: (context, state) => const RemoteSyncPage())],
          ),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          locale: const Locale('zh'),
          builder: (context, appChild) => TranslationProvider(child: appChild!),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a send walks parts → pairing code, and a short code is refused with words', (tester) async {
    // A peer nothing can reach: takesParts fails, so the send is treated as
    // going to a 3.x device that can only take everything.
    final service = RemoteSyncService.inert(
      follows: FollowRepository(InMemoryLibraryStore()),
      history: HistoryRepository(InMemoryLibraryStore()),
      preferences: AppPreferencesStore(repository: _MapRepository()),
    )..heard(
      RemoteSyncDevice(
        id: 'peer-1',
        name: '测试设备',
        platform: 'windows',
        version: '1.0.0',
        ip: '127.0.0.1',
        port: 1,
        lastSeen: DateTime(2026, 10),
        bonsoirName: null,
      ),
    );
    await pumpSyncPage(tester, service);

    await tester.tap(find.byKey(const ValueKey('remote-sync-send')).first);
    await tester.pump(); // takesParts starts
    await tester.pump(const Duration(seconds: 1)); // the refusal lands
    await tester.pumpAndSettle();

    // The locked parts dialog: every box ticked, and it says why.
    expect(find.byKey(const ValueKey('remote-sync-parts-note')), findsOne);
    expect(find.byKey(const ValueKey('remote-sync-confirm')), findsOne);

    await tester.tap(find.byKey(const ValueKey('remote-sync-confirm')));
    await tester.pumpAndSettle();

    // The pairing-code dialog: six boxes over one invisible field.
    expect(find.byKey(const ValueKey('remote-sync-code-field')), findsOne);
    await tester.enterText(find.byKey(const ValueKey('remote-sync-code-field')), '12345');
    await tester.tap(find.byKey(const ValueKey('remote-sync-code-ok')));
    await tester.pumpAndSettle();
    expect(find.text('配对码应为 6 位数字'), findsOne);
    expect(find.byKey(const ValueKey('remote-sync-pairing')), findsNothing);
  });

  testWidgets('a pasted sync link with its code skips the pairing dialog and the send answers by toast', (tester) async {
    final service = RemoteSyncService.inert(
      follows: FollowRepository(InMemoryLibraryStore()),
      history: HistoryRepository(InMemoryLibraryStore()),
      preferences: AppPreferencesStore(repository: _MapRepository()),
    );
    await pumpSyncPage(tester, service);

    await tester.enterText(find.byType(TextField).last, 'purelive://127.0.0.1:1/sync?code=123456');
    await tester.tap(find.byKey(const ValueKey('remote-sync-send')).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Parts (locked, nothing reachable) → confirm.
    await tester.tap(find.byKey(const ValueKey('remote-sync-confirm')));
    await tester.pumpAndSettle();
    // The pasted code went straight to the send — no pairing dialog — and
    // the unreachable peer answers with the failure toast, not a hang.
    expect(find.byKey(const ValueKey('remote-sync-pairing')), findsNothing);
    expect(find.text(t.remoteSync.sendFailed), findsOne);
  });

  testWidgets('the accounts switch says what it ships and stays off', (tester) async {
    final service = RemoteSyncService.inert(
      follows: FollowRepository(InMemoryLibraryStore()),
      history: HistoryRepository(InMemoryLibraryStore()),
      preferences: AppPreferencesStore(repository: _MapRepository()),
    );
    await pumpSyncPage(tester, service);
    expect(service.includeAccounts, isFalse);
    expect(find.text('同步账号 Cookie'), findsOne);
  });
}
