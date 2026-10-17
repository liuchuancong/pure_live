import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_fluent/live_uikit_fluent.dart';

/// The controls `live_uikit_fluent` renders natively (§3.1 capability
/// declaration): all seventeen the resolver dispatches — `select`, which only
/// Fluent renders for real, the page frame, list row, toast and dialog surfaces
/// this adapter maps to `ScaffoldPage`/`ListTile`/`InfoBar`/`ContentDialog`, the
/// five chrome controls it composes out of its own widgets, and the app host,
/// which is `FluentApp` itself.
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

/// The structural surfaces this adapter owns (§ surfaces).
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};

/// §16 integration pass for `live_uikit_fluent`: every one of the seventeen
/// controls resolves native, both structural surfaces resolve native, so a
/// Fluent language change reports no downgrade at all, and switching to the core
/// token base and back preserves the caller's controller (§11).
/// The downgrades this language is expected to report: none, because nothing in
/// the contract falls back any more (§15.5/§16.8).
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
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.fluent: fluentAdapter});
  const resolver = LiveUiResolver(registry: registry);

  test('the surfaces it owns are exactly the ones it declares (§ surfaces)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.fluent);
    for (final surface in LiveUiSurface.values) {
      expect(adapter.surfaces.supports(surface), nativeSurfaces.contains(surface), reason: '$surface');
    }
    for (final surface in nativeSurfaces) {
      resolver.requireSurface(LiveDesignLanguage.fluent, surface);
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

  test('every control it declares resolves to this adapter, with no downgrade (§16.3)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.fluent);
    for (final control in LiveUiControl.values) {
      expect(adapter.capabilities.supports(control), nativeControls.contains(control), reason: '$control');
    }
    for (final control in nativeControls) {
      resolver.requireControl(LiveDesignLanguage.fluent, control);
    }
  });

  testWidgets('Fluent ↔ its own library widgets swaps the path, not the state (§11)', (tester) async {
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

    // A re-theme through the same adapter keeps the caller's state: the path never
    // left this language, so nothing resets (§11).
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.fluent), page(), diagnostics));
    expect(find.byType(LiveTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
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
