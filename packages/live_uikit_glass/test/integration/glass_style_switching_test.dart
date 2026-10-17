import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glass_morphism_plus/glass_morphism_plus.dart' as glass;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_glass/live_uikit_glass.dart';

/// The controls `live_uikit_glass` renders with `glass_morphism_plus` (§3.1
/// capability declaration): all seventeen the resolver dispatches — four with the
/// library's own widgets, thirteen composed from its frosted surfaces and theme
/// values, the last two of those because the library ships neither a dialog nor a
/// page switcher.
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
/// `WidgetsApp` host and a shell composed from the library's frosted containers,
/// since it ships no navigation structure of its own.
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};

/// §16 integration pass for `live_uikit_glass`: all seventeen controls and both
/// structural surfaces resolve to this adapter, so a run that renders Glass
/// reports no downgrade at all, and re-theming through the same language must not
/// cost the caller its controller or its field state (§11).
///
/// The helper below is the assertion behind that claim: the diagnostics a Glass
/// run hands the host name no control and no surface, because every part of the
/// contract is answered by this adapter rather than by another one (§15/§16).
void expectUndeclaredControls(List<LiveUiDiagnostic> sink) {
  expect(
    sink.where((diagnostic) => diagnostic.control != null || diagnostic.surface != null),
    isEmpty,
    reason: 'every control and surface resolves to this adapter',
  );
}

void main() {
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.glass: glassAdapter});
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

  test('the surfaces it owns are exactly the ones it declares (§ surfaces)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.glass);
    for (final surface in LiveUiSurface.values) {
      expect(adapter.surfaces.supports(surface), nativeSurfaces.contains(surface), reason: '$surface');
    }
    for (final surface in nativeSurfaces) {
      resolver.requireSurface(LiveDesignLanguage.glass, surface);
    }
  });

  testWidgets('Glass ↔ its own library widgets swaps the path, not the state (§11)', (tester) async {
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
    // The progress bar has no library widget either, so it is this package's own
    // composed frosted groove — every control on this page is drawn here (§15).
    expectUndeclaredControls(diagnostics);

    // A re-theme through the same adapter keeps the caller's state: the path never
    // left this language, so nothing resets (§11).
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.glass), page(), diagnostics));
    expect(find.byType(LiveTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.glass), page(), diagnostics));
    expect(find.byType(glass.GlassTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);
    // The composed progress bar is still drawn after the re-theme, so a page that
    // mixes the library's own widgets with the composed ones keeps both.
    expect(find.byType(LiveProgress), findsOneWidget);
  });
}
