// The named `_Page` constructor cannot use the `new` shorthand while it is const.
// ignore_for_file: unnecessary_type_name_in_constructor
import 'dart:async';
import 'dart:io' show Directory;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:live_library/live_library.dart' show FollowRepository, InMemoryLibraryStore;
import 'package:live_net/live_net.dart' show DioFactory;
import 'package:live_platform/live_platform.dart'
    show DesktopDistribution, FormFactor, PlatformCapabilities, PlatformEnvironment, PlatformKind, PlatformRuntimeInfo;
import 'package:live_sites/live_sites.dart' show LiveCredential, LiveSiteRegistry;
import 'package:live_storage/live_storage.dart' show StorageRepository;
import 'package:pure_live/app/app_delegates.dart' show appLocalizationsDelegates, appSupportedLocales;
import 'package:pure_live/app/app_providers.dart';
import 'package:pure_live/app/composition/sites.dart' show AppSites;
import 'package:pure_live/features/account/login_providers.dart' show signedInAccountsProvider;
import 'package:pure_live/features/recorder/recorder_preferences.dart';
import 'package:pure_live/features/recorder/recorder_providers.dart';
import 'package:pure_live/features/settings/appearance/appearance_page.dart';
import 'package:pure_live/features/settings/danmaku/danmaku_settings_page.dart';
import 'package:pure_live/features/settings/general/general_settings_page.dart';
import 'package:pure_live/features/settings/loading/loading_style_settings_page.dart';
import 'package:pure_live/features/settings/local_config/local_config_preview_page.dart';
import 'package:pure_live/features/settings/local_interaction/local_interaction_settings_page.dart';
import 'package:pure_live/features/settings/logs/logs_settings_page.dart';
import 'package:pure_live/features/settings/navigation/navigation_settings_page.dart';
import 'package:pure_live/features/settings/network/network_proxy_settings_page.dart';
import 'package:pure_live/features/settings/pages/page_settings_page.dart';
import 'package:pure_live/features/settings/platforms/platforms_settings_page.dart';
import 'package:pure_live/features/settings/player/mpv_settings_page.dart';
import 'package:pure_live/features/settings/recording/record_settings_page.dart';
import 'package:pure_live/features/settings/refresh/refresh_settings_page.dart';
import 'package:pure_live/features/settings/room_card/room_card_settings_page.dart';
import 'package:pure_live/features/settings/settings_page.dart';
import 'package:pure_live/features/settings/video/background_guide_page.dart';
import 'package:pure_live/features/settings/video/portrait_settings_page.dart';
import 'package:pure_live/features/settings/video/video_settings_page.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/system/configuration/app_preferences.dart';
import 'package:pure_live/system/configuration/app_preferences_providers.dart';
import 'package:pure_live/system/resources/font_library.dart' show FontLibrary;
import 'package:pure_live/system/theme/appearance_store.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// Every settings screen, run through the app's real host chain in each design
/// language.
///
/// The cluster is one declarative tree now (`pure_settings_ui`), so what is worth
/// asserting is not a pixel but that each language's renderer survives the same
/// tree — the card, the row separator, the switch and the destination chevron all
/// come from a different library per language, and the app can boot into any of
/// them. The host is `PureApp`'s, not a bare `MaterialApp`: macOS needs its
/// theme, Fluent its localizations, forui its tokens, and that is exactly what a
/// regression in the shared tree would break.
void main() {
  for (final language in PureDesignLanguage.values) {
    testWidgets('the settings index renders under ${language.name}', (tester) async {
      final seen = await _pump(tester, language: language, child: const SettingsPage());
      expect(seen, language, reason: 'the host fell back to another language');
      expect(tester.takeException(), isNull, reason: language.name);
      // The search bar is the one piece always on screen: the split view's
      // pane title hides itself in the narrow forms (the Windows rail).
      expect(find.text('搜索设置'), findsOneWidget);
      // Hosts schedule their own one-shot timers (a tooltip, a reveal); the
      // tree must be drained before the framework checks for pending ones.
      await tester.pumpAndSettle();
    });

    testWidgets('the settings pages render under ${language.name}', (tester) async {
      for (var index = 0; index < _pages.length; index++) {
        final page = _pages[index];
        final seen = await _pump(tester, language: language, child: page.build());
        // Bounded pumps, never pumpAndSettle: the previews hold repeating
        // animations (a shimmer, a spinner) that never settle, and a settle
        // timeout reads as a page failure when it is only the harness waiting
        // for a frame that never comes.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        // Which language the host mounted is proven once per case: a host that
        // installs its own app widget reports its first frame on its own
        // schedule, and re-proving it per page only tests the harness's timing.
        if (index == 0) {
          expect(seen, language, reason: page.label);
        }
        expect(tester.takeException(), isNull, reason: '${language.name} / ${page.label}');
      }
    });
  }

  testWidgets('the two-pane index opens a section and finds rows by search', (tester) async {
    await _pump(tester, language: PureDesignLanguage.material, child: const SettingsPage());

    // 900 logical px wide is past the two-pane breakpoint: the overview and a
    // pane sit side by side and the appearance section is open at once.
    expect(find.text('界面'), findsOneWidget);
    expect(find.byKey(const ValueKey('settings-section-network')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settings-section-network')));
    await tester.pumpAndSettle();
    expect(find.text('代理'), findsWidgets);

    // Search filters the catalogue behind its debounce; a hit opens its page.
    await tester.enterText(find.byType(TextField).first, '弹幕');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings-entry-danmaku_visible')), findsOneWidget);
  });

  testWidgets('the appearance page links the list pages and writes the grid gaps', (tester) async {
    final stores = _Stores();
    await _pump(tester, language: PureDesignLanguage.material, child: const AppearancePage(), stores: stores);

    expect(find.byKey(const ValueKey('appearance-loading-style')), findsOneWidget);
    expect(find.byKey(const ValueKey('appearance-room-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('appearance-page-settings')), findsOneWidget);
    expect(find.text('6 px'), findsNWidgets(2));

    await tester.drag(find.byType(PureSlider).first, const Offset(200, 0));
    await tester.pump(const Duration(milliseconds: 600));
    expect(stores.preferences.value.crossAxisSpacing, greaterThan(6));
  });

  testWidgets('the danmaku page writes the default a room opens with', (tester) async {
    final stores = _Stores();
    await _pump(tester, language: PureDesignLanguage.material, child: const DanmakuSettingsPage(), stores: stores);

    expect(stores.preferences.value.danmakuVisible, isTrue);
    await tester.tap(find.text('默认显示弹幕'));
    await tester.pumpAndSettle();

    // The store debounces its write; letting the timer run out is what the app
    // does between a change and the next frame the user sees.
    await tester.pump(const Duration(milliseconds: 600));
    expect(stores.preferences.value.danmakuVisible, isFalse);
  });
}

/// A screen under test, with a name to fail with.
final class _Page {
  const _Page(this.label, this.build, {this.custom = false});

  final String label;
  final Widget Function() build;

  /// Whether the page places content the kit has no tile for — a preview card,
  /// a slider row, a reorderable list, a text field.
  final bool custom;
}

// The cache & data page is absent: it reads the history repository, which only
// the composition root builds. A library-store fake belongs with that graph, not
// here.
const List<_Page> _pages = [
  _Page('general', GeneralSettingsPage.new),
  _Page('refresh', RefreshSettingsPage.new),
  _Page('navigation', NavigationSettingsPage.new),
  _Page('pages', PageSettingsPage.new, custom: true),
  _Page('loading style', LoadingStyleSettingsPage.new, custom: true),
  _Page('room card', RoomCardSettingsPage.new, custom: true),
  _Page('network proxy', NetworkProxySettingsPage.new, custom: true),
  _Page('appearance', AppearancePage.new, custom: true),
  _Page('video', VideoSettingsPage.new, custom: true),
  _Page('background guide', BackgroundGuidePage.new),
  _Page('portrait', PortraitSettingsPage.new, custom: true),
  _Page('danmaku', DanmakuSettingsPage.new, custom: true),
  _Page('platforms', PlatformsSettingsPage.new),
  _Page('local interaction', LocalInteractionSettingsPage.new, custom: true),
  _Page('logs', LogsSettingsPage.new),
  _Page('mpv tuning', MpvSettingsPage.new),
  _Page('record', RecordSettingsPage.new, custom: true),
  _Page('local config', LocalConfigPreviewPage.new, custom: true),
];

/// The preference stores, both on an in-memory document. Unloaded, a store
/// answers the shipping defaults — which is the state worth rendering.
final class _Stores {
  final AppPreferencesStore preferences = AppPreferencesStore(repository: _MapRepository());
  final AppearanceStore appearance = AppearanceStore(repository: _MapRepository());
}

/// Pumps [child] as the app's only route, under the host the language mounts,
/// and reports the language the route actually resolved.
///
/// The host reads `PureTheme.of(context)` above it, so the provider sits outside
/// `PureApp` — the same order the app's own theme gives it. The probe inside the
/// route is the point: a host that quietly fell back to Material would render
/// fine and prove nothing.
Future<PureDesignLanguage?> _pump(
  WidgetTester tester, {
  required PureDesignLanguage language,
  required Widget child,
  _Stores? stores,
}) async {
  final resolved = stores ?? _Stores();
  PureDesignLanguage? seen;
  // A settings page is a column of cards taller than the phone window the test
  // surface defaults to; the overflow that reports is the harness's, not the
  // page's. The list scrolls — give it the height a scrollable has room for.
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesStoreProvider.overrideWithValue(resolved.preferences),
        appearanceStoreProvider.overrideWithValue(resolved.appearance),
        signedInAccountsProvider.overrideWith((ref) => const <String, LiveCredential>{}),
        // The refresh page's alert-scope rows enumerate the follow tags; the
        // harness hands the page an empty repository.
        followRepositoryProvider.overrideWithValue(FollowRepository(InMemoryLibraryStore())),
        environmentProvider.overrideWithValue(const _DesktopEnvironment()),
        // The video page's audience chips enumerate the site graph; the
        // harness hands it the empty one — the row still renders, the chips
        // just have no platforms to name here.
        sitesProvider.overrideWithValue(
          AppSites(factory: DioFactory(), http: DioFactory().create(), registry: LiveSiteRegistry(const [])),
        ),
        // The danmaku style group lists the registered cloud fonts; the
        // harness hands it an empty library — the row renders the 系统默认
        // answer and the chooser just has nothing more to offer.
        fontLibraryProvider.overrideWithValue(
          FontLibrary(
            root: Directory.systemTemp.createTempSync('pure-live-fonts'),
            http: DioFactory().create(),
            commit: 'main',
          ),
        ),
        // The recording page keeps its own document store; the harness hands
        // it the same in-memory repository the app stores get, and a fixed
        // root so the used-space row never asks the platform for one.
        recorderPreferencesStoreProvider.overrideWith((ref) async {
          final store = RecorderPreferencesStore(repository: _MapRepository());
          ref.onDispose(store.dispose);
          return store;
        }),
        recorderRootProvider.overrideWith((ref) async => 'C:/recordings'),
        // The appearance page reads the frozen boot language to say whether an
        // edit is waiting for a restart; the harness starts every language
        // fresh, which is the notRecorded case.
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
  // A host that mounts its own app widget (macOS, Fluent) defers its first
  // frame; the probe only records once the route is actually built.
  for (var attempt = 0; attempt < 4 && seen == null; attempt++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return seen;
}

/// A desktop environment, so the general settings' window-size section renders
/// the same way the app shows it. The capability list is not read here.
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

/// An in-memory [StorageRepository]: the same document round trip the real box
/// gives, without a file.
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
