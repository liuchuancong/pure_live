import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/shared/grids/card_grid.dart';

/// The one feed widget every wall renders through: the items on the wall,
/// the first load's skeletons, the empty pane's words, a failure's pane and
/// its retry, the endless feed's one ask at the end (and a pager's none),
/// and the bar a failed refresh keeps over the cards.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  Future<Translations> show(WidgetTester tester, Widget grid) async {
    // The view directly: the surface call leaves the MediaQuery at its
    // default, and the grid reads the width it is laid out in.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });
    final runtime = PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [platformRuntimeProvider.overrideWithValue(runtime)],
        child: TranslationProvider(
          child: DsScope(
            child: MaterialApp(
              home: Scaffold(
                body: Center(child: SizedBox(width: 800, height: 600, child: grid)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return tester.element(find.byType(CardGrid<String>).first).t;
  }

  Widget grid(
    List<String> items, {
    bool isLoading = false,
    bool hasMore = false,
    Future<void> Function()? onLoadMore,
    bool paged = false,
    String? error,
    VoidCallback? onRetry,
    String? emptyTitle,
    String? refreshError,
    VoidCallback? onRefreshRetry,
    ScrollController? controller,
  }) => CardGrid<String>(
    items: items,
    itemBuilder: (context, item) => Text(item),
    isLoading: isLoading,
    hasMore: hasMore,
    onLoadMore: onLoadMore,
    paged: paged,
    error: error,
    onRetry: onRetry,
    emptyTitle: emptyTitle,
    refreshError: refreshError,
    onRefresh: onRefreshRetry == null ? null : () async => onRefreshRetry(),
    scrollController: controller,
  );

  testWidgets('the items stand on the wall', (tester) async {
    await show(tester, grid(['甲', '乙', '丙']));

    expect(find.text('甲'), findsOneWidget);
    expect(find.text('乙'), findsOneWidget);
    expect(find.text('丙'), findsOneWidget);
  });

  testWidgets('a first load fills the window with skeletons', (tester) async {
    await show(tester, grid(const [], isLoading: true));

    expect(find.byType(DsSkeleton), findsWidgets); // the window's worth, at least
    expect(find.text('甲'), findsNothing);
  });

  testWidgets('an empty shelf says its words', (tester) async {
    await show(tester, grid(const [], emptyTitle: '这里还没有内容'));

    expect(find.text('这里还没有内容'), findsOneWidget);
    expect(find.byType(DsSkeleton), findsNothing);
  });

  testWidgets('a failure with nothing loaded names itself and reads again', (tester) async {
    var reads = 0;
    final t = await show(tester, grid(const [], error: '推荐没读上', onRetry: () => reads += 1));

    expect(find.text('推荐没读上'), findsOneWidget);
    await tester.tap(find.text(t.common.retry));
    await tester.pump();
    expect(reads, 1); // the pane reads again
  });

  testWidgets('an endless feed asks once at the end', (tester) async {
    final controller = ScrollController();
    var asks = 0;
    await show(
      tester,
      grid(
        [for (var i = 1; i <= 40; i++) '卡$i'],
        hasMore: true,
        onLoadMore: () async => asks += 1,
        controller: controller,
      ),
    );

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(asks, 1); // the end asked once

    controller.jumpTo(controller.position.minScrollExtent);
    await tester.pump();
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(asks, 2); // away and back asks again, once
  });

  testWidgets('a pager feed never asks from the scroll', (tester) async {
    final controller = ScrollController();
    var asks = 0;
    await show(
      tester,
      grid(
        [for (var i = 1; i <= 40; i++) '卡$i'],
        hasMore: true,
        onLoadMore: () async => asks += 1,
        paged: true,
        controller: controller,
      ),
    );

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(asks, 0); // the wheel is not the pager
  });

  testWidgets('a failed refresh keeps its bar over the cards', (tester) async {
    var reads = 0;
    final t = await show(tester, grid(const ['甲'], refreshError: '刷新没成', onRefreshRetry: () => reads += 1));

    expect(find.text('刷新没成'), findsOneWidget); // the reason rides the bar
    expect(find.text('甲'), findsOneWidget); // the cards it kept stay
    await tester.tap(find.text(t.common.retry));
    await tester.pump();
    expect(reads, 1); // the bar reads again
  });
}
