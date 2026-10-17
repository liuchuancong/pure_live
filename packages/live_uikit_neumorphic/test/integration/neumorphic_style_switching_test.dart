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
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.neumorphic: neumorphicAdapter});
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

  test('every control it declares resolves to this adapter, with no downgrade (§16.3)', () {
    final adapter = resolver.resolve(LiveDesignLanguage.neumorphic);
    for (final control in LiveUiControl.values) {
      expect(adapter.capabilities.supports(control), nativeControls.contains(control), reason: '$control');
    }
    for (final control in nativeControls) {
      resolver.requireControl(LiveDesignLanguage.neumorphic, control);
    }
  });

  testWidgets('Neumorphic ↔ its own library widgets swaps the path, not the state (§11)', (tester) async {
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

    // A re-theme through the same adapter keeps the caller's state: the path never
    // left this language, so nothing resets (§11).
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.neumorphic), page(), diagnostics));
    expect(find.byType(LiveTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.neumorphic), page(), diagnostics));
    expect(find.byType(neu.NeuTextField), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);

    // Segmented is composed here now, in the language's own dish-and-dome track,
    // and still callable (§16.7).
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(segmented, 1);
  });
}
