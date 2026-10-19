// The named private-class constructors cannot use the `new` shorthand.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// The sweep boots the real storage layer, which speaks Hive directly.
import 'package:hive_ce/hive.dart';
import 'package:live_iptv/live_iptv.dart' show InMemoryIptvStore, IptvLibrary;
import 'package:live_library/live_library.dart' show FollowRepository, HistoryRepository, InMemoryLibraryStore;
import 'package:live_net/live_net.dart' show DioFactory;
import 'package:live_platform/live_platform.dart'
    show DesktopDistribution, FormFactor, PlatformCapabilities, PlatformEnvironment, PlatformKind, PlatformRuntimeInfo;
import 'package:live_sites/live_sites.dart' show LiveCredential, LiveSiteRegistry;
import 'package:live_storage/live_storage.dart' show StorageRepository;
import 'package:pure_live/app/composition/sites.dart' show AppSites;
import 'package:pure_live/app/delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/preferences/app_preferences.dart' show AppPreferencesStore;
import 'package:pure_live/app/preferences/app_preferences_providers.dart';
import 'package:pure_live/app/providers/app_providers.dart';
import 'package:pure_live/app/theme/appearance_store.dart';
import 'package:pure_live/features/about/about_page.dart';
import 'package:pure_live/features/history/history_page.dart';
import 'package:pure_live/features/iptv/iptv_page.dart';
import 'package:pure_live/features/iptv/iptv_preferences.dart';
import 'package:pure_live/features/login/account_page.dart';
import 'package:pure_live/features/login/cookie_editor_page.dart';
import 'package:pure_live/features/login/login_providers.dart' show signedInAccountsProvider;
import 'package:pure_live/features/multiview/multiview_page.dart';
import 'package:pure_live/features/multiview/multiview_preferences.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_page.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_providers.dart';
import 'package:pure_live/features/remote_receiver/remote_sync_service.dart';
import 'package:pure_live/features/search/search_page.dart';
import 'package:pure_live/features/shield/shield_page.dart';
import 'package:pure_live/features/toolbox/toolbox_page.dart';
import 'package:pure_live/features/version/version_page.dart';
import 'package:pure_live/features/wallpaper/wallpaper_picker_page.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Every secondary page, run through every design language's real host chain.
///
/// The same contract `home_render_test` and `settings_render_test` hold: each
/// language dispatches the shared tree to a different library's widgets, and
/// the assertion that matters is that the renderer survives it. Absent on
/// purpose: backup (needs the booted `AppPaths`), remote receiver (network
/// services), splash (the boot flow), the recorder (FFmpeg) and area rooms
/// (route arguments) — the same "no fake stands in for the composition root"
/// rule the settings cluster documents.
void main() {
  setUpAll(() {
    // The shield panel and the search history open real boxes through the
    // storage layer; a temp directory is the test's stand-in for the data area.
    Hive.init(Directory.systemTemp.createTempSync('pure_live_test').path);
  });

  final pages = <(String, Widget)>[
    ('history', const HistoryPage()),
    ('search', const SearchPage()),
    ('shield', const ShieldPage()),
    ('about', const AboutPage()),
    ('version', const VersionPage()),
    ('iptv', const IptvPage()),
    ('toolbox', const ToolboxPage()),
    ('multiview', const MultiviewPage()),
    ('wallpaper', const WallpaperPickerPage()),
    ('account', const AccountPage()),
    ('account-cookie-editor', const CookieEditorPage(siteId: 'douyu')),
    ('remote-sync', const RemoteSyncPage()),
  ];

  for (final language in PureDesignLanguage.values) {
    testWidgets('the secondary pages render under ${language.name}', (tester) async {
      for (final (index, (label, page)) in pages.indexed) {
        final seen = await _pump(tester, language: language, child: page);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        if (index == 0) {
          expect(seen, language, reason: label);
        }
        expect(tester.takeException(), isNull, reason: '${language.name} / $label');
      }
    });
  }
}

/// Pumps [child] as the app's only route under the language's host, with the
/// composition-root providers faked in memory, and reports the language the
/// route actually resolved.
Future<PureDesignLanguage?> _pump(
  WidgetTester tester, {
  required PureDesignLanguage language,
  required Widget child,
}) async {
  PureDesignLanguage? seen;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2400);
  addTearDown(tester.view.reset);
  final sites = AppSites(factory: DioFactory(), http: DioFactory().create(), registry: LiveSiteRegistry(const []));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesStoreProvider.overrideWithValue(AppPreferencesStore(repository: _MapRepository())),
        appearanceStoreProvider.overrideWithValue(AppearanceStore(repository: _MapRepository())),
        signedInAccountsProvider.overrideWith((ref) => const <String, LiveCredential>{}),
        environmentProvider.overrideWithValue(const _DesktopEnvironment()),
        sitesProvider.overrideWithValue(sites),
        httpProvider.overrideWithValue(sites.http),
        followRepositoryProvider.overrideWithValue(FollowRepository(InMemoryLibraryStore())),
        historyRepositoryProvider.overrideWithValue(HistoryRepository(InMemoryLibraryStore())),
        // The sync page starts serving on entry; the inert service answers
        // the render sweep without ever touching a socket or a box.
        remoteSyncServiceProvider.overrideWithValue(
          RemoteSyncService.inert(
            follows: FollowRepository(InMemoryLibraryStore()),
            history: HistoryRepository(InMemoryLibraryStore()),
            preferences: AppPreferencesStore(repository: _MapRepository()),
          ),
        ),
        iptvLibraryProvider.overrideWithValue(IptvLibrary(InMemoryIptvStore())),
        iptvPreferencesStoreProvider.overrideWithValue(IptvPreferencesStore(repository: _MapRepository())),
        multiviewPreferencesStoreProvider.overrideWithValue(MultiviewPreferencesStore(repository: _MapRepository())),
        uiStartupConfigProvider.overrideWithValue(
          PureUiStartupConfig(language: language, origin: PureUiStartupOrigin.notRecorded, defaultLanguage: language),
        ),
      ],
      child: PureConfigProvider(
        config: UiConfig(language: language),
        child: PureApp(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => Builder(
                  builder: (context) {
                    seen ??= PureTheme.of(context).config.language;
                    return child;
                  },
                ),
              ),
            ],
          ),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          builder: (context, appChild) => TranslationProvider(child: appChild!),
        ),
      ),
    ),
  );
  for (var attempt = 0; attempt < 4 && seen == null; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return seen;
}

/// A desktop environment, so the pages read the desktop form factor the
/// shell pins navigation from.
final class _DesktopEnvironment implements PlatformEnvironment {
  const _DesktopEnvironment();

  @override
  PlatformRuntimeInfo get runtime => PlatformRuntimeInfo(
    kind: PlatformKind.windows,
    formFactor: FormFactor.desktop,
    distribution: DesktopDistribution.values.first,
    isPackaged: false,
    executableRoot: Directory.current,
  );

  @override
  PlatformCapabilities get capabilities => PlatformCapabilities.none;
}

/// An in-memory [StorageRepository]: the same document round trip the real
/// box gives, without a file.
final class _MapRepository implements StorageRepository<Map<dynamic, dynamic>> {
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
