import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_macos/live_uikit_macos.dart';
import 'package:macos_ui/macos_ui.dart' as macos;

/// The controls `live_uikit_macos` renders natively (§3.1 capability
/// declaration): all seventeen the resolver dispatches — the seven this adapter has
/// always mapped onto `PushButton`, `MacosTextField`, `MacosScaffold`, `ToolBar`
/// and the rest, the four it now maps too (`MacosSwitch`, `MacosSegmentedControl`,
/// `ProgressBar`/`ProgressCircle`, `MacosPopupButton`), and the six the library
/// has no widget for, assembled out of its own parts: `MacosSheet` for the card, the
/// toast surface and the dialogs the alert cannot take, `MacosTab` plus `MacosIcon`
/// for the two strips, and the library's own pane treatment around an `IndexedStack`
/// for the page switcher.
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

/// §16 integration pass for `live_uikit_macos`: every one of the fifteen controls
/// resolves native, and so do both structural surfaces — `MacosApp` for the host and
/// the library's own `SidebarItems` list for the shell — so this language reports no
/// downgrade at all, and a switch to the core token base and back replaces the
/// rendering path while the caller keeps its controller (§11).
/// The downgrades this language is expected to report: no control downgrade at all,
/// because nothing in the contract falls back any more (§15.5/§16.8).
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
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.macos: macosAdapter});
  const resolver = LiveUiResolver(registry: registry);

  test('the surfaces it owns are exactly the ones it declares (§ surfaces)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.macos);
    for (final surface in LiveUiSurface.values) {
      expect(adapter.surfaces.supports(surface), nativeSurfaces.contains(surface), reason: '$surface');
    }
    for (final surface in nativeSurfaces) {
      resolver.requireSurface(LiveDesignLanguage.macos, surface);
    }
  });

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

  test('every control it declares resolves to this adapter, with no downgrade (§16.3)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.macos);
    for (final control in LiveUiControl.values) {
      expect(adapter.capabilities.supports(control), nativeControls.contains(control), reason: '$control');
    }
    for (final control in nativeControls) {
      resolver.requireControl(LiveDesignLanguage.macos, control);
    }
  });

  testWidgets('macOS ↔ its own library widgets swaps the path, not the state (§11)', (tester) async {
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

    // A re-theme through the same adapter keeps the caller's state: the path never
    // left this language, so nothing resets (§11).
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.macos), page(), diagnostics));
    expect(find.byType(LiveTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.macos), page(), diagnostics));
    expect(find.byType(macos.MacosTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);

    // Select is the library's own pop-up button now: opening it and choosing a row
    // still keeps the caller's typed value across the switch (§16.7).
    expect(find.byType(macos.MacosPopupButton<String>), findsOneWidget);
    await tester.tap(find.byType(LiveSelect<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('b').last);
    await tester.pumpAndSettle();
    expect(selected, 'b');
  });
}
