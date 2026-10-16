import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart' as forui;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_forui/live_uikit_forui.dart';

/// The controls `live_uikit_forui` renders natively (§3.1 capability
/// declaration): all fifteen the resolver dispatches.
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
};

/// The structural surfaces this adapter owns (§ surfaces): both of them — the
/// app host and the app shell (`FSidebar` beside the router's body).
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};

/// §16 integration pass for `live_uikit_forui`: every one of the fifteen controls
/// resolves native — the page frame, the bars and the toast surface included, since
/// `forui` 0.27.5 ships `FScaffold`, `FHeader`, `FTile`, `FBottomNavigationBar` and
/// `FToast` — and switching to the core token base and back must not cost the caller
/// its controller or its field state (§11).
/// The downgrades this language is expected to report: none at all — every
/// control and both structural surfaces are native now. `forui` ships no
/// application widget, so the host is the app's own `WidgetsApp` under `FTheme`,
/// and the shell is `FSidebar`, which needs nothing above that same theme and
/// paints only the navigation column, the body staying the router's (§ surfaces).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  final controls = sink.where((diagnostic) => diagnostic.control != null);
  final surfaces = sink.where((diagnostic) => diagnostic.surface != null);
  // A language that renders every control reports no control downgrade at all,
  // so the code check only applies when something actually fell back.
  final expectedControls = LiveUiControl.values.toSet().difference(nativeControls);
  expect(controls.map((diagnostic) => diagnostic.control).toSet(), expectedControls);
  if (expectedControls.isNotEmpty) {
    expect(controls.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.controlUnsupported});
  }
  final expectedSurfaces = LiveUiSurface.values.toSet().difference(nativeSurfaces);
  expect(surfaces.map((diagnostic) => diagnostic.surface).toSet(), expectedSurfaces);
  if (expectedSurfaces.isNotEmpty) {
    expect(surfaces.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.surfaceUnsupported});
  }
  expect(
    sink,
    hasLength(
      LiveUiControl.values.length + LiveUiSurface.values.length - nativeControls.length - nativeSurfaces.length,
    ),
  );
}

void main() {
  const registry = LanguageRegistry(
    adapters: {LiveDesignLanguage.forui: foruiAdapter},
    fallback: SharedLanguageAdapter(),
  );
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

  test('every control resolves native, because this language declares the whole contract (§16.3)', () {
    for (final control in LiveUiControl.values) {
      final native = nativeControls.contains(control);
      final resolution = resolver.resolveControl(LiveDesignLanguage.forui, control);
      expect(
        resolution.implementation.kind,
        native ? LiveImplementationKind.adapterNative : LiveImplementationKind.shared,
        reason: '$control',
      );
      expect(
        resolution.diagnostic?.code,
        native ? isNull : LiveUiDiagnosticCode.controlUnsupported,
        reason: '$control',
      );
    }
  });

  testWidgets('ForUI ↔ the token base swaps the path, not the state (§11)', (tester) async {
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
    expect(find.byType(TokenSlider), findsNothing);
    expectUndeclaredControls(diagnostics);

    // `UiConfig()` defaults to the shared `token` base.
    await tester.pumpWidget(harness(const UiConfig(), page(), diagnostics));
    expect(find.byType(forui.FTextField), findsNothing);
    expect(find.byType(forui.FCard), findsNothing);
    expect(controller.text, 'typed before the switch');
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      contains(LiveUiDiagnosticCode.adapterMissing),
      reason: 'the core base has no adapter of its own, so the gap is reported',
    );

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
    expect(find.byWidgetPredicate((widget) => widget.runtimeType.toString().startsWith('Token')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
