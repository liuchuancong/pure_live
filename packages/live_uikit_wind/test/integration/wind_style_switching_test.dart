import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttersdk_wind/fluttersdk_wind.dart' as wind;
import 'package:live_uikit/live_uikit.dart';
import 'package:live_uikit_wind/live_uikit_wind.dart';

/// The controls `live_uikit_wind` renders natively (§3.1 capability
/// declaration): all seventeen the resolver dispatches — the six the fork has a
/// widget for, and the eleven it does not (the rail, the segmented track, the bar,
/// the tab strip, the page frame, the top bar, the list row, the bottom bar, the
/// toast surface, the dialog panel and the page switcher), which are composed out
/// of the fork's own parts.
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

/// The structural surfaces this adapter owns (§ surfaces): the `WidgetsApp` +
/// `WindTheme` host and a shell composed from the library's styled parts, since
/// it ships no navigation structure of its own.
const Set<LiveUiSurface> nativeSurfaces = <LiveUiSurface>{LiveUiSurface.appHost, LiveUiSurface.appShell};

/// §16/§11 integration pass for `live_uikit_wind`.
///
/// Wind renders the whole control contract and owns both structural surfaces, so
/// a switch into it replaces every rendering path at once. Switching to the core
/// another registered language and back still has to prove a caller-owned controller survives the
/// re-render (§11).
/// The downgrades this language is expected to report: none at all. Every control
/// is native and both surfaces — the `WidgetsApp` host and the composed shell —
/// are owned, so the derived checks below compare against empty sets and skip the
/// code assertions (§15.5/§16.8).
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
  const registry = LanguageRegistry(adapters: {LiveDesignLanguage.wind: windAdapter});
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
    final adapter = resolver.resolve(LiveDesignLanguage.wind);
    for (final control in LiveUiControl.values) {
      expect(adapter.capabilities.supports(control), nativeControls.contains(control), reason: '$control');
    }
    for (final control in nativeControls) {
      resolver.requireControl(LiveDesignLanguage.wind, control);
    }
  });

  testWidgets('Wind ↔ its own library widgets swaps the rendering path, not the state (§11)', (tester) async {
    final diagnostics = <LiveUiDiagnostic>[];
    final controller = TextEditingController(text: 'typed before the switch');
    addTearDown(controller.dispose);

    Widget page() => Column(
      children: [
        LiveTextField(controller: controller),
        LiveCard(onTap: () {}, child: const Text('card body')),
        LiveSwitch(value: true, onChanged: (_) {}),
        LiveSlider(value: 0.5, onChanged: (_) {}),
        const LiveProgress(value: 0.5),
        LiveSelect<String>(items: const ['a'], itemLabel: (item) => item, value: 'a', onChanged: (_) {}),
      ],
    );

    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.wind), page(), diagnostics));
    expect(find.byType(wind.WInput), findsOneWidget);
    expect(find.byType(wind.WCard), findsOneWidget);
    expect(find.byType(wind.WSwitch), findsOneWidget);
    expect(find.byType(wind.WSelect<String>), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    // Slider and progress are the fork's own parts now — a rail and a run drawn
    // as `WDiv`s — so no core-drawn control stands in for them inside a Wind page.
    expectUndeclaredControls(diagnostics);

    diagnostics.clear();
    await tester.pumpWidget(harness(const UiConfig(language: LiveDesignLanguage.wind), page(), diagnostics));
    expect(find.byType(wind.WInput), findsOneWidget);
    expect(find.byType(wind.WSelect<String>), findsOneWidget);
    expect(controller.text, 'typed before the switch');
    expectUndeclaredControls(diagnostics);
  });
}
