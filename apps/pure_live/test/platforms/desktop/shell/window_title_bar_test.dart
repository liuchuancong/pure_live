import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_live/platforms/desktop/shell/window_title_bar.dart';
import 'package:pure_uikit/pure_uikit.dart';

/// The strip's wiring, against a fake instead of a window manager.
///
/// The strip is the core's shared `PureTitleBar`; the geometry comes from the
/// shared Windows caption metrics, and the buttons' semantics — which call is
/// wired to which glyph, and that close goes through the seam rather than
/// doing anything itself — are what a regression here would break.
void main() {
  testWidgets('the strip is caption-height and carries the three buttons', (tester) async {
    await tester.pumpWidget(const _Harness());

    expect(tester.getSize(find.byType(PureTitleBar)).height, 32);
    expect(find.byTooltip('最小化'), findsOneWidget);
    expect(find.byTooltip('最大化'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);
    expect(find.text('Pure Live'), findsOneWidget);
  });

  testWidgets('minimise and close reach the seam untouched', (tester) async {
    final actions = _FakeActions();
    await tester.pumpWidget(_Harness(actions: actions));

    await tester.tap(find.byTooltip('最小化'));
    await tester.tap(find.byTooltip('关闭'));
    await tester.pump();

    expect(actions.minimized, 1);
    expect(actions.closed, 1);
    expect(actions.toggled, 0);
  });

  testWidgets('the maximise glyph follows the seam, and pressing toggles', (tester) async {
    final actions = _FakeActions(maximized: true);
    await tester.pumpWidget(_Harness(actions: actions));
    await tester.pumpAndSettle();
    // The strip asked the seam once at start, and a maximised window shows
    // the restore affordance, not a second maximise.
    expect(find.byTooltip('还原'), findsOneWidget);

    await tester.tap(find.byTooltip('还原'));
    await tester.pumpAndSettle();

    expect(actions.toggled, 1);
    expect(find.byTooltip('最大化'), findsOneWidget);
  });

  testWidgets('a double click on the drag region toggles the window', (tester) async {
    final actions = _FakeActions();
    await tester.pumpWidget(_Harness(actions: actions));

    await tester.tap(find.text('Pure Live'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Pure Live'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(actions.toggled, 1);
  });
}

final class _Harness extends StatelessWidget {
  const new({this.actions = const WindowManagerChromeActions()});

  final WindowChromeActions actions;

  @override
  Widget build(BuildContext context) => TranslationProvider(
    child: MaterialApp(
      // The caption strip takes its colours from the design language now, so the
      // harness has to give it one — a bare `MaterialApp` is precisely the ancestor
      // it must no longer lean on.
      home: PureConfigProvider(
        config: const UiConfig(language: PureDesignLanguage.material),
        child: Scaffold(
          body: PureTitleBar(
            labels: const PureTitleBarLabels(
              title: 'Pure Live',
              minimize: '最小化',
              maximize: '最大化',
              restore: '还原',
              close: '关闭',
            ),
            actions: actions,
          ),
        ),
      ),
    ),
  );
}

/// Records what the strip asked for; [toggleMaximize] flips the state the
/// seam reports, which is what the strip re-reads to pick its glyph.
final class _FakeActions implements WindowChromeActions {
  new({this.maximized = false});

  bool maximized;
  int minimized = 0;
  int toggled = 0;
  int closed = 0;

  @override
  Future<void> minimize() async => minimized++;

  @override
  Future<void> toggleMaximize() async {
    maximized = !maximized;
    toggled++;
  }

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> close() async => closed++;

  @override
  Future<void> startDragging() async {}
}
