import 'package:desen_ui/desen_ui.dart' show DsScope;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/shared/grids/paged_card_list.dart';

/// The paged list's pager: the page the viewer names sliced out of the
/// accumulated list, the count one page ahead while the source may continue,
/// a past-the-hand press asking and moving only when the block arrived, a
/// press while a page is in flight dropped, and a fresh page starting at its
/// head on the list's own controller.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  Widget wrap(WidgetTester tester, Widget list) {
    final runtime = PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    return ProviderScope(
      overrides: [platformRuntimeProvider.overrideWithValue(runtime)],
      child: TranslationProvider(
        child: DsScope(
          child: MaterialApp(
            home: Scaffold(body: SizedBox(width: 800, height: 600, child: list)),
          ),
        ),
      ),
    );
  }

  Future<void> show(WidgetTester tester, Widget list) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(wrap(tester, list));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Widget list(
    List<int> items, {
    required Future<void> Function()? onLoadMore,
    bool hasMore = false,
    bool isLoading = false,
  }) => PagedCardList<int>(
    items: items,
    itemBuilder: (context, item) => TextButton(onPressed: () {}, child: Text('行$item')),
    hasMore: hasMore,
    isLoading: isLoading,
    onLoadMore: onLoadMore,
  );

  Future<void> turnTo(WidgetTester tester, String page) async {
    await tester.tap(find.text(page));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a page slices the list, and the pager counts its local pages', (tester) async {
    final items = [for (var i = 0; i < 75; i++) i]; // three pages of thirty
    var asks = 0;
    await show(tester, list(items, onLoadMore: () async => asks += 1));

    expect(find.text('行0'), findsOneWidget);
    expect(find.text('行30'), findsNothing); // the second page waits for its number
    expect(find.text('3'), findsOneWidget); // the whole list is in hand

    await turnTo(tester, '3');
    expect(asks, 0); // the whole list pages locally
    expect(find.text('行60'), findsOneWidget);
    expect(find.text('行0'), findsNothing);
  });

  testWidgets('a past-the-hand press asks once and moves when the block arrived', (tester) async {
    final items = [for (var i = 0; i < 60; i++) i]; // two pages in hand
    var asks = 0;
    await show(
      tester,
      list(
        items,
        hasMore: true,
        onLoadMore: () async {
          asks += 1;
          items.addAll([for (var i = items.length; i < items.length + 30; i++) i]);
        },
      ),
    );

    expect(find.text('2'), findsOneWidget); // the in-hand page and the one ahead
    await turnTo(tester, '2');
    expect(asks, 0); // in hand

    await turnTo(tester, '3'); // past the hand: the source is asked
    expect(asks, 1);
    expect(find.text('行60'), findsOneWidget); // the block arrived, the page moved
  });

  testWidgets('a press while a page is in flight is dropped where it stands', (tester) async {
    final items = [for (var i = 0; i < 60; i++) i];
    var asks = 0;
    await show(tester, list(items, isLoading: true, onLoadMore: () async => asks += 1));

    await tester.drag(find.text('行0').first, const Offset(0, -300));
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.pixels, greaterThan(0));

    await turnTo(tester, '2');
    expect(asks, 0);
    expect(find.text('行0'), findsNothing); // the page did not move

    // a dropped press changes nothing: the list stays where the wheel left it
    expect(scrollable.position.pixels, 280.0);
  });

  testWidgets("a fresh page starts at its head on the list's own controller", (tester) async {
    final items = [for (var i = 0; i < 95; i++) i];
    var asks = 0;
    await show(tester, list(items, onLoadMore: () async => asks += 1)); // no caller controller

    await tester.drag(find.text('行0').first, const Offset(0, -300));
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.pixels, greaterThan(0));

    await turnTo(tester, '2');
    expect(find.text('行30'), findsOneWidget);
    expect(scrollable.position.pixels, 0); // the head, on the list's own controller too
  });
}
