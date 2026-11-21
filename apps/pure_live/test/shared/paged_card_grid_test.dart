import 'package:desen_ui/desen_ui.dart' show DsScope;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/shared/grids/paged_card_grid.dart';

/// The paged feed's pager: the page the viewer names sliced out of the
/// accumulated list, the count one page ahead while the source may continue,
/// a press past the hand asking for one block and moving only when it grew,
/// a press while a page is in flight dropped, a list that shrank keeping the
/// viewer on the last page left, and every fresh page starting at its head —
/// on the caller's controller or the grid's own.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  Widget wrap(WidgetTester tester, Widget grid) {
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
            home: Scaffold(body: SizedBox(width: 800, height: 600, child: grid)),
          ),
        ),
      ),
    );
  }

  Future<void> show(WidgetTester tester, Widget grid) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    await tester.pumpWidget(wrap(tester, grid));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Widget grid(
    List<int> items, {
    required Future<void> Function() onLoadMore,
    bool hasMore = false,
    bool isLoading = false,
    ScrollController? controller,
  }) => PagedCardGrid<int>(
    items: items,
    itemBuilder: (context, item) => TextButton(onPressed: () {}, child: Text('卡$item')),
    hasMore: hasMore,
    isLoading: isLoading,
    onLoadMore: onLoadMore,
    scrollController: controller,
  );

  Future<void> turnTo(WidgetTester tester, String page) async {
    await tester.tap(find.text(page));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a page slices the list, and a whole-in-hand pager never asks', (tester) async {
    final items = [for (var i = 0; i < 95; i++) i]; // four pages of 30
    var asks = 0;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await show(tester, grid(items, onLoadMore: () async => asks += 1, controller: controller));

    expect(find.text('卡0'), findsOneWidget);
    expect(find.text('卡5'), findsOneWidget); // the first thirty, the built rows of them
    expect(find.text('卡30'), findsNothing); // the second page waits for its number
    expect(find.text('4'), findsOneWidget); // the pager counts the local pages

    await turnTo(tester, '2');
    expect(find.text('卡30'), findsOneWidget);
    expect(find.text('卡0'), findsNothing);
    expect(asks, 0); // a page in hand moves without a request

    controller.jumpTo(500);
    await tester.pump();
    await turnTo(tester, '4'); // the short last page: five cards
    expect(find.text('卡90'), findsOneWidget);
    expect(find.text('卡94'), findsOneWidget);
    expect(find.text('卡95'), findsNothing);
    expect(controller.offset, 0); // the fresh page starts at its head
  });

  testWidgets('the pager counts one ahead, and the past-the-hand press asks', (tester) async {
    final items = [for (var i = 0; i < 60; i++) i]; // two pages in hand
    var asks = 0;
    await show(
      tester,
      grid(
        items,
        hasMore: true,
        onLoadMore: () async {
          asks += 1;
          items.addAll([for (var i = items.length; i < items.length + 30; i++) i]);
        },
      ),
    );

    expect(find.text('2'), findsOneWidget); // the in-hand page and the one ahead: two stops
    expect(find.text('3'), findsNothing);
    await turnTo(tester, '2');
    expect(asks, 0); // in hand: no ask

    expect(find.text('3'), findsOneWidget); // now the pager counts three
    await turnTo(tester, '3'); // past the hand: the source is asked
    expect(asks, 1);
    expect(find.text('卡60'), findsOneWidget); // the block arrived, the page moved
    expect(find.text('卡65'), findsOneWidget);
  });

  testWidgets('a block that does not grow keeps the pager where it was', (tester) async {
    final items = [for (var i = 0; i < 60; i++) i];
    var asks = 0;
    await show(tester, grid(items, hasMore: true, onLoadMore: () async => asks += 1));

    await turnTo(tester, '2'); // in hand
    await turnTo(tester, '3'); // past the hand: the source answers nothing new
    expect(asks, 1);
    expect(find.text('卡30'), findsOneWidget); // page two still shows
    expect(find.text('卡60'), findsNothing);
  });

  testWidgets('a press while a page is in flight is dropped', (tester) async {
    final items = [for (var i = 0; i < 60; i++) i];
    var asks = 0;
    await show(tester, grid(items, isLoading: true, onLoadMore: () async => asks += 1));

    await turnTo(tester, '2');
    expect(asks, 0);
    expect(find.text('卡0'), findsOneWidget); // the page did not move
  });

  testWidgets('a list that shrank keeps the viewer on the last page left', (tester) async {
    final items = [for (var i = 0; i < 90; i++) i];
    var asks = 0;
    final widget = grid(items, onLoadMore: () async => asks += 1);
    await show(tester, widget);

    await turnTo(tester, '3'); // the viewer reads page three of three
    expect(find.text('卡60'), findsOneWidget);

    // a new query's shorter list arrives under the same widget: the same
    // wrapper keeps the element, so the asked page survives to be clamped
    await tester.pumpWidget(wrap(tester, grid(items.sublist(0, 50), onLoadMore: () async => asks += 1)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('卡30'), findsOneWidget); // the last page left: thirty to fifty
    expect(find.text('卡35'), findsOneWidget);
    expect(find.text('卡60'), findsNothing);
    expect(find.text('3'), findsNothing); // the pager shrunk with the list
  });

  testWidgets("a fresh page starts at its head on the grid's own controller", (tester) async {
    final items = [for (var i = 0; i < 95; i++) i];
    var asks = 0;
    await show(tester, grid(items, onLoadMore: () async => asks += 1)); // no caller controller

    await tester.drag(find.text('卡0').first, const Offset(0, -300)); // the wheel's worth
    await tester.pump();
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.pixels, greaterThan(0));

    await turnTo(tester, '2');
    expect(find.text('卡30'), findsOneWidget);
    expect(scrollable.position.pixels, 0); // the head, on the grid's own controller too
  });
}
