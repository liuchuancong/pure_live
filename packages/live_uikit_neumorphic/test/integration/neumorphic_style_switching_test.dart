import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_ui_kit/flutter_neumorphic_ui_kit.dart' as neu;
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_neumorphic/live_uikit_neumorphic.dart';

/// The controls `live_uikit_neumorphic` renders with `flutter_neumorphic_ui_kit`
/// (§3.1 capability declaration): all seventeen the resolver dispatches — the eight it
/// has a widget for, plus `segmented`, `select`, `tabBar`, `toast`, `scaffold`,
/// `listRow`, `navBar`, `dialog` and `tabView`, which are composed out of that
/// library's own faces because it ships no such widget.
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

/// The structural surfaces this adapter owns (§ surfaces): the `WidgetsApp` host
/// under `NeuTheme`, and a shell composed from the library's container faces, since
/// it ships no rail.
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};

/// §16 integration pass for `live_uikit_neumorphic`: the whole contract native, so a
/// Neumorphic language change reports no control downgrade at all, and a switch to the
/// core token base and back leaves the caller's controller and values intact (§11).
/// The downgrades this language is expected to report: none at all. Every control is
/// native and both structural surfaces are owned, so the derived checks below compare
/// against empty sets and skip the code assertions (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  // Nothing falls back any more: the host is this package's `WidgetsApp` under
  // `NeuTheme`, and the shell is the column it composes, so a Neumorphic window
  // reports no downgrade of either kind (§ surfaces).
  final controls = sink.where((diagnostic) => diagnostic.control != null);
  final surfaces = sink.where((diagnostic) => diagnostic.surface != null);
  // Asserted only while there is something to report: an empty set of codes would
  // otherwise match `{controlUnsupported}` trivially and say nothing.
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
    adapters: {LiveDesignLanguage.neumorphic: neumorphicAdapter},
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

  test('every declared control resolves native and reports nothing (§16.3)', () {
    for (final control in LiveUiControl.values) {
      final native = nativeControls.contains(control);
      final resolution = resolver.resolveControl(LiveDesignLanguage.neumorphic, control);
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

  testWidgets('Neumorphic ↔ the token base swaps the path, not the state (§11)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    final controller = TextEditingController(text: 'typed before the switch');
    addTearDown(controller.dispose);
    var segmented = -1;

    Widget page() => Column(
      children: [
        LiveButton(label: 'Save', onPressed: () {}),
        const LiveCard(child: Text('card body')),
        LiveTextField(controller: controller),
        LiveSwitch(value: true, onChanged: (_) {}),
        LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (i) => segmented = i),
      ],
    );

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.neumorphic), page(), diagnostics));
    expect(find.byType(neu.NeuButton), findsOneWidget);
    expect(find.byType(neu.NeuCard), findsOneWidget);
    expect(find.byType(neu.NeuTextField), findsOneWidget);
    expect(find.byType(neu.NeuSwitch), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expectUndeclaredControls(diagnostics);

    // `UiConfig()` defaults to the shared `token` base.
    await tester.pumpWidget(harness(const UiConfig(), page(), diagnostics));
    expect(find.byType(neu.NeuTextField), findsNothing);
    expect(find.byType(neu.NeuSwitch), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      contains(LiveUiDiagnosticCode.adapterMissing),
      reason: 'the core base has no adapter of its own, so the gap is reported',
    );

    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.neumorphic), page(), diagnostics));
    expect(find.byType(neu.NeuTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);

    // Segmented is composed here now, in the language's own dish-and-dome track,
    // and still callable (§16.7).
    expect(find.byType(TokenSegmented), findsNothing);
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(segmented, 1);
  });
}
