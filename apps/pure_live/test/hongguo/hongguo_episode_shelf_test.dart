import 'dart:io' show Directory;

import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_cache/live_cache.dart' show LiveCacheManager;
import 'package:live_net/live_net.dart' show ClientProfile, DioFactory;
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart' show HongguoWatchProgress;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart'
    show HongguoEpisode, HongguoSeriesDetail, HongguoSeriesMeta;
import 'package:pure_live/modules/hongguo/widgets/hongguo_episode_shelf.dart' show hongguoEpisodeMarks;
import 'package:pure_live/shared/images/app_image_cache.dart' show installLiveCacheManager;

/// The episode shelf: the watch marks every surface reads the same way, the
/// grouping by place in the loaded list (not by episode number), the range
/// tabs' labels, and the shelf on stage — one group's numbers as chips, the
/// playing one filled, a move of the current episode walking the pages.
void main() {
  setUpAll(() {
    final root = Directory.systemTemp.createTempSync('hongguo-shelf-test');
    addTearDown(() => root.deleteSync(recursive: true));
    installLiveCacheManager(
      LiveCacheManager(
        directory: root,
        http: DioFactory().create(profile: ClientProfile.media),
      ),
    );
  });

  group('the marks and the groups', () {
    test('the watch marks: finished takes the tick, a stopped one the resume, none takes none', () {
      expect(hongguoEpisodeMarks(null), (watchedThrough: 0, resumeAt: null));

      const finished = HongguoWatchProgress(
        seriesId: '7100001',
        title: '剧',
        cover: '',
        episodeIndex: 7,
        episodeVid: 'vid7',
        positionMs: 0,
        durationMs: 1000,
        completed: true,
        updatedAt: 0,
      );
      expect(hongguoEpisodeMarks(finished), (watchedThrough: 7, resumeAt: null)); // done: no resume

      const halfway = HongguoWatchProgress(
        seriesId: '7100001',
        title: '剧',
        cover: '',
        episodeIndex: 7,
        episodeVid: 'vid7',
        positionMs: 300,
        durationMs: 1000,
        completed: false,
        updatedAt: 0,
      );
      expect(hongguoEpisodeMarks(halfway), (watchedThrough: 6, resumeAt: 7)); // six done, the seventh open
    });

    test("the group is the episode's place in the list, an unknown one at the start", () {
      final episodes = [for (var i = 1; i <= 45; i++) HongguoEpisode(index: i, vid: 'vid$i')];
      expect(hongguoEpisodeGroupOf(episodes, null), 0);
      expect(hongguoEpisodeGroupOf(episodes, const HongguoEpisode(index: 9, vid: 'nope')), 0); // not loaded here
      expect(hongguoEpisodeGroupOf(episodes, episodes[19]), 0); // the twentieth sits in the first page
      expect(hongguoEpisodeGroupOf(episodes, episodes[20]), 1);
      expect(hongguoEpisodeGroupOf(episodes, episodes[44]), 2);
    });

    test('the range labels name the numbers each page holds', () {
      final episodes = [for (var i = 1; i <= 102; i++) HongguoEpisode(index: i, vid: 'vid$i')];
      expect(hongguoEpisodeRangeLabel(episodes, 0), '1–20');
      expect(hongguoEpisodeRangeLabel(episodes, 4), '81–100');
      expect(hongguoEpisodeRangeLabel(episodes, 5), '101–102'); // the short last page
      expect(hongguoEpisodeRangeLabel(episodes.sublist(0, 5), 0), '1–5');
    });
  });

  group('the shelf on stage', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    HongguoSeriesDetail detailOf(int count) => HongguoSeriesDetail(
      meta: const HongguoSeriesMeta(seriesId: '7100001', title: '剧'),
      episodes: [for (var i = 1; i <= count; i++) HongguoEpisode(index: i, vid: 'vid$i')],
    );

    Future<void> showShelf(
      WidgetTester tester, {
      required HongguoSeriesDetail detail,
      required ValueChanged<HongguoEpisode> onOpen,
      HongguoEpisode? current,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
                  body: SingleChildScrollView(
                    child: HongguoEpisodeShelf(detail: detail, current: current, onOpen: onOpen),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets("the current episode's page is on stage, the playing chip filled", (tester) async {
      var opened = '';
      await showShelf(
        tester,
        detail: detailOf(45),
        current: const HongguoEpisode(index: 30, vid: 'vid30'),
        onOpen: (episode) => opened = episode.vid,
      );

      expect(find.text('1–20'), findsOneWidget);
      expect(find.text('21–40'), findsOneWidget);
      expect(find.text('41–45'), findsOneWidget);
      expect(find.text('21'), findsOneWidget); // the current group's numbers
      expect(find.text('40'), findsOneWidget);
      expect(find.text('1'), findsNothing); // the first page is off stage
      expect(find.text('30'), findsOneWidget); // the playing one among them

      await tester.tap(find.text('21'));
      await tester.pump();
      expect(opened, 'vid21'); // a chip opens its episode
    });

    testWidgets('a move of the current episode walks the pages under it', (tester) async {
      final detail = detailOf(45);
      HongguoEpisode? current = const HongguoEpisode(index: 30, vid: 'vid30');
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
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
                  body: SingleChildScrollView(
                    child: HongguoEpisodeShelf(detail: detail, current: current, onOpen: (_) {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('21–40'), findsOneWidget);
      expect(find.text('5'), findsNothing); // the first page is off stage

      current = const HongguoEpisode(index: 5, vid: 'vid5'); // the player went back to the opening
      await tester.pumpWidget(
        ProviderScope(
          overrides: [platformRuntimeProvider.overrideWithValue(runtime)],
          child: TranslationProvider(
            child: DsScope(
              child: MaterialApp(
                home: Scaffold(
                  body: SingleChildScrollView(
                    child: HongguoEpisodeShelf(detail: detail, current: current, onOpen: (_) {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('1'), findsOneWidget); // the first page walked in
      expect(find.text('5'), findsOneWidget);
      expect(find.text('30'), findsNothing);
    });

    testWidgets('a short series shows no range tabs', (tester) async {
      await showShelf(tester, detail: detailOf(12), onOpen: (_) {});
      expect(find.text('1–20'), findsNothing); // one page needs no tabs
      expect(find.text('12'), findsNWidgets(2)); // the header's count and the chip agree
    });
  });
}
