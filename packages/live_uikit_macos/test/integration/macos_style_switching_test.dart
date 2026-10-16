import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/styling.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// The controls `live_uikit_macos` renders natively (§3.1 capability
/// declaration): eight of the sixteen the resolver dispatches, including the
/// page frame, the bar and the row mapped onto `MacosScaffold`, `ToolBar` and
/// `MacosListTile`, and the app host, which is `MacosApp` itself.
const Set<LiveUiControl> nativeControls = {
  LiveUiControl.button,
  LiveUiControl.textField,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.appHost,
};

/// §16 integration pass for `live_uikit_macos`: eight declared controls native,
/// the other eight shared (`card`, `switchWidget`, `segmented`, `progress`,
/// `select`, `tabBar` and the two chrome controls `macos_ui` has no widget for —
/// `navBar`, whose place is taken by a `Sidebar`, and `toast`, whose `Toast` is an
/// overlay manager rather than a surface), and a switch to the core token base and
/// back that replaces the rendering path while the caller keeps its controller (§11).
/// The downgrades this language is expected to report: every control the adapter
/// does not declare, each exactly once per language change (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  expect(sink.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.controlUnsupported});
  expect(sink.map((diagnostic) => diagnostic.control).toSet(), LiveUiControl.values.toSet().difference(nativeControls));
  expect(sink, hasLength(LiveUiControl.values.length - nativeControls.length));
}

void main() {
  const registry = LanguageRegistry(
    adapters: {LiveDesignLanguage.macos: macosAdapter},
    fallback: SharedLanguageAdapter(),
  );
  const resolver = LiveUiResolver(registry: registry);

  Widget harness(UiConfig ui, Widget child, List<LiveUiDiagnostic> sink) => LiveConfigProvider(
    config: ui,
    registry: registry,
    diagnostics: sink.add,
    child: MaterialApp(
      localizationsDelegates: liveLocalizationsDelegates,
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  test('the eight declared controls resolve native, the rest shared (§16.3)', () {
    for (final control in LiveUiControl.values) {
      final native = nativeControls.contains(control);
      final resolution = resolver.resolveControl(LiveDesignLanguage.macos, control);
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

  testWidgets('macOS ↔ the token base swaps the path, not the state (§11)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    final controller = TextEditingController(text: 'typed before the switch');
    addTearDown(controller.dispose);
    var selected = '';

    Widget page() => Column(
      children: [
        LiveTextField(controller: controller),
        LiveCheckbox(value: true, onChanged: (_) {}),
        LiveSlider(value: 0.5, onChanged: (_) {}),
        SizedBox(
          width: 260,
          child: LiveSelect<String>(items: const ['a', 'b'], itemLabel: (s) => s, onChanged: (v) => selected = v),
        ),
      ],
    );

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.macos), page(), diagnostics));
    expect(find.byType(macos.MacosTextField), findsOneWidget);
    expect(find.byType(macos.MacosCheckbox), findsOneWidget);
    expect(find.byType(macos.MacosSlider), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expectUndeclaredControls(diagnostics);

    // `UiConfig()` defaults to the shared `token` base.
    await tester.pumpWidget(harness(const UiConfig(), page(), diagnostics));
    expect(find.byType(macos.MacosTextField), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      contains(LiveUiDiagnosticCode.adapterMissing),
      reason: 'the core base has no adapter of its own, so the gap is reported',
    );

    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.macos), page(), diagnostics));
    expect(find.byType(macos.MacosTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);

    // Select is a shared-fallback control here: opening it and choosing keeps the
    // caller's typed value across the switch (§16.7).
    await tester.tap(find.byType(LiveSelect<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b').last);
    await tester.pumpAndSettle();
    expect(selected, 'b');
  });
}
