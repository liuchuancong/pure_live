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
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/live/history/history_page.dart';
import 'package:pure_live/modules/live/history/history_repository.dart';
import 'package:pure_live/shared/images/app_image_cache.dart' show installLiveCacheManager;

/// The history page end to end over the real providers on the in-memory
/// store: the day sections, the one-record removal through its confirm,
/// and the word the toolbar hands into the filter.
void main() {
  setUpAll(() {
    // The room cards' covers go through the app's image cache; a throwaway
    // manager over a temp folder keeps the test bare of the boot.
    final root = Directory.systemTemp.createTempSync('history-page-test');
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

  LiveRoom roomOf(String platform, String id, {String? title}) => LiveRoom.normalized(
    platform: platform,
    roomId: id,
    content: RoomContent.of(title: title ?? 'Room $id'),
  );

  /// Seeds three records: Alpha today, Beta yesterday, Gamma two days ago.
  Future<void> seed() async {
    final store = await StorageStores.instance.openStore('history');
    final repository = HistoryRepository(store);
    final now = DateTime.now().toUtc();
    await repository.record(roomOf('douyu', '1', title: 'Alpha'), now);
    await repository.record(roomOf('huya', '2', title: 'Beta'), now.subtract(const Duration(days: 1)));
    await repository.record(roomOf('douyu', '3', title: 'Gamma'), now.subtract(const Duration(days: 2)));
  }

  Future<void> showHistory(WidgetTester tester) async {
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
          child: const DsScope(
            child: MaterialApp(home: Scaffold(body: HistoryPage())),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Translations tOf(WidgetTester tester) => tester.element(find.byType(HistoryPage)).t;

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(HistoryPage)));

  Future<void> closeHistory(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('an empty page asks for a first watch', (tester) async {
    await showHistory(tester);
    final t = tOf(tester);
    expect(find.text(t.history.emptyTitle), findsOneWidget);
    expect(find.text(t.history.emptyDescription), findsOneWidget);
    await closeHistory(tester);
  });

  testWidgets('the records sit in their day sections', (tester) async {
    await seed();
    await showHistory(tester);
    final t = tOf(tester);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    expect(find.text(t.history.today), findsOneWidget);
    expect(find.text(t.history.yesterday), findsOneWidget);
    expect(find.text(t.history.earlier), findsOneWidget);
    await closeHistory(tester);
  });

  testWidgets("a record's ✕ asks, then the record is gone", (tester) async {
    await seed();
    await showHistory(tester);
    final t = tOf(tester);
    final semantics = tester.ensureSemantics();

    await tester.tap(find.bySemanticsLabel(t.history.remove).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // The confirm names the room before anything leaves.
    expect(find.text(t.history.deleteConfirmTitle), findsOneWidget);
    await tester.tap(find.text(t.history.deleteAction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);
    semantics.dispose();
    await closeHistory(tester);
  });

  testWidgets("the toolbar's word narrows the records in place", (tester) async {
    await seed();
    await showHistory(tester);
    final t = tOf(tester);
    final container = containerOf(tester);

    container.read(historySearchHandoffProvider.notifier).hand('Beta');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(find.text(t.history.filterMatches(count: 1)), findsOneWidget);

    await tester.tap(find.text(t.history.filterReset));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Gamma'), findsOneWidget);
    await closeHistory(tester);
  });
}
