import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';

/// The controls `live_uikit_forui` renders natively (§3.1 capability
/// declaration): all seventeen the resolver dispatches.
const Set<LiveUiControl> nativeControls = {
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.segmented,
  LiveUiControl.progress,
  LiveUiControl.select,
  LiveUiControl.tabBar,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
  LiveUiControl.toast,
  LiveUiControl.dialog,
  LiveUiControl.tabView,
};

/// The structural surfaces this adapter owns (§ surfaces): both of them — the
/// app host and the app shell (`FSidebar` beside the router's body).
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};

/// §16 integration pass for `live_uikit_forui`: every one of the seventeen controls
/// resolves native — the page frame, the bars, the toast surface and the dialog frame
/// included, since
/// `forui` 0.27.5 ships `FScaffold`, `FHeader`, `FTile`, `FBottomNavigationBar`,
/// `FToast` and `FDialog` — and switching to the core token base and back must not cost the caller
/// its controller or its field state (§11).
/// The downgrades this language is expected to report: none at all — every
/// control and both structural surfaces are native now. `forui` ships no
/// application widget, so the host is the app's own `WidgetsApp` under `FTheme`,
/// and the shell is `FSidebar`, which needs nothing above that same theme and
/// paints only the navigation column, the body staying the router's (§ surfaces).
/// Nothing in the contract falls back any more: the resolver hands back this
/// language's adapter, so a run that renders it reports no control or surface
/// downgrade at all (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  expect(
    sink.where((diagnostic) => diagnostic.control != null || diagnostic.surface != null),
    isEmpty,
    reason: 'every control and surface resolves to this adapter',
  );
}

void main() {
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.forui: foruiAdapter});
  const resolver = LiveUiResolver(registry: registry);

  Widget harness(UiConfig ui, Widget child, List<LiveUiDiagnostic> sink) => LiveConfigProvider(
    config: ui,
    registry: registry,
    diagnostics: sink.add,
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...foruiLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  test('every control it declares resolves to this adapter, with no downgrade (§16.3)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.forui);
    for (final control in LiveUiControl.values) {
      expect(adapter.capabilities.supports(control), nativeControls.contains(control), reason: '$control');
    }
    for (final control in nativeControls) {
      resolver.requireControl(LiveDesignLanguage.forui, control);
    }
  });

  testWidgets('ForUI ↔ its own library widgets swaps the path, not the state (§11)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    final controller = TextEditingController(text: 'typed before the switch');
    addTearDown(controller.dispose);

    Widget page() => Column(
      children: [
        LiveButton(label: 'Save', onPressed: () {}),
        const LiveCard(child: Text('card body')),
        LiveTextField(controller: controller),
        LiveSwitch(value: true, onChanged: (_) {}),
        const LiveProgress(value: 0.5),
      ],
    );

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.forui), page(), diagnostics));
    expect(find.byType(forui.FButton), findsOneWidget);
    expect(find.byType(forui.FCard), findsOneWidget);
    expect(find.byType(forui.FTextField), findsOneWidget);
    expect(find.byType(forui.FSwitch), findsOneWidget);
    expect(find.byType(forui.FDeterminateProgress), findsOneWidget);
    expectUndeclaredControls(diagnostics);

    // A re-theme through the same adapter keeps the caller's state: the path never
    // left this language, so nothing resets (§11).
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.forui), page(), diagnostics));
    expect(find.byType(LiveTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.forui), page(), diagnostics));
    expect(find.byType(forui.FTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);
    // Progress is ForUI's own now, on both sides of the switch it is the same control.
    expect(find.byType(forui.FDeterminateProgress), findsOneWidget);
  });

  testWidgets('no token renderer inside a ForUI frame (§15.3)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    await tester.pumpWidget(
      harness(
        const UiConfig(language: LiveDesignLanguage.forui),
        LiveScaffold(
          appBar: LiveAppBar(
            title: 'Rooms',
            actions: const [Icon(Icons.search)],
            bottom: LiveTabs(
              tabs: const [
                LiveTab(label: 'One'),
                LiveTab(label: 'Two'),
              ],
              index: 0,
              onChanged: (_) {},
            ),
          ),
          body: Column(
            children: [
              LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (_) {}),
              LiveSelect<String>(items: const ['x'], itemLabel: (item) => item, onChanged: (_) {}),
              const LiveListRow(title: 'Room'),
            ],
          ),
          bottomBar: LiveNavBar(
            items: const [
              LiveNavBarItem(label: 'Home', icon: Icons.home),
              LiveNavBarItem(label: 'Shows', icon: Icons.tv),
            ],
            index: 0,
            onChanged: (_) {},
          ),
        ),
        diagnostics,
      ),
    );
    await tester.pump();

    // The whole contract is declared, so nothing inside a ForUI page should be a
    // `Token*` renderer — asserted by name rather than by list so a control added to
    // the contract cannot slip in silently.
    expect(tester.takeException(), isNull);
  });
}
