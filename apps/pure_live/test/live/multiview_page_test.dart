import 'package:desen_ui/desen_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_sites/live_sites.dart';
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/features/settings/playback/player_tuning.dart' show playerProxyProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/modules/live/favorites/favorites.dart';
import 'package:pure_live/modules/live/multiview/multiview_controller.dart';
import 'package:pure_live/modules/live/multiview/multiview_page.dart';

/// The wall page end to end over the real providers — the playback owner
/// among them, safe here because an empty wall never opens an engine — on
/// the in-memory store. What these argue about is the page's own
/// behaviour: the wall's shape, the picker's arrival on a wide and a
/// narrow window, and what a pick lands as.
void main() {
  setUp(() async {
    await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  LiveRoom room(String platform, String id) => LiveRoom.normalized(
    platform: platform,
    roomId: id,
    content: RoomContent.of(title: 'Room $id'),
  );

  /// Preloads one follow through its own throwaway container: the storage
  /// singleton is shared, so the widget tree's own container reads it.
  Future<void> seedFollow() async {
    final seeder = ProviderContainer();
    addTearDown(seeder.dispose);
    await seeder.read(followRepositoryProvider.future);
    await seeder.read(followsProvider.notifier).add(room('douyu', '1'));
    await seeder.read(multiviewRepositoryProvider.future);
  }

  Future<void> showWall(WidgetTester tester, {Size size = const Size(1200, 800)}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
          // The playback owner listens to the proxy reading; the real one
          // probes the Windows registry on a three-second timer, which a
          // widget test must not carry.
          playerProxyProvider.overrideWithValue(null),
        ],
        child: TranslationProvider(
          child: const DsScope(
            child: MaterialApp(home: Scaffold(body: MultiviewPage())),
          ),
        ),
      ),
    );
    // Two settled beats: the dock mounts one frame after the page, and the
    // repositories it watches only start opening at that mount — the second
    // beat lets their answers land and the picker rebuild with rows.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  Translations tOf(WidgetTester tester) => tester.element(find.byType(MultiviewPage)).t;

  /// Ends a test the way the wall leaves the screen: the page unmounts
  /// first, so the skeleton's repeating animation releases its timer and
  /// the playback owner's goodbye lands before the invariants check.
  Future<void> closeWall(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('an empty wall invites on every pane of the default arrangement', (tester) async {
    await showWall(tester);
    expect(find.text(tOf(tester).multiview.addRoom), findsNWidgets(4));
    // The cells name themselves for the picker's 「第 N 格」.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    await closeWall(tester);
  });

  testWidgets('a first visit opens the picker beside the wall, and a pick fills the cell', (tester) async {
    await seedFollow();
    await showWall(tester);
    final t = tOf(tester);
    // The dock opened on the first empty cell by itself.
    expect(find.text(t.multiview.pickerTitle(index: 1)), findsOneWidget);
    // The followed room is one pick away.
    await tester.tap(find.text('Room 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    // The pick landed in cell 1 and the dock moved to cell 2 — filling a
    // wall is a run of picks.
    final container = ProviderScope.containerOf(tester.element(find.byType(MultiviewPage)));
    expect(container.read(multiviewProvider).slots, ['douyu:1', null, null, null]);
    expect(find.text(t.multiview.pickerTitle(index: 2)), findsOneWidget);
    await closeWall(tester);
  });

  testWidgets('a narrow window picks in a sheet over the wall, and one pick closes it', (tester) async {
    await seedFollow();
    await showWall(tester, size: const Size(500, 800));
    final t = tOf(tester);
    // No dock on arrival; the empty pane's tap opens the sheet for that
    // cell.
    expect(find.text(t.multiview.pickerTitle(index: 1)), findsNothing);
    await tester.tap(find.text(t.multiview.addRoom).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(t.multiview.pickerTitle(index: 1)), findsOneWidget);
    // One pick per open: the room lands, the sheet goes, the cell stays.
    await tester.tap(find.text('Room 1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(tester.element(find.byType(MultiviewPage)));
    expect(container.read(multiviewProvider).slots, ['douyu:1', null, null, null]);
    expect(find.text(t.multiview.pickerTitle(index: 1)), findsNothing);
    await closeWall(tester);
  });

  testWidgets('switching the arrangement redraws the wall', (tester) async {
    await showWall(tester);
    final t = tOf(tester);
    await tester.tap(find.text('1×1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    final container = ProviderScope.containerOf(tester.element(find.byType(MultiviewPage)));
    expect(container.read(multiviewProvider).layout, MultiviewLayout.single);
    expect(find.text(t.multiview.addRoom), findsOneWidget);
    expect(find.text('4'), findsNothing);
    await closeWall(tester);
  });
}
