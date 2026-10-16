import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';

/// The controls `live_uikit_fluent` renders natively (§3.1 capability
/// declaration): eleven of the fifteen the resolver dispatches, including
/// `select`, which only Fluent renders for real, the page frame, list row and
/// toast surface this adapter maps to `ScaffoldPage`/`ListTile`/`InfoBar`, and
/// the app host, which is `FluentApp` itself.
const Set<LiveUiControl> nativeControls = {
  LiveUiControl.button,
  LiveUiControl.card,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.checkbox,
  LiveUiControl.slider,
  LiveUiControl.progress,
  LiveUiControl.select,
  LiveUiControl.scaffold,
  LiveUiControl.listRow,
  LiveUiControl.toast,
};

/// The structural surfaces this adapter owns (§ surfaces).
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};

/// §16 integration pass for `live_uikit_fluent`: the twelve `nativeControls`
/// resolve native — including `select`, which only Fluent renders for real — the
/// four controls of the fifteen-control dispatch contract this adapter does not
/// declare (`segmented`, `tabBar` and the chrome `appBar`/`navBar`, for which
/// fluent_ui has no page-level title strip with widget actions and no bottom
/// navigation strip) resolve shared, and switching to the core token base and
/// back preserves the caller's controller (§11).
/// The downgrades this language is expected to report: every control the adapter
/// does not declare, each exactly once per language change (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  final controls = sink.where((diagnostic) => diagnostic.control != null);
  final surfaces = sink.where((diagnostic) => diagnostic.surface != null);
  expect(controls.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.controlUnsupported});
  expect(
    controls.map((diagnostic) => diagnostic.control).toSet(),
    LiveUiControl.values.toSet().difference(nativeControls),
  );
  // A language that owns both surfaces reports no structural downgrade at all,
  // so the code check only applies when something is actually missing.
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
    adapters: {LiveDesignLanguage.fluent: fluentAdapter},
    fallback: SharedLanguageAdapter(),
  );
  const resolver = LiveUiResolver(registry: registry);

  test('the surfaces it owns structurally resolve native, the rest shared', () {
    for (final surface in LiveUiSurface.values) {
      final owned = nativeSurfaces.contains(surface);
      final resolution = resolver.resolveSurface(LiveDesignLanguage.fluent, surface);
      expect(
        resolution.implementation.kind,
        owned ? LiveImplementationKind.adapterNative : LiveImplementationKind.shared,
        reason: '$surface',
      );
      expect(resolution.diagnostic?.code, owned ? isNull : LiveUiDiagnosticCode.surfaceUnsupported, reason: '$surface');
    }
  });

  Widget harness(UiConfig ui, Widget child, List<LiveUiDiagnostic> sink) => LiveConfigProvider(
    config: ui,
    registry: registry,
    diagnostics: sink.add,
    child: MaterialApp(
      localizationsDelegates: const [...liveLocalizationsDelegates, ...fluentLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  test('the eleven declared controls resolve native, the other four shared (§16.3)', () {
    for (final control in LiveUiControl.values) {
      final native = nativeControls.contains(control);
      final resolution = resolver.resolveControl(LiveDesignLanguage.fluent, control);
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

  testWidgets('Fluent ↔ the token base swaps the path, not the state (§11)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    final controller = TextEditingController(text: 'typed before the switch');
    addTearDown(controller.dispose);
    var segmented = -1;

    Widget page() => Column(
      children: [
        LiveTextField(controller: controller),
        LiveSwitch(value: true, onChanged: (_) {}),
        SizedBox(
          width: 220,
          child: LiveSelect<String>(items: const ['a', 'b'], itemLabel: (s) => s, onChanged: (_) {}),
        ),
        LiveSegmented(labels: const ['A', 'B'], index: 0, onChanged: (i) => segmented = i),
      ],
    );

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.fluent), page(), diagnostics));
    expect(find.byType(fluent.TextBox), findsOneWidget);
    expect(find.byType(fluent.ToggleSwitch), findsOneWidget);
    expect(find.byType(fluent.ComboBox<String>), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expectUndeclaredControls(diagnostics);

    // `UiConfig()` defaults to the shared `token` base.
    await tester.pumpWidget(harness(const UiConfig(), page(), diagnostics));
    expect(find.byType(fluent.TextBox), findsNothing);
    expect(find.byType(fluent.ComboBox<String>), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      contains(LiveUiDiagnosticCode.adapterMissing),
      reason: 'the core base has no adapter of its own, so the gap is reported',
    );

    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.fluent), page(), diagnostics));
    expect(find.byType(fluent.TextBox), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);

    // Segmented stays a shared-fallback control, so it is callable on both sides
    // while `select` — native here and shared in most other languages — keeps its
    // typed value path intact (§16.7).
    await tester.tap(find.text('B'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(segmented, 1);
  });
}
