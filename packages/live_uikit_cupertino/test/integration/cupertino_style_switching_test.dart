import 'package:cupertino_ui/cupertino_ui.dart' as cu;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_cupertino/live_uikit_cupertino.dart';

/// The controls `live_uikit_cupertino` renders natively (§3.1 capability
/// declaration): eight of the fifteen the resolver dispatches.
const Set<LiveUiControl> nativeControls = {
  LiveUiControl.button,
  LiveUiControl.textField,
  LiveUiControl.switchWidget,
  LiveUiControl.slider,
  LiveUiControl.scaffold,
  LiveUiControl.appBar,
  LiveUiControl.listRow,
  LiveUiControl.navBar,
};

/// The structural surfaces this adapter owns (§ surfaces).
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost};

/// §16 integration pass for `live_uikit_cupertino`: the nine declared controls
/// resolve native and the seven others resolve shared (`card`, `checkbox`,
/// `segmented`, `progress`, `select`, `tabBar`, `toast`), and switching to the
/// core token base and back replaces the rendering path without touching the
/// caller's controller or the fallback controls' behaviour (§11).
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
    adapters: {LiveDesignLanguage.cupertino: cupertinoAdapter},
    fallback: SharedLanguageAdapter(),
  );
  const resolver = LiveUiResolver(registry: registry);

  test('the surfaces it owns structurally resolve native, the rest shared', () {
    for (final surface in LiveUiSurface.values) {
      final owned = nativeSurfaces.contains(surface);
      final resolution = resolver.resolveSurface(LiveDesignLanguage.cupertino, surface);
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
      localizationsDelegates: const [...liveLocalizationsDelegates, ...cupertinoLocalizationsDelegates],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: Center(child: child)),
    ),
  );

  test('the nine declared controls resolve native, the rest shared (§16.3)', () {
    for (final control in LiveUiControl.values) {
      final native = nativeControls.contains(control);
      final resolution = resolver.resolveControl(LiveDesignLanguage.cupertino, control);
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

  testWidgets('Cupertino UI ↔ the token base swaps the path, not the state (§11)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    final controller = TextEditingController(text: 'typed before the switch');
    addTearDown(controller.dispose);
    var tabs = -1;

    Widget page() => Column(
      children: [
        LiveTextField(controller: controller),
        LiveSwitch(value: true, onChanged: (_) {}),
        LiveSlider(value: 0.5, onChanged: (_) {}),
        LiveTabs(
          tabs: const [
            LiveTab(label: 'One'),
            LiveTab(label: 'Two'),
          ],
          index: 0,
          onChanged: (i) => tabs = i,
        ),
      ],
    );

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.cupertino), page(), diagnostics));
    expect(find.byType(cu.CupertinoTextField), findsOneWidget);
    expect(find.byType(cu.CupertinoSwitch), findsOneWidget);
    expect(find.byType(cu.CupertinoSlider), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expectUndeclaredControls(diagnostics);

    // `UiConfig()` defaults to the shared `token` base.
    await tester.pumpWidget(harness(const UiConfig(), page(), diagnostics));
    expect(find.byType(cu.CupertinoTextField), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expect(
      diagnostics.map((diagnostic) => diagnostic.code),
      contains(LiveUiDiagnosticCode.adapterMissing),
      reason: 'the core base has no adapter of its own, so the gap is reported',
    );

    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.cupertino), page(), diagnostics));
    expect(find.byType(cu.CupertinoTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);

    // Tabs are a shared-fallback control in this language: usable on both sides
    // of the switch, and still typed (§16.7).
    await tester.tap(find.text('Two'));
    await tester.pump();
    expect(tabs, 1);
  });
}
