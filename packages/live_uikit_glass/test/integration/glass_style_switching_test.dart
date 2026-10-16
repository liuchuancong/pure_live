import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

/// The controls `live_uikit_glass` renders natively (§3.1 capability
/// declaration): three of the thirteen the resolver dispatches.
const Set<LiveUiControl> nativeControls = {LiveUiControl.button, LiveUiControl.card, LiveUiControl.textField};

/// §16 integration pass for `live_uikit_glass`: the three controls the frosted
/// library actually serves resolve native, the other ten resolve shared (the
/// seven widget controls `switchWidget`, `checkbox`, `slider`, `segmented`,
/// `progress`, `select`, `tabBar` plus the page trio `scaffold`, `appBar`,
/// `listRow` that no adapter maps yet), and a switch to the core token base and
/// back must not cost the caller its controller or its field state (§11).
/// The downgrades this language is expected to report: every control the adapter
/// does not declare, each exactly once per language change (§15.5/§16.8).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  // This adapter owns no structural surface, so both the app host and the shell
  // fall back alongside the controls it does not declare — two kinds of downgrade
  // with two codes (§ surfaces).
  final controls = sink.where((diagnostic) => diagnostic.control != null);
  final surfaces = sink.where((diagnostic) => diagnostic.surface != null);
  expect(controls.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.controlUnsupported});
  expect(
    controls.map((diagnostic) => diagnostic.control).toSet(),
    LiveUiControl.values.toSet().difference(nativeControls),
  );
  expect(surfaces.map((diagnostic) => diagnostic.code).toSet(), {LiveUiDiagnosticCode.surfaceUnsupported});
  expect(surfaces.map((diagnostic) => diagnostic.surface).toSet(), LiveUiSurface.values.toSet());
  expect(sink, hasLength(LiveUiControl.values.length + LiveUiSurface.values.length - nativeControls.length));
}

void main() {
  const registry = LanguageRegistry(
    adapters: {LiveDesignLanguage.glass: glassAdapter},
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

  test('the three declared controls resolve native, the rest shared (§16.3)', () {
    for (final control in LiveUiControl.values) {
      final native = nativeControls.contains(control);
      final resolution = resolver.resolveControl(LiveDesignLanguage.glass, control);
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

  testWidgets('Glass ↔ the token base swaps the path, not the state (§11)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    final controller = TextEditingController(text: 'typed before the switch');
    addTearDown(controller.dispose);

    Widget page() => Column(
      children: [
        LiveButton(label: 'Save', onPressed: () {}),
        const LiveCard(child: Text('card body')),
        LiveTextField(controller: controller),
        const LiveProgress(value: 0.5),
      ],
    );

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.glass), page(), diagnostics));
    expect(find.byType(glass.GlassButton), findsOneWidget);
    expect(find.byType(glass.GlassCard), findsOneWidget);
    expect(find.byType(glass.GlassTextField), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
    expectUndeclaredControls(diagnostics);

    // `UiConfig()` defaults to the shared `token` base.
    await tester.pumpWidget(harness(const UiConfig(), page(), diagnostics));
    expect(find.byType(glass.GlassTextField), findsNothing);
    expect(find.byType(glass.GlassCard), findsNothing);
    expect(controller.text, 'typed before the switch');
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      contains(LiveUiDiagnosticCode.adapterMissing),
      reason: 'the core base has no adapter of its own, so the gap is reported',
    );

    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.glass), page(), diagnostics));
    expect(find.byType(glass.GlassTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);
    // Progress stays a shared-fallback control and keeps rendering on both sides.
    expect(find.byType(LiveProgress), findsOneWidget);
  });
}
