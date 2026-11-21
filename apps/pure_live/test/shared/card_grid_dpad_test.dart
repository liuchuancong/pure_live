import 'package:desen_ui/desen_ui.dart' show DsScope;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_platform/live_platform.dart' show DesktopDistribution, FormFactor, PlatformBootstrap;
import 'package:live_storage/live_storage.dart';
import 'package:pure_live/app/providers/boot/environment_providers.dart' show platformRuntimeProvider;
import 'package:pure_live/l10n/translations.g.dart';
import 'package:pure_live/shared/grids/card_grid.dart';

/// The feed's D-pad walk: the arrows moving by index through the columns the
/// width made, the edges falling through to the page around the grid, a
/// short last row clamping its target, and the last row's own ask — the
/// endless feed pre-loading there, the paged one keeping its pager.
void main() {
  late StorageStores stores;

  setUp(() async {
    stores = await StorageStores.openInMemory();
    await StoragePrefs.init();
  });

  tearDown(() => stores.close());

  Future<void> show(WidgetTester tester, Widget grid) async {
    // The view directly: the surface call leaves the MediaQuery at its
    // default, and the grid reads the width it is laid out in.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 600);
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
              home: Scaffold(body: SizedBox(width: 800, height: 600, child: grid)),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Three columns in the 800-wide pane: 800 / (300 + 16) → 3.
  Widget grid(
    List<int> items, {
    required Map<int, FocusNode> nodes,
    bool paged = false,
    bool hasMore = false,
    Future<void> Function()? onLoadMore,
  }) => CardGrid<int>(
    items: items,
    itemBuilder: (context, item) => TextButton(onPressed: () {}, focusNode: nodes[item], child: Text('卡$item')),
    cardExtent: 300,
    padding: EdgeInsets.zero,
    paged: paged,
    hasMore: hasMore,
    onLoadMore: onLoadMore,
  );

  Map<int, FocusNode> nodes(int count) => {for (var i = 0; i < count; i++) i: FocusNode(debugLabel: '卡$i')};

  testWidgets('the walk moves by its columns and turns around', (tester) async {
    final nodes6 = nodes(6);
    await show(tester, grid([for (var i = 0; i < 6; i++) i], nodes: nodes6));

    nodes6[0]!.requestFocus();
    await tester.pump();
    expect(nodes6[0]!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // row 0 → row 1, same column
    await tester.pump();
    expect(nodes6[3]!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(nodes6[4]!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(nodes6[3]!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // back to row 0
    await tester.pump();
    expect(nodes6[0]!.hasFocus, isTrue);
  });

  testWidgets('the edges fall through: the ring stays at its stop', (tester) async {
    final nodes6 = nodes(6);
    await show(tester, grid([for (var i = 0; i < 6; i++) i], nodes: nodes6));

    nodes6[2]!.requestFocus(); // the right edge of row 0
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(nodes6[2]!.hasFocus, isTrue); // nothing right of the grid

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // nothing above row 0
    await tester.pump();
    expect(nodes6[2]!.hasFocus, isTrue);

    nodes6[3]!.requestFocus(); // the left edge of row 1
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(nodes6[3]!.hasFocus, isTrue); // nothing left of the grid
  });

  testWidgets('a short last row clamps the down step', (tester) async {
    final nodes7 = nodes(7); // three rows of 3/3/1
    await show(tester, grid([for (var i = 0; i < 7; i++) i], nodes: nodes7));

    nodes7[2]!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(nodes7[5]!.hasFocus, isTrue); // straight down, its own column

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // the last row holds one card
    await tester.pump();
    expect(nodes7[6]!.hasFocus, isTrue); // the walk lands on it
  });

  testWidgets('an endless feed asks from the last two rows and keeps its ring', (tester) async {
    final nodes30 = nodes(30); // ten rows of 3
    var asks = 0;
    await show(
      tester,
      grid([for (var i = 0; i < 30; i++) i], hasMore: true, onLoadMore: () async => asks += 1, nodes: nodes30),
    );

    // the walk starts at the head: seed the ring there — a press with no
    // focus would be spent finding the first stop instead
    nodes30[0]!.requestFocus();
    await tester.pump();

    // walk down to row 9: rows 8 and 9 are the preload band
    // two pumps per press: the reveal jumps, the lazy row builds, the
    // retry lands focus
    for (var i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump();
    }
    expect(nodes30[27]!.hasFocus, isTrue);
    expect(asks, greaterThanOrEqualTo(1)); // the band pre-loaded before the walk ended

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // the last row's own ask
    await tester.pump();
    expect(nodes30[27]!.hasFocus, isTrue); // the ring stays; the walk does not leave the grid
    expect(asks, greaterThanOrEqualTo(2));
  });

  testWidgets('a paged feed keeps its pager: the last row never turns the page', (tester) async {
    final nodes30 = nodes(30);
    var asks = 0;
    await show(
      tester,
      grid(
        [for (var i = 0; i < 30; i++) i],
        paged: true,
        hasMore: true,
        onLoadMore: () async => asks += 1,
        nodes: nodes30,
      ),
    );

    // the walk starts at the head: seed the ring there
    nodes30[0]!.requestFocus();
    await tester.pump();

    // two pumps per press: the reveal jumps, the lazy row builds, the
    // retry lands focus
    for (var i = 0; i < 9; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump();
    }
    expect(nodes30[27]!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(asks, 0); // the pager below is the only advancer, not the walk

    // inside the page the walk still moves
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp); // back to 24
    await tester.pump();
    await tester.pump();
    expect(nodes30[24]!.hasFocus, isTrue);
    expect(asks, 0);
  });
}
