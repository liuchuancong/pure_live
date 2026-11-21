import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart' show HongguoWatchProgress;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart'
    show HongguoFilterOption, HongguoFilterRow, HongguoSeries;
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart';
import 'package:pure_live/shared/shared.dart' show columnExtentForWidth;

/// The widgets module's own words and measures: the clock an episode's
/// length reads as, the columns a poster wall counts (and the width a tile
/// gets), the board row's place and marks, a filter row's one-choice chips,
/// the watched stripe's clamp, and a shelf's four answers — its cards, its
/// skeleton, its failure's retry, and its silence when it has nothing.
void main() {
  Translations tOf(WidgetTester tester, Type anchor) => tester.element(find.byType(anchor)).t;

  group('the clock', () {
    test('the length reads as the station pages print it', () {
      expect(hongguoDurationText(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
      expect(hongguoDurationText(const Duration(minutes: 2, seconds: 3)), '2:03'); // no hour, no hour field
      expect(hongguoDurationText(const Duration(hours: 1)), '1:00:00');
      expect(hongguoDurationText(const Duration(minutes: 12, seconds: 4)), '12:04'); // minutes stand bare
      expect(hongguoDurationText(const Duration(seconds: 5)), '0:05');
    });
  });

  group('the poster wall', () {
    test('the columns a row of content takes', () {
      expect(hongguoPosterColumns(0), 1); // no content, one column to draw in
      expect(hongguoPosterColumns(-10), 1);

      expect(hongguoPosterColumns(368), 2); // two tiles exactly
      expect(hongguoPosterColumns(380), 2); // a third would thin them past the floor
      expect(hongguoPosterColumns(400), 2);
      expect(hongguoPosterColumns(720), 4); // four whole tiles fit
    });

    test("the viewer's pin raises the count, to what still fits", () {
      expect(hongguoPosterColumns(380, pinned: 4), 2); // nothing more fits
      expect(hongguoPosterColumns(720, pinned: 6), 4); // the floor caps the raise
      expect(hongguoPosterColumns(720, pinned: 3), 4); // the width already says more
    });

    test("the tile width is the row's even share", () {
      expect(hongguoPosterExtentForWidth(368), closeTo(176, 0.01)); // the hair keeps the grid from tipping
      expect(hongguoPosterExtentForWidth(380), closeTo(182, 0.01)); // two columns share the row
      expect(hongguoPosterExtentForWidth(0), 176.0); // no content: the measure itself
      expect(hongguoPosterExtentForWidth(380, pinned: 4), closeTo(182, 0.01)); // the pin could not act
      expect(
        hongguoPosterExtentForWidth(368),
        columnExtentForWidth(368, hongguoPosterColumns(368), 16), // the share the grid takes
      );
    });
  });

  testWidgets('the board row grades its place and carries its marks', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: const DsScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HongguoRankRow(
                    series: HongguoSeries(
                      seriesId: '7100001',
                      title: '剧',
                      episodeCount: 80,
                      rank: 1,
                      hot: '热度第一',
                      score: '8.6',
                      favoriteText: '12.3万收藏',
                      likeText: '4.5万点赞',
                      coverTags: ['爆剧', '新剧', '独播'],
                      today: true,
                    ),
                    watched: HongguoWatchProgress(
                      seriesId: '7100001',
                      title: '剧',
                      cover: '',
                      episodeIndex: 12,
                      episodeVid: 'vid12',
                      positionMs: 0,
                      durationMs: 1,
                      completed: false,
                      updatedAt: 0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final t = tOf(tester, HongguoRankRow);

    expect(find.text('1'), findsOneWidget); // the board's own place
    expect(find.text('热度第一'), findsOneWidget); // the heat beside the name
    expect(find.text('12.3万收藏'), findsOneWidget);
    expect(find.text('4.5万点赞'), findsOneWidget);
    expect(find.text('爆剧'), findsOneWidget); // the station's tags, two at most
    expect(find.text('新剧'), findsOneWidget);
    expect(find.text('独播'), findsNothing);
    expect(find.text('8.6'), findsOneWidget);
    expect(find.text(t.hongguo.todayTag), findsOneWidget);
    // the listing line leads with the viewer's own place, and the figure the
    // heat already says beside the name is not printed a second time
    final listing = '${t.hongguo.favoriteWatchedTo(index: 12)} · ${t.hongguo.episodesCount(count: 80)}';
    expect(find.text(listing), findsOneWidget); // the place, then the total the line itself says
  });

  testWidgets('the board row falls back to the position it was given', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: const DsScope(
            child: MaterialApp(
              home: Scaffold(
                body: HongguoRankRow(
                  position: 7,
                  series: HongguoSeries(seriesId: '7100002', title: '静', episodeCount: 3),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('7'), findsOneWidget); // the listing's own place, when the title ranks none
    expect(find.byType(Wrap), findsNothing); // no marks, no wrap
  });

  testWidgets('a filter row is one choice, and the lit one lets itself go', (tester) async {
    final chosen = <String?>[];
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    const row = HongguoFilterRow(
      type: 'category_dim_theme',
      rowName: '题材',
      items: [
        HongguoFilterOption(id: 'theme:1', name: '甜宠'),
        HongguoFilterOption(id: 'theme:2', name: '复仇'),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: DsScope(
            child: MaterialApp(
              home: Scaffold(
                body: HongguoFilterRowView(row: row, selection: const {}, onSelect: chosen.add),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final t = tOf(tester, HongguoFilterRowView);

    expect(find.text('题材'), findsOneWidget); // the dimension heads the group
    expect(find.text(t.hongguo.filterAll), findsOneWidget);

    await tester.tap(find.text('甜宠'));
    await tester.pump();
    expect(chosen.single, 'theme:1'); // the option's own id

    await tester.tap(find.text(t.hongguo.filterAll));
    await tester.pump();
    expect(chosen.last, isNull); // 全部 is the clearing answer

    // choosing the lit one clears the dimension: the chip's own off answer
    final chip = tester.widget<DsChip>(find.ancestor(of: find.text('甜宠'), matching: find.byType(DsChip)));
    chip.onChanged?.call(false);
    await tester.pump();
    expect(chosen.last, isNull);
  });

  testWidgets('the watched stripe clamps its share', (tester) async {
    Future<double> stripeOf(double fraction) async {
      await tester.pumpWidget(
        DsScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(width: 100, height: 20, child: HongguoProgressStripe(fraction: fraction)),
            ),
          ),
        ),
      );
      final box = tester.widget<FractionallySizedBox>(
        find.descendant(of: find.byType(HongguoProgressStripe), matching: find.byType(FractionallySizedBox)),
      );
      return box.widthFactor!;
    }

    expect(await stripeOf(0.4), 0.4);
    expect(await stripeOf(2), 1.0); // no more than the whole
    expect(await stripeOf(-1), 0.0); // and never less than nothing
  });

  group('the shelf', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    Widget shelf(List<HongguoSeries> items, {bool loading = false, String? error, VoidCallback? onRetry}) => SizedBox(
      width: 400,
      child: HongguoShelf(
        title: '为您推荐',
        items: items,
        cardBuilder: (context, series) => Text(series.title),
        loading: loading,
        error: error,
        onRetry: onRetry,
      ),
    );

    Future<ProviderContainer> show(WidgetTester tester, Widget child) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final runtime = PlatformBootstrap.init(
        appNamespace: 'pure_live',
        declaredDistribution: DesktopDistribution.unknown,
        formFactor: FormFactor.desktop,
        debug: true,
      );
      final container = ProviderContainer(overrides: [platformRuntimeProvider.overrideWithValue(runtime)]);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: TranslationProvider(
            child: DsScope(
              child: MaterialApp(
                home: Scaffold(body: SingleChildScrollView(child: child)),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return container;
    }

    List<HongguoSeries> items(int count) => [
      for (var i = 1; i <= count; i++) HongguoSeries(seriesId: '71$i', title: '剧$i', episodeCount: i),
    ];

    testWidgets('the shelf draws one row of posters, not the whole list', (tester) async {
      await show(tester, shelf(items(6)));

      expect(find.text('为您推荐'), findsOneWidget);
      expect(find.text('剧1'), findsOneWidget);
      expect(find.text('剧2'), findsOneWidget);
      expect(find.text('剧3'), findsNothing); // a 400 px row holds two posters
    });

    testWidgets('a shelf reading its list shows the row of skeletons', (tester) async {
      await show(tester, shelf(const [], loading: true));

      expect(find.byType(DsSkeleton), findsNWidgets(2)); // one per column the row holds
    });

    testWidgets('a shelf with nothing and no ask stays quiet', (tester) async {
      await show(tester, shelf(const []));

      expect(find.byType(DsSkeleton), findsNothing);
      expect(find.text('剧1'), findsNothing);
    });

    testWidgets('a failure with nothing to show names itself and offers the read again', (tester) async {
      var reads = 0;
      await show(tester, shelf(const [], error: '推荐没读上', onRetry: () => reads += 1));

      expect(find.text('推荐没读上'), findsOneWidget);
      final t = tester.element(find.text('为您推荐')).t;
      await tester.tap(find.text(t.common.retry));
      await tester.pump();
      expect(reads, 1); // the retry reads the shelf again
    });

    testWidgets('a failure with titles on the wall keeps the wall', (tester) async {
      await show(tester, shelf(items(2), error: '推荐没读上'));

      expect(find.text('剧1'), findsOneWidget); // the titles it did read stay drawn
      expect(find.text('推荐没读上'), findsNothing); // and the failure says nothing
    });
  });
}
