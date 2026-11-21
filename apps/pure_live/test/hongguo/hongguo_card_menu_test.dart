import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_library.dart'
    show HongguoFavoriteUpdate, HongguoLibraryState, HongguoWatchProgress;
import 'package:pure_live/modules/hongguo/controller/hongguo_models.dart' show HongguoSeries;
import 'package:pure_live/modules/hongguo/widgets/hongguo_card_menu.dart';
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart'
    show hongguoFavoriteLine, hongguoResumeSeconds, hongguoSeriesListingLine, hongguoWatchedLabel;
import 'package:pure_live/shared/utils/audience_format.dart' show AudienceFormat;

/// The card menu's own words and its presence: what "where this device
/// stopped" means, whether a listing's row opens at all, the one listing
/// line a title gets and the pieces the caller can turn off, a favorite's
/// two total readings, and on stage — a published title wears the menu, an
/// unpublished reservation keeps its label and loses it.
void main() {
  testWidgets('the card-menu words answer their states', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    late Translations t;
    await tester.pumpWidget(
      TranslationProvider(
        child: DsScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                t = context.t;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    final t0 = t;
    const progress = HongguoWatchProgress(
      seriesId: '7100001',
      title: '剧',
      cover: '',
      episodeIndex: 12,
      episodeVid: 'vid12',
      positionMs: 90000,
      durationMs: 600000,
      completed: false,
      updatedAt: 0,
    );

    // Where this device stopped: a stopped episode at its seconds, anything
    // finished, blank or unidentified never resumes.
    expect(hongguoResumeSeconds(progress), 90.0);
    expect(
      hongguoResumeSeconds(
        const HongguoWatchProgress(
          seriesId: 's',
          title: '',
          cover: '',
          episodeIndex: 3,
          episodeVid: 'vid3',
          positionMs: 90000,
          durationMs: 600000,
          completed: true,
          updatedAt: 0,
        ),
      ),
      isNull,
    );
    expect(
      hongguoResumeSeconds(
        const HongguoWatchProgress(
          seriesId: 's',
          title: '',
          cover: '',
          episodeIndex: 12,
          episodeVid: 'vid12',
          positionMs: 0,
          durationMs: 600000,
          completed: false,
          updatedAt: 0,
        ),
      ),
      isNull,
    ); // never played: nothing to resume
    expect(hongguoResumeSeconds(null), isNull);

    // Whether a listing's row opens: an unpublished reservation does not.
    expect(hongguoSeriesOpenable(const HongguoSeries(seriesId: '7100001', title: '剧')), isTrue);
    expect(hongguoSeriesOpenable(const HongguoSeries(seriesId: 'reservation:7100001', title: '待上线')), isFalse);
    expect(hongguoSeriesOpenable(const HongguoSeries(seriesId: '', title: '无')), isFalse);

    // The shelf's two words about the same title.
    expect(hongguoWatchedLabel(t0, progress), t0.hongguo.favoriteWatchedTo(index: 12));
    expect(
      hongguoWatchedLabel(
        t0,
        const HongguoWatchProgress(
          seriesId: 's',
          title: '',
          cover: '',
          episodeIndex: 80,
          episodeVid: 'vid80',
          positionMs: 0,
          durationMs: 1,
          completed: true,
          updatedAt: 0,
        ),
      ),
      t0.hongguo.watchedBadge,
    );
  });

  testWidgets('the listing line joins the pieces, each one switchable', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    late Translations t;
    await tester.pumpWidget(
      TranslationProvider(
        child: DsScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                t = context.t;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    final t0 = t;
    const watched = HongguoWatchProgress(
      seriesId: 's',
      title: '',
      cover: '',
      episodeIndex: 12,
      episodeVid: 'vid12',
      positionMs: 0,
      durationMs: 1,
      completed: false,
      updatedAt: 0,
    );
    const series = HongguoSeries(seriesId: '7100001', title: '剧', episodeCount: 80, hot: '热度第一', category: '言情');

    expect(hongguoSeriesListingLine(t0, series), '${t0.hongguo.episodesCount(count: 80)} · 热度第一 · 言情');
    expect(
      hongguoSeriesListingLine(t0, series, watched: watched),
      '${t0.hongguo.favoriteWatchedTo(index: 12)} · ${t0.hongguo.episodesCount(count: 80)} · 热度第一 · 言情',
    ); // the viewer's own state leads the line
    expect(hongguoSeriesListingLine(t0, series, withEpisodeCount: false), '热度第一 · 言情');
    expect(hongguoSeriesListingLine(t0, series, withFigure: false), '${t0.hongguo.episodesCount(count: 80)} · 言情');
    expect(hongguoSeriesListingLine(t0, series, withCategory: false), '${t0.hongguo.episodesCount(count: 80)} · 热度第一');
    expect(
      hongguoSeriesListingLine(t0, series, note: '停在 12:00'),
      '${t0.hongguo.episodesCount(count: 80)} · 热度第一 · 言情 · 停在 12:00',
    );

    // A title with neither heat nor plays leaves the figure out whole.
    const quiet = HongguoSeries(seriesId: '7100002', title: '静', episodeCount: 3);
    expect(hongguoSeriesListingLine(t0, quiet), t0.hongguo.episodesCount(count: 3));
    const played = HongguoSeries(seriesId: '7100003', title: '热', episodeCount: 3, playCount: 12000);
    expect(
      hongguoSeriesListingLine(t0, played),
      '${t0.hongguo.episodesCount(count: 3)} · ${t0.hongguo.plays} ${AudienceFormat.format(12000)}',
    ); // the play count stands in when the heat is empty
  });

  testWidgets("a favorite's line reads the check's answer", (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    late Translations t;
    await tester.pumpWidget(
      TranslationProvider(
        child: DsScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                t = context.t;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    final t0 = t;
    const stopped = HongguoWatchProgress(
      seriesId: '7100001',
      title: '剧',
      cover: '',
      episodeIndex: 12,
      episodeVid: 'vid12',
      positionMs: 0,
      durationMs: 1,
      completed: false,
      updatedAt: 0,
    );
    const gained = HongguoLibraryState(
      history: [stopped],
      updates: {'7100001': HongguoFavoriteUpdate(total: 80, seen: 77, checkedAt: 1)},
    );
    const plain = HongguoLibraryState(history: [stopped]);
    const series = HongguoSeries(seriesId: '7100001', title: '剧', episodeCount: 77);

    expect(
      hongguoFavoriteLine(t0, gained, series),
      '${t0.hongguo.favoriteTotalAdded(total: 80, added: 3)} · ${t0.hongguo.favoriteWatchedTo(index: 12)}',
    ); // the gain the check found, and where the viewer stopped
    expect(
      hongguoFavoriteLine(t0, plain, series),
      '${t0.hongguo.favoriteTotal(total: 77)} · ${t0.hongguo.favoriteWatchedTo(index: 12)}',
    ); // no check yet: the card's own total
    expect(
      hongguoFavoriteLine(t0, plain, const HongguoSeries(seriesId: 'reservation:7100009', title: '待')),
      t0.hongguo.favoriteTotalPending, // the platform has not said, and nothing watched either
    );
    expect(
      hongguoFavoriteLine(
        t0,
        const HongguoLibraryState(
          history: [stopped],
          updates: {'7100001': HongguoFavoriteUpdate(total: 80, seen: 80, checkedAt: 1)},
        ),
        series,
      ),
      '${t0.hongguo.favoriteTotal(total: 80)} · ${t0.hongguo.favoriteWatchedTo(index: 12)}', // nothing gained
    );
  });

  group('the menu on stage', () {
    late StorageStores stores;

    setUp(() async {
      stores = await StorageStores.openInMemory();
      await StoragePrefs.init();
    });

    tearDown(() => stores.close());

    Future<void> showCard(WidgetTester tester, {required HongguoSeries series, VoidCallback? onOpen}) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));
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
                  body: Center(
                    child: SizedBox(
                      width: 200,
                      height: 120,
                      child: HongguoCardMenu(
                        series: series,
                        onOpen: onOpen,
                        child: ColoredBox(color: Colors.blue, child: Text(series.title)),
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
    }

    testWidgets('a published title wears the menu region', (tester) async {
      await showCard(
        tester,
        series: const HongguoSeries(seriesId: '7100001', title: '剧'),
        onOpen: () {},
      );
      expect(find.byType(DsContextMenuRegion), findsOneWidget);
    });

    testWidgets('an unpublished reservation keeps its label and loses the menu', (tester) async {
      // the row opens nowhere, so the host hands no verb over
      await showCard(
        tester,
        series: const HongguoSeries(seriesId: 'reservation:7100001', title: '待上线'),
      );
      expect(find.byType(DsContextMenuRegion), findsNothing);
      expect(find.text('待上线'), findsOneWidget); // the card itself stays
    });
  });
}
