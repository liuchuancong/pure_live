import 'dart:convert' show jsonEncode;
import 'dart:io' show Directory;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_cache/live_cache.dart' show LiveCacheManager;
import 'package:live_net/live_net.dart' show ClientProfile, DioFactory;
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/app.dart' show sitesProvider;
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/live/favorites/data/favorites_inline_search.dart';
import 'package:pure_live/modules/live/favorites/data/follow_repository.dart';
import 'package:pure_live/modules/live/favorites/data/follow_tags.dart' show followTagsProvider;
import 'package:pure_live/modules/live/favorites/pages/favorites_page.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show installLiveCacheManager;
import 'package:pure_live/shared/shared.dart' show PlatformTabRow, localizedSiteName;

/// The follows page end to end over the real providers on the in-memory
/// store: which slice the page opens on, what the group, platform, tag and
/// word each cut, and what a vanished tag leaves showing.
void main() {
  setUpAll(() {
    // The room cards' covers go through the app's image cache; a throwaway
    // manager over a temp folder keeps the test bare of the boot.
    final root = Directory.systemTemp.createTempSync('favorites-page-test');
    addTearDown(() => root.deleteSync(recursive: true));
    installLiveCacheManager(
      LiveCacheManager(
        directory: root,
        http: DioFactory().create(profile: ClientProfile.media),
      ),
    );
  });

  setUp(() async {
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  LiveRoom roomOf(String platform, String id, {LiveStatus? status, String? title, List<String> tags = const []}) =>
      LiveRoom.normalized(
        platform: platform,
        roomId: id,
        content: RoomContent.of(title: title ?? 'Room $id'),
      ).rebuild(
        (b) => b
          ..broadcast.liveStatus = status
          ..local.tagIds.addAll(tags),
      );

  /// Seeds the follows straight into the store: Alpha and Gamma are live,
  /// Gamma carries the tag, Beta on another platform is offline.
  Future<void> seed({String? tagId}) async {
    final store = await StorageStores.instance.openStore('follows');
    final repository = FollowRepository(store);
    await repository.add(roomOf('douyu', '1', status: LiveStatus.live, title: 'Alpha'));
    await repository.add(
      roomOf('douyu', '3', status: LiveStatus.live, title: 'Gamma', tags: tagId == null ? const [] : [tagId]),
    );
    await repository.add(roomOf('huya', '2', status: LiveStatus.offline, title: 'Beta'));
  }

  Future<Widget> page(WidgetTester tester) async {
    final runtime = PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    return ProviderScope(
      overrides: [platformRuntimeProvider.overrideWithValue(runtime)],
      child: TranslationProvider(
        child: const DsScope(
          child: MaterialApp(home: Scaffold(body: FavoritesPage())),
        ),
      ),
    );
  }

  Future<void> showPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(await page(tester));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Translations tOf(WidgetTester tester) => tester.element(find.byType(FavoritesPage)).t;

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(FavoritesPage)));

  Future<void> closePage(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Taps the named word on the page's group tabs; the same word sits on
  /// the platform row too, so the tabs scope the touch.
  Future<void> selectGroup(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: find.byWidgetPredicate((widget) => widget is DsTabs), matching: find.text(label)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Taps the named platform on the platform tab row.
  Future<void> selectPlatform(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(PlatformTabRow), matching: find.text(label)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('an empty page asks for a room to follow', (tester) async {
    await showPage(tester);
    final t = tOf(tester);
    expect(find.text(t.favorites.emptyTitle), findsOneWidget);
    expect(find.text(t.favorites.searchLive), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('the page opens on the live rooms, with the counts on the tabs', (tester) async {
    await seed();
    await showPage(tester);
    final t = tOf(tester);
    // The default group is live: the two live rooms show, the offline one
    // waits on its tab.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    // Each tab wears its count, and the whole count answers 全部: the
    // counts ride the tabs, zero stays quiet.
    expect(find.text('2'), findsWidgets); // the live count
    expect(find.text('1'), findsWidgets); // the offline count
    expect(find.text('3'), findsOneWidget); // 全部's whole count
    expect(find.text(t.favorites.statusReplay), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('the group tabs cut the follows, 全部 shows them all', (tester) async {
    await seed();
    await showPage(tester);
    final t = tOf(tester);
    await selectGroup(tester, t.favorites.statusOfflineNow);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    await selectGroup(tester, t.favorites.statusAll);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('the platform tab cuts the follows by their site', (tester) async {
    await seed();
    await showPage(tester);
    final container = containerOf(tester);
    final t = tOf(tester);
    final huya = localizedSiteName(container.read(sitesProvider).getById('huya')!);
    await selectGroup(tester, t.favorites.statusAll);
    await selectPlatform(tester, huya);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    // Back to every platform through the wall entry.
    await selectPlatform(tester, t.favorites.statusAll);
    expect(find.text('Alpha'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('the toolbar word narrows in place and widens back', (tester) async {
    await seed();
    await showPage(tester);
    final t = tOf(tester);
    final container = containerOf(tester);
    // Group 全部, so the word is the only cut.
    await selectGroup(tester, t.favorites.statusAll);

    container.read(favoritesInlineSearchProvider.notifier).search('Alpha');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Gamma'), findsNothing);
    expect(find.text(t.favorites.inlineMatches(query: 'Alpha', count: 1)), findsOneWidget);

    container.read(favoritesInlineSearchProvider.notifier).clear();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gamma'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('a tag cuts its rooms, and removing it shows every room again', (tester) async {
    // The tag exists before its room, written straight into the prefs
    // record the controller reads: one awaited write, no provider races
    // before the page mounts. The write runs under runAsync — the one
    // real-clock window a widget test has — because the prefs write
    // travels a drift transaction whose hops the fake clock only moves
    // on a pump, and this await has none to give.
    await tester.runAsync(() async {
      await StoragePrefs.setString(
        'follow.tags',
        jsonEncode([
          {'id': 't1', 'name': '游戏', 'description': ''},
        ]),
      );
      await seed(tagId: 't1');
    });
    await showPage(tester);
    final container = containerOf(tester);
    final t = tOf(tester);
    // 全部, so the tag chip is the only cut.
    await selectGroup(tester, t.favorites.statusAll);
    expect(find.text('游戏'), findsOneWidget);

    await tester.tap(find.text('游戏'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsNothing);

    // Removing the tag strips it from the room and clears the cut: the
    // page never sits on a tag that no longer exists. The write runs
    // under runAsync — the page is watching the store, and an in-body
    // await on a drift write behind live stream queries waits on hops the
    // fake clock only moves on a pump, which an await never gives.
    await tester.runAsync(() => container.read(followTagsProvider.notifier).remove('t1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('游戏'), findsNothing);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    await closePage(tester);
  });

  testWidgets('the platform whose last follow left falls back to 全部', (tester) async {
    await seed();
    await showPage(tester);
    final container = containerOf(tester);
    final t = tOf(tester);
    await selectGroup(tester, t.favorites.statusAll);
    final huya = localizedSiteName(container.read(sitesProvider).getById('huya')!);
    await selectPlatform(tester, huya);
    expect(find.text('Beta'), findsOneWidget);

    // The platform's only follow leaves: the view falls back to 全部
    // rather than pointing at a tab that no longer exists. The write runs
    // under runAsync, behind the page's own live watch of the store.
    final repository = FollowRepository(await StorageStores.instance.openStore('follows'));
    await tester.runAsync(() => repository.remove('huya:2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The list follows the tabs to 全部: not an empty slice, the other
    // platforms' rooms on the wall again.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text(t.favorites.emptyOfflineHint), findsNothing);
    await closePage(tester);
  });
}
