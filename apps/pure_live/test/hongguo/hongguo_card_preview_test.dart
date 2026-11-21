import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/features/settings/surface/settings_widgets.dart' show SettingsConfigRow;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/hongguo/controller/hongguo_card_settings.dart';
import 'package:pure_live/modules/hongguo/widgets/hongguo_card_preview.dart';
import 'package:pure_live/modules/hongguo/widgets/hongguo_widgets.dart' show HongguoSeriesCard, HongguoSeriesRow;

/// The card preview page and its panel: the poster card's panel offers every
/// piece while the list row's keeps to the one switch a row can move, a
/// switch writes through to the set every surface reads, the switches move
/// the sample on the stage (the corner keeps one state, the heart is the
/// sample's own and writes nothing), the list design swaps the stage and
/// thins the panel, and the reset asks first — the dialog's answer is the
/// only one that acts. The controller under these mounts keeps the set in
/// memory only: the write's landing in the store is the controller's own
/// contract, and a store write never lands under the widget test's clock.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  Finder switchOf(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(SettingsConfigRow)),
    matching: find.byType(DsSwitch),
  );

  Finder dsIcon(DsIconData data) => find.byWidgetPredicate((widget) => widget is DsIcon && widget.icon == data);

  Future<ProviderContainer> showPanel(WidgetTester tester, {required bool coverPieces}) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final runtime = PlatformBootstrap.init(
      appNamespace: 'pure_live',
      declaredDistribution: DesktopDistribution.unknown,
      formFactor: FormFactor.desktop,
      debug: true,
    );
    final container = ProviderContainer(
      overrides: [
        platformRuntimeProvider.overrideWithValue(runtime),
        hongguoCardSettingsProvider.overrideWith(_MemoryCardSettings.new),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TranslationProvider(
          child: DsScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: HongguoCardSettings(coverPieces: coverPieces)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  Future<Translations> showPage(WidgetTester tester) async {
    // The view directly, not setSurfaceSize: the surface call reshapes the
    // render constraints but the MediaQuery this page reads keeps the 800 by
    // 600 default, and the page folds its panel away as a narrow window.
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
        overrides: [
          platformRuntimeProvider.overrideWithValue(runtime),
          hongguoCardSettingsProvider.overrideWith(_MemoryCardSettings.new),
        ],
        child: TranslationProvider(
          child: const DsScope(child: MaterialApp(home: HongguoCardPreviewPage())),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return tester.element(find.byType(HongguoCardPreviewPage)).t;
  }

  const card = HongguoSeriesCard;
  Finder stageOf(Finder child) => find.descendant(of: find.byType(card), matching: child);

  testWidgets('the poster card panel offers every piece, two dark by design', (tester) async {
    final container = await showPanel(tester, coverPieces: true);
    final t = tester.element(find.byType(SettingsConfigRow).first).t;
    final labels = [
      t.settings.hongguoCardRank,
      t.settings.hongguoCardTags,
      t.settings.hongguoCardToday,
      t.settings.hongguoCardScore,
      t.settings.hongguoCardEpisodes,
      t.settings.hongguoCardFavorite,
      t.settings.hongguoCardHot,
      t.settings.hongguoCardCategory,
      t.settings.hongguoCardMeta,
    ];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }

    // The designed default: the episode count and the score sit dark, the
    // rest drawn.
    expect(tester.widget<DsSwitch>(switchOf(labels[4])).value, isFalse);
    expect(tester.widget<DsSwitch>(switchOf(labels[3])).value, isFalse);
    expect(tester.widget<DsSwitch>(switchOf(labels[2])).value, isTrue);
    expect(tester.widget<DsSwitch>(switchOf(labels[8])).value, isTrue);
    expect(container.read(hongguoCardSettingsProvider), HongguoCardVisibility.standard);
  });

  testWidgets('the list row panel keeps to the one switch a row can move', (tester) async {
    await showPanel(tester, coverPieces: false);
    final t = tester.element(find.byType(SettingsConfigRow).first).t;

    expect(find.text(t.settings.hongguoCardMeta), findsOneWidget);
    // A row folds every cover piece into its listing line, so a switch here
    // would move nothing on the stage — the panel does not offer them.
    expect(find.text(t.settings.hongguoCardRank), findsNothing);
    expect(find.text(t.settings.hongguoCardTags), findsNothing);
    expect(find.text(t.settings.hongguoCardToday), findsNothing);
    expect(find.text(t.settings.hongguoCardScore), findsNothing);
    expect(find.text(t.settings.hongguoCardEpisodes), findsNothing);
    expect(find.text(t.settings.hongguoCardFavorite), findsNothing);
    expect(find.text(t.settings.hongguoCardHot), findsNothing);
    expect(find.text(t.settings.hongguoCardCategory), findsNothing);
  });

  testWidgets('a switch writes its piece through to the set every surface reads', (tester) async {
    final container = await showPanel(tester, coverPieces: true);
    final t = tester.element(find.byType(SettingsConfigRow).first).t;

    expect(container.read(hongguoCardSettingsProvider).shows(HongguoCardElement.score), isFalse);

    await tester.tap(switchOf(t.settings.hongguoCardScore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.widget<DsSwitch>(switchOf(t.settings.hongguoCardScore)).value, isTrue); // the switch reads back
    expect(container.read(hongguoCardSettingsProvider).shows(HongguoCardElement.score), isTrue);
    expect(container.read(hongguoCardSettingsProvider).shows(HongguoCardElement.episodes), isFalse); // the rest kept
  });

  testWidgets('the stage draws the poster card with its corners and its inert heart', (tester) async {
    final t = await showPage(tester);

    expect(stageOf(find.text(t.settings.hongguoCardPreviewTitle)), findsOneWidget); // the sample's own name
    expect(stageOf(find.text(t.hongguo.todayTag)), findsOneWidget); // the corner's newest marker
    expect(stageOf(find.text('8.6')), findsNothing); // the score sits dark by design

    // The sample's heart is drawn, and writes nothing: the mark the caller
    // gave is the sample's own, not this device's shelf.
    final heart = find.ancestor(of: stageOf(dsIcon(DsIcons.heart)), matching: find.byType(DsButton));
    expect(tester.widget<DsButton>(heart.first).onPressed, isNull);
  });

  testWidgets('the switches move the sample on the stage', (tester) async {
    final t = await showPage(tester);

    await tester.ensureVisible(switchOf(t.settings.hongguoCardFavorite));
    await tester.tap(switchOf(t.settings.hongguoCardFavorite));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(stageOf(dsIcon(DsIcons.heart)), findsNothing); // the heart leaves the cover

    await tester.tap(switchOf(t.settings.hongguoCardToday));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(stageOf(find.text(t.hongguo.todayTag)), findsNothing); // the corner empties

    await tester.ensureVisible(switchOf(t.settings.hongguoCardScore));
    await tester.tap(switchOf(t.settings.hongguoCardScore));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(stageOf(find.text('8.6')), findsOneWidget); // the corner's next candidate takes it
  });

  testWidgets('the list design swaps the stage and thins the panel to one switch', (tester) async {
    final t = await showPage(tester);

    expect(find.byType(HongguoSeriesCard), findsOneWidget);
    expect(find.byType(HongguoSeriesRow), findsNothing);
    expect(find.byType(HongguoCardSettings), findsOneWidget);
    expect(find.text(t.settings.hongguoCardRank), findsOneWidget); // every piece offered

    await tester.tap(dsIcon(DsIcons.layoutList)); // the strip's list circle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(HongguoSeriesRow), findsOneWidget); // the row on the stage
    expect(find.byType(HongguoSeriesCard), findsNothing);
    expect(find.text(t.settings.hongguoCardPreviewIntro), findsOneWidget); // the row's own third line
    expect(find.byType(HongguoCardSettings), findsOneWidget);
    expect(find.text(t.settings.hongguoCardRank), findsNothing); // the cover pieces leave the panel
    expect(find.text(t.settings.hongguoCardMeta), findsOneWidget); // the one a row can move stays
    expect(find.textContaining(t.hongguo.episodesCount(count: 80)), findsOneWidget); // the listing line

    await tester.tap(switchOf(t.settings.hongguoCardMeta));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining(t.hongguo.episodesCount(count: 80)), findsNothing); // the line closes
    expect(find.text(t.settings.hongguoCardPreviewIntro), findsOneWidget); // the synopsis is the row's own
  });

  testWidgets('the reset asks first, and the answer is the only one that acts', (tester) async {
    final t = await showPage(tester);

    await tester.ensureVisible(switchOf(t.settings.hongguoCardToday));
    await tester.tap(switchOf(t.settings.hongguoCardToday));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(stageOf(find.text(t.hongguo.todayTag)), findsNothing); // the ask's subject

    await tester.tap(dsIcon(DsIcons.rotateCcw));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(t.settings.hongguoCardResetConfirmTitle), findsOneWidget); // the ask is on stage

    await tester.tap(find.text(t.common.cancel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(stageOf(find.text(t.hongguo.todayTag)), findsNothing); // the answer was no

    await tester.tap(dsIcon(DsIcons.rotateCcw));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text(t.settings.hongguoCardResetCurrent)); // the danger button's own words
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(stageOf(find.text(t.hongguo.todayTag)), findsOneWidget); // back to the design
  });
}

/// The controller this file's mounts run under: the set lives in memory only.
/// A store write never lands under the widget test's clock — the fire-and-
/// forget put stays pending and the tear-down's close would wait on it — and
/// the write's landing is the controller's own contract, pinned where the
/// clock is real.
final class _MemoryCardSettings extends HongguoCardSettingsController {
  @override
  Future<void> set(HongguoCardVisibility visibility) async {
    state = visibility;
  }
}
